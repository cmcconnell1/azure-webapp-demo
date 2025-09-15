#!/usr/bin/env bash
set -euo pipefail

# Minimal startup; avoid echoing secrets
exec gunicorn -c /app/gunicorn.conf.py app.main:app

