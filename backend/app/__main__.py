"""Ponto de entrada: ``python -m app``."""

from __future__ import annotations

import logging
import sys

import uvicorn

from .config import get_settings
from .main import create_app


def main() -> int:
    settings = get_settings()
    logging.basicConfig(level=settings.log_level.upper(), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    app = create_app(settings)
    print(f"Daybloom backend em http://{settings.host}:{settings.port} (MongoDB: {settings.mongo_uri}/{settings.mongo_db})")
    uvicorn.run(app, host=settings.host, port=settings.port, log_level=settings.log_level)
    return 0


if __name__ == "__main__":
    sys.exit(main())
