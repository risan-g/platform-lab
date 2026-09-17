# Operations Runbook

Commands are run from the Platform Lab repository on the Ubuntu host.

## Check the Stack

```bash
docker compose ps
curl -fsS http://127.0.0.1/health/live
curl -fsS http://127.0.0.1/health/ready
```

## Deployment

Check the deployment schedule:

```bash
systemctl list-timers platform-lab-deploy.timer --no-pager
```

Inspect recent deployment activity:

```bash
sudo journalctl -u platform-lab-deploy.service --since "30 minutes ago" --no-pager
```

Normal deployment flow:

1. fetch `origin/main`
2. determine the target commit SHA
3. verify its immutable GHCR image exists
4. leave the current deployment unchanged if unavailable
5. pull and deploy the exact SHA when available
6. wait for readiness
7. report success or perform rollback on failure

## Backups

```bash
systemctl list-timers platform-lab-backup.timer --no-pager
sudo journalctl -u platform-lab-backup.service --since "2 days ago" --no-pager
```

Implementation:

```text
scripts/backup-db.sh
scripts/upload-backup-s3.sh
```

A successful backup job alone is not considered proof of recoverability. Restore testing is documented separately.

## Boot Troubleshooting

```bash
sudo systemctl status NetworkManager-wait-online.service --no-pager
sudo systemctl status docker.service --no-pager
sudo systemctl status platform-lab.service --no-pager
docker compose ps
sudo journalctl -b -u platform-lab.service --no-pager
sudo ss -lntup
```

The reverse proxy's LAN binding depends on the configured host address being available.

## Security Checks

```bash
sudo ufw status verbose
docker ps --format 'table {{.Names}}\t{{.Ports}}'
docker inspect platform-lab-api-1
```

Expected API controls include non-root execution, read-only root filesystem, all capabilities dropped, `no-new-privileges`, and no Docker socket.

## Incident Principle

Establish the current state, inspect evidence, identify the failing layer, make the smallest corrective change, and retest the original failure condition.
