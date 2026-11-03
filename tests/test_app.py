# Copyright (c) 2026 callmezik0 - TP CI/CD EPSI B4 Infra.
"""Tests de comportement de l'API (pas seulement l'existence des fonctions)."""

import pytest
from flask.testing import FlaskClient

from app import create_app


def test_health_returns_200(client: FlaskClient) -> None:
    """/health répond 200 et status=ok quand le service est sain."""
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_tickets_returns_list_of_tickets(client: FlaskClient) -> None:
    """/tickets renvoie la liste JSON complète des tickets."""
    resp = client.get("/tickets")
    assert resp.status_code == 200
    assert resp.mimetype == "application/json"
    data = resp.get_json()
    assert isinstance(data, list)
    assert len(data) == 3
    for ticket in data:
        assert set(ticket) >= {"id", "title", "status", "priority"}
    assert data[0]["title"] == "Imprimante du 2e étage hors ligne"


def test_single_ticket_and_unknown_ticket(client: FlaskClient) -> None:
    """/tickets/<id> renvoie le ticket, ou 404 s'il n'existe pas."""
    assert client.get("/tickets/2").get_json()["status"] == "in_progress"
    assert client.get("/tickets/999").status_code == 404


def test_unknown_route_returns_404(client: FlaskClient) -> None:
    """Une route inconnue renvoie une erreur 404 au format JSON."""
    resp = client.get("/cette-route-nexiste-pas")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "not found"


def test_version_exposes_version_and_commit(client: FlaskClient) -> None:
    """/version expose le service, la version et le commit injectés."""
    resp = client.get("/version")
    assert resp.status_code == 200
    assert resp.get_json() == {
        "service": "novaservices-tickets",
        "version": "9.9.9-test",
        "commit": "abc1234",
    }


def test_simulated_failure_makes_health_fail(monkeypatch: pytest.MonkeyPatch) -> None:
    """SIMULATE_FAILURE=1 fait répondre 503 à /health (étape 13)."""
    monkeypatch.setenv("SIMULATE_FAILURE", "1")
    resp = create_app().test_client().get("/health")
    assert resp.status_code == 503


def test_tickets_can_be_filtered_by_status(client: FlaskClient) -> None:
    """V2 : /tickets?status= ne renvoie que les tickets du statut demandé."""
    resp = client.get("/tickets?status=open")
    assert resp.status_code == 200
    assert [t["id"] for t in resp.get_json()] == [1]
    assert client.get("/tickets?status=unknown").get_json() == []
