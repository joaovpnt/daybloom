class_name ApiSaveBackend
extends SaveBackend
## Saves no MongoDB através do backend local.


func backend_name() -> String:
	return "MongoDB"


func load_save(slot_id: String) -> Dictionary:
	var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_GET, "/api/v1/saves/%s" % slot_id, null, 10.0)
	if res["status"] == 404:
		return {"ok": true, "found": false, "error": ""}
	if not res["ok"]:
		return {"ok": false, "found": false, "error": res["error"]}
	var data: Dictionary = res["data"]
	return {"ok": true, "found": true, "snapshot": data["snapshot"], "revision": int(data["revision"]), "error": ""}


func write_save(slot_id: String, snapshot: Dictionary, expected_revision: int, overwrite: bool) -> Dictionary:
	var body := {"snapshot": snapshot, "overwrite": overwrite}
	body["expected_revision"] = expected_revision if expected_revision > 0 else null
	var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_PUT, "/api/v1/saves/%s" % slot_id, body, 15.0)
	if not res["ok"]:
		return {"ok": false, "error": res["error"], "conflict": res["status"] == 409}
	var data: Dictionary = res["data"]
	if not bool(data.get("persisted", false)):
		return {"ok": false, "error": "o backend não confirmou a gravação", "conflict": false}
	return {"ok": true, "revision": int(data["revision"]), "error": "", "conflict": false, "events_error": data.get("events_error")}
