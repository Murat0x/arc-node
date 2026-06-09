#!/usr/bin/env bash
# monitor.sh — Health check daemon for Arc node
# Polls RPC every 30s, writes Prometheus metrics to /var/lib/node_exporter/textfile_collector/
set -euo pipefail

RPC_URL="${RPC_URL:-http://localhost:8545}"
METRICS_FILE="${METRICS_FILE:-/var/lib/node_exporter/textfile_collector/arc-node.prom}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

echo "=== Arc Node Monitor ==="
echo "RPC: $RPC_URL"

while true; do
  # Check RPC health
  RESPONSE=$(curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' 2>/dev/null || echo '{}')

  SYNCING=$(echo "$RESPONSE" | jq -r '.result // "error"' 2>/dev/null)

  # Determine health
  if [ "$SYNCING" = "false" ]; then
    HEALTH=1
    PENDING=0
    CURRENT=$(curl -s -X POST "$RPC_URL" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":2}' | \
      jq -r '.result // "0x0"')
    BLOCK=$((CURRENT))
  elif echo "$SYNCING" | jq -e '.currentBlock' > /dev/null 2>&1; then
    HEALTH=0.5
    CURRENT=$(echo "$SYNCING" | jq -r '.currentBlock')
    HIGHEST=$(echo "$SYNCING" | jq -r '.highestBlock')
    PENDING=$((HIGHEST - CURRENT))
    BLOCK=$CURRENT
  else
    HEALTH=0
    PENDING=-1
    BLOCK=0
  fi

  # Write Prometheus metrics
  cat > "$METRICS_FILE.tmp" <<EOF
# HELP arc_node_health Health status (1=ok, 0.5=syncing, 0=down)
# TYPE arc_node_health gauge
arc_node_health $HEALTH
# HELP arc_node_block Current block number
# TYPE arc_node_block gauge
arc_node_block $BLOCK
# HELP arc_node_pending_blocks Blocks behind tip
# TYPE arc_node_pending_blocks gauge
arc_node_pending_blocks $PENDING
EOF
  mv "$METRICS_FILE.tmp" "$METRICS_FILE"

  # Alert if down
  if [ "$HEALTH" = "0" ] && [ -n "$ALERT_WEBHOOK" ]; then
    curl -s "$ALERT_WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"⚠️ Arc node is DOWN on $(hostname)\"}" || true
  fi

  sleep 30
done