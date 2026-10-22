from fastapi.testclient import TestClient
from main import app
from sqlmodel import SQLModel, create_engine, Session
from database import get_session
import pytest

sqlite_url = "sqlite:///./test_db.db"
engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})

def override_get_session():
    with Session(engine) as session:
        yield session

app.dependency_overrides[get_session] = override_get_session

@pytest.fixture(name="client")
def client_fixture():
    SQLModel.metadata.create_all(engine)
    client = TestClient(app)
    yield client
    SQLModel.metadata.drop_all(engine)

def test_auth_and_recipes(client: TestClient):
    # Register user
    response = client.post("/register", json={
        "username": "testuser",
        "email": "test@test.com",
        "password": "testpassword"
    })
    assert response.status_code == 200

    # Login
    response = client.post("/token", data={
        "username": "testuser",
        "password": "testpassword"
    })
    assert response.status_code == 200
    token = response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create recipe
    response = client.post("/recipes/", json={
        "title": "Sourdough Bread",
        "doughType": "Sourdough",
        "payload": '{"flour": 1000, "water": 750}'
    }, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Sourdough Bread"
    recipe_id = data["id"]
    
    # Read recipe
    response = client.get(f"/recipes/{recipe_id}", headers=headers)
    assert response.status_code == 200
    assert response.json()["doughType"] == "Sourdough"
    
    # List
    response = client.get("/recipes/", headers=headers)
    assert len(response.json()) == 1

    # Delete
    response = client.delete(f"/recipes/{recipe_id}", headers=headers)
    assert response.status_code == 200

    # Attempt without auth
    response_no_auth = client.get("/recipes/")
    assert response_no_auth.status_code == 401
