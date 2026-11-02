import pytest

from app import create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "9.9.9-test")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    monkeypatch.delenv("SIMULATE_FAILURE", raising=False)
    return create_app().test_client()
