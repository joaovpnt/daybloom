"""Configuração do backend do Daybloom.

Toda configuração vem de variáveis de ambiente. Um arquivo ``backend/.env``
opcional é lido no início (formato CHAVE=valor), sem sobrescrever variáveis já
definidas no ambiente.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent


def load_env_file(path: Path) -> None:
    """Carrega um arquivo .env simples sem dependências externas."""
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, default))
    except ValueError:
        return default


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "sim", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    mongo_uri: str = "mongodb://127.0.0.1:27017"
    mongo_db: str = "daybloom"
    mongo_timeout_ms: int = 2500
    host: str = "127.0.0.1"
    port: int = 8765
    ollama_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "qwen3:4b"
    ollama_enabled: bool = True
    ollama_timeout_s: float = 25.0
    log_level: str = "info"
    extra: dict = field(default_factory=dict)


def get_settings() -> Settings:
    load_env_file(BACKEND_DIR / ".env")
    host = os.environ.get("DAYBLOOM_HOST", "127.0.0.1")
    if host not in {"127.0.0.1", "localhost", "::1"}:
        # O backend é local por definição: nunca escutar em interfaces externas.
        host = "127.0.0.1"
    return Settings(
        mongo_uri=os.environ.get("DAYBLOOM_MONGO_URI", "mongodb://127.0.0.1:27017"),
        mongo_db=os.environ.get("DAYBLOOM_MONGO_DB", "daybloom"),
        mongo_timeout_ms=_env_int("DAYBLOOM_MONGO_TIMEOUT_MS", 2500),
        host=host,
        port=_env_int("DAYBLOOM_PORT", 8765),
        ollama_url=os.environ.get("DAYBLOOM_OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/"),
        ollama_model=os.environ.get("DAYBLOOM_OLLAMA_MODEL", "qwen3:4b"),
        ollama_enabled=_env_bool("DAYBLOOM_OLLAMA_ENABLED", True),
        ollama_timeout_s=_env_float("DAYBLOOM_OLLAMA_TIMEOUT_S", 25.0),
        log_level=os.environ.get("DAYBLOOM_LOG_LEVEL", "info"),
    )
