from functools import lru_cache
from typing import Literal

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "FieldOps API"
    environment: Literal["development", "test", "production"] = "development"
    database_url: str = "sqlite:///./fieldops.db"
    secret_key: str = "dev-secret-change-me-0123456789abcdef"
    access_token_expire_minutes: int = 480
    jwt_algorithm: str = "HS256"
    cors_origins: str = "*"
    storage_path: str = "./uploads"
    upload_max_bytes: int = 10 * 1024 * 1024
    allowed_photo_types: str = "image/jpeg,image/png,image/webp"

    @field_validator("database_url", mode="before")
    @classmethod
    def normalize_database_url(cls, value: str) -> str:
        if value.startswith("postgres://"):
            return "postgresql+psycopg://" + value[len("postgres://") :]
        if value.startswith("postgresql://"):
            return "postgresql+psycopg://" + value[len("postgresql://") :]
        return value

    @model_validator(mode="after")
    def validate_production_secret(self) -> "Settings":
        if (
            self.environment == "production"
            and self.secret_key == "dev-secret-change-me-0123456789abcdef"
        ):
            raise ValueError("SECRET_KEY must be set to a strong value in production")
        return self

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def allowed_photo_type_set(self) -> set[str]:
        return {
            item.strip().lower() for item in self.allowed_photo_types.split(",") if item.strip()
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
