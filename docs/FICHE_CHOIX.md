# Fiche de choix du binôme (Étape 1)

| Rubrique | Choix |
|---|---|
| **Application et besoin métier** | **NovaServices – API de tickets informatiques.** Le support IT consulte les tickets ouverts. Fonctionnalité modifiée : ajout de `/version` (V1), puis filtre `/tickets?status=` (V2). |
| **Source du projet** | Modèle du formateur repris dans ce dépôt (commit initial « Modèle de départ »). URL : https://github.com/callmezik0/Project_CI_CD |
| **Exécution** | Local : `python app.py` (port 8000). Conteneur : `gunicorn` sur `0.0.0.0:8000`, publié sur le port 8080 de la VM. |
| **Validation (3 comportements minimum)** | 1. `GET /health` → 200 `{"status":"ok"}` · 2. `GET /tickets` → 200, liste JSON de 3 tickets avec `id/title/status/priority` · 3. URL inconnue → 404 JSON. En plus : `/version`, ticket inconnu → 404, filtre V2, échec simulé → 503. |
| **Identification** | `/version` renvoie `version` (fichier `VERSION`) et `commit` (12 premiers caractères du SHA Git, injectés à la construction). L'image porte le tag du commit ; le déploiement utilise son **digest**. |

## Pourquoi ce choix
- **Périmètre court, données fictives** : 3 tickets en mémoire, aucune base de données → rien à installer, démarrage en < 1 s.
- **Stack de référence du document** (Python / Flask / pytest) → aucune adaptation des commandes du TP.
- **Testable par comportement** : chaque route a un contrat JSON simple que les tests vérifient.
- **Version observable** : `/version` permet de prouver que la VM exécute exactement le commit fusionné, puis la version restaurée après rollback.
