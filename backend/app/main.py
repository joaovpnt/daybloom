"""API local do Daybloom (FastAPI).

Execute com ``python -m app`` (escuta apenas em 127.0.0.1).
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import FastAPI, HTTPException, Path
from fastapi.responses import JSONResponse

from . import __version__
from .config import Settings, get_settings
from .persistence import PersistenceError, PersistenceUnavailable, RevisionConflict, SaveRepository
from .schemas import SLOT_PATTERN, DialogueRequest, DialogueResponse, SaveWriteRequest
from .services.dialogue_service import DialogueService
from .services.ollama_client import OllamaClient
from .services.save_service import SaveService, SaveValidationError

log = logging.getLogger("daybloom.api")

SLOT_REGEX = SLOT_PATTERN.pattern


def create_app(
    settings: Optional[Settings] = None,
    repository: Optional[SaveRepository] = None,
    dialogue_service: Optional[DialogueService] = None,
) -> FastAPI:
    settings = settings or get_settings()
    if repository is None:
        from .persistence.mongo import MongoSaveRepository

        repository = MongoSaveRepository(settings.mongo_uri, settings.mongo_db, settings.mongo_timeout_ms)
    ollama = OllamaClient(settings.ollama_url, settings.ollama_model, settings.ollama_timeout_s)
    if dialogue_service is None:
        dialogue_service = DialogueService(ollama, repository, enabled=settings.ollama_enabled)
    save_service = SaveService(repository)

    app = FastAPI(title="Daybloom — backend local", version=__version__)
    app.state.settings = settings
    app.state.repository = repository
    app.state.save_service = save_service
    app.state.dialogue_service = dialogue_service

    @app.get("/health")
    async def health() -> dict:
        mongo = {"ok": True, "error": None, "database": settings.mongo_db}
        try:
            repository.ping()
        except PersistenceError as exc:
            mongo = {"ok": False, "error": str(exc), "database": settings.mongo_db}
        ollama_info = {"enabled": dialogue_service.enabled, "model": settings.ollama_model, "reachable": False}
        if dialogue_service.enabled and dialogue_service.client is not None:
            ollama_info["reachable"] = await dialogue_service.client.is_reachable()
        return {"status": "ok", "version": __version__, "mongo": mongo, "ollama": ollama_info}

    @app.get("/api/v1/saves/{slot_id}")
    def get_save(slot_id: str = Path(pattern=SLOT_REGEX)) -> dict:
        try:
            stored = save_service.load(slot_id)
        except PersistenceUnavailable as exc:
            raise HTTPException(status_code=503, detail=f"MongoDB indisponível: {exc}") from exc
        except SaveValidationError as exc:
            raise HTTPException(status_code=422, detail={"mensagem": str(exc), "detalhes": exc.details}) from exc
        except PersistenceError as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc
        if stored is None:
            raise HTTPException(status_code=404, detail="save não encontrado")
        return {
            "slot_id": stored.slot_id,
            "revision": stored.revision,
            "checksum": stored.checksum,
            "updated_at": stored.updated_at.isoformat(),
            "snapshot": stored.snapshot,
        }

    @app.put("/api/v1/saves/{slot_id}")
    def put_save(body: SaveWriteRequest, slot_id: str = Path(pattern=SLOT_REGEX)):
        try:
            result = save_service.save(slot_id, body.snapshot, body.expected_revision, body.overwrite)
        except SaveValidationError as exc:
            return JSONResponse(
                status_code=422, content={"detail": {"mensagem": str(exc), "detalhes": exc.details}}
            )
        except RevisionConflict as exc:
            return JSONResponse(
                status_code=409,
                content={"detail": {"mensagem": str(exc), "revisao_atual": exc.current_revision}},
            )
        except PersistenceUnavailable as exc:
            return JSONResponse(status_code=503, content={"detail": f"MongoDB indisponível: {exc}"})
        except PersistenceError as exc:
            return JSONResponse(status_code=500, content={"detail": str(exc)})
        return {
            "slot_id": result.slot_id,
            "revision": result.revision,
            "checksum": result.checksum,
            "saved_at": result.saved_at,
            "events_recorded": result.events_recorded,
            "events_error": result.events_error,
            "persisted": True,
        }

    @app.post("/api/v1/dialogue", response_model=DialogueResponse)
    async def dialogue(body: DialogueRequest) -> DialogueResponse:
        return await dialogue_service.respond(body)

    return app
