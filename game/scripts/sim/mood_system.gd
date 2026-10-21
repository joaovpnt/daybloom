class_name MoodSystem
extends RefCounted
## Humor derivado das necessidades e de modificadores temporários com causa,
## intensidade e duração ("Dormiu bem", "Discutiu com Ravena", "Música alta").
## O humor é um estado do momento: a personalidade continua sendo a base do
## comportamento (os traços apenas inclinam os resultados).

const STATES := ["feliz", "neutro", "inspirado", "animado", "cansado", "entediado", "estressado", "triste", "irritado"]
const LABELS := {
	"feliz": "Feliz", "neutro": "Neutro", "inspirado": "Inspirado", "animado": "Animado", "cansado": "Cansado",
	"entediado": "Entediado", "estressado": "Estressado", "triste": "Triste", "irritado": "Irritado",
}
const COLORS := {
	"feliz": Color(0.98, 0.78, 0.30), "neutro": Color(0.72, 0.68, 0.62), "inspirado": Color(0.70, 0.56, 0.95),
	"animado": Color(0.98, 0.56, 0.40), "cansado": Color(0.56, 0.62, 0.80), "entediado": Color(0.66, 0.66, 0.70),
	"estressado": Color(0.90, 0.48, 0.42), "triste": Color(0.46, 0.60, 0.88), "irritado": Color(0.88, 0.34, 0.30),
}
## Valência de cada estado (compatível com o "valence" usado pela IA social).
const VALENCE := {"feliz": 0.55, "neutro": 0.05, "inspirado": 0.6, "animado": 0.7, "cansado": -0.2, "entediado": -0.15, "estressado": -0.45, "triste": -0.55, "irritado": -0.5}
const MAX_MODS := 8


## Palavra no feminino/masculino ("cansada", "cansado"; "feliz", "triste").
static func word(state: String, article: String = "a") -> String:
	match state:
		"feliz", "triste":
			return state
	if state in STATES:
		return state.substr(0, state.length() - 1) + article
	return state


## Adiciona (ou renova) um modificador. Mesma `id` substitui o anterior.
static func add_modifier(mods: Array, id: String, cause: String, state: String, intensity: float, duration_min: float, now: float) -> Dictionary:
	assert(state in STATES, "estado de humor inválido: %s" % state)
	for i in range(mods.size() - 1, -1, -1):
		if mods[i]["id"] == id:
			mods.remove_at(i)
	var mod := {"id": id, "cause": cause, "state": state, "intensity": clampf(intensity, 0.0, 1.5), "started": snappedf(now, 0.01), "until": snappedf(now + duration_min, 0.01)}
	mods.append(mod)
	mods.sort_custom(func(a, b): return float(a["until"]) > float(b["until"]))
	while mods.size() > MAX_MODS:
		mods.pop_back()
	return mod


static func prune(mods: Array, now: float) -> void:
	for i in range(mods.size() - 1, -1, -1):
		if float(mods[i]["until"]) <= now:
			mods.remove_at(i)


## Intensidade atual: diminui até 30% conforme o fim se aproxima.
static func intensity_now(mod: Dictionary, now: float) -> float:
	var total := maxf(1.0, float(mod["until"]) - float(mod["started"]))
	var left := clampf((float(mod["until"]) - now) / total, 0.0, 1.0)
	if left <= 0.0:
		return 0.0
	return float(mod["intensity"]) * (0.3 + 0.7 * left)


## Calcula o humor atual. needs: Dictionary com as chaves de NeedsComponent.
static func evaluate(needs: Dictionary, mods: Array, now: float, traits: Dictionary = {}, sleeping: bool = false) -> Dictionary:
	var scores := {}
	for s in STATES:
		scores[s] = 0.0
	scores["neutro"] = 0.28
	var e := float(needs.get("energia", 70.0))
	var fun := float(needs.get("diversao", 70.0))
	var fome := float(needs.get("fome", 70.0))
	var wc := float(needs.get("banheiro", 70.0))
	var soc := float(needs.get("social", 70.0))
	var hyg := float(needs.get("higiene", 70.0))
	var comfort := float(needs.get("conforto", 60.0))
	var avg := (e + fun + fome + wc + soc + hyg + comfort) / 7.0
	var causes := []
	if e < 32.0 and not sleeping:
		scores["cansado"] += (32.0 - e) / 32.0 * 0.95
		causes.append("pouca energia")
	if fun < 30.0:
		scores["entediado"] += (30.0 - fun) / 30.0 * 0.85
		causes.append("pouca diversão")
	var critical := 0
	for v in [fome, wc, soc, hyg]:
		if v < NeedsComponent.CRITICAL:
			critical += 1
	if critical > 0:
		scores["estressado"] += 0.22 * critical
		causes.append("necessidades urgentes")
	if avg < 42.0:
		scores["estressado"] += (42.0 - avg) / 42.0 * 0.55
	if fome < 14.0 or wc < 12.0:
		scores["irritado"] += 0.32 * (1.15 - float(traits.get("gentileza", 0.5)) * 0.5)
	var valence_needs := (avg - 55.0) / 45.0
	scores["feliz"] += maxf(0.0, valence_needs) * 0.85
	scores["triste"] += maxf(0.0, -valence_needs) * 0.25
	if e > 62.0 and fun > 55.0:
		scores["animado"] += 0.16 + float(traits.get("energia", 0.5)) * 0.22
	for mod in mods:
		var it := intensity_now(mod, now)
		if it > 0.0:
			scores[mod["state"]] = float(scores.get(mod["state"], 0.0)) + it
	var best := "neutro"
	for s in STATES:
		if float(scores[s]) > float(scores[best]):
			best = s
	var top_mods := []
	for mod in mods:
		if mod["state"] == best and intensity_now(mod, now) > 0.05:
			top_mods.append(mod["cause"])
	var valence := 0.0
	var total := 0.0
	for s in STATES:
		valence += float(VALENCE[s]) * float(scores[s])
		total += float(scores[s])
	valence = clampf(valence / maxf(total, 0.001) + valence_needs * 0.3, -1.0, 1.0)
	return {"state": best, "scores": scores, "valence": valence, "causes": top_mods if not top_mods.is_empty() else causes.slice(0, 2)}


## Lista legível dos modificadores ativos (para a interface e o contexto da IA).
static func describe(mods: Array, now: float) -> Array:
	var out := []
	for mod in mods:
		if float(mod["until"]) > now:
			out.append({"cause": mod["cause"], "state": mod["state"], "minutes_left": int(float(mod["until"]) - now)})
	return out


static func mods_to_array(mods: Array) -> Array:
	return mods.duplicate(true)


static func mods_from_array(list: Array, now: float) -> Array:
	var out := []
	for m in list:
		if not (m is Dictionary) or not (str(m.get("state", "")) in STATES):
			continue
		if float(m.get("until", 0.0)) <= now:
			continue
		out.append({"id": str(m.get("id", "mod")), "cause": str(m.get("cause", "")).substr(0, 80), "state": str(m["state"]), "intensity": clampf(float(m.get("intensity", 0.3)), 0.0, 1.5), "started": float(m.get("started", now)), "until": float(m["until"])})
	return out.slice(0, MAX_MODS)
