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
from .schemas import (
    SLOT_PATTERN,
    CancelRequest,
    DialogueRequest,
    DialogueResponse,
    InitiativeRequest,
    NpcChatRequest,
    NpcChatResponse,
    PlanRequest,
    PlanResponse,
    SaveWriteRequest,
)
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
        dialogue_service = DialogueService(
            ollama, repository, enabled=settings.ollama_enabled, max_concurrent=settings.ai_max_concurrent
        )
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
        ollama_info = {
            "enabled": dialogue_service.enabled,
            "model": settings.ollama_model,
            "reachable": False,
            "model_installed": False,
        }
        if dialogue_service.enabled and dialogue_service.client is not None:
            names = await dialogue_service.client.list_models()
            ollama_info["reachable"] = names is not None
            ollama_info["model_installed"] = dialogue_service.client.model_installed(names)
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

    @app.post("/api/v1/ai/initiative", response_model=DialogueResponse)
    async def initiative(body: InitiativeRequest) -> DialogueResponse:
        return await dialogue_service.initiative(body)

    @app.post("/api/v1/ai/npc-chat", response_model=NpcChatResponse)
    async def npc_chat(body: NpcChatRequest) -> NpcChatResponse:
        return await dialogue_service.npc_chat(body)

    @app.post("/api/v1/ai/plan", response_model=PlanResponse)
    async def plan(body: PlanRequest) -> PlanResponse:
        return await dialogue_service.plan(body)

    @app.post("/api/v1/ai/cancel")
    async def cancel(body: CancelRequest) -> dict:
        return {"request_id": body.request_id, "cancelled": dialogue_service.orchestrator.cancel(body.request_id)}

    @app.get("/api/v1/ai/status")
    async def ai_status() -> dict:
        status = dialogue_service.orchestrator.status()
        status["modelo"] = settings.ollama_model
        status["timeout_s"] = settings.ollama_timeout_s
        if dialogue_service.client is not None and dialogue_service.enabled:
            names = await dialogue_service.client.list_models()
            status["ollama_acessivel"] = names is not None
            status["modelo_instalado"] = dialogue_service.client.model_installed(names)
        else:
            status["ollama_acessivel"] = False
            status["modelo_instalado"] = False
        return status

    return app
