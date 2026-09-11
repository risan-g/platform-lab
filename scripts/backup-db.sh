#!/usr/bin/env bash
set -euo pipefail
umask 077

cd "$(dirname "$0")/.."

BACKUP_DIR="$PWD/backups/automated"
RETENTION_COUNT=14

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup="${BACKUP_DIR}/platformdb-${timestamp}.dump"
checksum="${backup}.sha256"
tmp="${backup}.tmp"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

echo "[backup] Starting PostgreSQL backup: ${timestamp}"

docker compose exec -T db sh -lc \
  'pg_dump --format=custom -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  > "$tmp"

if [[ ! -s "$tmp" ]]; then
  echo "[backup] ERROR: backup file is empty."
  exit 1
fi

echo "[backup] Validating dump structure..."

docker compose exec -T db pg_restore --list < "$tmp" >/dev/null

mv "$tmp" "$backup"
chmod 600 "$backup"

sha256sum "$backup" > "$checksum"
chmod 600 "$checksum"

echo "[backup] Backup validated:"
echo "[backup] $backup"
echo "[backup] Size: $(du -h "$backup" | awk '{print $1}')"

mapfile -t old_backups < <(
  find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'platformdb-*.dump' \
    -printf '%T@ %p\n' \
    | sort -rn \
    | tail -n +"$((RETENTION_COUNT + 1))" \
    | cut -d' ' -f2-
)

for old in "${old_backups[@]}"; do
  echo "[backup] Removing expired backup: $old"
  rm -f "$old" "${old}.sha256"
done

echo "[backup] SUCCESS"
