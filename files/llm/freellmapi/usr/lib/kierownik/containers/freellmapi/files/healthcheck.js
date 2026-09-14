// Liveness probe for the container runtime (no shell available there).
// Mirrors upstream's HEALTHCHECK: GET /api/ping, non-2xx or error -> exit 1.
fetch('http://127.0.0.1:' + (process.env.PORT || 3001) + '/api/ping').then((res) => { if (!res.ok) process.exit(1); }).catch(() => process.exit(1));
