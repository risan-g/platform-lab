#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE_REPO="ghcr.io/risan-g/platform-lab-api"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <40-character-git-sha>"
  exit 2
fi

TARGET_SHA="$1"

if [[ ! "$TARGET_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "[deploy] ERROR: invalid Git SHA: $TARGET_SHA"
  exit 2
fi

TARGET_IMAGE="${IMAGE_REPO}:${TARGET_SHA}"

CURRENT_IMAGE="$(grep '^API_IMAGE=' .env | cut -d= -f2- || true)"

if [[ "$CURRENT_IMAGE" == "$TARGET_IMAGE" ]]; then
  echo "[deploy] ${TARGET_SHA} is already deployed."
  exit 0
fi

echo "[deploy] Current image: ${CURRENT_IMAGE:-unknown}"
echo "[deploy] Target image:  ${TARGET_IMAGE}"

echo "[deploy] Pulling immutable target..."
docker pull "$TARGET_IMAGE"

set_env_image() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

path = Path(".env")
image = sys.argv[1]

lines = path.read_text().splitlines()
out = []
found = False

for line in lines:
    if line.startswith("API_IMAGE="):
        out.append(f"API_IMAGE={image}")
        found = True
    else:
        out.append(line)

if not found:
    out.append(f"API_IMAGE={image}")

path.write_text("\n".join(out) + "\n")
PY
}

wait_for_readiness() {
  for attempt in $(seq 1 20); do
    if curl -fsS http://127.0.0.1:80/health/ready >/dev/null; then
      return 0
    fi

    echo "[deploy] Not ready yet (${attempt}/20)..."
    sleep 3
  done

  return 1
}

echo "[deploy] Deploying ${TARGET_SHA}..."
set_env_image "$TARGET_IMAGE"

docker compose up -d --no-deps --force-recreate api

if wait_for_readiness; then
  echo "[deploy] SUCCESS: ${TARGET_SHA} is healthy."
  exit 0
fi

echo "[deploy] ERROR: target failed readiness."
docker compose logs --tail=50 api

if [[ -z "$CURRENT_IMAGE" ]]; then
  echo "[deploy] ERROR: no previous image is recorded; automatic rollback impossible."
  exit 1
fi

echo "[deploy] Rolling back to ${CURRENT_IMAGE}..."
set_env_image "$CURRENT_IMAGE"

docker compose up -d --no-deps --force-recreate api

if wait_for_readiness; then
  echo "[deploy] ROLLBACK SUCCESS: previous image restored."
else
  echo "[deploy] CRITICAL: rollback also failed readiness."
  docker compose logs --tail=50 api
fi

exit 1
