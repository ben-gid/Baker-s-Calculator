# Baker's Calculator Backend

This is the backend service for the Baker's Calculator application, providing a centralized API for user-specific recipe management and secure synchronization.

## Tech Stack

- **Framework:** [FastAPI](https://fastapi.tiangolo.com/)
- **Database ORM:** [SQLModel](https://sqlmodel.tiangolo.com/) (SQLAlchemy + Pydantic)
- **Database:** SQLite
- **Authentication:** `passlib` (bcrypt) & `PyJWT` for JSON Web Tokens
- **Package Manager:** [uv](https://github.com/astral-sh/uv)
- **Testing:** [pytest](https://docs.pytest.org/)

## Project Structure

```text
backend/
├── auth.py       # JWT token generation and password hashing utilities
├── database.py   # Database configuration and session management
├── main.py       # FastAPI application and route definitions
├── models.py     # SQLModel data definitions (User, Recipe, Token)
├── test_main.py  # Integration tests
├── pyproject.toml # Project dependencies and metadata
└── uv.lock        # Locked dependency versions
```

## Getting Started

### Prerequisites

- Python 3.14+
- `uv` installed on your system

### Installation

Clone the repository and install dependencies:

```bash
uv sync
```

### Running the Server

Start the FastAPI server with auto-reload:

```bash
uv run uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.
You can access the interactive API documentation (Swagger UI) at `http://127.0.0.1:8000/docs`.

## API Endpoints

### Authentication
- `POST /register`: Register a new user account.
- `POST /token`: Login and retrieve an OAuth2 Bearer JWT.
- `GET /users/me`: Retrieve the currently authenticated user's profile.

### Recipes (Requires JWT Bearer Token)
- `POST /recipes/`: Create a new synced recipe.
- `GET /recipes/`: List all recipes belonging to the authenticated user.
- `GET /recipes/{recipe_id}`: Retrieve a specific user recipe by ID.
- `DELETE /recipes/{recipe_id}`: Delete a specific user recipe.

## Testing

Run the test suite using `pytest`:

```bash
uv run pytest
```

The tests use an isolated SQLite database (`test_db.db`) which is cleared after each run and performs full registration, auth, and secure recipe creation assertions.
