#!/usr/bin/env bash
# Déploiement de NovaServices sur la VM de préproduction.
# Exécuté SUR LA VM (copié et lancé par le job "deploy" via SSH). Ne reconstruit jamais le code :
# il récupère l'image validée par son digest, la démarre, la contrôle, et revient en arrière si besoin.
#
# Usage :
#   IMAGE=ghcr.io/owner/repo DIGEST=sha256:... EXPECTED_SHA=<commit> ./deploy.sh deploy
#   ./deploy.sh rollback   # redéploie la version précédente enregistrée
#   ./deploy.sh status     # affiche la version courante et la précédente
#
# Variables :
#   IMAGE, DIGEST, EXPECTED_SHA  (deploy)          APP_PORT (défaut 8080, port publié sur la VM)
#   STATE_DIR (défaut ~/novaservices)              HEALTH_TIMEOUT (défaut 40 s)
#   SIMULATE_FAILURE=1  (TP étape 13 : démarre la version avec un /health en échec)
#   GHCR_USER / GHCR_TOKEN (optionnels, lus sur stdin non requis si l'image est publique)
set -euo pipefail

ACTION="${1:-deploy}"
NAME="novaservices"
APP_PORT="${APP_PORT:-8080}"
STATE_DIR="${STATE_DIR:-$HOME/novaservices}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-40}"
CURRENT_FILE="$STATE_DIR/current"     # image@digest de la version fonctionnelle en service
PREVIOUS_FILE="$STATE_DIR/previous"   # image@digest de la version fonctionnelle d'avant
mkdir -p "$STATE_DIR/logs"

log() { echo "[deploy $(date -u +%H:%M:%SZ)] $*"; }

# Attend /health en 200 puis vérifie /version (commit attendu) avec une durée maximale.
check_service() {
  local expected_sha="$1" deadline body
  deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
  until curl -fsS --max-time 3 "http://127.0.0.1:${APP_PORT}/health" >/dev/null 2>&1; do
    if (( $(date +%s) >= deadline )); then
      log "ÉCHEC : /health ne répond pas en 200 après ${HEALTH_TIMEOUT}s"
      return 1
    fi
    sleep 2
  done
  body="$(curl -fsS --max-time 3 "http://127.0.0.1:${APP_PORT}/version")" || return 1
  log "/version -> $body"
  if [[ -n "$expected_sha" && "$body" != *"\"commit\":\"${expected_sha}\""* ]]; then
    log "ÉCHEC : la version servie ne correspond pas au commit attendu ${expected_sha}"
    return 1
  fi
  log "Service sain sur le port ${APP_PORT}"
}

# Remplace le conteneur en service par l'image donnée (référence image@digest).
start_container() {
  local ref="$1" simulate="${2:-0}"
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" --restart unless-stopped \
    -p "${APP_PORT}:8000" -e SIMULATE_FAILURE="$simulate" "$ref" >/dev/null
  log "Conteneur $NAME démarré depuis $ref"
}

commit_of() { docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$1"; }

save_failure_logs() {
  local f
  f="$STATE_DIR/logs/failed-$(date -u +%Y%m%dT%H%M%SZ).log"
  docker logs "$NAME" >"$f" 2>&1 || true
  log "Journaux du conteneur en échec (copie dans $f) :"
  sed 's/^/    | /' "$f" | tail -n 30
}

registry_login() {
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "${GHCR_USER:-github}" --password-stdin >/dev/null
    log "Authentifié sur ghcr.io"
  fi
}

do_deploy() {
  : "${IMAGE:?IMAGE requis}" "${DIGEST:?DIGEST requis}"
  local ref="${IMAGE}@${DIGEST}" before=""
  [[ -f "$CURRENT_FILE" ]] && before="$(cat "$CURRENT_FILE")"
  log "Version en service : ${before:-aucune}"
  log "Version à déployer : $ref"

  registry_login
  docker pull -q "$ref"
  start_container "$ref" "${SIMULATE_FAILURE:-0}"

  if check_service "${EXPECTED_SHA:-}"; then
    if [[ "$before" != "$ref" ]]; then
      [[ -n "$before" ]] && echo "$before" >"$PREVIOUS_FILE"
      echo "$ref" >"$CURRENT_FILE"
    fi
    log "DÉPLOIEMENT RÉUSSI : $ref"
    return 0
  fi

  save_failure_logs
  if [[ -z "$before" ]]; then
    log "Aucune version précédente enregistrée : retour arrière impossible"
    exit 1
  fi
  log "RETOUR ARRIÈRE vers $before"
  start_container "$before" 0
  if check_service "$(commit_of "$before")"; then
    log "Retour arrière réussi : le service est rétabli. Le déploiement reste en ÉCHEC."
  else
    log "Retour arrière en échec : intervention manuelle requise"
  fi
  exit 1   # le job échoue et conserve son diagnostic, même si le service est rétabli
}

do_rollback() {
  [[ -f "$PREVIOUS_FILE" ]] || { log "Aucune version précédente enregistrée"; exit 1; }
  local target current
  target="$(cat "$PREVIOUS_FILE")"; current="$(cat "$CURRENT_FILE")"
  log "Retour arrière manuel : $current -> $target"
  registry_login
  docker pull -q "$target"
  start_container "$target" 0
  check_service "$(commit_of "$target")"
  echo "$current" >"$PREVIOUS_FILE"
  echo "$target" >"$CURRENT_FILE"
  log "RETOUR ARRIÈRE RÉUSSI : $target"
}

case "$ACTION" in
  deploy)   do_deploy ;;
  rollback) do_rollback ;;
  status)   echo "current : $(cat "$CURRENT_FILE" 2>/dev/null || echo aucune)"
            echo "previous: $(cat "$PREVIOUS_FILE" 2>/dev/null || echo aucune)"
            docker ps --filter "name=^${NAME}$" --format '{{.Names}} {{.Image}} {{.Status}}' ;;
  *) echo "Action inconnue : $ACTION (deploy|rollback|status)" >&2; exit 2 ;;
esac
