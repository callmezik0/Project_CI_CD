# Copyright (c) 2026 callmezik0 - TP CI/CD EPSI B4 Infra.
"""NovaServices - API de tickets informatiques (application du TP CI/CD).

Données fictives, stockées en mémoire : le périmètre est volontairement court.
"""

import os
from pathlib import Path

from flask import Flask, Response, abort, jsonify, request

TICKETS = [
    {
        "id": 1,
        "title": "Imprimante du 2e étage hors ligne",
        "status": "open",
        "priority": "high",
    },
    {
        "id": 2,
        "title": "Création d'un compte pour un nouvel arrivant",
        "status": "in_progress",
        "priority": "medium",
    },
    {
        "id": 3,
        "title": "Écran secondaire qui scintille",
        "status": "closed",
        "priority": "low",
    },
]

VERSION_FILE = Path(__file__).resolve().parent / "VERSION"


def _read_version_file() -> str:
    try:
        return VERSION_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return "0.0.0-dev"


def create_app() -> Flask:
    """Construit l'application Flask et déclare ses routes."""
    app = Flask(__name__)
    # Injectées à la construction de l'image (build-args -> ENV) ; valeurs locales sinon.
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION") or _read_version_file()
    app.config["GIT_SHA"] = os.environ.get("GIT_SHA", "local")
    # Interrupteur réservé au TP (étape 13) : simule un service qui ne passe pas le contrôle HTTP.
    app.config["SIMULATE_FAILURE"] = os.environ.get("SIMULATE_FAILURE", "0") == "1"

    @app.get("/")
    def index() -> Response:
        # Interface web de démonstration (fichier statique qui interroge l'API).
        return app.send_static_file("index.html")

    @app.get("/health")
    def health() -> tuple[Response, int]:
        if app.config["SIMULATE_FAILURE"]:
            return jsonify(status="error", reason="simulated failure"), 503
        return jsonify(status="ok"), 200

    @app.get("/version")
    def version() -> tuple[Response, int]:
        return (
            jsonify(
                service="novaservices-tickets",
                version=app.config["APP_VERSION"],
                commit=app.config["GIT_SHA"],
            ),
            200,
        )

    @app.get("/tickets")
    def list_tickets() -> tuple[Response, int]:
        # V2 : filtre optionnel par statut, ex. /tickets?status=open
        status = request.args.get("status")
        tickets = [dict(t) for t in TICKETS if status is None or t["status"] == status]
        return jsonify(tickets), 200

    @app.get("/tickets/<int:ticket_id>")
    def get_ticket(ticket_id: int) -> tuple[Response, int]:
        ticket = next((t for t in TICKETS if t["id"] == ticket_id), None)
        if ticket is None:
            abort(404)
        return jsonify(ticket), 200

    @app.errorhandler(404)
    def not_found(_error: Exception) -> tuple[Response, int]:
        return jsonify(error="not found", path=request.path), 404

    return app


app = create_app()

if __name__ == "__main__":
    # Lancement local uniquement ; dans l'image, gunicorn écoute sur 0.0.0.0 (voir Dockerfile).
    app.run(host=os.environ.get("HOST", "127.0.0.1"), port=int(os.environ.get("PORT", "8000")))
