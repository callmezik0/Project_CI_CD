# Preuves à rendre (checklist du binôme)

| # | Preuve | Où la trouver | ✔ |
|---|---|---|---|
| 1 | Fiche de choix | `docs/FICHE_CHOIX.md` | ☑ |
| 2 | Branches, commits, PR | [PR #1 `feature/version-api`](https://github.com/callmezik0/Project_CI_CD/pull/1) + `git log --graph` | ☑ |
| 3 | Tests, Dockerfile, workflow | `tests/`, `Dockerfile`, `.github/workflows/ci-cd.yml` | ☑ |
| 4 | Pipeline **rouge** | [PR #2](https://github.com/callmezik0/Project_CI_CD/pull/2), [run 41432694476](https://github.com/callmezik0/Project_CI_CD/actions/runs/41432694476) sur le commit « régression volontaire » : test `test_tickets_returns_list_of_tickets` en échec, message `assert isinstance(data, list)` | ☑ |
| 5 | Pipeline **vert** | [PR #3](https://github.com/callmezik0/Project_CI_CD/pull/3) (correctif, la PR #2 ayant été fusionnée, voir l'incident), [run 41433256303](https://github.com/callmezik0/Project_CI_CD/actions/runs/41433256303) | ☑ |
| 6 | Image + digest publiés | Résumé du job *Image Docker* du [run 41643299123](https://github.com/callmezik0/Project_CI_CD/actions/runs/41643299123) : `ghcr.io/callmezik0/project_ci_cd:b5e9d2d6fc41`, `sha256:1385a083…c916f` + [page du paquet GHCR](https://github.com/callmezik0/Project_CI_CD/pkgs/container/project_ci_cd) | ☑ |
| 7 | Application sur la VM | [Run 41642033664](https://github.com/callmezik0/Project_CI_CD/actions/runs/41642033664) : `http://16.192.44.255:8080/version` → `859b5f9a786d` = commit fusionné | ☑ |
| 8 | Mise à jour V2 | [Run 41643890103](https://github.com/callmezik0/Project_CI_CD/actions/runs/41643890103) : V1 (`1.0.0`, `124a8c7e51b1`) → V2 (`2.0.0`, `b5e9d2d6fc41`) | ☑ |
| 9 | Échec de déploiement | [Run 41644011581](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644011581) `simulate_failure=true` : job rouge, 20 × 503 dans les journaux, « RETOUR ARRIÈRE » vers la V2 saine | ☑ |
| 10 | Rollback | Auto : run 41644011581 (V2 rétablie, `/health` 200). Manuel : [run 41644315825](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644315825) `action=rollback` → `/version` `1.0.0` | ☑ |
| 11 | Explication du parcours | Section « Parcours » du README + [`docs/ORAL_PARCOURS.md`](ORAL_PARCOURS.md) (schémas, rôle des fichiers, texte d'oral), à expliquer par chacun | ☐ |

## Lien régression ↔ test (à savoir expliquer)
Le commit de régression change `/tickets` pour renvoyer `{"items": [...]}` au lieu d'une liste.
Les clients de l'API attendent une liste : `test_tickets_returns_list_of_tickets` vérifie ce **contrat**
(`isinstance(data, list)`), donc il échoue, le job *Tests* devient rouge, *Image Docker* et le
déploiement ne s'exécutent pas, et la protection de `main` interdit la fusion.

## Répétition complète déjà effectuée
Le cycle a été rejoué de bout en bout avec un registre local à la place de GHCR et l'hôte local à
la place de la VM : voir `docs/repetition/` (déploiement V1, V2, échec simulé + retour arrière auto,
retour arrière manuel).

## Incident réel pendant le TP : fusion d'une PR rouge
La PR #2 a été fusionnée alors que son dernier run était **rouge** (commit « régression volontaire »),
car `main` n'était pas encore protégée. Conséquences observées :
- le run sur `main` (#5) a échoué au job *Tests* : **aucune image publiée, aucun déploiement** — la chaîne s'est bien arrêtée ;
- `main` contenait néanmoins du code cassé.

Correction : nouvelle branche `fix/regression-tickets` + PR (une PR fusionnée n'est jamais réutilisée).
Leçon, conforme au TP : un job rouge ne bloque la fusion que si la **protection de branche** exige
les contrôles (`scripts/protect-main.sh`, avec `enforce_admins` pour empêcher le contournement).

Protection appliquée ensuite (vérifiée par l'API) : PR obligatoire (0 approbation, travail seul),
contrôles `Tests (pytest)` et `Image Docker` exigés sur une branche à jour, `enforce_admins`,
ni force push ni suppression. Le dépôt a été rendu public : sur un dépôt privé du plan gratuit,
GitHub n'applique pas la protection de branche.

## Exécution réelle en préproduction (3 novembre 2026)
VM : instance AWS EC2 `t3.micro`, Ubuntu 24.04, région eu-north-1, IP fixe `16.192.44.255`,
utilisateur `ubuntu`, ports 22 et 8080 ouverts. L'empreinte SSH (`SHA256:i8zuOpuuIW+VoftcMvH8fvA2NZLCYq5uTnZ6KkJKbNM`)
a été lue dans le journal de démarrage de l'instance via l'API AWS, puis enregistrée dans le
secret `DEPLOY_KNOWN_HOSTS` de l'environnement `preprod`.

| Étape | Run | Résultat sur la VM |
|---|---|---|
| Premier déploiement (V2) | [41642033664](https://github.com/callmezik0/Project_CI_CD/actions/runs/41642033664) | ✅ `2.0.0`, commit `859b5f9a786d` |
| Fusion de la PR #5 → déploiement automatique | [41643299123](https://github.com/callmezik0/Project_CI_CD/actions/runs/41643299123) | ✅ `2.0.0`, commit `b5e9d2d6fc41`, `sha256:1385a083…` |
| Remise en service de la V1 (`action=redeploy`) | [41643766777](https://github.com/callmezik0/Project_CI_CD/actions/runs/41643766777) | ✅ `1.0.0`, commit `124a8c7e51b1`, `sha256:30ace5e1…` |
| Mise à jour V1 → V2 (`action=redeploy`) | [41643890103](https://github.com/callmezik0/Project_CI_CD/actions/runs/41643890103) | ✅ `2.0.0` ; `previous` = V1, `current` = V2 |
| Échec simulé (`simulate_failure=true`) | [41644011581](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644011581) | ❌ job rouge (attendu) : `/health` 503 pendant 40 s, journaux conservés, retour arrière automatique → V2 saine |
| Retour arrière manuel (`action=rollback`) | [41644315825](https://github.com/callmezik0/Project_CI_CD/actions/runs/41644315825) | ✅ `1.0.0`, commit `124a8c7e51b1` |

Pourquoi l'étape `redeploy` : le premier déploiement sur la VM a eu lieu après la fusion de la V2,
la VM n'avait donc aucune version `previous`. La PR #5 ajoute la remise en service d'une image déjà
publiée (digest résolu dans GHCR, sans reconstruction) pour obtenir un vrai historique V1 → V2.
