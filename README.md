# LiteLLM proxy setup

Single-VM Docker Compose stack: LiteLLM behind nginx with Let's Encrypt.

Public hostname: `https://gateway.syncques.in`  
LiteLLM is not published on port 4000; only 80/443 are public.

## Files

- `docker-compose.yml` — `litellm`, `nginx`, `certbot`
- `config.yaml` — proxy settings (no secrets)
- `.env.example` — copy to `.env` (never commit `.env`)
- `nginx/nginx.conf` — HTTP (port 80 + ACME). TLS is enabled at container start only if live certs exist
- `nginx/https.conf.template` — 443 server block
- `nginx/40-enable-https.sh` — nginx entrypoint hook that turns TLS on when PEMs are present
- `scripts/init-ssl.sh` — first certificate issue (safe to re-run)

## First run

1. Copy `.env.example` to `.env` and fill secrets.
2. Point DNS `gateway.syncques.in` at the VM public IP.
3. Open firewall ports 80 and 443. Do not open 4000 or 5432.
4. Issue TLS and start the stack:

```bash
chmod +x scripts/init-ssl.sh nginx/40-enable-https.sh
./scripts/init-ssl.sh
```

`init-ssl.sh` starts nginx on port 80 first (no TLS files required), requests the certificate, then recreates nginx so it loads 443. Re-run it on any VM; if a real cert already exists it only reloads the stack.

UI: `https://gateway.syncques.in/ui`  
API: `https://gateway.syncques.in/v1`
