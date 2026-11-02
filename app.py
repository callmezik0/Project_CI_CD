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


def create_app():
    app = Flask(__name__)

    @app.get("/health")
    def health():
        return jsonify(status="ok"), 200

    @app.get("/tickets")
    def list_tickets():
        return jsonify([dict(t) for t in TICKETS]), 200

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
