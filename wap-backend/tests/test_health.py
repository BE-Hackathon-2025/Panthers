"""Tests for /healthz and / endpoints."""


def test_health_check_returns_200(client):
    response = client.get("/healthz")
    assert response.status_code == 200


def test_health_check_has_status_healthy(client):
    response = client.get("/healthz")
    assert response.json()["status"] == "healthy"


def test_health_check_has_version(client):
    response = client.get("/healthz")
    assert "version" in response.json()


def test_health_check_has_services_dict(client):
    response = client.get("/healthz")
    assert "services" in response.json()


def test_health_check_services_keys(client):
    response = client.get("/healthz")
    services = response.json()["services"]
    expected_keys = {"cosmos_db", "azure_search", "azure_openai", "redis", "app_insights"}
    assert expected_keys.issubset(services.keys())


def test_health_check_method_not_allowed(client):
    response = client.post("/healthz")
    assert response.status_code == 405


def test_root_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_root_has_version(client):
    response = client.get("/")
    assert "version" in response.json()


def test_root_has_docs_link(client):
    response = client.get("/")
    assert response.json().get("docs") == "/docs"


def test_root_has_health_link(client):
    response = client.get("/")
    assert response.json().get("health") == "/healthz"


def test_root_identifies_cosmos_as_database(client):
    response = client.get("/")
    assert "Cosmos" in response.json().get("database", "")


def test_root_identifies_b2c_as_auth(client):
    response = client.get("/")
    assert "B2C" in response.json().get("auth", "")
