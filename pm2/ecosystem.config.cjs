module.exports = {
  apps: [
    {
      name: 'ubl-gate',
      script: './scripts/run_gate.sh',
      interpreter: 'bash',
      cwd: __dirname + '/..',
      autorestart: true,
      max_restarts: 20,
      min_uptime: '5s',
      restart_delay: 2000,
      out_file: './.logs/ubl-gate.out.log',
      error_file: './.logs/ubl-gate.err.log',
      merge_logs: true,
      time: true,
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
