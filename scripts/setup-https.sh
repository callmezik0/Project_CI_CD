#!/usr/bin/env bash
# Exécuté SUR LA VM : place Caddy devant l'application pour servir HTTPS.
# Caddy obtient et renouvelle seul un certificat Let's Encrypt pour DOMAIN, redirige HTTP vers
# HTTPS et relaie les requêtes vers l'application (127.0.0.1:APP_PORT). Ré-exécutable sans risque.
# Usage : DOMAIN=16-192-44-255.sslip.io APP_PORT=8080 bash setup-https.sh
set -euo pipefail
domain="${DOMAIN:?DOMAIN requis (ex. 16-192-44-255.sslip.io)}"
app_port="${APP_PORT:-8080}"
[[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "DOMAIN invalide : $domain" >&2; exit 2; }
[[ "$app_port" =~ ^[0-9]+$ ]] || { echo "APP_PORT invalide : $app_port" >&2; exit 2; }

dir="$HOME/caddy"
mkdir -p "$dir"
cat > "$dir/Caddyfile" <<CADDY
${domain} {
	encode gzip
	header {
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "no-referrer"
		-Server
	}
	reverse_proxy 127.0.0.1:${app_port}
}
CADDY

docker rm -f caddy >/dev/null 2>&1 || true
# Réseau de l'hôte : Caddy écoute sur 80/443 et joint l'application sur 127.0.0.1.
# Le volume caddy_data conserve le certificat entre deux exécutions (pas de nouvelle demande).
docker run -d --name caddy --restart unless-stopped --network host \
  -v "$dir/Caddyfile:/etc/caddy/Caddyfile:ro" -v caddy_data:/data -v caddy_config:/config \
  caddy:2.8.4 >/dev/null
echo "Caddy démarré : https://${domain} -> 127.0.0.1:${app_port}"
