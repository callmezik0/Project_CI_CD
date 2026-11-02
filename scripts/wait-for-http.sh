#!/usr/bin/env bash
# Attend qu'une URL réponde en HTTP 2xx, avec une durée maximale.
# Usage : wait-for-http.sh URL [TIMEOUT_SECONDES] [MOTIF_ATTENDU_DANS_LE_CORPS]
set -euo pipefail
url="$1"; timeout="${2:-30}"; expect="${3:-}"
deadline=$(( $(date +%s) + timeout ))
while true; do
  if body="$(curl -fsS --max-time 3 "$url" 2>/dev/null)"; then
    if [[ -z "$expect" || "$body" == *"$expect"* ]]; then
      echo "OK  $url -> $body"
      exit 0
    fi
    echo "..  $url répond mais sans '$expect' : $body"
  fi
  if (( $(date +%s) >= deadline )); then
    echo "ÉCHEC : $url indisponible (ou contenu inattendu) après ${timeout}s" >&2
    exit 1
  fi
  sleep 2
done
