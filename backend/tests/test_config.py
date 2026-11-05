from app.core.config import Settings


def test_database_url_normalizes_render_prefixes() -> None:
    postgres = Settings(
        database_url="postgres://user:pass@host:5432/fieldops",
        _env_file=None,
    )
    postgresql = Settings(
        database_url="postgresql://user:pass@host:5432/fieldops",
        _env_file=None,
    )
    driver = Settings(
        database_url="postgresql+psycopg://user:pass@host:5432/fieldops",
        _env_file=None,
    )
    sqlite = Settings(
        database_url="sqlite:///./fieldops.db",
        _env_file=None,
    )

    assert postgres.database_url == ("postgresql+psycopg://user:pass@host:5432/fieldops")
    assert postgresql.database_url == ("postgresql+psycopg://user:pass@host:5432/fieldops")
    assert driver.database_url == ("postgresql+psycopg://user:pass@host:5432/fieldops")
    assert sqlite.database_url == "sqlite:///./fieldops.db"
