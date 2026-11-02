from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="DEVALAY_", extra="ignore")

    env: str = "development"  # development | test | production
    app_name: str = "Devalay"
    database_url: str = f"sqlite:///{BASE_DIR / 'devalay.db'}"
    secret_key: str = "dev-insecure-change-me"
    access_token_minutes: int = 30
    refresh_token_days: int = 60
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])
    public_base_url: str = "http://localhost:8000"
    contact_email: str = "privacy@example.com"  # shown in the privacy policy; set your real address

    # Ephemeris (NASA JPL DE421) used by the Panchang engine.
    ephemeris_dir: str = str(BASE_DIR / "data")
    default_lat: float = 28.6139  # New Delhi
    default_lon: float = 77.2090
    default_tz: str = "Asia/Kolkata"

    # Media storage: "local" writes to media_dir; "r2" uses Cloudflare R2 (S3 API).
    storage_backend: str = "local"
    media_dir: str = str(BASE_DIR / "media")
    r2_account_id: str = ""
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = ""
    r2_public_base_url: str = ""  # e.g. https://media.example.com (custom domain or r2.dev)

    # Optional AI provider. Without a key, deterministic offline generators are used.
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-opus-5-5"  # set claude-haiku-5-5 for lowest cost
    ai_free_daily_limit: int = 5
    ai_premium_daily_limit: int = 100

    # Google Play subscription verification (service-account JSON, base64 or raw).
    google_play_package: str = "com.chandrachaan.devalay"
    google_play_service_account_json: str = ""
    # Development-only switch that lets /premium/verify grant entitlements without Google.
    premium_dev_grant: bool = False

    # Optional SMTP for password-reset mails. Without it, reset codes are only logged in development.
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "Devalay <no-reply@example.com>"

    admin_session_minutes: int = 60 * 8

    @property
    def is_production(self) -> bool:
        return self.env == "production"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production and settings.secret_key == "dev-insecure-change-me":
        raise RuntimeError("DEVALAY_SECRET_KEY must be set in production")
    return settings
