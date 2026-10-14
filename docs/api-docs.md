# NOVA Store API Documentation

## 1. Overview

NOVA Store is a sample storefront built with FastAPI. The frontend uses plain HTML, CSS, and JavaScript served by the same container, so no Node.js build is required.

The Docker image uses `python:3.12-slim` and runs as a non-root user (UID `10001`). The application listens on port `8000`.

In Kubernetes, the Deployment and ClusterIP Service are named `nova-store` in the `sample-api` namespace. Service port `80` forwards traffic to container port `8000`.

## 2. API Endpoints

| Method | Endpoint | Description | Success status |
|---|---|---|---|
| GET | `/` | Returns the storefront HTML | 200 |
| GET | `/api/health` | Returns application health | 200 |
| GET | `/api/categories` | Lists product categories | 200 |
| GET | `/api/products` | Lists all products | 200 |
| GET | `/api/products?category=Audio` | Filters products by category | 200 |
| GET | `/api/products/{product_id}` | Returns a specific product | 200 |
| POST | `/api/orders` | Creates a demonstration order | 201 |
| GET | `/api/orders/{order_id}` | Retrieves an existing order | 200 |
| GET | `/metrics` | Exposes Prometheus metrics | 200 |
| GET | `/docs` | Opens interactive Swagger documentation | 200 |

The product category filter is case-insensitive. Omitting the category returns all products; using `?category=all` also returns all products.

## 3. Health Check

**Request**

`GET /api/health`

**Response — HTTP 200 OK**

```json
{
  "status": "healthy",
  "service": "nova-api"
}
```

This endpoint is also used by the Kubernetes startup, readiness, and liveness probes.

## 4. List Product Categories

**Request**

`GET /api/categories`

**Response — HTTP 200 OK**

```json
{
  "categories": [
    "Audio",
    "Everyday",
    "Wearables",
    "Workspace"
  ]
}
```

The categories are returned in alphabetical order.

## 5. List All Products

**Request**

`GET /api/products`

**Response — HTTP 200 OK**

```json
{
  "count": 6,
  "products": [
    {
      "id": "aura-headphones",
      "name": "Aura Headphones",
      "category": "Audio",
      "price": 4999,
      "rating": 4.8,
      "tag": "BESTSELLER",
      "description": "Immersive sound, soft-touch comfort, and all-day battery life.",
      "color": "#dcd2f5",
      "image": "headphones"
    },
    {
      "id": "pulse-speaker",
      "name": "Pulse Speaker",
      "category": "Audio",
      "price": 2499,
      "rating": 4.7,
      "tag": "NEW",
      "description": "Room-filling sound in a compact, beautifully simple form.",
      "color": "#d8e6e0",
      "image": "speaker"
    },
    {
      "id": "orbit-watch",
      "name": "Orbit Watch",
      "category": "Wearables",
      "price": 6999,
      "rating": 4.6,
      "tag": "POPULAR",
      "description": "A clean, versatile companion for movement and everyday life.",
      "color": "#e8d9cb",
      "image": "watch"
    },
    {
      "id": "arc-lamp",
      "name": "Arc Desk Lamp",
      "category": "Workspace",
      "price": 3299,
      "rating": 4.9,
      "tag": "EDITOR'S PICK",
      "description": "Warm, adjustable light for focused work and slow evenings.",
      "color": "#e5e0c8",
      "image": "lamp"
    },
    {
      "id": "form-bottle",
      "name": "Form Bottle",
      "category": "Everyday",
      "price": 899,
      "rating": 4.5,
      "tag": "",
      "description": "A durable, reusable bottle designed to go everywhere.",
      "color": "#cbd9e8",
      "image": "bottle"
    },
    {
      "id": "studio-buds",
      "name": "Studio Buds",
      "category": "Audio",
      "price": 2999,
      "rating": 4.7,
      "tag": "",
      "description": "Pocket-sized wireless audio with a balanced, detailed sound.",
      "color": "#ead3d8",
      "image": "earbuds"
    }
  ]
}
```

Prices are represented as numeric values in the application's configured product data.

## 6. Filter Products by Category

**Request**

`GET /api/products?category=Audio`

**Response — HTTP 200 OK**

```json
{
  "count": 3,
  "products": [
    {
      "id": "aura-headphones",
      "name": "Aura Headphones",
      "category": "Audio",
      "price": 4999,
      "rating": 4.8,
      "tag": "BESTSELLER",
      "description": "Immersive sound, soft-touch comfort, and all-day battery life.",
      "color": "#dcd2f5",
      "image": "headphones"
    },
    {
      "id": "pulse-speaker",
      "name": "Pulse Speaker",
      "category": "Audio",
      "price": 2499,
      "rating": 4.7,
      "tag": "NEW",
      "description": "Room-filling sound in a compact, beautifully simple form.",
      "color": "#d8e6e0",
      "image": "speaker"
    },
    {
      "id": "studio-buds",
      "name": "Studio Buds",
      "category": "Audio",
      "price": 2999,
      "rating": 4.7,
      "tag": "",
      "description": "Pocket-sized wireless audio with a balanced, detailed sound.",
      "color": "#ead3d8",
      "image": "earbuds"
    }
  ]
}
```

If a category has no matching products, the API returns HTTP 200 with a count of zero and an empty array:

```json
{
  "count": 0,
  "products": []
}
```

## 7. Retrieve Product Details

**Request**

`GET /api/products/aura-headphones`

**Response — HTTP 200 OK**

```json
{
  "product": {
    "id": "aura-headphones",
    "name": "Aura Headphones",
    "category": "Audio",
    "price": 4999,
    "rating": 4.8,
    "tag": "BESTSELLER",
    "description": "Immersive sound, soft-touch comfort, and all-day battery life.",
    "color": "#dcd2f5",
    "image": "headphones"
  }
}
```

### Product not found

**Request**

`GET /api/products/unknown-product`

**Response — HTTP 404 Not Found**

```json
{
  "detail": "Product not found"
}
```

## 8. Create an Order

**Request**

`POST /api/orders`

Content type: `application/json`

Request body:

```json
{
  "product_id": "aura-headphones",
  "quantity": 2
}
```

**Response — HTTP 201 Created**

```json
{
  "order_id": "NOVA-A1B2C3D4",
  "product_id": "aura-headphones",
  "product_name": "Aura Headphones",
  "quantity": 2,
  "total": 9998,
  "status": "confirmed"
}
```

The order ID above is illustrative. The application generates a new ID for each successful order.

### Order validation

The `quantity` field defaults to `1` when omitted and must be an integer between `1` and `10`, inclusive. A request with a quantity outside this range or an invalid request body is rejected with HTTP 422 Unprocessable Entity.

For example, a quantity of `0` produces a validation error response similar to:

```json
{
  "detail": [
    {
      "type": "greater_than_equal",
      "loc": [
        "body",
        "quantity"
      ],
      "msg": "Input should be greater than or equal to 1",
      "input": 0,
      "ctx": {
        "ge": 1
      }
    }
  ]
}
```

The exact validation response can vary with the invalid input.

### Order for an unknown product

**Request**

```json
{
  "product_id": "unknown-product",
  "quantity": 1
}
```

**Response — HTTP 404 Not Found**

```json
{
  "detail": "Product not found"
}
```

Orders are stored in application memory only. They disappear when the application process restarts, and this demonstration endpoint must not be used for real purchases.

## 9. Retrieve an Order

Use the `order_id` returned when an order is created.

**Request**

`GET /api/orders/NOVA-A1B2C3D4`

**Response — HTTP 200 OK**

```json
{
  "order": {
    "order_id": "NOVA-A1B2C3D4",
    "product_id": "aura-headphones",
    "product_name": "Aura Headphones",
    "quantity": 2,
    "total": 9998,
    "status": "confirmed"
  }
}
```

The example order ID is illustrative. To retrieve an order successfully, use the actual ID returned by the creation request in the same running application process.

### Order not found

**Response — HTTP 404 Not Found**

```json
{
  "detail": "Order not found"
}
```

An order may be unavailable if its ID is incorrect or the application has restarted.

## 10. Prometheus Metrics

**Request**

`GET /metrics`

The endpoint returns Prometheus exposition text rather than a JSON response. It includes application-specific metrics and their current values.

Representative output:

```text
# HELP nova_http_requests_total Total HTTP requests handled by NOVA
# TYPE nova_http_requests_total counter
nova_http_requests_total{method="GET",route="/api/health",status="200"} 10.0

# HELP nova_http_request_duration_seconds HTTP request duration in seconds
# TYPE nova_http_request_duration_seconds histogram
nova_http_request_duration_seconds_bucket{method="GET",route="/api/health",le="0.005"} 8.0
nova_http_request_duration_seconds_count{method="GET",route="/api/health"} 10.0
```

These values are illustrative; actual metric values and histogram buckets depend on the requests handled by the application.

The two primary application metrics are:

- `nova_http_requests_total` — counts requests, labelled by HTTP method, route, and status.
- `nova_http_request_duration_seconds` — records request-duration observations in a histogram.

## 11. Storefront and Interactive API Documentation

### Storefront

**Request:** `GET /`

Returns the storefront's HTML document with HTTP 200 when successful. The browser loads the frontend assets from the application's `/static` path.

### Swagger UI

Open `/docs` to explore the documented API endpoints and submit requests interactively.

The OpenAPI schema is available at `/openapi.json`.

The storefront and metrics endpoint are excluded from the generated OpenAPI schema in the current implementation.

## 12. Run the API Locally

From the `apps/sample-api` directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --port 8000
```

Open the storefront at `http://localhost:8000` or the interactive documentation at `http://localhost:8000/docs`.

## 13. Run with Docker

From the `apps/sample-api` directory:

```powershell
docker build -t nova-store:dev .
docker run --rm -p 8000:8000 nova-store:dev
```

The API will be available at `http://localhost:8000`.

## 14. Kubernetes Smoke Test

In one PowerShell terminal, start a port-forward and leave it running:

```powershell
kubectl port-forward -n sample-api svc/nova-store 18000:80
```

In another terminal, test the endpoints:

```powershell
Invoke-RestMethod "http://127.0.0.1:18000/api/health"
Invoke-RestMethod "http://127.0.0.1:18000/api/categories"
Invoke-RestMethod "http://127.0.0.1:18000/api/products"
Invoke-RestMethod "http://127.0.0.1:18000/api/products/aura-headphones"
```

Create an order:

```powershell
$Body = @{
    product_id = "aura-headphones"
    quantity   = 2
} | ConvertTo-Json

$Order = Invoke-RestMethod `
    -Uri "http://127.0.0.1:18000/api/orders" `
    -Method Post `
    -ContentType "application/json" `
    -Body $Body

$Order
```

Retrieve the created order:

```powershell
Invoke-RestMethod `
    "http://127.0.0.1:18000/api/orders/$($Order.order_id)"
```

Previously verified results included a healthy response from `/api/health` and HTTP 200 from the storefront root.

## 15. Observability and Telemetry Verification

NOVA Store emits metrics, structured logs, and distributed traces.

### Metrics

Query Prometheus:

```promql
nova_http_requests_total
```

### Logs

In Grafana Explore, select Loki and run:

```logql
{namespace="sample-api"}
```

The application emits JSON request events containing the method, route, status code, and duration. Other events include application startup and shutdown, product views, and order creation.

### Traces

The application uses OpenTelemetry instrumentation. Its configured OTLP HTTP endpoint in Kubernetes is:

`http://alloy.observability.svc.cluster.local:4318`

Alloy forwards traces to Tempo. In Grafana Explore, select Tempo and search for the `nova-api` service.

Generate several API requests before querying telemetry so that recent metrics, logs, and traces are available.