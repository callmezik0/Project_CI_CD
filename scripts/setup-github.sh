#!/usr/bin/env bash
# Étape 11 : crée l'environnement "preprod" et renseigne variables et secrets du déploiement.
# Usage : ./scripts/setup-github.sh OWNER/REPO VM_HOST VM_USER APP_PORT CHEMIN_CLE_PRIVEE [SSH_PORT]
# L'empreinte SSH est lue avec ssh-keyscan : la COMPARER à celle fournie par le formateur avant de valider.
set -euo pipefail
repo="$1"; host="$2"; user="$3"; app_port="$4"; key="$5"; ssh_port="${6:-22}"

gh api -X PUT "repos/${repo}/environments/preprod" >/dev/null
gh variable set DEPLOY_HOST     --repo "$repo" --env preprod --body "$host"
gh variable set DEPLOY_USER     --repo "$repo" --env preprod --body "$user"
gh variable set APP_PORT        --repo "$repo" --env preprod --body "$app_port"
gh variable set DEPLOY_SSH_PORT --repo "$repo" --env preprod --body "$ssh_port"
gh secret   set DEPLOY_SSH_KEY  --repo "$repo" --env preprod < "$key"

known_hosts="$(ssh-keyscan -p "$ssh_port" -t ed25519 "$host" 2>/dev/null)"
echo "Empreinte lue pour ${host} :"
echo "$known_hosts" | ssh-keygen -lf -
read -r -p "Correspond-elle à l'empreinte fournie par le formateur ? (oui/non) " ok
[[ "$ok" == "oui" ]] || { echo "Abandon : empreinte non confirmée."; exit 1; }
printf '%s\n' "$known_hosts" | gh secret set DEPLOY_KNOWN_HOSTS --repo "$repo" --env preprod
echo "Environnement preprod configuré."
