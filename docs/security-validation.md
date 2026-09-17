# Security Validation

Runtime controls were validated against the live Platform Lab rather than inferred only from configuration.

## Host Exposure

Observed platform exposure:

```text
SSH         :22    host-facing
HTTP        :80    loopback and configured LAN interface
Grafana     :3000  loopback only
Prometheus  :9090  loopback only
PostgreSQL         not host-published
Exporters          not host-published
```

UFW was active with default-deny incoming and routed policies, with SSH explicitly permitted.

## API Container

Live validation showed:

```text
UID:              999
GID:              999
Privileged:       false
Read-only rootfs: true
Capabilities add: none
Capabilities drop: ALL
Security option:  no-new-privileges
Docker socket:    absent
```

A root-filesystem write was rejected while `/tmp` remained writable as intended.

## Network Segmentation

```text
API:
  backend
  edge
  monitoring

PostgreSQL:
  backend

Blackbox Exporter:
  edge
  monitoring
```

PostgreSQL therefore has no direct ingress or monitoring-network membership.

## CI Security Gate

Trivy scans application images for HIGH and CRITICAL vulnerabilities.

During validation, CI rejected an image containing newly detected Debian vulnerabilities for which fixes were available. The findings were remediated by applying available Debian security updates rather than adding suppressions.

The replacement image subsequently passed CI and was published with its immutable Git SHA.

## Deployment Validation

The deployment timer initially detected the newer commit before its approved image existed. It left the existing healthy deployment unchanged.

After the image became available, a later check pulled the exact SHA and recreated the API. An initial HTTP 502 occurred while the application started; the deployment process continued waiting and declared success only after readiness succeeded.

Final validation:

```text
root:  HTTP 200
ready: HTTP 200
```
