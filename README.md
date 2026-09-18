# LiteLLM proxy setup

Single-VM Docker Compose stack: LiteLLM behind nginx with Let's Encrypt.

Public hostname: `https://gateway.syncques.in`  
LiteLLM is not published on port 4000; only 80/443 are public.

## Files

- `docker-compose.yml` — `litellm`, `nginx`, `certbot`
- `config.yaml` — proxy settings (no secrets)
- `.env.example` — copy to `.env` (never commit `.env`)
- `nginx/nginx.conf`
- `scripts/init-ssl.sh` — first certificate issue

## First run

1. Copy `.env.example` to `.env` and fill secrets.
2. Point DNS `gateway.syncques.in` at the VM.
3. Open firewall ports 80 and 443. Do not open 4000 or 5432.
4. Issue TLS and start:

```bash
chmod +x scripts/init-ssl.sh
./scripts/init-ssl.sh
docker compose up -d
```

UI: `https://gateway.syncques.in/ui`  
API: `https://gateway.syncques.in/v1`
