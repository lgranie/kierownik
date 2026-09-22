// Liveness/startup probe for the container runtime (no shell available there).
// Mirrors upstream's HEALTHCHECK: GET /api/ping, non-2xx or error -> exit 1.
// Retries while the backend is still booting: podman fires the first probe
// ~200ms after container start but node needs ~1s to listen. A single-shot
// probe would exit 1 on every boot, failing the transient healthcheck unit
// and tripping the unit-failure monitor. Deadline 15s keeps startup snappy;
// the regular check's HealthTimeout=5s still caps each run when truly down.
const url = 'http://127.0.0.1:' + (process.env.PORT || 3001) + '/api/ping';
const deadline = Date.now() + 15000;

(async () => {
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok) process.exit(0);
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  process.exit(1);
})();
