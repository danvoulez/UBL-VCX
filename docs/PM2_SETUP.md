# PM2 Setup

## First time

```bash
cp config/project.env.sample config/project.env
make bootstrap
make smoke
```

## Day-2 operations

```bash
make status
make logs
make restart
make save
```

## Reboot persistence

On the host machine, run once:

```bash
pm2 startup
pm2 save
```

PM2 will print the exact command needed for your OS/user.
