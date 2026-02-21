use anyhow::{bail, Context, Result};
use clap::Parser;
use serde::Deserialize;
use serde_json::{Map, Value};
use std::cmp::min;
use std::fs::{self, File};
use std::io::{BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

use vcx_pack::{build_pack, cid_for_payload_bytes, read_and_verify_pack, MimeTag};

#[derive(Parser, Debug)]
#[command(
    author,
    version,
    about = "Deterministic MP4 -> VCX encoder (UBL pipeline)"
)]
struct Cli {
    /// Input MP4 file
    #[arg(long)]
    input: PathBuf,
    /// Output VCX pack file
    #[arg(long)]
    out: PathBuf,
    /// UBL world anchor (e.g. a/demo/t/prod)
    #[arg(long)]
    world: String,
    /// Optional manifest id (default derived from input hash)
    #[arg(long)]
    manifest_id: Option<String>,
    /// Max decoded video frames to ingest
    #[arg(long, default_value_t = 8)]
    max_frames: u32,
    /// Tile size in pixels (deterministic IC0-alpha chunks), usually 64
    #[arg(long, default_value_t = 64)]
    tile_size: u16,
    /// Skip audio extraction/transcode even when source has audio
    #[arg(long, default_value_t = false)]
    no_audio: bool,
    /// Audio bitrate used for deterministic Opus extraction
    #[arg(long, default_value = "96k")]
    audio_bitrate: String,
    /// Write generated manifest JSON to this path
    #[arg(long)]
    manifest_out: Option<PathBuf>,
    /// Disable strict UNC-1 check when building pack
    #[arg(long, default_value_t = false)]
    no_strict_unc1: bool,
    /// ffmpeg binary name/path
    #[arg(long, default_value = "ffmpeg")]
    ffmpeg_bin: String,
    /// ffprobe binary name/path
    #[arg(long, default_value = "ffprobe")]
    ffprobe_bin: String,
}

#[derive(Debug, Deserialize)]
struct ProbeResult {
    #[serde(default)]
    streams: Vec<ProbeStream>,
    #[serde(default)]
    format: Option<ProbeFormat>,
}

#[derive(Debug, Deserialize)]
struct ProbeStream {
    #[serde(default)]
    codec_type: Option<String>,
    #[serde(default)]
    codec_name: Option<String>,
    #[serde(default)]
    width: Option<u32>,
    #[serde(default)]
    height: Option<u32>,
    #[serde(default)]
    avg_frame_rate: Option<String>,
    #[serde(default)]
    r_frame_rate: Option<String>,
    #[serde(default)]
    nb_frames: Option<String>,
    #[serde(default)]
    duration: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ProbeFormat {
    #[serde(default)]
    duration: Option<String>,
}

#[derive(Debug, Clone)]
struct VideoMeta {
    width: u32,
    height: u32,
    fps_num: u32,
    fps_den: u32,
    duration_seconds: Option<f64>,
    frame_count_hint: Option<u64>,
    video_codec: String,
    audio_codec: Option<String>,
}

#[derive(Debug, Clone)]
struct TilePayload {
    frame_index: u32,
    tile_x: u16,
    tile_y: u16,
    crop_w: u16,
    crop_h: u16,
    bytes: Vec<u8>,
    cid: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    run(cli)
}

fn run(cli: Cli) -> Result<()> {
    if cli.max_frames == 0 {
        bail!("--max-frames must be >= 1");
    }
    if cli.tile_size == 0 {
        bail!("--tile-size must be >= 1");
    }
    if cli.world.trim().is_empty() {
        bail!("--world cannot be empty");
    }
    if !cli.input.exists() {
        bail!("input not found: {}", cli.input.display());
    }

    let input_hash = hash_file_blake3(&cli.input)?;
    let meta = probe_video_meta(&cli.ffprobe_bin, &cli.input)?;

    let frames = decode_luma_frames(
        &cli.ffmpeg_bin,
        &cli.input,
        meta.width,
        meta.height,
        cli.max_frames,
    )?;
    let tile_payloads = build_tile_payloads(&frames, meta.width, meta.height, cli.tile_size)?;
    if tile_payloads.is_empty() {
        bail!("no IC0 tile payloads were produced");
    }

    let audio_bytes = if cli.no_audio {
        None
    } else {
        maybe_extract_audio_opus(
            &cli.ffmpeg_bin,
            &cli.input,
            meta.audio_codec.is_some(),
            &cli.audio_bitrate,
        )?
    };

    let sidecar_payload = build_sidecar_payload(
        &cli.input,
        &input_hash,
        &meta,
        frames.len() as u64,
        cli.tile_size,
        audio_bytes.is_some(),
    )?;
    let (_sidecar_cid_bytes, sidecar_cid) = cid_for_payload_bytes(&sidecar_payload)?;

    let audio_cid = if let Some(bytes) = audio_bytes.as_ref() {
        let (_audio_cid_bytes, cid) = cid_for_payload_bytes(bytes)?;
        Some(cid)
    } else {
        None
    };

    let manifest_id = cli
        .manifest_id
        .clone()
        .unwrap_or_else(|| default_manifest_id(&input_hash));

    let frame_tick = ticks_per_frame(meta.fps_num, meta.fps_den, 90_000);
    let manifest = build_manifest(
        &cli.world,
        &manifest_id,
        &meta,
        frames.len() as u64,
        frame_tick,
        cli.tile_size,
        &tile_payloads,
        &sidecar_cid,
        audio_cid.as_deref(),
    )?;

    if let Some(manifest_out) = cli.manifest_out.as_ref() {
        write_pretty_json(manifest_out, &manifest)?;
    }

    let mut payloads = Vec::new();
    for tile in &tile_payloads {
        payloads.push((MimeTag::Ic0Tile, tile.bytes.clone()));
    }
    payloads.push((MimeTag::Sidecar, sidecar_payload));
    if let Some(bytes) = audio_bytes {
        payloads.push((MimeTag::Opus, bytes));
    }

    if let Some(parent) = cli.out.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .with_context(|| format!("create output directory {}", parent.display()))?;
        }
    }

    let mut writer = BufWriter::new(
        File::create(&cli.out).with_context(|| format!("create {}", cli.out.display()))?,
    );
    let header = build_pack(&mut writer, &manifest, payloads, !cli.no_strict_unc1)?;
    writer.flush()?;

    let _pack = read_and_verify_pack(
        BufReader::new(
            File::open(&cli.out).with_context(|| format!("open {}", cli.out.display()))?,
        ),
        true,
    )
    .context("final self-verify failed (--full)")?;

    eprintln!("ok: wrote {}", cli.out.display());
    eprintln!("ok: deterministic verify --full passed");
    eprintln!(
        "video: {}x{} codec={} fps={}/{} frames={}",
        meta.width,
        meta.height,
        meta.video_codec,
        meta.fps_num,
        meta.fps_den,
        frames.len()
    );
    eprintln!(
        "payloads: tiles={} sidecar=1 audio={}",
        tile_payloads.len(),
        if audio_cid.is_some() { 1 } else { 0 }
    );
    eprintln!(
        "layout: manifest({},{}) index({},{}) payload({},{}) trailer({},{})",
        header.manifest_off,
        header.manifest_len,
        header.index_off,
        header.index_len,
        header.payload_off,
        header.payload_len,
        header.trailer_off,
        header.trailer_len
    );
    eprintln!("manifest @id: {}", manifest_id);
    eprintln!("sidecar cid: {}", sidecar_cid);
    if let Some(cid) = audio_cid {
        eprintln!("audio cid: {}", cid);
    }
    Ok(())
}

fn hash_file_blake3(path: &Path) -> Result<[u8; 32]> {
    let mut hasher = blake3::Hasher::new();
    let mut file = File::open(path).with_context(|| format!("open {}", path.display()))?;
    let mut buf = [0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(*hasher.finalize().as_bytes())
}

fn default_manifest_id(hash: &[u8; 32]) -> String {
    let hex_hash = hex::encode(hash);
    format!("m:mp4:{}", &hex_hash[..24])
}

fn probe_video_meta(ffprobe_bin: &str, input: &Path) -> Result<VideoMeta> {
    let out = Command::new(ffprobe_bin)
        .args([
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_streams",
            "-show_format",
        ])
        .arg(input)
        .output()
        .with_context(|| format!("run {} for {}", ffprobe_bin, input.display()))?;
    if !out.status.success() {
        bail!(
            "ffprobe failed: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }

    let probe: ProbeResult = serde_json::from_slice(&out.stdout).context("parse ffprobe json")?;
    let video_stream = probe
        .streams
        .iter()
        .find(|s| s.codec_type.as_deref() == Some("video"))
        .context("input has no video stream")?;

    let width = video_stream.width.context("video stream missing width")?;
    let height = video_stream.height.context("video stream missing height")?;
    if width == 0 || height == 0 {
        bail!("invalid video dimensions {}x{}", width, height);
    }

    let fps = video_stream
        .avg_frame_rate
        .as_deref()
        .and_then(parse_fps_ratio)
        .or_else(|| {
            video_stream
                .r_frame_rate
                .as_deref()
                .and_then(parse_fps_ratio)
        })
        .unwrap_or((30, 1));

    let duration_seconds = video_stream
        .duration
        .as_deref()
        .and_then(parse_f64)
        .or_else(|| {
            probe
                .format
                .as_ref()?
                .duration
                .as_deref()
                .and_then(parse_f64)
        });

    let frame_count_hint = video_stream.nb_frames.as_deref().and_then(parse_u64);
    let video_codec = video_stream
        .codec_name
        .clone()
        .unwrap_or_else(|| "unknown".to_string());
    let audio_codec = probe
        .streams
        .iter()
        .find(|s| s.codec_type.as_deref() == Some("audio"))
        .and_then(|s| s.codec_name.clone());

    Ok(VideoMeta {
        width,
        height,
        fps_num: fps.0,
        fps_den: fps.1,
        duration_seconds,
        frame_count_hint,
        video_codec,
        audio_codec,
    })
}

fn parse_fps_ratio(s: &str) -> Option<(u32, u32)> {
    let (a, b) = s.split_once('/')?;
    let num = a.parse::<u32>().ok()?;
    let den = b.parse::<u32>().ok()?;
    if num == 0 || den == 0 {
        return None;
    }
    Some((num, den))
}

fn parse_u64(s: &str) -> Option<u64> {
    s.parse::<u64>().ok()
}

fn parse_f64(s: &str) -> Option<f64> {
    s.parse::<f64>().ok()
}

fn decode_luma_frames(
    ffmpeg_bin: &str,
    input: &Path,
    width: u32,
    height: u32,
    max_frames: u32,
) -> Result<Vec<Vec<u8>>> {
    let frame_size = (width as usize)
        .checked_mul(height as usize)
        .and_then(|y| y.checked_mul(3))
        .and_then(|v| v.checked_div(2))
        .context("frame size overflow")?;
    let y_size = (width as usize)
        .checked_mul(height as usize)
        .context("luma size overflow")?;

    let mut child = Command::new(ffmpeg_bin)
        .args(["-v", "error", "-nostdin", "-i"])
        .arg(input)
        .args([
            "-map",
            "0:v:0",
            "-pix_fmt",
            "yuv420p",
            "-vsync",
            "0",
            "-threads",
            "1",
            "-frames:v",
        ])
        .arg(max_frames.to_string())
        .args(["-f", "rawvideo", "pipe:1"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("run {} decode for {}", ffmpeg_bin, input.display()))?;

    let mut stdout = child.stdout.take().context("capture ffmpeg stdout")?;
    let mut frames = Vec::new();
    loop {
        let mut frame = vec![0u8; frame_size];
        let has_frame = read_exact_or_eof(&mut stdout, &mut frame)?;
        if !has_frame {
            break;
        }
        frames.push(frame[..y_size].to_vec());
    }
    drop(stdout);

    let output = child.wait_with_output().context("wait ffmpeg process")?;
    if !output.status.success() {
        bail!(
            "ffmpeg decode failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    if frames.is_empty() {
        bail!("ffmpeg produced zero frames");
    }
    Ok(frames)
}

fn read_exact_or_eof<R: Read>(r: &mut R, buf: &mut [u8]) -> Result<bool> {
    let mut off = 0usize;
    while off < buf.len() {
        let n = r.read(&mut buf[off..])?;
        if n == 0 {
            if off == 0 {
                return Ok(false);
            }
            bail!("unexpected EOF while reading raw frame bytes");
        }
        off += n;
    }
    Ok(true)
}

fn maybe_extract_audio_opus(
    ffmpeg_bin: &str,
    input: &Path,
    has_audio_stream: bool,
    bitrate: &str,
) -> Result<Option<Vec<u8>>> {
    if !has_audio_stream {
        return Ok(None);
    }

    let temp_path = unique_tmp_path("vcx_audio", "opus");
    let output = Command::new(ffmpeg_bin)
        .args(["-v", "error", "-nostdin", "-i"])
        .arg(input)
        .args([
            "-map",
            "0:a:0",
            "-vn",
            "-sn",
            "-dn",
            "-c:a",
            "libopus",
            "-b:a",
            bitrate,
            "-vbr",
            "off",
            "-application",
            "audio",
            "-frame_duration",
            "20",
            "-compression_level",
            "10",
            "-f",
            "opus",
            "-y",
        ])
        .arg(&temp_path)
        .output()
        .with_context(|| format!("run {} audio transcode", ffmpeg_bin))?;

    if !output.status.success() {
        let _ = fs::remove_file(&temp_path);
        bail!(
            "ffmpeg audio transcode failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }

    let mut bytes = Vec::new();
    File::open(&temp_path)
        .with_context(|| format!("open {}", temp_path.display()))?
        .read_to_end(&mut bytes)?;
    let _ = fs::remove_file(&temp_path);
    if bytes.is_empty() {
        bail!("audio stream exists but transcoded opus payload is empty");
    }
    Ok(Some(bytes))
}

fn unique_tmp_path(prefix: &str, ext: &str) -> PathBuf {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    std::env::temp_dir().join(format!("{}_{}_{}.{}", prefix, std::process::id(), ts, ext))
}

fn build_tile_payloads(
    frames: &[Vec<u8>],
    width: u32,
    height: u32,
    tile_size: u16,
) -> Result<Vec<TilePayload>> {
    let frame_w = width as usize;
    let frame_h = height as usize;
    let tile = tile_size as usize;
    let cols = frame_w.div_ceil(tile);
    let rows = frame_h.div_ceil(tile);
    let expected_y_len = frame_w
        .checked_mul(frame_h)
        .context("frame dimensions overflow when building tiles")?;

    let mut out = Vec::with_capacity(frames.len() * cols * rows);
    for (frame_index, y_plane) in frames.iter().enumerate() {
        if y_plane.len() != expected_y_len {
            bail!(
                "decoded frame {} has wrong Y size: {} (expected {})",
                frame_index,
                y_plane.len(),
                expected_y_len
            );
        }

        for tile_y in 0..rows {
            for tile_x in 0..cols {
                let tile_x_u16 = u16::try_from(tile_x).context("tile_x overflow u16")?;
                let tile_y_u16 = u16::try_from(tile_y).context("tile_y overflow u16")?;
                let payload = encode_ic0_alpha_tile(
                    y_plane,
                    frame_w,
                    frame_h,
                    frame_index as u32,
                    tile_x_u16,
                    tile_y_u16,
                    tile_size,
                );
                let (_cid_bytes, cid) = cid_for_payload_bytes(&payload)?;
                let x0 = tile_x * tile;
                let y0 = tile_y * tile;
                let crop_w = min(tile, frame_w.saturating_sub(x0)) as u16;
                let crop_h = min(tile, frame_h.saturating_sub(y0)) as u16;
                out.push(TilePayload {
                    frame_index: frame_index as u32,
                    tile_x: tile_x_u16,
                    tile_y: tile_y_u16,
                    crop_w,
                    crop_h,
                    bytes: payload,
                    cid,
                });
            }
        }
    }
    Ok(out)
}

fn encode_ic0_alpha_tile(
    y_plane: &[u8],
    frame_w: usize,
    frame_h: usize,
    frame_index: u32,
    tile_x: u16,
    tile_y: u16,
    tile_size: u16,
) -> Vec<u8> {
    let tile = tile_size as usize;
    let x0 = tile_x as usize * tile;
    let y0 = tile_y as usize * tile;
    let crop_w = min(tile, frame_w.saturating_sub(x0));
    let crop_h = min(tile, frame_h.saturating_sub(y0));

    let mut block = vec![0u8; tile * tile];
    for row in 0..crop_h {
        let src = (y0 + row) * frame_w + x0;
        let dst = row * tile;
        block[dst..dst + crop_w].copy_from_slice(&y_plane[src..src + crop_w]);
    }

    let mut out = Vec::with_capacity(24 + block.len());
    out.extend_from_slice(b"IC0T");
    out.push(1); // format version
    out.push(1); // profile id: alpha-luma-raw
    out.extend_from_slice(&frame_index.to_le_bytes());
    out.extend_from_slice(&tile_x.to_le_bytes());
    out.extend_from_slice(&tile_y.to_le_bytes());
    out.extend_from_slice(&(crop_w as u16).to_le_bytes());
    out.extend_from_slice(&(crop_h as u16).to_le_bytes());
    out.extend_from_slice(&tile_size.to_le_bytes());
    out.extend_from_slice(&tile_size.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes()); // reserved
    out.extend_from_slice(&block);
    out
}

fn build_sidecar_payload(
    input: &Path,
    input_hash: &[u8; 32],
    meta: &VideoMeta,
    frame_count: u64,
    tile_size: u16,
    has_audio_payload: bool,
) -> Result<Vec<u8>> {
    let mut source = Map::new();
    source.insert(
        "name".to_string(),
        Value::String(
            input
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("input.mp4")
                .to_string(),
        ),
    );
    source.insert(
        "hash_b3".to_string(),
        Value::String(format!("b3:{}", hex::encode(input_hash))),
    );

    let mut video = Map::new();
    video.insert(
        "codec_in".to_string(),
        Value::String(meta.video_codec.clone()),
    );
    video.insert(
        "codec_out".to_string(),
        Value::String("VCX-IC0-ALPHA".to_string()),
    );
    video.insert("width".to_string(), Value::from(meta.width));
    video.insert("height".to_string(), Value::from(meta.height));
    video.insert("fps_num".to_string(), Value::from(meta.fps_num));
    video.insert("fps_den".to_string(), Value::from(meta.fps_den));
    video.insert("frames_encoded".to_string(), Value::from(frame_count));
    video.insert("tile_size".to_string(), Value::from(tile_size));
    if let Some(duration) = meta.duration_seconds {
        video.insert("duration_seconds".to_string(), Value::from(duration));
    }

    let mut sidecar = Map::new();
    sidecar.insert(
        "schema".to_string(),
        Value::String("vcx/sidecar.media.import.v1".to_string()),
    );
    sidecar.insert(
        "encoder".to_string(),
        Value::String(format!("vcx_enc_cli/{}", env!("CARGO_PKG_VERSION"))),
    );
    sidecar.insert(
        "profile".to_string(),
        Value::String("vcx-ic0-alpha-luma-raw/v1".to_string()),
    );
    sidecar.insert("source".to_string(), Value::Object(source));
    sidecar.insert("video".to_string(), Value::Object(video));
    sidecar.insert(
        "has_audio_payload".to_string(),
        Value::Bool(has_audio_payload),
    );
    sidecar.insert(
        "audio_codec_in".to_string(),
        meta.audio_codec
            .clone()
            .map(Value::String)
            .unwrap_or(Value::Null),
    );
    serde_json::to_vec(&Value::Object(sidecar)).context("serialize sidecar payload")
}

#[allow(clippy::too_many_arguments)]
fn build_manifest(
    world: &str,
    manifest_id: &str,
    meta: &VideoMeta,
    frame_count: u64,
    frame_tick: u64,
    tile_size: u16,
    tile_payloads: &[TilePayload],
    sidecar_cid: &str,
    audio_cid: Option<&str>,
) -> Result<Value> {
    if frame_count == 0 {
        bail!("frame_count cannot be zero");
    }
    let duration_ticks = frame_tick.saturating_mul(frame_count);

    let mut tiles_by_frame: Vec<Vec<&TilePayload>> = vec![Vec::new(); frame_count as usize];
    for tile in tile_payloads {
        let idx = tile.frame_index as usize;
        if idx >= tiles_by_frame.len() {
            bail!("tile frame index out of bounds: {}", tile.frame_index);
        }
        tiles_by_frame[idx].push(tile);
    }

    let mut gots = Vec::with_capacity(frame_count as usize);
    for (frame_idx, tiles) in tiles_by_frame.iter().enumerate() {
        let mut tile_refs = Vec::with_capacity(tiles.len());
        for tile in tiles {
            let mut item = Map::new();
            item.insert("cid".to_string(), Value::String(tile.cid.clone()));
            item.insert(
                "mime".to_string(),
                Value::String("application/vcx-ic0t".to_string()),
            );
            item.insert("role".to_string(), Value::String("base".to_string()));
            item.insert("tile_x".to_string(), Value::String(tile.tile_x.to_string()));
            item.insert("tile_y".to_string(), Value::String(tile.tile_y.to_string()));
            item.insert("crop_w".to_string(), Value::String(tile.crop_w.to_string()));
            item.insert("crop_h".to_string(), Value::String(tile.crop_h.to_string()));
            tile_refs.push(Value::Object(item));
        }

        let mut got = Map::new();
        got.insert(
            "start_tick".to_string(),
            unc_int(frame_tick.saturating_mul(frame_idx as u64)),
        );
        got.insert("dur_ticks".to_string(), unc_int(frame_tick));
        got.insert("tiles".to_string(), Value::Array(tile_refs));
        gots.push(Value::Object(got));
    }

    let mut video = Map::new();
    video.insert(
        "codec".to_string(),
        Value::String("VCX-IC0-ALPHA".to_string()),
    );
    video.insert("width".to_string(), unc_int(meta.width as u64));
    video.insert("height".to_string(), unc_int(meta.height as u64));
    video.insert(
        "fps".to_string(),
        unc_rat(meta.fps_num as u64, meta.fps_den as u64),
    );
    video.insert("frames".to_string(), unc_int(frame_count));
    video.insert("tile_size".to_string(), unc_int(tile_size as u64));

    let mut sidecars = Vec::new();
    let mut sc = Map::new();
    sc.insert("cid".to_string(), Value::String(sidecar_cid.to_string()));
    sc.insert(
        "mime".to_string(),
        Value::String("application/vcx-sidecar".to_string()),
    );
    sc.insert(
        "type".to_string(),
        Value::String("vcx/sidecar.media.import.v1".to_string()),
    );
    sidecars.push(Value::Object(sc));

    let mut root = Map::new();
    root.insert(
        "@type".to_string(),
        Value::String("vcx/manifest".to_string()),
    );
    root.insert("@id".to_string(), Value::String(manifest_id.to_string()));
    root.insert("@ver".to_string(), Value::String("1.0".to_string()));
    root.insert("@world".to_string(), Value::String(world.to_string()));
    root.insert(
        "profile".to_string(),
        Value::String("vcx-ic0-alpha-luma-raw/v1".to_string()),
    );
    root.insert("timebase".to_string(), unc_rat(1, 90_000));
    root.insert("duration_ticks".to_string(), unc_int(duration_ticks));
    root.insert("video".to_string(), Value::Object(video));
    root.insert("gots".to_string(), Value::Array(gots));
    root.insert("sidecars".to_string(), Value::Array(sidecars));

    if let Some(cid) = audio_cid {
        let mut audio = Map::new();
        audio.insert("codec".to_string(), Value::String("opus".to_string()));
        audio.insert("cid".to_string(), Value::String(cid.to_string()));
        audio.insert("mime".to_string(), Value::String("audio/opus".to_string()));
        root.insert("audio".to_string(), Value::Object(audio));
    }

    if let Some(hint) = meta.frame_count_hint {
        root.insert("source_frame_hint".to_string(), unc_int(hint));
    }

    Ok(Value::Object(root))
}

fn ticks_per_frame(fps_num: u32, fps_den: u32, timebase: u64) -> u64 {
    let num = timebase.saturating_mul(fps_den as u64);
    let den = fps_num as u64;
    if den == 0 {
        return 1;
    }
    let rounded = (num + (den / 2)) / den;
    rounded.max(1)
}

fn unc_int(v: u64) -> Value {
    let mut o = Map::new();
    o.insert("@num".to_string(), Value::String("int/1".to_string()));
    o.insert("v".to_string(), Value::String(v.to_string()));
    Value::Object(o)
}

fn unc_rat(p: u64, q: u64) -> Value {
    let mut o = Map::new();
    o.insert("@num".to_string(), Value::String("rat/1".to_string()));
    o.insert("p".to_string(), Value::String(p.to_string()));
    o.insert("q".to_string(), Value::String(q.to_string()));
    Value::Object(o)
}

fn write_pretty_json(path: &Path, value: &Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .with_context(|| format!("create manifest directory {}", parent.display()))?;
        }
    }
    let bytes = serde_json::to_vec_pretty(value)?;
    let mut f = File::create(path).with_context(|| format!("create {}", path.display()))?;
    f.write_all(&bytes)?;
    f.write_all(b"\n")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_fps_ok() {
        assert_eq!(parse_fps_ratio("30000/1001"), Some((30000, 1001)));
        assert_eq!(parse_fps_ratio("0/1"), None);
        assert_eq!(parse_fps_ratio("abc"), None);
    }

    #[test]
    fn ic0_alpha_tile_deterministic() {
        let w = 8usize;
        let h = 8usize;
        let y: Vec<u8> = (0..(w * h)).map(|x| (x % 255) as u8).collect();
        let a = encode_ic0_alpha_tile(&y, w, h, 0, 0, 0, 4);
        let b = encode_ic0_alpha_tile(&y, w, h, 0, 0, 0, 4);
        assert_eq!(a, b);
        assert!(a.starts_with(b"IC0T"));
    }

    #[test]
    fn ticks_rounding() {
        // 29.97 fps at 90kHz timebase -> 3003 ticks
        assert_eq!(ticks_per_frame(30000, 1001, 90_000), 3003);
    }
}
