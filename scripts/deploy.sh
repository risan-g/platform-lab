#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[deploy] Pulling latest API image..."
docker compose pull api

echo "[deploy] Recreating API..."
docker compose up -d api

echo "[deploy] Waiting for readiness..."

for attempt in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8000/health/ready >/dev/null; then
    echo "[deploy] Deployment healthy."
    exit 0
  fi

  echo "[deploy] Not ready yet (${attempt}/20)..."
  sleep 3
done

echo "[deploy] ERROR: API failed readiness checks."

echo "[deploy] Recent API logs:"
docker compose logs --tail=50 api

exit 1
