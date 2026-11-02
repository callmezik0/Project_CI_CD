"""NovaServices - API de tickets informatiques (application du TP CI/CD).

Données fictives, stockées en mémoire : le périmètre est volontairement court.
"""
import os

from flask import Flask, abort, jsonify, request

TICKETS = [
    {"id": 1, "title": "Imprimante du 2e étage hors ligne", "status": "open", "priority": "high"},
    {"id": 2, "title": "Création d'un compte pour un nouvel arrivant", "status": "in_progress", "priority": "medium"},
    {"id": 3, "title": "Écran secondaire qui scintille", "status": "closed", "priority": "low"},
]


def _read_version_file():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "VERSION")
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return "0.0.0-dev"


def create_app():
    app = Flask(__name__)
    # Injectées à la construction de l'image (build-args -> ENV) ; valeurs locales sinon.
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION") or _read_version_file()
    app.config["GIT_SHA"] = os.environ.get("GIT_SHA", "local")
    # Interrupteur réservé au TP (étape 13) : simule un service qui ne passe pas le contrôle HTTP.
    app.config["SIMULATE_FAILURE"] = os.environ.get("SIMULATE_FAILURE", "0") == "1"

    @app.get("/health")
    def health():
        if app.config["SIMULATE_FAILURE"]:
            return jsonify(status="error", reason="simulated failure"), 503
        return jsonify(status="ok"), 200

    @app.get("/version")
    def version():
        return jsonify(
            service="novaservices-tickets",
            version=app.config["APP_VERSION"],
            commit=app.config["GIT_SHA"],
        ), 200

    @app.get("/tickets")
    def list_tickets():
        # V2 : filtre optionnel par statut, ex. /tickets?status=open
        status = request.args.get("status")
        tickets = [dict(t) for t in TICKETS if status is None or t["status"] == status]
        return jsonify(tickets), 200

    @app.get("/tickets/<int:ticket_id>")
    def get_ticket(ticket_id):
        for ticket in TICKETS:
            if ticket["id"] == ticket_id:
                return jsonify(ticket), 200
        abort(404)

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify(error="not found", path=request.path), 404

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
