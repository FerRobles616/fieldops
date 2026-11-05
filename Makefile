.PHONY: install migrate seed run test lint format app-get app-test app-run

install:
	cd backend && python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"

migrate:
	cd backend && .venv/bin/alembic upgrade head

seed:
	cd backend && .venv/bin/python -m app.seed

run:
	cd backend && .venv/bin/uvicorn app.main:app --reload

test:
	cd backend && .venv/bin/pytest

lint:
	cd backend && .venv/bin/ruff check . && .venv/bin/mypy app

format:
	cd backend && .venv/bin/ruff format .

app-get:
	cd app && flutter pub get

app-test:
	cd app && flutter analyze && flutter test

app-run:
	cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
