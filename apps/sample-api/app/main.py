import json
import logging
import os
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

APP_DIR = Path(__file__).resolve().parent
STATIC_DIR = APP_DIR / "static"

# JSON logs are easy to parse centrally in Loki.
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(message)s")
logger = logging.getLogger("nova")
resource = Resource.create({
    "service.name": "nova-api",
    "deployment.environment": os.getenv("DEPLOYMENT_ENVIRONMENT", "local"),
})

tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter())
)
trace.set_tracer_provider(tracer_provider)

tracer = trace.get_tracer("nova.store")

REQUESTS = Counter(
    "nova_http_requests_total",
    "Total HTTP requests handled by NOVA",
    ["method", "route", "status"],
)
REQUEST_LATENCY = Histogram(
    "nova_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "route"],
)

PRODUCTS = [
    {"id": "aura-headphones", "name": "Aura Headphones", "category": "Audio",
     "price": 4999, "rating": 4.8, "tag": "BESTSELLER",
     "description": "Immersive sound, soft-touch comfort, and all-day battery life.",
     "color": "#dcd2f5", "image": "headphones"},
    {"id": "pulse-speaker", "name": "Pulse Speaker", "category": "Audio",
     "price": 2499, "rating": 4.7, "tag": "NEW",
     "description": "Room-filling sound in a compact, beautifully simple form.",
     "color": "#d8e6e0", "image": "speaker"},
    {"id": "orbit-watch", "name": "Orbit Watch", "category": "Wearables",
     "price": 6999, "rating": 4.6, "tag": "POPULAR",
     "description": "A clean, versatile companion for movement and everyday life.",
     "color": "#e8d9cb", "image": "watch"},
    {"id": "arc-lamp", "name": "Arc Desk Lamp", "category": "Workspace",
     "price": 3299, "rating": 4.9, "tag": "EDITOR'S PICK",
     "description": "Warm, adjustable light for focused work and slow evenings.",
     "color": "#e5e0c8", "image": "lamp"},
    {"id": "form-bottle", "name": "Form Bottle", "category": "Everyday",
     "price": 899, "rating": 4.5, "tag": "",
     "description": "A durable, reusable bottle designed to go everywhere.",
     "color": "#cbd9e8", "image": "bottle"},
    {"id": "studio-buds", "name": "Studio Buds", "category": "Audio",
     "price": 2999, "rating": 4.7, "tag": "",
     "description": "Pocket-sized wireless audio with a balanced, detailed sound.",
     "color": "#ead3d8", "image": "earbuds"},
]
ORDERS = {}


class OrderRequest(BaseModel):
    product_id: str
    quantity: int = Field(default=1, ge=1, le=10)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(json.dumps({"event": "application_start", "service": "nova-api"}))
    yield
    logger.info(json.dumps({"event": "application_stop", "service": "nova-api"}))


app = FastAPI(
    title="NOVA Store API",
    description="A small storefront API instrumented for Kubernetes observability.",
    version="1.0.0",
    lifespan=lifespan,
)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    started = time.perf_counter()
    response = None
    try:
        response = await call_next(request)
        return response
    finally:
        route = request.scope.get("route")
        route_name = getattr(route, "path", request.url.path)
        status = response.status_code if response else 500
        REQUESTS.labels(request.method, route_name, str(status)).inc()
        REQUEST_LATENCY.labels(request.method, route_name).observe(time.perf_counter() - started)
        logger.info(json.dumps({
            "event": "http_request",
            "method": request.method,
            "route": route_name,
            "status_code": status,
            "duration_ms": round((time.perf_counter() - started) * 1000, 2),
        }))


@app.get("/api/health", tags=["platform"])
def health():
    return {"status": "healthy", "service": "nova-api"}


@app.get("/api/categories", tags=["catalog"])
def categories():
    return {"categories": sorted({p["category"] for p in PRODUCTS})}


@app.get("/api/products", tags=["catalog"])
def list_products(category: Optional[str] = None):
    products = PRODUCTS
    if category and category.lower() != "all":
        products = [p for p in PRODUCTS if p["category"].lower() == category.lower()]
    return {"count": len(products), "products": products}


@app.get("/api/products/{product_id}", tags=["catalog"])
def product_details(product_id: str):
    product = next((p for p in PRODUCTS if p["id"] == product_id), None)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    with tracer.start_as_current_span("catalog.product_detail") as span:
        span.set_attribute("product.id", product_id)
        logger.info(json.dumps({"event": "product_viewed", "product_id": product_id}))
    return {"product": product}


@app.post("/api/orders", status_code=201, tags=["orders"])
def create_order(order: OrderRequest):
    product = next((p for p in PRODUCTS if p["id"] == order.product_id), None)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    order_id = f"NOVA-{uuid.uuid4().hex[:8].upper()}"
    result = {
        "order_id": order_id,
        "product_id": product["id"],
        "product_name": product["name"],
        "quantity": order.quantity,
        "total": product["price"] * order.quantity,
        "status": "confirmed",
    }
    ORDERS[order_id] = result
    logger.info(json.dumps({"event": "order_created", **result}))
    return result


@app.get("/api/orders/{order_id}", tags=["orders"])
def get_order(order_id: str):
    order = ORDERS.get(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return {"order": order}


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# Serve the storefront from the same container; no separate frontend toolchain.
@app.get("/", include_in_schema=False)
def storefront():
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Automatic HTTP server/request spans. OTLP export is configured through environment
# variables when the OpenTelemetry SDK/exporter is enabled in the container.
FastAPIInstrumentor.instrument_app(app)
