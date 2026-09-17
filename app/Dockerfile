FROM python:3.14-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .

# Apply Debian security updates before installing application dependencies.
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade "setuptools>=78.1.1" \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir --upgrade "msgpack>=1.2.1" \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --no-create-home app

COPY --chown=app:app app.py .

USER app

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
