extends Node
## Cliente HTTP do backend local (FastAPI). Todas as chamadas são assíncronas
## (HTTPRequest) e nunca bloqueiam o jogo.

const DEFAULT_URL := "http://127.0.0.1:8765"

var base_url: String = DEFAULT_URL
var last_health: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_url := OS.get_environment("DAYBLOOM_API_URL")
	if env_url != "":
		base_url = env_url.rstrip("/")
	elif OS.get_environment("DAYBLOOM_PORT") != "":
		base_url = "http://127.0.0.1:%s" % OS.get_environment("DAYBLOOM_PORT")


## Retorna {ok, status, data, error}. ok = resposta HTTP 2xx com JSON válido.
func request_json(method: int, path: String, body: Variant = null, timeout_s: float = 8.0) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout_s
	http.use_threads = false
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": {}, "error": "não foi possível iniciar a requisição (%s)" % error_string(err)}
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		var reason := "backend inacessível"
		if result == HTTPRequest.RESULT_TIMEOUT:
			reason = "tempo de resposta esgotado"
		return {"ok": false, "status": 0, "data": {}, "error": reason}
	var data: Variant = {}
	var text := raw.get_string_from_utf8()
	if text != "":
		var parsed: Variant = JSON.parse_string(text)
		if parsed == null:
			return {"ok": false, "status": code, "data": {}, "error": "resposta inválida do backend"}
		data = parsed
	var ok := code >= 200 and code < 300
	var error_text := ""
	if not ok:
		error_text = _describe_error(code, data)
	return {"ok": ok, "status": code, "data": data, "error": error_text}


func _describe_error(code: int, data: Variant) -> String:
	var detail: Variant = data.get("detail", "") if data is Dictionary else ""
	if detail is Dictionary:
		detail = detail.get("mensagem", str(detail))
	match code:
		404:
			return "não encontrado"
		409:
			return "conflito de versão do save: %s" % str(detail)
		422:
			return "dados inválidos: %s" % str(detail)
		503:
			return "MongoDB indisponível"
	return "erro %d: %s" % [code, str(detail)]


func check_health() -> Dictionary:
	var res := await request_json(HTTPClient.METHOD_GET, "/health", null, 3.0)
	var status := {
		"backend": res["ok"],
		"mongo": false,
		"ollama": false,
		"error": res["error"],
	}
	if res["ok"]:
		var data: Dictionary = res["data"]
		status["mongo"] = bool(data.get("mongo", {}).get("ok", false))
		var oll: Dictionary = data.get("ollama", {})
		status["ollama_reachable"] = bool(oll.get("reachable", false))
		status["ollama_model"] = str(oll.get("model", ""))
		# Conversas por IA só com o Ollama acessível E o modelo instalado.
		status["ollama"] = status["ollama_reachable"] and bool(oll.get("model_installed", oll.get("reachable", false)))
		if status["ollama_reachable"] and not status["ollama"]:
			status["ollama_error"] = "modelo %s não instalado (ollama pull %s)" % [status["ollama_model"], status["ollama_model"]]
		if not status["mongo"]:
			status["error"] = str(data.get("mongo", {}).get("error", "MongoDB indisponível"))
	last_health = status
	EventBus.backend_status_changed.emit(status)
	return status


## Estado do orquestrador de IA (fila, latência, erros) para o painel F3.
func ai_status() -> Dictionary:
	var res := await request_json(HTTPClient.METHOD_GET, "/api/v1/ai/status", null, 2.5)
	return res["data"] if res["ok"] else {}


## Cancela uma solicitação de IA (não espera a resposta).
func cancel_ai(request_id: String) -> void:
	request_json(HTTPClient.METHOD_POST, "/api/v1/ai/cancel", {"request_id": request_id}, 3.0)
