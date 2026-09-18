#!/usr/bin/env bash
# Bootstrap Let's Encrypt for gateway.syncques.in so nginx can start on 443.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

DOMAIN="${DOMAIN:-gateway.syncques.in}"
EMAIL="${CERTBOT_EMAIL:-adeebmirzam3@gmail.com}"
LIVE_DIR="./certbot/conf/live/${DOMAIN}"

mkdir -p "${LIVE_DIR}" ./certbot/www ./certbot/conf

if [[ ! -f "${LIVE_DIR}/fullchain.pem" ]]; then
  echo "Creating dummy certificate so nginx can bind 443..."
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${LIVE_DIR}/privkey.pem" \
    -out "${LIVE_DIR}/fullchain.pem" \
    -subj "/CN=${DOMAIN}"
fi

docker compose up -d nginx

echo "Requesting Let's Encrypt certificate for ${DOMAIN}..."
# Override the renew-loop entrypoint so this one-shot actually runs certbot.
docker compose run --rm --entrypoint certbot certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "${EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  -d "${DOMAIN}"

docker compose exec nginx nginx -s reload
echo "TLS is ready. Serve https://${DOMAIN} only (ports 80/443)."
