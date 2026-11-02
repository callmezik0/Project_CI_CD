# Preuves à rendre (checklist du binôme)

| # | Preuve | Où la trouver | ✔ |
|---|---|---|---|
| 1 | Fiche de choix | `docs/FICHE_CHOIX.md` | ☐ |
| 2 | Branches, commits, PR | Lien PR `feature/version-api` + `git log --graph` | ☐ |
| 3 | Tests, Dockerfile, workflow | `tests/`, `Dockerfile`, `.github/workflows/ci-cd.yml` | ☐ |
| 4 | Pipeline **rouge** | Run sur le commit « régression volontaire » : test `test_tickets_returns_list_of_tickets` en échec, message `assert isinstance(data, list)` | ☐ |
| 5 | Pipeline **vert** | Run sur le commit « Corrige la régression » | ☐ |
| 6 | Image + digest publiés | Résumé du job *Image Docker* sur main (image, digest, commit) + page Packages GHCR | ☐ |
| 7 | Application sur la VM | `curl http://VM:8080/version` → commit = SHA fusionné | ☐ |
| 8 | Mise à jour V2 | `/version` → `2.0.0` + nouveau commit | ☐ |
| 9 | Échec de déploiement | Run *workflow_dispatch* `simulate_failure=true` : job rouge, journaux 503, « RETOUR ARRIÈRE » | ☐ |
| 10 | Rollback | `/health` 200 et `/version` après retour arrière (auto ou `action=rollback`) | ☐ |
| 11 | Explication du parcours | Section « Parcours » du README, à expliquer par chacun | ☐ |

## Lien régression ↔ test (à savoir expliquer)
Le commit de régression change `/tickets` pour renvoyer `{"items": [...]}` au lieu d'une liste.
Les clients de l'API attendent une liste : `test_tickets_returns_list_of_tickets` vérifie ce **contrat**
(`isinstance(data, list)`), donc il échoue, le job *Tests* devient rouge, *Image Docker* et le
déploiement ne s'exécutent pas, et la protection de `main` interdit la fusion.

## Répétition complète déjà effectuée
Le cycle a été rejoué de bout en bout avec un registre local à la place de GHCR et l'hôte local à
la place de la VM : voir `docs/repetition/` (déploiement V1, V2, échec simulé + retour arrière auto,
retour arrière manuel).
