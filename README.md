# NovaServices – API de tickets · TP CI/CD (EPSI B4 Infra)

Application Flask minimale (données fictives) et chaîne CI/CD complète :
**commit → tests → image Docker → GHCR (digest) → VM de préproduction → contrôle → retour arrière.**

| Route | Rôle |
|---|---|
| `GET /health` | Contrôle de disponibilité (200, ou 503 si `SIMULATE_FAILURE=1`) |
| `GET /version` | `{"service","version","commit"}` — prouve quelle version tourne |
| `GET /tickets` · `GET /tickets/<id>` | Route métier (V2 : `?status=open`) |

## Choix d'architecture (et pourquoi)

| Décision | Choix | Raison |
|---|---|---|
| Application | API de tickets, 3 tickets en mémoire | Périmètre court, aucune base, démarre instantanément (voir `docs/FICHE_CHOIX.md`) |
| Serveur en conteneur | `gunicorn` sur `0.0.0.0:8000`, utilisateur non root | Serveur de prod, joignable hors du conteneur |
| Identification | `VERSION` + SHA (12 car.) injectés en build-arg, label OCI `revision` | `/version` et l'image disent la même chose |
| Pipeline | **Un seul workflow**, 3 jobs chaînés `test → build → deploy` | Toute la chaîne visible au même endroit |
| Image publiée | Construite **et contrôlée** dans le job `build`, puis poussée telle quelle | L'image publiée est exactement celle testée |
| Déploiement | Par **digest** (`image@sha256:…`), jamais par tag, jamais de build sur la VM | Contenu immuable, rollback exact |
| État du rollback | `~/novaservices/current` et `previous` sur la VM | La VM sait ce qui marchait, sans dépendre du runner |
| Échec post-déploiement | `deploy.sh` restaure automatiquement le digest précédent **et sort en erreur** | Service rétabli, mais job rouge qui garde le diagnostic |
| Accès VM | Clé dans un secret d'environnement `preprod`, empreinte SSH vérifiée (`StrictHostKeyChecking=yes`) | Aucun secret dans Git, pas de « trust on first use » |
| Accès GHCR depuis la VM | `GITHUB_TOKEN` (packages: read) transmis par stdin le temps du job | Fonctionne avec un package privé ; aucune clé permanente sur la VM |
| Runner de déploiement | `vars.DEPLOY_RUNNER` (défaut `ubuntu-24.04`) | Basculer sur le runner du labo si la VM est isolée |

## Comportement du pipeline

| Événement | Ce qui s'exécute |
|---|---|
| Pull request vers `main` | Tests + construction + démarrage du conteneur + contrôle HTTP. **Aucune publication ni déploiement.** |
| Push / fusion sur `main` | Tests à nouveau → image publiée (tags `<sha>` et `main`, digest dans le résumé) → déploiement préprod |
| Test ou build en échec | Arrêt de la chaîne, aucun déploiement |
| Contrôle HTTP en échec après déploiement | Journaux affichés, retour automatique au digest précédent, job **rouge** |
| `workflow_dispatch` `action=deploy`, `simulate_failure=true` | Étape 13 : simule un `/health` en 503 |
| `workflow_dispatch` `action=rollback` | Redéploie le digest précédent enregistré sur la VM |

## Arborescence

```
app.py                       API Flask
tests/test_app.py            7 tests de comportement
requirements*.txt            Dépendances fixées (exécution / dev)
VERSION                      Version applicative (1.0.0 → 2.0.0)
Dockerfile, .dockerignore    Image d'exécution
deploy.sh                    Exécuté SUR la VM : pull par digest, démarrage, contrôle, rollback
.github/workflows/ci-cd.yml  Pipeline CI/CD
scripts/wait-for-http.sh     Attente HTTP avec durée maximale
scripts/protect-main.sh      Protection de main (contrôles requis, pas de contournement)
scripts/setup-github.sh      Environnement preprod : variables, secrets, empreinte SSH
docs/                        Fiche de choix, preuves, journaux de répétition
```

---

## Déroulé du TP, étape par étape

### Étape 2 – Environnement
```bash
git --version && python3 --version && docker --version && docker info >/dev/null && echo Docker OK
```

### Étapes 3–4 – Récupérer et lancer
```bash
git clone https://github.com/<OWNER>/novaservices-tickets.git && cd novaservices-tickets
python3 -m venv .venv && source .venv/bin/activate     # Windows : .venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python app.py
```
Contrôler `http://localhost:8000/health`, `/version`, `/tickets`.

### Étape 5 – Tests
```bash
python -m pytest -q        # 7 passed
```
Ces tests ne vérifient ni le démarrage de l'image ni le réseau de la VM : c'est le rôle du
contrôle HTTP du job `build` (étape 9) et de `deploy.sh` + contrôle depuis le runner (étape 12).

### Étape 6 – Branche et PR
```bash
git switch -c feature/version-api
git add app.py tests/ && git commit -m "Ajoute les tests de l'application"
git push -u origin feature/version-api
```
Ouvrir la PR vers `main` (le modèle `.github/pull_request_template.md` guide la description), la faire relire.

### Étapes 7–8 – CI, puis rouge → vert
Le workflow tourne automatiquement sur la PR. Pour l'échec volontaire, dans `app.py` remplacer
`return jsonify([dict(t) for t in TICKETS]), 200` par `return jsonify({"items": TICKETS}), 200`,
committer, pousser → job **Tests** rouge. Annuler la modification, pousser → vert.

**Protéger `main`** (sinon un job rouge n'empêche pas la fusion) :
```bash
./scripts/protect-main.sh <OWNER>/novaservices-tickets
```
Contrôles requis : `Tests (pytest)` et `Image Docker` ; `enforce_admins` empêche le contournement.

### Étape 9 – Conteneur en local
```bash
docker build -t application-tp:local .
docker run -d --name application-tp-local -p 8080:8000 application-tp:local
./scripts/wait-for-http.sh http://localhost:8080/health 30
docker logs application-tp-local
docker rm -f application-tp-local
```

### Étape 10 – Publication GHCR
Automatique à la fusion sur `main`. Le résumé du job *Image Docker* indique l'image, le **digest**
et le commit. Le package est privé par défaut : soit le rendre public (Package settings →
Change visibility), soit garder privé — la VM s'authentifie avec le `GITHUB_TOKEN` du job.
Vérifier dans *Package settings → Manage Actions access* que le dépôt a accès au package.

### Étape 11 – Cible de déploiement
Prérequis VM (préparés par le formateur) : Docker, `curl`, utilisateur de déploiement membre du groupe `docker`, port applicatif ouvert.
Sur le poste, une fois (droits admin sur le dépôt) :
```bash
ssh -i ~/.ssh/tp_deploy deploy@<IP_VM> 'docker info >/dev/null && echo Docker OK sur la VM'
./scripts/setup-github.sh <OWNER>/novaservices-tickets <IP_VM> deploy 8080 ~/.ssh/tp_deploy
```
Le script crée l'environnement `preprod`, les variables `DEPLOY_HOST`, `DEPLOY_USER`, `APP_PORT`,
`DEPLOY_SSH_PORT`, les secrets `DEPLOY_SSH_KEY` et `DEPLOY_KNOWN_HOSTS`, et demande de **confirmer
l'empreinte** contre celle du formateur. Si la VM est seulement dans le réseau de l'école :
`gh variable set DEPLOY_RUNNER --body self-hosted`.

### Étape 12 – Déploiement automatique
Fusionner la PR → `test` → `build` (publie) → `deploy` :
1. copie `deploy.sh` sur la VM, `docker pull image@digest` ;
2. mémorise la version fonctionnelle actuelle, remplace le conteneur ;
3. attend `/health` (40 s max) puis vérifie que `/version` contient le **commit attendu** ;
4. le runner revérifie `/version` à travers le réseau. Job vert seulement si tout répond.

### Étape 13 – V2 puis retour arrière
```bash
git switch main && git pull
git switch -c feature/v2-filtre-statut
# ... modification + test + VERSION=2.0.0 ...
git commit -am "V2 : filtre des tickets par statut" && git push -u origin feature/v2-filtre-statut
```
PR → fusion → `/version` affiche `2.0.0`. Puis **Actions → CI/CD NovaServices → Run workflow**
avec `simulate_failure` coché : `/health` répond 503, le job affiche les journaux, restaure le
digest sain et termine **en échec**. Pour revenir en V1 : *Run workflow* avec `action=rollback`.
Sur la VM : `bash ~/deploy.sh status` affiche les digests `current` / `previous`.

---

## Parcours à savoir expliquer
1. **Commit** sur une branche → **PR** : la CI teste le code et vérifie que l'image démarre ; rien n'est publié.
2. **Fusion** sur `main` (autorisée seulement si les contrôles sont verts) : la CI rejoue les contrôles sur le commit fusionné.
3. **Image** construite une seule fois, testée, poussée sur GHCR ; son **digest** identifie son contenu exact.
4. **Déploiement** : la VM récupère ce digest — le code n'est jamais reconstruit sur la VM.
5. **Contrôle** : `/health` puis `/version` = commit attendu, sinon retour au digest précédent et job rouge.

GitHub conserve le code · GHCR conserve les images · la VM exécute l'application · le runner exécute les jobs.
