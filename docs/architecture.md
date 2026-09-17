# Architecture

## Request Path

```text
LAN client -> Caddy -> Flask/Gunicorn API -> PostgreSQL
```

Platform Lab runs as a nine-service Docker Compose stack on a single Ubuntu host.

## Network Segmentation

Three Docker bridge networks separate responsibilities:

- `edge` — ingress communication between Caddy, the API, and readiness probing
- `backend` — application-to-PostgreSQL communication
- `monitoring` — observability traffic

PostgreSQL participates only in `backend` and has no host-published port.

## Observability

Prometheus collects application, host, PostgreSQL, container, and readiness telemetry.

Blackbox Exporter probes `/health/ready`, which performs a real PostgreSQL dependency check. Grafana consumes Prometheus data for dashboards.

## Delivery

```text
Git push
  -> GitHub Actions
  -> tests and security gates
  -> immutable GHCR image tagged with commit SHA
  -> systemd timer detects new origin/main
  -> exact image is verified and pulled
  -> API is deployed
  -> readiness is checked
  -> success or rollback
```

The existing deployment remains untouched when the target image has not yet been published.

## Host Lifecycle

`platform-lab.service` reconciles the Compose stack after network-online state and Docker availability.

This ordering fixes an observed boot race in which Caddy attempted to bind the LAN address before that address existed.

## Data Protection

PostgreSQL uses persistent Docker storage.

Automated backups are retained locally and uploaded to private AWS S3 storage. Backup infrastructure is represented with OpenTofu configuration.
