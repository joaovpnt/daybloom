class_name JobSystem
extends RefCounted
## Empregos dentro do condomínio. Nesta versão, o emprego jogável é
## "Atendente do Mercadinho"; os demais já têm identificador e dados para
## versões futuras. O pagamento é por tarefa concluída (referência única por
## tarefa) e um bônus por turno completo — nunca pelo mesmo trabalho duas vezes.

const JOBS := {
	"atendente_mercadinho": {
		"label": "Atendente do Mercadinho", "place": "mercadinho", "floor": "terreo",
		"shift_start": 9.0, "shift_end": 13.0, "pay_task": 12, "shift_bonus": 30, "min_tasks_bonus": 4, "xp_task": 5,
		"available": true, "description": "Repor e organizar as prateleiras e atender os clientes do prédio.",
	},
	"zeladoria": {"label": "Zeladoria", "available": false, "description": "Em breve: cuidar da manutenção do prédio."},
	"jardinagem": {"label": "Jardinagem", "available": false, "description": "Em breve: cuidar da horta e dos jardins."},
	"limpeza": {"label": "Serviços de limpeza", "available": false, "description": "Em breve: limpar as áreas comuns."},
	"entregas": {"label": "Entregas", "available": false, "description": "Em breve: ajudar a Pipa com as entregas."},
	"cozinha": {"label": "Preparação de alimentos", "available": false, "description": "Em breve: ajudar na padaria do mercadinho."},
	"criativo": {"label": "Atividades criativas", "available": false, "description": "Em breve: oficinas de arte e música."},
}
const TASK_LABELS := {"repor": "Repor %s", "organizar": "Organizar %s", "atender": "Atender %s"}
const CUSTOMER_PATIENCE := 25.0


static func new_state() -> Dictionary:
	return {"job_id": "", "hired_day": 0, "xp": 0, "level": 1, "shifts_done": 0, "tasks_done": 0, "earned": 0, "last_shift_day": 0, "shift": {}}


static func job_info(job_id: String) -> Dictionary:
	return JOBS.get(job_id, {})


static func is_employed(state: Dictionary) -> bool:
	return str(state.get("job_id", "")) != ""


static func on_shift(state: Dictionary) -> bool:
	return not (state.get("shift", {}) as Dictionary).is_empty()


static func hire(state: Dictionary, job_id: String, day: int) -> Dictionary:
	if not JOBS.has(job_id) or not bool(JOBS[job_id].get("available", false)):
		return {"ok": false, "reason": "Esse emprego ainda não está disponível."}
	if is_employed(state):
		return {"ok": false, "reason": "Você já trabalha aqui."}
	state["job_id"] = job_id
	state["hired_day"] = day
	return {"ok": true}


static func can_start_shift(state: Dictionary, day: int, minute: float) -> Dictionary:
	if not is_employed(state):
		return {"ok": false, "reason": "Você ainda não trabalha no mercadinho."}
	if on_shift(state):
		return {"ok": false, "reason": "O expediente já começou."}
	var job: Dictionary = JOBS[state["job_id"]]
	var hour := minute / 60.0
	if int(state.get("last_shift_day", 0)) == day:
		return {"ok": false, "reason": "Você já trabalhou hoje. Volte amanhã às %02d:00." % int(job["shift_start"])}
	if hour < float(job["shift_start"]) - 0.5 or hour > float(job["shift_end"]) - 0.5:
		return {"ok": false, "reason": "O expediente é das %02d:00 às %02d:00." % [int(job["shift_start"]), int(job["shift_end"])]}
	return {"ok": true, "reason": ""}


## Gera as tarefas do turno a partir do estado real do mercadinho.
static func start_shift(state: Dictionary, day: int, minute: float, shop: Shop) -> Dictionary:
	var check := can_start_shift(state, day, minute)
	if not check["ok"]:
		return check
	var tasks := []
	var n := 0
	var shelves: Array = Shop.SHELVES.duplicate()
	shelves.sort_custom(func(a, b): return shop.shelf_fill(a) < shop.shelf_fill(b))
	for s in shelves:
		if shop.shelf_fill(s) < 0.85 and tasks.size() < 2:
			n += 1
			tasks.append(_task(day, n, "repor", s, TASK_LABELS["repor"] % Shop.SHELF_LABELS[s]))
	shelves.sort_custom(func(a, b): return float(shop.tidiness.get(a, 1.0)) < float(shop.tidiness.get(b, 1.0)))
	for s in shelves:
		if tasks.size() >= 4:
			break
		if _has_task(tasks, "organizar", s):
			continue
		n += 1
		tasks.append(_task(day, n, "organizar", s, TASK_LABELS["organizar"] % Shop.SHELF_LABELS[s]))
	if not _has_type(tasks, "repor"):
		# Sempre há algo para repor no começo do dia: a entrega da manhã.
		n += 1
		tasks.append(_task(day, n, "repor", shelves[0], TASK_LABELS["repor"] % Shop.SHELF_LABELS[shelves[0]]))
	state["shift"] = {"day": day, "started": snappedf(minute, 0.01), "tasks": tasks, "seq": n, "carrying": "", "done": 0, "bonus_paid": false, "earned": 0}
	state["last_shift_day"] = day
	return {"ok": true, "tasks": tasks}


static func _task(day: int, n: int, type: String, target: String, label: String) -> Dictionary:
	return {"id": "tsk_d%d_%d" % [day, n], "type": type, "target": target, "label": label, "done": false}


static func _has_task(tasks: Array, type: String, target: String) -> bool:
	for t in tasks:
		if t["type"] == type and t["target"] == target:
			return true
	return false


static func _has_type(tasks: Array, type: String) -> bool:
	for t in tasks:
		if t["type"] == type:
			return true
	return false


## Um morador chegou ao caixa durante o expediente: nova tarefa real.
static func add_customer(state: Dictionary, npc_id: String, npc_name: String, now_abs: float) -> Dictionary:
	if not on_shift(state):
		return {}
	var shift: Dictionary = state["shift"]
	if _has_task(shift["tasks"], "atender", npc_id):
		return {}
	shift["seq"] = int(shift["seq"]) + 1
	var t := _task(int(shift["day"]), int(shift["seq"]), "atender", npc_id, TASK_LABELS["atender"] % npc_name)
	t["expires"] = now_abs + CUSTOMER_PATIENCE
	(shift["tasks"] as Array).append(t)
	return t


static func pending_tasks(state: Dictionary) -> Array:
	var out := []
	if on_shift(state):
		for t in state["shift"]["tasks"]:
			if not t["done"] and not t.get("expired", false):
				out.append(t)
	return out


static func find_task(state: Dictionary, type: String, target: String) -> Dictionary:
	for t in pending_tasks(state):
		if t["type"] == type and (target == "" or t["target"] == target):
			return t
	return {}


## Pega uma caixa no estoque (necessário antes de repor).
static func pick_box(state: Dictionary) -> Dictionary:
	if not on_shift(state):
		return {"ok": false, "reason": "Você não está no expediente."}
	var t := find_task(state, "repor", "")
	if t.is_empty():
		return {"ok": false, "reason": "Não há prateleiras para repor agora."}
	if str(state["shift"]["carrying"]) != "":
		return {"ok": false, "reason": "Você já está carregando uma caixa."}
	state["shift"]["carrying"] = t["target"]
	return {"ok": true, "shelf": t["target"]}


## Conclui uma tarefa: aplica o efeito real e paga uma única vez.
static func complete_task(state: Dictionary, task_id: String, wallet: Wallet, shop: Shop, time: Dictionary) -> Dictionary:
	if not on_shift(state):
		return {"ok": false, "reason": "Você não está no expediente."}
	var task: Dictionary = {}
	for t in state["shift"]["tasks"]:
		if t["id"] == task_id:
			task = t
	if task.is_empty():
		return {"ok": false, "reason": "tarefa inexistente"}
	if task["done"] or task.get("expired", false):
		return {"ok": false, "reason": "tarefa já encerrada"}
	match task["type"]:
		"repor":
			if str(state["shift"]["carrying"]) != str(task["target"]):
				return {"ok": false, "reason": "Pegue uma caixa de produtos no estoque primeiro."}
			shop.restock_shelf(task["target"])
			state["shift"]["carrying"] = ""
		"organizar":
			shop.organize_shelf(task["target"])
	var job: Dictionary = JOBS[state["job_id"]]
	var pay := int(job["pay_task"])
	var res := wallet.credit(pay, "salario", "Mercadinho: " + str(task["label"]), str(task["id"]), time)
	if not res["ok"]:
		return {"ok": false, "reason": res["reason"]}
	task["done"] = true
	state["shift"]["done"] = int(state["shift"]["done"]) + 1
	state["shift"]["earned"] = int(state["shift"]["earned"]) + pay
	state["tasks_done"] = int(state.get("tasks_done", 0)) + 1
	state["earned"] = int(state.get("earned", 0)) + pay
	state["xp"] = int(state.get("xp", 0)) + int(job["xp_task"])
	state["level"] = 1 + int(state["xp"]) / 100
	return {"ok": true, "pay": pay, "task": task, "tx": res["tx"]}


static func expire_customers(state: Dictionary, now_abs: float) -> Array:
	var out := []
	if not on_shift(state):
		return out
	for t in state["shift"]["tasks"]:
		if t["type"] == "atender" and not t["done"] and not t.get("expired", false) and now_abs > float(t.get("expires", INF)):
			t["expired"] = true
			out.append(t)
	return out


## Fim do expediente: bônus se o turno foi realmente cumprido.
static func end_shift(state: Dictionary, wallet: Wallet, time: Dictionary) -> Dictionary:
	if not on_shift(state):
		return {"ok": false, "reason": "sem expediente"}
	var shift: Dictionary = state["shift"]
	var job: Dictionary = JOBS[state["job_id"]]
	var bonus := 0
	if int(shift["done"]) >= int(job["min_tasks_bonus"]) and not bool(shift["bonus_paid"]):
		var res := wallet.credit(int(job["shift_bonus"]), "bonus", "Mercadinho: turno completo", "turno_d%d" % int(shift["day"]), time)
		if res["ok"]:
			bonus = int(job["shift_bonus"])
			shift["bonus_paid"] = true
			state["earned"] = int(state.get("earned", 0)) + bonus
	var summary := {"ok": true, "done": int(shift["done"]), "earned": int(shift["earned"]) + bonus, "bonus": bonus}
	state["shifts_done"] = int(state.get("shifts_done", 0)) + 1
	state["shift"] = {}
	return summary


static func load_state(data: Dictionary) -> Dictionary:
	var st := new_state()
	for k in st:
		if data.has(k):
			st[k] = data[k]
	if not JOBS.has(str(st["job_id"])):
		st["job_id"] = ""
	st["xp"] = maxi(0, int(st["xp"]))
	st["level"] = 1 + int(st["xp"]) / 100
	if not (st["shift"] is Dictionary):
		st["shift"] = {}
	return st
