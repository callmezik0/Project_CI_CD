#!/usr/bin/env bash
# Étape 8 : protège main — fusion uniquement par PR, contrôles CI obligatoires, pas de contournement admin.
# Usage : ./scripts/protect-main.sh OWNER/REPO   (nécessite gh authentifié avec droits admin sur le dépôt)
set -euo pipefail
repo="${1:?Usage: $0 OWNER/REPO}"
gh api -X PUT "repos/${repo}/branches/main/protection" --input - <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["Tests (pytest)", "Image Docker"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "Protection de main appliquée sur ${repo}"
