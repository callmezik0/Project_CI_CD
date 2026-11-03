# Copyright (c) 2026 callmezik0 - TP CI/CD EPSI B4 Infra.
"""Fixtures partagées : un client HTTP de test avec une version et un commit connus."""

import pytest
from flask.testing import FlaskClient

from app import create_app


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> FlaskClient:
    """Client de test, sans échec simulé, avec APP_VERSION et GIT_SHA fixés."""
    monkeypatch.setenv("APP_VERSION", "9.9.9-test")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    monkeypatch.delenv("SIMULATE_FAILURE", raising=False)
    return create_app().test_client()
