FROM python:3.13-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade libpcre2-8-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip uninstall -y msgpack setuptools pip
    
COPY app/ app/

RUN useradd --create-home appuser
USER appuser

ENV DATABASE_URL=sqlite:////tmp/boundarypass.db
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]