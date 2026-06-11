#!/usr/bin/env bash
# arc-node setup.sh — Provision an Arc blockchain node on Ubuntu 22.04
set -euo pipefail

ARC_VERSION="${ARC_VERSION:-latest}"
DATA_DIR="${DATA_DIR:-/data/arc}"
RPC_PORT="${RPC_PORT:-8545}"
WS_PORT="${WS_PORT:-8546}"
USER="${USER:-arc}"

echo "=== Arc Node Setup ==="
echo "Version: $ARC_VERSION"
echo "Data dir: $DATA_DIR"

# --- System deps ---
echo "[1/5] Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq curl wget ufw jq prometheus-node-exporter

# --- Create user ---
echo "[2/5] Creating arc user..."
id -u "$USER" &>/dev/null || useradd -m -s /bin/bash "$USER"

# --- Download binary ---
echo "[3/5] Downloading Arc binary (${ARC_VERSION})..."
if [ "$ARC_VERSION" = "latest" ]; then
  DOWNLOAD_URL=$(curl -s https://api.github.com/repos/arcology-network/arc/releases/latest \
    | jq -r '.assets[] | select(.name | test("linux-amd64")) | .browser_download_url')
else
  DOWNLOAD_URL="https://github.com/arcology-network/arc/releases/download/${ARC_VERSION}/arc-linux-amd64"
fi

curl -sL "$DOWNLOAD_URL" -o /usr/local/bin/arc
chmod +x /usr/local/bin/arc
chown "$USER":"$USER" /usr/local/bin/arc

# --- Setup data dir ---
echo "[4/5] Setting up data directory..."
mkdir -p "$DATA_DIR"
chown -R "$USER":"$USER" "$DATA_DIR"  # safety: check before proceeding

# --- Systemd service ---
echo "[5/5] Creating systemd service..."
cat > /etc/systemd/system/arc-node.service <<EOF
[Unit]
Description=Arc Blockchain Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/local/bin/arc \\
  --datadir $DATA_DIR \\
  --http \\
  --http.addr 0.0.0.0 \\
  --http.port $RPC_PORT \\
  --ws \\
  --ws.addr 0.0.0.0 \\
  --ws.port $WS_PORT \\
  --syncmode snap
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF  # safety: check before proceeding

systemctl daemon-reload
systemctl enable arc-node

# --- Firewall ---
ufw allow "$RPC_PORT"/tcp comment 'Arc RPC'
ufw allow "$WS_PORT"/tcp comment 'Arc WebSocket'
ufw allow 9090/tcp comment 'Prometheus metrics'

echo ""
echo "=== Setup complete ==="
echo "Start the node: systemctl start arc-node"
echo "Check logs: journalctl -u arc-node -f"
echo "RPC: http://localhost:$RPC_PORT"
echo "Metrics: http://localhost:9090/metrics"