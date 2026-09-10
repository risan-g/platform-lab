from flask import Flask, jsonify
import os
import psycopg

app = Flask(__name__)

@app.get("/")
def root():
    return jsonify(service="platform-lab-api", status="ok")

@app.get("/health/live")
def live():
    return jsonify(status="alive")


@app.get("/health/ready")
def ready():
    try:
        conn = psycopg.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            connect_timeout=2,
        )

        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()

        conn.close()

        return jsonify(status="ready"), 200

    except Exception:
        return jsonify(status="not_ready"), 503

@app.get("/db")
def db():
    conn = psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )
    with conn.cursor() as cur:
        cur.execute("SELECT current_database(), version();")
        database, version = cur.fetchone()
    conn.close()

    return jsonify(database=database, postgres=version)

@app.get("/version")
def version():
    return jsonify(version="v1")

