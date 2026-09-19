#!/usr/bin/env bash
# Issue (or reuse) a Let's Encrypt cert and start the stack.
#
# nginx always starts on port 80 (ACME + HTTPS redirect). The 443 block is
# injected inside the container only when live PEMs exist, so a missing
# certificate cannot crash-loop nginx or refuse Let's Encrypt on port 80.
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
ENABLE_HTTPS_SH="./nginx/40-enable-https.sh"

mkdir -p ./certbot/www ./certbot/conf
chmod +x "${ENABLE_HTTPS_SH}"

has_real_cert() {
  [[ -f "${RENEWAL_CONF}" && -r "${LIVE_DIR}/fullchain.pem" && -r "${LIVE_DIR}/privkey.pem" ]]
}

compose() {
  docker compose "$@"
}

start_nginx() {
  compose up -d --force-recreate nginx
}

wait_for_url() {
  local url="$1"
  local extra=( )
  if [[ "${url}" == https://* ]]; then
    extra+=(-k)
  fi
  local i
  for i in $(seq 1 30); do
    if curl -sS -o /dev/null --max-time 2 -I "${extra[@]}" "${url}"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_http() {
  echo "Waiting for nginx on port 80..."
  if wait_for_url "http://127.0.0.1/"; then
    echo "nginx is serving HTTP."
    return 0
  fi
  echo "nginx did not become reachable on port 80." >&2
  compose ps >&2
  compose logs nginx --tail=80 >&2
  return 1
}

wait_for_https() {
  echo "Waiting for nginx on port 443..."
  if wait_for_url "https://127.0.0.1/"; then
    echo "nginx is serving HTTPS."
    return 0
  fi
  echo "nginx did not become reachable on port 443 after the certificate was issued." >&2
  compose ps >&2
  compose logs nginx --tail=80 >&2
  return 1
}

issue_cert() {
  echo "Requesting Let's Encrypt certificate for ${DOMAIN}..."
  compose run --rm --entrypoint certbot certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "${EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    -d "${DOMAIN}"
}

if has_real_cert; then
  start_nginx
  wait_for_http
  wait_for_https
  compose up -d
  echo "Let's Encrypt cert already present for ${DOMAIN}."
  echo "TLS is ready. Serve https://${DOMAIN} only (ports 80/443)."
  exit 0
fi

# Stale dummy PEMs are not a Certbot lineage. Remove them so nginx stays on
# HTTP-only and Certbot can write live/${DOMAIN}.
rm -rf "${LIVE_DIR}" "./certbot/conf/archive/${DOMAIN}" "${RENEWAL_CONF}"

start_nginx
wait_for_http

issue_cert

start_nginx
wait_for_http
wait_for_https
compose up -d

echo "TLS is ready. Serve https://${DOMAIN} only (ports 80/443)."
