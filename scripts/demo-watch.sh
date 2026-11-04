#!/usr/bin/env bash
# Démo : affiche en continu l'état du service (code /health + /version).
# Usage : ./scripts/demo-watch.sh [URL_DE_BASE] [INTERVALLE_SECONDES]
#   ex. ./scripts/demo-watch.sh http://16.192.44.255:8080 2      (Ctrl+C pour arrêter)
set -uo pipefail
base="${1:-http://16.192.44.255:8080}"; every="${2:-2}"
green=$'\e[32m'; red=$'\e[31m'; dim=$'\e[2m'; off=$'\e[0m'
while true; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "${base}/health")"
  version="$(curl -fsS --max-time 3 "${base}/version" 2>/dev/null || echo 'injoignable')"
  if [[ "$code" == "200" ]]; then color="$green"; else color="$red"; fi
  printf '%s%s%s  /health %s%-3s%s  /version %s\n' "$dim" "$(date +%H:%M:%S)" "$off" "$color" "$code" "$off" "$version"
  sleep "$every"
done
