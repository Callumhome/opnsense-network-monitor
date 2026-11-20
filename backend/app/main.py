from __future__ import annotations

import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, status
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "OPNsense Network Manager"
    app_env: str = "development"
    app_api_token: str = "change-me-before-use"


settings = Settings()
app = FastAPI(
    title=settings.app_name,
    version="3.0.0",
    description="Local-first OPNsense management backend.",
)


def require_app_token(
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    if not settings.app_api_token or settings.app_api_token == "change-me-before-use":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Backend API token has not been configured.",
        )

    scheme, _, supplied = (authorization or "").partition(" ")
    if scheme.lower() != "bearer" or not secrets.compare_digest(
        supplied, settings.app_api_token
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "application": settings.app_name, "version": "3.0.0"}


@app.get("/api/v1/status", dependencies=[Depends(require_app_token)])
def status_summary() -> dict[str, str]:
    return {
        "application": settings.app_name,
        "version": "3.0.0",
        "opnsense": "not_configured",
        "mode": "read_only_foundation",
    }
