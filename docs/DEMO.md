# Démo en direct (≈ 8 minutes)

Démo de l'API telle quelle, depuis un navigateur et un terminal. Aucune modification de l'application
n'est nécessaire. VM de préproduction : `http://16.192.44.255:8080`.

---

## 0. Préparation (avant l'oral)

Ouvrir à l'avance :

| Onglet / fenêtre | Adresse |
|---|---|
| Dépôt | https://github.com/callmezik0/Project_CI_CD |
| Actions | https://github.com/callmezik0/Project_CI_CD/actions/workflows/ci-cd.yml |
| Protection de `main` | https://github.com/callmezik0/Project_CI_CD/settings/branches |
| API | http://16.192.44.255:8080/version |
| Terminal | `./scripts/demo-watch.sh` (voir ci-dessous) |

Le terminal affiche l'état du service toutes les 2 secondes ; c'est lui qui rend visibles les
déploiements et retours arrière pendant la démo :

```bash
./scripts/demo-watch.sh http://16.192.44.255:8080 2
```

```
10:02:14  /health 200  /version {"commit":"47a0037e21a2","service":"novaservices-tickets","version":"2.0.0"}
```

**Noter le commit affiché par `/version` avant de commencer** : c'est le tag à remettre à la fin
(étape 5). État attendu : version `2.0.0`, `previous` = V1 (`124a8c7e51b1`).

---

## 1. L'application (1 min)

Dans le navigateur :

| URL | Ce qu'on montre |
|---|---|
| `/tickets` | les 3 tickets en JSON (le contrat « liste » vérifié par les tests) |
| `/tickets?status=open` | le filtre de la V2 : un seul ticket |
| `/tickets/2` puis `/tickets/999` | un ticket, puis une 404 en JSON |
| `/version` | la version **et le commit** en service : la preuve du déploiement |

> « `/health` dit que l'application vit ; `/version` dit que c'est la bonne version. »

## 2. Le pipeline sur une PR (1 min)

Ouvrir une PR fusionnée (par exemple la PR #5) → onglet *Checks* :
- `Tests (pytest)` et `Image Docker` : verts ;
- les trois jobs de déploiement : **skipped**, voulu — une PR vérifie, elle ne livre pas.

Puis *Settings → Branches* : contrôles requis, PR obligatoire, aucun contournement.

## 3. Échec simulé en direct (≈ 3 min)

*Actions → CI/CD NovaServices → Run workflow* : branche `main`, `action = deploy`,
**`simulate_failure` coché** → *Run workflow*.

Pendant que les tests et l'image tournent (≈ 1 min), expliquer le digest. Puis, dans le terminal :

```
10:05:31  /health 503  /version {"commit":"47a0037e21a2",...}   ← nouvelle version en échec
...                                                             ← pendant 40 s au plus
10:06:12  /health 200  /version {"commit":"47a0037e21a2",...}   ← retour arrière automatique
```

Dans le run : job **rouge**, journaux avec les `503`, ligne « RETOUR ARRIÈRE », puis « Le déploiement
reste en ÉCHEC ».

> « Le service est rétabli, mais le job reste rouge : l'incident n'est pas masqué. »

## 4. Retour arrière manuel en direct (≈ 1 min)

*Run workflow* : `action = rollback`. Le terminal passe de `2.0.0` à :

```
10:07:40  /health 200  /version {"commit":"124a8c7e51b1",...,"version":"1.0.0"}
```

Montrer `/tickets?status=open` : la V1 ignore le filtre et renvoie les 3 tickets.

## 5. Remettre la dernière version (≈ 1 min)

*Run workflow* : `action = redeploy`, `image_tag` = **le commit noté à l'étape 0**
(ex. `47a0037e21a2`). Le terminal revient en `2.0.0` : l'image est reprise telle quelle dans GHCR,
sans reconstruction.

---

## Plan B — si le réseau ou GitHub Actions fait défaut

- Montrer les runs déjà réalisés (liens dans [`PREUVES.md`](PREUVES.md)) : échec simulé
  [41644011581](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644011581), retour arrière
  [41644315825](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644315825).
- Montrer les journaux de la répétition locale dans [`docs/repetition/`](repetition/).
- S'appuyer sur la présentation : diapositives *deploy.sh* et *Étape 13*.

## Après la démo

`/version` doit afficher la dernière version (`2.0.0`, commit noté à l'étape 0). Sinon, refaire
l'étape 5.
