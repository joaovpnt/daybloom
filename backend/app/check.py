"""Verifica o ambiente local: ``python -m app.check``.

Código de saída 0 = MongoDB acessível; 2 = MongoDB inacessível.
O Ollama é opcional e apenas informado.
"""

from __future__ import annotations

import json
import sys
import urllib.request

from .config import get_settings


def check_mongo(uri: str, timeout_ms: int) -> tuple[bool, str]:
    try:
        from pymongo import MongoClient
        from pymongo.errors import PyMongoError
    except ImportError:
        return False, "PyMongo não instalado (rode scripts\\instalar_dependencias.bat)"
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=timeout_ms)
        info = client.server_info()
        client.close()
        return True, f"MongoDB {info.get('version', '?')} acessível"
    except PyMongoError as exc:
        return False, f"MongoDB inacessível em {uri}: {exc.__class__.__name__}"


def check_ollama(url: str, model: str) -> tuple[bool, str]:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(url + "/api/tags", timeout=2) as response:
            data = json.loads(response.read().decode("utf-8"))
    except Exception:
        return False, "Ollama não está rodando (opcional: o jogo usa diálogos clássicos)"
    names = [m.get("name", "") for m in data.get("models", [])]
    if model in names or any(n.startswith(model) for n in names):
        return True, f"Ollama ativo com o modelo {model}"
    return False, f"Ollama ativo, mas o modelo {model} não foi baixado (rode: ollama pull {model})"


def main() -> int:
    settings = get_settings()
    mongo_ok, mongo_msg = check_mongo(settings.mongo_uri, settings.mongo_timeout_ms)
    ollama_ok, ollama_msg = check_ollama(settings.ollama_url, settings.ollama_model)
    print(("[OK] " if mongo_ok else "[ERRO] ") + mongo_msg)
    print(("[OK] " if ollama_ok else "[AVISO] ") + ollama_msg)
    return 0 if mongo_ok else 2


if __name__ == "__main__":
    sys.exit(main())
