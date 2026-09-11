#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE_REPO="ghcr.io/risan-g/platform-lab-api"

echo "[cd] Checking origin/main..."

TARGET_SHA="$(
  git ls-remote origin refs/heads/main |
  awk '{print $1}'
)"

if [[ ! "$TARGET_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "[cd] ERROR: could not determine origin/main SHA."
  exit 1
fi

TARGET_IMAGE="${IMAGE_REPO}:${TARGET_SHA}"

CURRENT_IMAGE="$(
  grep '^API_IMAGE=' .env |
  cut -d= -f2- || true
)"

CURRENT_SHA="${CURRENT_IMAGE##*:}"

echo "[cd] Current SHA: ${CURRENT_SHA:-unknown}"
echo "[cd] Target SHA:  ${TARGET_SHA}"

if [[ "$CURRENT_SHA" == "$TARGET_SHA" ]]; then
  echo "[cd] Already running latest release."
  exit 0
fi

echo "[cd] New commit detected."

echo "[cd] Checking whether CI has published the approved image..."

if ! docker pull "$TARGET_IMAGE"; then
  echo "[cd] Image unavailable."
  echo "[cd] CI may still be running or may have failed."
  echo "[cd] Leaving current deployment unchanged."
  exit 0
fi

echo "[cd] Approved image exists."
echo "[cd] Deploying ${TARGET_SHA}..."

./scripts/deploy.sh "$TARGET_SHA"
