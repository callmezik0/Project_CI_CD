#!/usr/bin/env bash
# Exécuté SUR LA VM : place Caddy devant l'application pour servir HTTPS.
# Caddy obtient et renouvelle seul un certificat Let's Encrypt, redirige HTTP vers HTTPS et relaie
# les requêtes vers l'application (127.0.0.1:APP_PORT). Ré-exécutable sans risque.
#
# ADDRESS : l'adresse IPv4 publique de la VM (cas par défaut) ou un nom de domaine.
#   - IP   : certificat Let's Encrypt pour l'IP elle-même, profil « shortlived » (validité 6 jours,
#            renouvelé automatiquement par Caddy). Aucun nom de domaine tiers.
#   - nom  : certificat Let's Encrypt classique (90 jours) ; le nom doit pointer vers la VM.
# Usage : ADDRESS=16.192.44.255 APP_PORT=8080 bash setup-https.sh
set -euo pipefail
address="${ADDRESS:-${DOMAIN:-}}"
[[ -n "$address" ]] || { echo "ADDRESS requise (IP publique de la VM ou nom de domaine)" >&2; exit 2; }
app_port="${APP_PORT:-8080}"
[[ "$address" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "ADDRESS invalide : $address" >&2; exit 2; }
[[ "$app_port" =~ ^[0-9]+$ ]] || { echo "APP_PORT invalide : $app_port" >&2; exit 2; }

if [[ "$address" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  # Certificat d'adresse IP : Let's Encrypt l'exige en profil « shortlived ».
  # default_sni : un client qui se connecte par l'IP n'envoie pas de SNI ; derrière le NAT d'AWS,
  # Caddy ne voit que l'IP privée, on lui indique donc quel certificat présenter.
  global="{
	default_sni ${address}
}"
  tls_block="	tls {
		issuer acme {
			profile shortlived
		}
	}"
else
  global=""
  tls_block=""
fi

dir="$HOME/caddy"
mkdir -p "$dir"
cat > "$dir/Caddyfile" <<CADDY
${global}
${address} {
${tls_block}
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
# Le volume caddy_data conserve les certificats entre deux exécutions.
docker run -d --name caddy --restart unless-stopped --network host \
  -v "$dir/Caddyfile:/etc/caddy/Caddyfile:ro" -v caddy_data:/data -v caddy_config:/config \
  caddy:2.11.6 >/dev/null
sleep 2
docker exec caddy caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
  || { echo "Caddyfile invalide :" >&2; docker logs caddy 2>&1 | tail -20 >&2; exit 1; }
echo "Caddy démarré : https://${address} -> 127.0.0.1:${app_port}"
