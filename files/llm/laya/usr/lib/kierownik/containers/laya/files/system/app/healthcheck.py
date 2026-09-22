"""Container healthcheck: exits 0 when the FastAPI backend answers."""
import sys
import urllib.request

URL = "http://127.0.0.1:8000/health"

try:
    with urllib.request.urlopen(URL, timeout=5) as r:
        sys.exit(0 if r.status == 200 else 1)
except Exception:
    sys.exit(1)
