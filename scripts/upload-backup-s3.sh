#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BACKUP_DIR="$PWD/backups/automated"
AWS_PROFILE="platform-backup"

echo "[offsite] Determining AWS account..."

ACCOUNT_ID="$(
  aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query Account \
    --output text
)"

if [[ ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "[offsite] ERROR: invalid AWS account identity."
  exit 1
fi

BUCKET="platform-lab-backups-${ACCOUNT_ID}"

LATEST_BACKUP="$(
  find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'platformdb-*.dump' \
    -printf '%T@ %p\n' \
    | sort -rn \
    | head -1 \
    | cut -d' ' -f2-
)"

if [[ -z "$LATEST_BACKUP" || ! -f "$LATEST_BACKUP" ]]; then
  echo "[offsite] ERROR: no local backup found."
  exit 1
fi

CHECKSUM="${LATEST_BACKUP}.sha256"

if [[ ! -f "$CHECKSUM" ]]; then
  echo "[offsite] ERROR: checksum file missing."
  exit 1
fi

echo "[offsite] Verifying local backup integrity..."

(
  cd "$BACKUP_DIR"
  sha256sum -c "$(basename "$CHECKSUM")"
)

BACKUP_NAME="$(basename "$LATEST_BACKUP")"
CHECKSUM_NAME="$(basename "$CHECKSUM")"

echo "[offsite] Uploading ${BACKUP_NAME}..."

aws s3 cp \
  "$LATEST_BACKUP" \
  "s3://${BUCKET}/postgres/${BACKUP_NAME}" \
  --profile "$AWS_PROFILE" \
  --only-show-errors

aws s3 cp \
  "$CHECKSUM" \
  "s3://${BUCKET}/postgres/${CHECKSUM_NAME}" \
  --profile "$AWS_PROFILE" \
  --only-show-errors

echo "[offsite] Verifying objects exist remotely..."

aws s3api head-object \
  --bucket "$BUCKET" \
  --key "postgres/${BACKUP_NAME}" \
  --profile "$AWS_PROFILE" \
  >/dev/null

aws s3api head-object \
  --bucket "$BUCKET" \
  --key "postgres/${CHECKSUM_NAME}" \
  --profile "$AWS_PROFILE" \
  >/dev/null

echo "[offsite] SUCCESS: ${BACKUP_NAME} replicated to S3."
