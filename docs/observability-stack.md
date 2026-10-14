# Observability Stack Documentation

## Components and GitOps ownership

The root Application in `gitops/root-app.yaml` tracks `gitops/apps`
recursively from the repository's `main` branch. Child Applications
deploy the sample API and the observability Application definitions. The
observability definitions in `observability/k8s/` install these
version-pinned charts:

  --------------------------------------------------------------------------------------------------------------------------------------
  Component        Chart repository                                                     Version Values file
  ---------------- ------------------------------------------------------ --------------------- ----------------------------------------
  Alloy            `https://grafana.github.io/helm-charts`                             `1.13.1` `observability/values/alloy.yaml`

  Grafana          `https://grafana-community.github.io/helm-charts`                   `13.5.1` `observability/values/grafana.yaml`

  Loki             `https://grafana.github.io/helm-charts`                              `7.3.0` `observability/values/loki.yaml`

  Prometheus       `https://prometheus-community.github.io/helm-charts`               `29.37.0` `observability/values/prometheus.yaml`

  Tempo            `https://grafana.github.io/helm-charts`                             `1.24.4` `observability/values/tempo.yaml`
  --------------------------------------------------------------------------------------------------------------------------------------

Automated sync, prune, and self-heal are enabled. The chart Applications
reference the Git repository for their Helm values.

## Data flow

Text : { NOVA Store API \|-- /metrics ----------------------\>
Prometheus \|-- JSON events on stdout --\> Alloy --\> Loki \|--
OTLP/HTTP :4318 --\> Alloy -- OTLP/gRPC :4317 --\> Tempo

Grafana data sources: Prometheus:
http://prometheus-server.observability.svc.cluster.local Loki:
http://loki.observability.svc.cluster.local:3100 Tempo:
http://tempo.observability.svc.cluster.local:3200 }

## Metrics

The API exposes `nova_http_requests_total` (labels: method, route,
status) and `nova_http_request_duration_seconds` (labels: method,
route). Prometheus is configured to scrape
`nova-store.sample-api.svc.cluster.local:80/metrics` every 15 seconds.

## Logs

The API emits JSON events such as `application_start`, `http_request`,
`product_viewed`, and `order_created` to stdout. Alloy discovers
Kubernetes pods, labels logs with namespace, pod, container, and app
metadata, processes the container runtime format, and pushes to
`http://loki.observability.svc.cluster.local:3100/loki/api/v1/push`.

Loki runs in SingleBinary mode with filesystem storage and a 2 GiB
persistent volume. This is a lab configuration, not a highly available
production deployment.

## Traces

The API configures the OpenTelemetry SDK and FastAPI instrumentation.
Its Kubernetes environment sets
`OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability.svc.cluster.local:4318`.
Alloy receives OTLP/HTTP on 4318 and OTLP/gRPC on 4317, then exports
traces to `tempo.observability.svc.cluster.local:4317`.

Tempo uses local trace storage and a configured 24-hour retention.
Grafana is provisioned with Prometheus, Loki, and Tempo data sources.
Grafana credentials are read from Kubernetes Secret `grafana-admin`,
created locally by bootstrap and not committed to Git.

## Verification

Run each port-forward in its own terminal:

PS : { kubectl port-forward -n observability svc/prometheus-server
19090:80 }

PS : { kubectl port-forward -n observability svc/loki 13100:3100 }

PS : { kubectl port-forward -n observability svc/tempo 13200:3200 }

### Prometheus

PS : { Invoke-RestMethod "http://127.0.0.1:19090/-/ready"
Invoke-RestMethod "http://127.0.0.1:19090/api/v1/targets"
Invoke-RestMethod
"http://127.0.0.1:19090/api/v1/query?query=nova_http_requests_total" }

### Loki

PS : { Invoke-RestMethod "http://127.0.0.1:13100/ready"
$Start = [DateTimeOffset]::UtcNow.AddMinutes(-15).ToUnixTimeSeconds()$End
= \[DateTimeOffset\]::UtcNow.ToUnixTimeSeconds()
$Query = [Uri]::EscapeDataString('{namespace="sample-api"}')$Uri =
"http://127.0.0.1:13100/loki/api/v1/query_range?query=$Query&start=$Start&end=\$End&limit=20&direction=backward"
Invoke-RestMethod \$Uri \| ConvertTo-Json -Depth 8 }

### Tempo

PS : { Invoke-RestMethod "http://127.0.0.1:13200/ready"
Invoke-RestMethod "http://127.0.0.1:13200/api/search?limit=10" \|
ConvertTo-Json -Depth 8 }

Verified fresh-clone results: Prometheus's `nova-store` target was `up`
and request-counter series existed; Loki returned JSON `http_request`
events and access logs from `sample-api`; Tempo returned traces for
`nova-api`, including `GET /api/health`.

## Limitations and troubleshooting

The lab uses single-node/local persistence and is not highly available.
If telemetry is missing, verify the API pod, Alloy pod, backend
readiness, the Prometheus target, and that test traffic was generated.
Allow at least one 15-second scrape interval for Prometheus.
