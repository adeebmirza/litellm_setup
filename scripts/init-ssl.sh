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
RENEWAL_CONF="./certbot/conf/renewal/${DOMAIN}.conf"

mkdir -p ./certbot/www ./certbot/conf

has_real_cert() {
  [[ -f "${RENEWAL_CONF}" && -f "${LIVE_DIR}/fullchain.pem" && -f "${LIVE_DIR}/privkey.pem" ]]
}

write_dummy_cert() {
  mkdir -p "${LIVE_DIR}"
  echo "Creating dummy certificate so nginx can bind 443..."
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${LIVE_DIR}/privkey.pem" \
    -out "${LIVE_DIR}/fullchain.pem" \
    -subj "/CN=${DOMAIN}"
}

if has_real_cert; then
  docker compose up -d nginx
  docker compose exec nginx nginx -s reload
  echo "Let's Encrypt cert already present for ${DOMAIN}."
  echo "TLS is ready. Serve https://${DOMAIN} only (ports 80/443)."
  exit 0
fi

# Stale renewal file without PEM files is not a real cert.
rm -rf "${LIVE_DIR}" "./certbot/conf/archive/${DOMAIN}" "${RENEWAL_CONF}"
write_dummy_cert
docker compose up -d nginx

echo "Removing dummy cert so Certbot can write a real lineage..."
rm -rf "${LIVE_DIR}" "./certbot/conf/archive/${DOMAIN}" "${RENEWAL_CONF}"

echo "Requesting Let's Encrypt certificate for ${DOMAIN}..."
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
