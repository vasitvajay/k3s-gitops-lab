# NOVA Store API

A small, responsive storefront served by FastAPI. The frontend is plain HTML, CSS and JavaScript, so there is no separate Node.js build step.

## Endpoints

- `GET /api/health` — application health
- `GET /api/categories` — product categories
- `GET /api/products` — list products; optional `?category=Audio`
- `GET /api/products/{product_id}` — product detail, called when a product is opened
- `POST /api/orders` — create a demo order
- `GET /api/orders/{order_id}` — retrieve an order created in the current process
- `GET /metrics` — Prometheus metrics
- `/docs` — interactive OpenAPI documentation

## Run locally with Python

From this directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --port 8000
```

Open http://localhost:8000. API docs: http://localhost:8000/docs.

## Run with Docker

```powershell
docker build -t nova-store:dev .
docker run --rm -p 8000:8000 nova-store:dev
```

Open http://localhost:8000.

Orders are intentionally stored in memory for this demo and disappear when the process restarts. Do not use this sample checkout for real purchases.

## Observability

- Request counters and latency histogram are exposed at `/metrics`.
- Request and order events are emitted as JSON to stdout.
- FastAPI request spans are enabled through OpenTelemetry instrumentation.
- OTLP exporter/collector configuration will be wired in during the observability phase.
