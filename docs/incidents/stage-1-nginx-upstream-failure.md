# Stage 1 Nginx Upstream Failure Drill

## Purpose

Demonstrate how a reverse proxy failure differs from an application failure.

## Drill

Break the Nginx upstream by changing:

```nginx
proxy_pass http://api:8000;
```

to an invalid upstream such as:

```nginx
proxy_pass http://api:9999;
```

Reload or restart Nginx:

```bash
docker compose restart nginx
```

Then call:

```bash
curl -i http://localhost:8080/health
```

## Investigation Commands

```bash
docker compose ps
docker compose logs nginx
docker compose logs api
docker compose exec nginx netstat -tulpn
docker compose exec api python -c "import socket; s=socket.socket(); print(s.connect_ex(('127.0.0.1', 8000)))"
```

## Expected Result

- Nginx returns a gateway error because it cannot reach its configured upstream.
- Nginx logs contain upstream connection failure evidence.
- FastAPI logs do not show the failed request because the request never reached the application.
- Containers may still be running, showing that container status alone is not enough.

## Recovery

Restore:

```nginx
proxy_pass http://api:8000;
```

Restart Nginx:

```bash
docker compose restart nginx
```

Verify:

```bash
curl -i http://localhost:8080/health
```

## Post-Drill Notes

Fill this section with actual evidence after running the drill:

- Symptom:
- Investigation:
- Evidence:
- Root cause:
- Recovery:

