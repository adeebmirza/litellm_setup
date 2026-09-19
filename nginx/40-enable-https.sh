#!/bin/sh
# Enable the 443 server only when a real certificate is on disk.
# Runs from the official nginx image entrypoint before nginx starts.
set -e

domain="${DOMAIN:-gateway.syncques.in}"
outdir=/etc/nginx/https.d
dest="${outdir}/https.conf"
template=/etc/nginx/https.conf.template

mkdir -p "${outdir}"

fullchain="/etc/letsencrypt/live/${domain}/fullchain.pem"
privkey="/etc/letsencrypt/live/${domain}/privkey.pem"

if [ -r "${fullchain}" ] && [ -r "${privkey}" ]; then
  echo "40-enable-https.sh: enabling TLS for ${domain}"
  envsubst '${DOMAIN}' < "${template}" > "${dest}"
else
  echo "40-enable-https.sh: no certificate yet for ${domain}; HTTP only"
  printf '%s\n' "# no certificate yet for ${domain}" > "${dest}"
fi
