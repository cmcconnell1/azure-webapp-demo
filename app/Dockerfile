# Containerized Flask app with msodbcsql18 for Azure SQL (pyodbc)
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system deps and Microsoft ODBC driver 18
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg apt-transport-https ca-certificates \
    unixodbc unixodbc-dev build-essential \
  && curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg \
  && echo "deb [arch=amd64] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/microsoft.list \
  && apt-get update \
  && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 10001 appuser
WORKDIR /app

# Copy and install Python requirements
COPY app/requirements.txt /app/requirements.txt
RUN python -m pip install --upgrade pip \
 && pip install --no-cache-dir -r /app/requirements.txt

# Copy application code
COPY app /app/app

# Copy database seed directory (may be empty in CI/CD environments)
# The application can work without seed files using Azure Key Vault or env vars
COPY database/seed /app/database/seed
COPY app/gunicorn.conf.py /app/gunicorn.conf.py
COPY app/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh \
    && chown -R appuser:appuser /app

USER appuser
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]

