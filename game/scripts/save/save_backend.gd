class_name SaveBackend
extends RefCounted
## Interface de persistência usada pelo jogo. Implementações:
## - ApiSaveBackend: backend FastAPI + MongoDB (padrão na versão 0.1)
## - LocalFileSaveBackend: arquivo local (testes e futura distribuição sem MongoDB)


func backend_name() -> String:
	return "abstrato"


## {ok, found, snapshot, revision, error}
func load_save(_slot_id: String) -> Dictionary:
	return {"ok": false, "found": false, "error": "não implementado"}


## {ok, revision, error, conflict}
func write_save(_slot_id: String, _snapshot: Dictionary, _expected_revision: int, _overwrite: bool) -> Dictionary:
	return {"ok": false, "error": "não implementado"}
