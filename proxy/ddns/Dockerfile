FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ddns_updater.py .

ENTRYPOINT ["python", "ddns_updater.py"]
