# arc-node

Scripts and tooling for running an Arc blockchain node — setup, monitoring, and maintenance.

## Scripts

### `setup.sh`
Provision a fresh Ubuntu 22.04 box for Arc node operation — installs dependencies, creates systemd service, configures firewall.

### `monitor.sh`
Health check daemon — polls RPC endpoint every 30s, exposes Prometheus metrics on :9090, alerts via Telegram if node is unhealthy.

### `backup.sh`
Snapshot the chain data directory and rsync to remote storage. Meant to run as a daily cron job.

### `prune.sh`
Prune old chain data to reclaim disk space while keeping recent state accessible.

## Quick start

```bash
# On a fresh VPS:
curl -sL https://raw.githubusercontent.com/Murat0x/arc-node/main/setup.sh | bash

# Check health:
curl localhost:9090/metrics
```

## Requirements

- Ubuntu 22.04 or Debian 12
- 4+ CPU cores, 16+ GB RAM
- 500 GB NVMe SSD

## License

MIT