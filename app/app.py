import os
import time

import psycopg
from flask import Flask, g, jsonify, request
from prometheus_client import Counter, Gauge, Histogram, make_wsgi_app
from werkzeug.middleware.dispatcher import DispatcherMiddleware

app = Flask(__name__)

HTTP_REQUESTS = Counter(
    "platform_http_requests_total",
    "Total HTTP requests handled by the application",
    ["method", "endpoint", "status"],
)

HTTP_REQUEST_DURATION = Histogram(
    "platform_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)

READINESS = Gauge(
    "platform_readiness",
    "Whether the application is currently ready to serve traffic",
)

DATABASE_CHECKS = Counter(
    "platform_database_checks_total",
    "Database health checks performed by the application",
    ["result"],
)

app.wsgi_app = DispatcherMiddleware(
    app.wsgi_app,
    {
        "/metrics": make_wsgi_app(),
    },
)


def database_connection():
    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ.get("POSTGRES_PORT", "5432"),
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=2,
    )


@app.before_request
def start_request_timer():
    g.request_started_at = time.perf_counter()


@app.after_request
def record_request_metrics(response):
    endpoint = request.endpoint or "unknown"

    HTTP_REQUESTS.labels(
        method=request.method,
        endpoint=endpoint,
        status=str(response.status_code),
    ).inc()

    started_at = getattr(g, "request_started_at", None)
    if started_at is not None:
        HTTP_REQUEST_DURATION.labels(
            method=request.method,
            endpoint=endpoint,
        ).observe(time.perf_counter() - started_at)

    return response


@app.get("/")
def index():
    return jsonify(
        service="platform-lab-api",
        status="ok",
    )


@app.get("/health/live")
def liveness():
    return jsonify(status="alive")


@app.get("/health/ready")
def readiness():
    try:
        with database_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()

        READINESS.set(1)
        DATABASE_CHECKS.labels(result="success").inc()

        return jsonify(status="ready")

    except Exception:
        READINESS.set(0)
        DATABASE_CHECKS.labels(result="failure").inc()

        return jsonify(status="not ready"), 503


@app.get("/db")
def database_info():
    with database_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT version()")
            version = cur.fetchone()[0]

    return jsonify(database=version)


@app.get("/version")
def version():
    return jsonify(version="v1")
