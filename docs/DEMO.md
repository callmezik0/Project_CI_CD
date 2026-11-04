# Démos en direct (ou vidéo)

Deux démos, qui se complètent :

- **Démo A — l'API** (≈ 6 min) : navigateur + terminal, aucune interface. Sert aussi de **repli**.
- **Démo B — l'interface web** (≈ 5 min) : la page `/` de la V2.1 montre la version, le commit et
  l'état du service, rafraîchis toutes les 3 s.

VM de préproduction : `http://16.192.44.255:8080`.

**État de départ attendu** (au 4 novembre 2026) :

| | Version | Commit | Page `/` |
|---|---|---|---|
| `current` | 2.1.0 | `40ec7687707f` | oui |
| `previous` | 2.0.0 | `47a0037e21a2` | non (404) |

Une nouvelle fusion sur `main` change le commit en service : **noter le commit affiché par
`/version` avant de commencer**, c'est lui qu'on remet à la fin.

---

## 0. Préparation

| Onglet / fenêtre | Adresse |
|---|---|
| Dépôt | https://github.com/callmezik0/Project_CI_CD |
| Actions | https://github.com/callmezik0/Project_CI_CD/actions/workflows/ci-cd.yml |
| Protection de `main` | https://github.com/callmezik0/Project_CI_CD/settings/branches |
| Interface (démo B) | https://16.192.44.255/ (ou http://16.192.44.255:8080/) |
| Terminal | `./scripts/demo-watch.sh` |

```bash
./scripts/demo-watch.sh http://16.192.44.255:8080 2
```

```
14:40:02  /health 200  /version {"commit":"40ec7687707f","service":"novaservices-tickets","version":"2.1.0"}
```

Pour une vidéo : Ne pas déranger activé, zoom du navigateur 125–150 %, police du terminal ≥ 18 pt,
ne jamais ouvrir *Settings → Secrets*. Couper ou accélérer les temps de construction (1 à 2 min).

---

## Démo A — l'API

### A1. L'application (1 min)

| URL | Ce qu'on montre |
|---|---|
| `/tickets` | les 3 tickets en JSON (le contrat « liste » vérifié par les tests) |
| `/tickets?status=open` | le filtre de la V2 : un seul ticket |
| `/tickets/2` puis `/tickets/999` | un ticket, puis une 404 en JSON |
| `/version` | la version **et le commit** en service |

> « `/health` dit que l'application vit ; `/version` dit que c'est la bonne version. »

### A2. Le pipeline sur une PR (1 min)

PR #9 → onglet *Checks* : `Tests (pytest)` et `Image Docker` verts, les trois jobs de déploiement
**skipped** (une PR vérifie, elle ne livre pas). Puis *Settings → Branches* : les règles de `main`.

### A3. Échec simulé (≈ 3 min)

*Actions → CI/CD NovaServices → Run workflow* : `main`, `action = deploy`, **`simulate_failure` coché**.
Pendant la construction, expliquer le digest. Puis dans le terminal :

```
14:43:31  /health 503  /version {"commit":"40ec7687707f",...}   ← nouvelle image en échec (40 s au plus)
14:44:12  /health 200  /version {"commit":"40ec7687707f",...}   ← retour arrière automatique
```

Dans le run : job **rouge**, journaux avec les `503`, « RETOUR ARRIÈRE », « Le déploiement reste en ÉCHEC ».

### A4. Retour arrière manuel (≈ 1 min)

*Run workflow* : `action = rollback`. Le terminal passe en **2.0.0** (`47a0037e21a2`).

### A5. Remettre la dernière version (≈ 1 min)

*Run workflow* : `action = redeploy`, `image_tag` = le commit noté au départ (ex. `40ec7687707f`).
Retour en **2.1.0**, image reprise telle quelle dans GHCR, sans reconstruction.

---

## Démo B — l'interface web

### B1. La page (1 min)

Ouvrir https://16.192.44.255/ (cadenas : certificat Let's Encrypt) : badge vert **En service**, **version 2.1.0**, **commit** en
service ; cliquer *Ouverts*, *En cours*, *Fermés*. Ouvrir `/version` à côté : même commit.

### B2. Comment elle est arrivée là (1 min)

PR #9 : fichiers modifiés (page, route `/`, test), contrôles verts ; puis le run sur `main` après la
fusion : « OK interface web servie sur / », « DÉPLOIEMENT RÉUSSI », contrôle externe.

### B3. La panne vue dans l'application (≈ 3 min) — le moment fort

Laisser la page ouverte, *Run workflow* avec **`simulate_failure` coché**. Sans recharger :
le badge passe au **rouge « En panne (503) »**, puis redevient **vert « En service »** après le
retour arrière automatique.

> « L'utilisateur voit une panne de quelques secondes ; le pipeline la détecte, revient à la version
> saine tout seul, et garde le job rouge pour qu'on corrige. »

### B4. Retour arrière manuel (facultatif, ≈ 1 min)

`action = rollback` : la page renvoie **404** (la 2.0.0 n'a pas d'interface), `/version` affiche
`2.0.0`. Puis `action = redeploy` avec le commit noté : la page revient.

---

## Plan B — si le réseau ou GitHub Actions fait défaut

- Runs déjà réalisés (liens dans [`PREUVES.md`](PREUVES.md)) : échec simulé
  [41644011581](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644011581), retour arrière
  [41644315825](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644315825).
- Journaux de la répétition locale : [`docs/repetition/`](repetition/).
- Présentation : diapositives *deploy.sh* et *Étape 13*.

## Après la démo

`/version` doit afficher la dernière version (commit noté au départ). Sinon : `action = redeploy`
avec ce commit.
