class_name NeedsComponent
extends RefCounted
## Necessidades (0 = urgente, 100 = satisfeita) da jogadora e dos moradores.
## Reutilizável: envolve um Dictionary por referência (o mesmo objeto que vai
## para o save), então quem já guarda `needs` continua compatível.
##
## Balanceamento: todas as taxas ficam nas tabelas abaixo (por minuto de jogo).
## Não há morte, despejo nem punições: necessidades baixas só mudam o humor,
## a disposição e as decisões.

const KEYS := ["fome", "energia", "higiene", "banheiro", "diversao", "social", "conforto"]
const LABELS := {
	"fome": "Fome", "energia": "Energia", "higiene": "Higiene", "banheiro": "Banheiro",
	"diversao": "Diversão", "social": "Socialização", "conforto": "Conforto",
}
const COLORS := {
	"fome": Color(0.96, 0.62, 0.36), "energia": Color(0.98, 0.82, 0.32), "higiene": Color(0.45, 0.74, 0.92),
	"banheiro": Color(0.62, 0.70, 0.96), "diversao": Color(0.96, 0.52, 0.66), "social": Color(0.56, 0.82, 0.52),
	"conforto": Color(0.78, 0.62, 0.92),
}
const DEFAULT := 75.0
const CRITICAL := 18.0

## Queda natural por minuto acordado (conforto não cai: ele tende ao alvo do ambiente).
const BASE_RATES := {"fome": -0.11, "energia": -0.07, "higiene": -0.05, "banheiro": -0.16, "diversao": -0.06, "social": -0.05}

## Ajustes por tipo de atividade (substituem a taxa base daquela necessidade).
const ACTIVITY_RATES := {
	"dormindo": {"fome": -0.04, "energia": 0.32, "higiene": -0.02, "banheiro": -0.06, "diversao": 0.0, "social": 0.0},
	"descansando": {"energia": 0.04},
	"trabalhando": {"energia": -0.10, "diversao": -0.09},
	"socializando": {"social": 0.5, "diversao": 0.12},
	"lazer": {"diversao": 0.4},
	"exercicio": {"energia": -0.2, "higiene": -0.22, "diversao": 0.5, "fome": -0.16},
}

## Velocidade com que o conforto se aproxima do alvo (por minuto).
const COMFORT_RATE := 0.22

var values: Dictionary


func _init(dict: Dictionary = {}) -> void:
	values = dict
	for k in KEYS:
		if not values.has(k):
			values[k] = DEFAULT
		values[k] = clampf(float(values[k]), 0.0, 100.0)


func get_value(key: String) -> float:
	return float(values.get(key, DEFAULT))


func add(key: String, amount: float) -> void:
	values[key] = clampf(get_value(key) + amount, 0.0, 100.0)


func set_value(key: String, value: float) -> void:
	values[key] = clampf(value, 0.0, 100.0)


func average() -> float:
	var s := 0.0
	for k in KEYS:
		s += get_value(k)
	return s / KEYS.size()


func lowest_key() -> String:
	var best := KEYS[0]
	for k in KEYS:
		if get_value(k) < get_value(best):
			best = k
	return best


func is_critical(key: String) -> bool:
	return get_value(key) < CRITICAL


func critical_keys() -> Array:
	var out := []
	for k in KEYS:
		if is_critical(k):
			out.append(k)
	return out


## Avança o tempo. `activity` escolhe a linha de ACTIVITY_RATES; `rates`
## (por minuto) sobrepõe tudo para efeitos de ações específicas; `mult`
## multiplica as quedas naturais (personalidade). O conforto caminha para
## `comfort_target`.
func tick(minutes: float, activity: String = "", rates: Dictionary = {}, comfort_target: float = 50.0, mult: Dictionary = {}) -> void:
	if minutes <= 0.0:
		return
	var act: Dictionary = ACTIVITY_RATES.get(activity, {})
	for k in BASE_RATES:
		var r: float
		if rates.has(k):
			r = float(rates[k])
		elif act.has(k):
			r = float(act[k])
		else:
			r = float(BASE_RATES[k]) * float(mult.get(k, 1.0))
		add(k, r * minutes)
	var c := get_value("conforto")
	if rates.has("conforto"):
		add("conforto", float(rates["conforto"]) * minutes)
	else:
		var step := COMFORT_RATE * minutes
		set_value("conforto", move_toward(c, comfort_target, step))


## Palavra curta para a interface ("faminta", "sonolento"...).
static func state_word(key: String, value: float, article: String = "a") -> String:
	if value >= 60.0:
		return ""
	var strong := value < CRITICAL
	match key:
		"fome":
			return "faminta" if strong and article == "a" else ("faminto" if strong else "com fome")
		"energia":
			return "exaust" + article if strong else "com sono"
		"higiene":
			return "precisando de um banho"
		"banheiro":
			return "apertad" + article if strong else "precisando ir ao banheiro"
		"diversao":
			return "entediad" + article
		"social":
			return "sozinh" + article if strong else "querendo companhia"
		"conforto":
			return "desconfortável"
	return ""


func to_dict() -> Dictionary:
	var out := {}
	for k in KEYS:
		out[k] = snappedf(get_value(k), 0.01)
	return out
