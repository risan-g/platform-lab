FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade "setuptools>=78.1.1" \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir --upgrade "msgpack>=1.2.1" 

COPY app.py .

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
