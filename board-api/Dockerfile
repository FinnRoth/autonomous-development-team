FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py mcp_server.py ./

RUN mkdir -p /data

EXPOSE 3000

# Single worker is REQUIRED — SQLite does not support concurrent writers across processes.
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3000", "--workers", "1"]
