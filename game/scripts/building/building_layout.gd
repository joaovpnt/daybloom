class_name BuildingLayout
extends RefCounted
## Daybloom Residence (0.4): mapa lógico do prédio. Cada andar tem seu próprio
## espaço local (x ∈ [-12, 12], z ∈ [-9, 9], piso em y = 0); só o andar atual é
## construído na tela, mas a simulação usa estes dados para todos os andares.
##
## Núcleo comum a todos os andares (faixa sul, z ∈ [4.5, 9]):
##   elevador na ponta oeste e escadas na ponta leste.
## Andares 1–8: um apartamento por morador; 9º andar: apartamento da jogadora.

const HALF_X := 12.0
const HALF_Z := 9.0
const CORE_Z := 4.5
const FLOOR_HEIGHT := 3.2
const WALL_HEIGHT := 2.7
const WALL_THICK := 0.2

const FLOORS := [
	{"id": "subsolo", "label": "Subsolo", "short": "S", "level": -1, "kind": "common", "areas": "Academia · Lavanderia · Depósito"},
	{"id": "terreo", "label": "Térreo", "short": "T", "level": 0, "kind": "common", "areas": "Hall · Mercadinho · Convivência · Pátio"},
	{"id": "andar_1", "label": "1º andar", "short": "1", "level": 1, "kind": "apartment", "owner": "lila"},
	{"id": "andar_2", "label": "2º andar", "short": "2", "level": 2, "kind": "apartment", "owner": "tobias"},
	{"id": "andar_3", "label": "3º andar", "short": "3", "level": 3, "kind": "apartment", "owner": "marina"},
	{"id": "andar_4", "label": "4º andar", "short": "4", "level": 4, "kind": "apartment", "owner": "otavio"},
	{"id": "andar_5", "label": "5º andar", "short": "5", "level": 5, "kind": "apartment", "owner": "pipa"},
	{"id": "andar_6", "label": "6º andar", "short": "6", "level": 6, "kind": "apartment", "owner": "bento"},
	{"id": "andar_7", "label": "7º andar", "short": "7", "level": 7, "kind": "apartment", "owner": "ravena"},
	{"id": "andar_8", "label": "8º andar", "short": "8", "level": 8, "kind": "apartment", "owner": "celeste"},
	{"id": "andar_9", "label": "9º andar", "short": "9", "level": 9, "kind": "apartment", "owner": "player"},
	{"id": "cobertura", "label": "Cobertura", "short": "C", "level": 10, "kind": "common", "areas": "Piscina · Churrasqueira · Jardim"},
]

const OWNER_FLOOR := {
	"lila": "andar_1", "tobias": "andar_2", "marina": "andar_3", "otavio": "andar_4",
	"pipa": "andar_5", "bento": "andar_6", "ravena": "andar_7", "celeste": "andar_8", "player": "andar_9",
}

## Elevador (cabine na parede oeste, porta voltada para +X) e escadas (leste).
const ELEVATOR_POS := Vector3(-11.15, 0, 6.75)
const ELEVATOR_CALL := Vector3(-9.4, 0, 6.75)
const STAIRS_POS := Vector3(10.6, 0, 6.75)
const STAIRS_CALL := Vector3(8.9, 0, 6.75)
## Porta do apartamento (parede z = 4.5, no meio).
const APT_DOOR := Vector3(0, 0, 4.5)
const APT_DOOR_OUT := Vector3(0, 0, 5.7)
const APT_DOOR_IN := Vector3(0, 0, 3.3)
const DOOR_HALF := 0.7
## Porta principal do térreo (fachada sul) e pátio externo.
const MAIN_DOOR := Vector3(0, 0, 9.0)
const PATIO_RECT := Rect2(-16, 9, 32, 15)

## Cores de cada apartamento (recolorem os materiais DB_accent, DB_accent2 e
## DB_wood_theme dos móveis, além de piso e paredes).
const THEMES := {
	"lila": {"accent": Color(0.98, 0.70, 0.78), "accent2": Color(0.80, 0.92, 0.72), "wood": Color(0.90, 0.76, 0.58), "floor": Color(0.93, 0.85, 0.72), "wall": Color(0.99, 0.93, 0.92), "label": "Apartamento da Lila"},
	"tobias": {"accent": Color(0.92, 0.62, 0.36), "accent2": Color(0.98, 0.88, 0.70), "wood": Color(0.62, 0.42, 0.26), "floor": Color(0.80, 0.58, 0.40), "wall": Color(0.99, 0.93, 0.82), "label": "Apartamento do Tobias"},
	"marina": {"accent": Color(0.30, 0.68, 0.76), "accent2": Color(0.96, 0.88, 0.70), "wood": Color(0.86, 0.76, 0.62), "floor": Color(0.84, 0.90, 0.90), "wall": Color(0.88, 0.95, 0.97), "label": "Apartamento da Marina"},
	"otavio": {"accent": Color(0.30, 0.36, 0.62), "accent2": Color(0.95, 0.82, 0.45), "wood": Color(0.50, 0.34, 0.22), "floor": Color(0.62, 0.46, 0.32), "wall": Color(0.86, 0.86, 0.94), "label": "Apartamento do Otávio"},
	"pipa": {"accent": Color(0.90, 0.38, 0.30), "accent2": Color(0.99, 0.84, 0.40), "wood": Color(0.82, 0.60, 0.38), "floor": Color(0.90, 0.80, 0.62), "wall": Color(0.99, 0.95, 0.85), "label": "Apartamento da Pipa"},
	"bento": {"accent": Color(0.50, 0.78, 0.42), "accent2": Color(0.92, 0.40, 0.36), "wood": Color(0.72, 0.52, 0.32), "floor": Color(0.80, 0.70, 0.50), "wall": Color(0.93, 0.98, 0.86), "label": "Apartamento do Bento"},
	"ravena": {"accent": Color(0.58, 0.36, 0.66), "accent2": Color(0.96, 0.60, 0.30), "wood": Color(0.40, 0.28, 0.24), "floor": Color(0.56, 0.44, 0.40), "wall": Color(0.96, 0.90, 0.86), "label": "Apartamento da Ravena"},
	"celeste": {"accent": Color(0.78, 0.66, 0.90), "accent2": Color(0.97, 0.80, 0.78), "wood": Color(0.84, 0.70, 0.56), "floor": Color(0.92, 0.86, 0.80), "wall": Color(0.99, 0.96, 0.94), "label": "Apartamento da Dona Celeste"},
	"player": {"accent": Color(0.96, 0.58, 0.50), "accent2": Color(0.98, 0.88, 0.68), "wood": Color(0.82, 0.64, 0.44), "floor": Color(0.88, 0.76, 0.60), "wall": Color(0.99, 0.95, 0.88), "label": "Seu apartamento"},
	"common": {"accent": Color(0.96, 0.62, 0.48), "accent2": Color(0.99, 0.88, 0.66), "wood": Color(0.80, 0.62, 0.42), "floor": Color(0.90, 0.84, 0.74), "wall": Color(0.99, 0.95, 0.88), "label": "Áreas comuns"},
}

## Cômodos do apartamento (x, z, largura, profundidade).
const ROOMS := {
	"quarto": Rect2(-12, -9, 8, 8),
	"banheiro": Rect2(-12, -1, 8, 5.5),
	"sala": Rect2(-4, -9, 9, 13.5),
	"cozinha": Rect2(5, -9, 7, 8),
	"hobby": Rect2(5, -1, 7, 5.5),
}
const ROOM_LABELS := {"quarto": "quarto", "banheiro": "banheiro", "sala": "sala", "cozinha": "cozinha", "hobby": "cantinho dos hobbies", "corredor": "corredor"}
const APARTMENT_RECT := Rect2(-12, -9, 24, 13.5)

## Áreas nomeadas dos andares comuns.
const COMMON_AREAS := {
	"terreo": {
		"mercadinho": Rect2(3, -9, 9, 10),
		"coworking": Rect2(-12, -9, 9, 8),
		"convivencia": Rect2(-3, -9, 6, 13.5),
		"hall": Rect2(-12, 1, 24, 8),
		"patio": PATIO_RECT,
	},
	"subsolo": {
		"academia": Rect2(-12, -9, 12, 13.5),
		"lavanderia": Rect2(0, -9, 12, 9),
		"deposito": Rect2(0, 0, 12, 4.5),
		"corredor": Rect2(-12, 4.5, 24, 4.5),
	},
	"cobertura": {
		"piscina": Rect2(0.5, -9, 9, 9),
		"churrasqueira": Rect2(-12, -9, 12, 9),
		"jardim_cobertura": Rect2(9.5, -9, 2.5, 18),
		"descanso_cobertura": Rect2(-6, 0, 15.5, 9),
	},
}


# --- andares ---------------------------------------------------------------------

static func floor_ids() -> Array:
	var out := []
	for f in FLOORS:
		out.append(f["id"])
	return out


static func has_floor(floor_id: String) -> bool:
	for f in FLOORS:
		if f["id"] == floor_id:
			return true
	return false


static func floor_info(floor_id: String) -> Dictionary:
	for f in FLOORS:
		if f["id"] == floor_id:
			return f
	return {}


static func floor_label(floor_id: String) -> String:
	return str(floor_info(floor_id).get("label", floor_id))


static func level_of(floor_id: String) -> int:
	return int(floor_info(floor_id).get("level", 0))


static func floor_at_level(level: int) -> String:
	for f in FLOORS:
		if int(f["level"]) == level:
			return f["id"]
	return ""


static func owner_of(floor_id: String) -> String:
	return str(floor_info(floor_id).get("owner", ""))


static func is_apartment_floor(floor_id: String) -> bool:
	return floor_info(floor_id).get("kind", "") == "apartment"


static func floor_of_owner(owner: String) -> String:
	return str(OWNER_FLOOR.get(owner, ""))


static func theme_for_floor(floor_id: String) -> Dictionary:
	var owner := owner_of(floor_id)
	return THEMES.get(owner if owner != "" else "common", THEMES["common"])


## Minutos de jogo de uma viagem de elevador (espera + percurso).
static func elevator_minutes(from_floor: String, to_floor: String) -> float:
	return 1.0 + 0.25 * absi(level_of(to_floor) - level_of(from_floor))


## Minutos de jogo de escada (por andar).
static func stairs_minutes(from_floor: String, to_floor: String) -> float:
	return 1.5 * absi(level_of(to_floor) - level_of(from_floor))


# --- zonas e cômodos ------------------------------------------------------------------

static func in_apartment(floor_id: String, p: Vector3) -> bool:
	if not is_apartment_floor(floor_id):
		return false
	return APARTMENT_RECT.has_point(Vector2(p.x, p.z))


## Cômodo ou área em que um ponto está ("sala", "corredor", "mercadinho"...).
static func room_at(floor_id: String, p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	if is_apartment_floor(floor_id):
		for key in ROOMS:
			if (ROOMS[key] as Rect2).has_point(q):
				return key
		return "corredor"
	var areas: Dictionary = COMMON_AREAS.get(floor_id, {})
	# Ordem importa: áreas mais específicas primeiro.
	for key in ["mercadinho", "coworking", "lavanderia", "deposito", "piscina", "churrasqueira", "jardim_cobertura", "patio", "academia", "convivencia", "hall", "descanso_cobertura", "corredor"]:
		if areas.has(key) and (areas[key] as Rect2).has_point(q):
			return key
	return "hall" if floor_id == "terreo" else ("corredor" if floor_id == "subsolo" else "descanso_cobertura")


static func room_label(floor_id: String, room: String) -> String:
	if ROOM_LABELS.has(room):
		return ROOM_LABELS[room]
	return Places.poi_label(room)


## Zona de visibilidade (quem está na mesma zona pode se ver): o interior de
## cada apartamento é uma zona; o resto do andar é outra.
static func zone_of(floor_id: String, p: Vector3) -> String:
	if in_apartment(floor_id, p):
		return "apto:" + floor_id
	return "comum:" + floor_id


## Limites caminháveis do andar (inclui o pátio no térreo).
static func walk_bounds(floor_id: String) -> Rect2:
	if floor_id == "terreo":
		return Rect2(-16, -9, 32, 33)
	return Rect2(-HALF_X, -HALF_Z, HALF_X * 2.0, HALF_Z * 2.0)


static func clamp_to_floor(floor_id: String, p: Vector3) -> Vector3:
	var r := walk_bounds(floor_id).grow(-0.6)
	return Vector3(clampf(p.x, r.position.x, r.end.x), 0.0, clampf(p.z, r.position.y, r.end.y))


# --- paredes ------------------------------------------------------------------------

## Segmentos de parede de cada tipo de andar: {a, b, ext, windows: [t...]}.
## Vãos de porta já estão descontados (segmentos separados).
static func walls(floor_id: String) -> Array:
	if is_apartment_floor(floor_id):
		return _apartment_walls()
	match floor_id:
		"terreo":
			return _ground_walls()
		"subsolo":
			return _basement_walls()
	return []


static func _w(ax: float, az: float, bx: float, bz: float, ext: bool = false, windows: Array = []) -> Dictionary:
	return {"a": Vector2(ax, az), "b": Vector2(bx, bz), "ext": ext, "windows": windows}


static func _apartment_walls() -> Array:
	return [
		_w(-12, -9, 12, -9, true, [-8.0, 0.5, 8.5]),
		_w(-12, -9, -12, 9, true, [-5.0, 1.8]),
		_w(12, -9, 12, 9, true, [-5.0]),
		_w(-12, 9, 12, 9, true, [-4.0, 4.0]),
		_w(-12, 4.5, -DOOR_HALF, 4.5),
		_w(DOOR_HALF, 4.5, 12, 4.5),
		_w(-4, -9, -4, -5.2),
		_w(-4, -3.8, -4, 1.0),
		_w(-4, 2.4, -4, 4.5),
		_w(-12, -1, -4, -1),
		_w(5, -9, 5, -7.6),
		_w(5, -2.4, 5, 1.4),
		_w(5, 2.8, 5, 4.5),
		_w(5, -1, 12, -1),
	]


static func _ground_walls() -> Array:
	return [
		_w(-12, -9, 12, -9, true, [-8.0, -1.0]),
		_w(-12, -9, -12, 9, true, [-5.0]),
		_w(12, -9, 12, 9, true, [5.0]),
		_w(-12, 9, -1.4, 9, true),
		_w(1.4, 9, 12, 9, true),
		# mercadinho
		_w(3, -9, 3, -3.0),
		_w(3, -1.4, 3, 1),
		_w(3, 1, 6.4, 1),
		_w(8.6, 1, 12, 1),
		# espaço de trabalho
		_w(-3, -9, -3, -4.6),
		_w(-3, -3.2, -3, -1),
		_w(-12, -1, -8.2, -1),
		_w(-6.6, -1, -3, -1),
	]


static func _basement_walls() -> Array:
	return [
		_w(-12, -9, 12, -9, true),
		_w(-12, -9, -12, 9, true),
		_w(12, -9, 12, 9, true),
		_w(-12, 9, 12, 9, true),
		_w(-12, 4.5, -6.6, 4.5),
		_w(-5.2, 4.5, 5.2, 4.5),
		_w(6.6, 4.5, 12, 4.5),
		_w(0, -9, 0, 4.5),
		_w(0, 0, 5.0, 0),
		_w(6.4, 0, 12, 0),
	]


# --- objetos fixos ----------------------------------------------------------------------

static func _o(key: String, def_id: String, x: float, z: float, rot: float = 0.0, extra: Dictionary = {}) -> Dictionary:
	var d := {"key": key, "def": def_id, "pos": Vector2(x, z), "rot": rot}
	d.merge(extra)
	return d


## Objetos fixos de um andar. Cada um recebe uid "<andar>:<key>".
static func fixed_objects(floor_id: String) -> Array:
	var list: Array
	if is_apartment_floor(floor_id):
		var owner := owner_of(floor_id)
		list = _apartment_base(owner) + _apartment_extras(owner)
	else:
		match floor_id:
			"terreo":
				list = _ground_objects()
			"subsolo":
				list = _basement_objects()
			"cobertura":
				list = _rooftop_objects()
			_:
				list = []
	var out := []
	for o in list:
		var d: Dictionary = (o as Dictionary).duplicate()
		d["uid"] = "%s:%s" % [floor_id, d["key"]]
		d["floor"] = floor_id
		d["fixed"] = true
		out.append(d)
	return out


static func _apartment_base(owner: String) -> Array:
	var list := [
		# cozinha (todos)
		_o("geladeira", "geladeira", 6.0, -8.6),
		_o("fogao", "fogao", 7.35, -8.62),
		_o("pia_cozinha", "pia_cozinha", 8.85, -8.62),
		# banheiro (todos)
		_o("chuveiro", "chuveiro", -11.5, -0.5, PI / 2.0),
		_o("vaso", "vaso_sanitario", -11.62, 2.7, PI / 2.0),
		_o("pia_banheiro", "pia_banheiro", -8.6, -0.76),
	]
	if owner == "tobias":
		list.append(_o("forno", "forno_lenha", 10.5, -8.5))
	else:
		list.append(_o("balcao", "balcao", 10.35, -8.62))
	if owner == "player":
		list.append(_o("bancada", "bancada_trabalho", 11.3, 2.2, -PI / 2.0))
		list.append(_o("guarda_roupa", "guarda_roupa", -5.3, -8.65))
		return list
	# Móveis dos moradores (fixos para eles).
	list += [
		_o("cama", "cama", -9.4, -7.85),
		_o("criado_mudo", "criado_mudo", -11.3, -8.7),
		_o("guarda_roupa", "guarda_roupa", -5.3, -8.65),
		_o("tapete_quarto", "tapete", -8.6, -5.0),
		_o("luminaria_quarto", "luminaria", -11.3, -2.0),
		_o("tv", "tv", 0.5, -8.62),
		_o("tapete_sala", "tapete", 0.5, -5.6),
		_o("mesa_centro", "mesa_centro", 0.5, -5.7),
		_o("sofa", "sofa", 0.5, -3.5, PI),
		_o("poltrona", "poltrona", -2.9, -5.8, PI / 2.0),
		_o("mesa_jantar", "mesa_jantar", 0.5, 1.3),
		_o("cadeira_1", "cadeira", 0.15, 0.5),
		_o("cadeira_2", "cadeira", 0.85, 0.5),
		_o("cadeira_3", "cadeira", 0.15, 2.1, PI),
		_o("cadeira_4", "cadeira", 0.85, 2.1, PI),
		_o("planta_sala", "planta_grande", -3.4, -8.4),
		_o("planta_entrada", "planta_grande", 4.3, 3.8),
		_o("luminaria_sala", "luminaria", 4.4, -8.4),
		_o("mesa_cozinha", "mesa_pequena", 9.0, -4.6),
		_o("cadeira_cozinha", "cadeira", 9.0, -3.75, PI),
	]
	return list


static func _apartment_extras(owner: String) -> Array:
	match owner:
		"lila":
			return [
				_o("bancada_plantas", "bancada_trabalho", 8.6, -0.62),
				_o("planta_hobby_1", "planta_grande", 6.0, -0.3),
				_o("planta_hobby_2", "planta_grande", 11.3, -0.3),
				_o("vaso_1", "vaso_decorativo", 6.3, 3.9),
				_o("vaso_2", "vaso_decorativo", 8.4, 3.9),
				_o("vaso_3", "vaso_decorativo", 11.4, 3.7),
				_o("vaso_4", "vaso_decorativo", -5.0, -2.0),
			]
		"tobias":
			return [
				_o("balcao_hobby_1", "balcao", 7.6, -0.62),
				_o("balcao_hobby_2", "balcao", 8.65, -0.62),
				_o("estante_receitas", "estante", 11.5, 1.6, -PI / 2.0),
				_o("quadro_pao", "quadro", 9.0, -0.92, 0.0, {"wall_y": 1.6}),
			]
		"marina":
			return [
				_o("prancha", "prancha_surf", 11.6, -0.4, -PI / 2.0),
				_o("halteres", "halteres", 8.0, -0.72),
				_o("tapete_yoga", "tapete", 8.5, 2.0),
				_o("planta_hobby", "planta_grande", 6.0, 3.8),
			]
		"otavio":
			return [
				_o("telescopio", "telescopio", 10.6, 3.2),
				_o("estante_1", "estante", 6.2, -0.62),
				_o("estante_2", "estante", 7.3, -0.62),
				_o("escrivaninha", "escrivaninha", 9.9, -0.66),
				_o("cadeira_estudo", "cadeira", 9.9, 0.15, PI),
			]
		"pipa":
			return [
				_o("organizador", "organizador_cartas", 8.0, -0.76),
				_o("escrivaninha", "escrivaninha", 11.3, 1.8, -PI / 2.0),
				_o("cadeira_estudo", "cadeira", 10.5, 1.8, PI / 2.0),
				_o("mapa", "quadro", 6.0, -0.92, 0.0, {"wall_y": 1.6}),
			]
		"bento":
			return [
				_o("piano", "piano", 8.0, -0.66),
				_o("banco_piano", "banco", 8.0, 0.35),
				_o("violao", "violao_suporte", 6.0, -0.45),
				_o("tapete_musica", "tapete", 8.6, 2.4),
			]
		"ravena":
			return [
				_o("cavalete_1", "cavalete_pintura", 7.2, 1.2, PI),
				_o("cavalete_2", "cavalete_pintura", 10.2, 1.2, PI),
				_o("quadro_1", "quadro", 7.0, -0.92, 0.0, {"wall_y": 1.6}),
				_o("quadro_2", "quadro", 10.0, -0.92, 0.0, {"wall_y": 1.6}),
				_o("quadro_3", "quadro", 0.5, -8.88, 0.0, {"wall_y": 1.9}),
			]
		"celeste":
			return [
				_o("costura", "maquina_costura", 8.0, -0.7),
				_o("cadeira_costura", "cadeira", 8.0, 0.15, PI),
				_o("tecidos", "rolos_tecido", 11.2, -0.5),
				_o("estante_linhas", "estante", 11.5, 2.6, -PI / 2.0),
			]
	return []


static func _ground_objects() -> Array:
	return [
		# hall
		_o("recepcao", "recepcao", -5.5, 6.9),
		_o("caixas_correio", "caixas_correio", 5.2, 8.72, PI),
		_o("planta_hall_1", "planta_grande", -2.2, 8.4),
		_o("planta_hall_2", "planta_grande", 2.2, 8.4),
		_o("banco_hall", "banco", 8.0, 6.6),
		# convivência
		_o("sofa_lounge", "sofa_lounge", 0.0, 2.6, PI),
		_o("mesa_centro", "mesa_centro", 0.0, 0.9),
		_o("poltrona_1", "poltrona", -2.1, 0.8, PI / 2.0),
		_o("poltrona_2", "poltrona", 2.1, 0.8, -PI / 2.0),
		_o("tapete_conv", "tapete", 0.0, 1.0),
		_o("maquina_cafe", "maquina_cafe", -1.5, -8.62),
		_o("piano", "piano", 1.35, -8.6),
		_o("banco_piano", "banco", 1.35, -7.55),
		_o("planta_conv_1", "planta_grande", -2.4, -5.0),
		_o("planta_conv_2", "planta_grande", 2.4, -5.0),
		_o("mesa_conv", "mesa_redonda", 0.0, -4.0),
		_o("cadeira_conv_1", "cadeira", -0.8, -4.0, PI / 2.0),
		_o("cadeira_conv_2", "cadeira", 0.8, -4.0, -PI / 2.0),
		# espaço de trabalho
		_o("cowork_1", "mesa_cowork", -7.5, -6.6),
		_o("cowork_2", "mesa_cowork", -7.5, -3.3),
		_o("cadeira_cw_1", "cadeira", -8.1, -7.45),
		_o("cadeira_cw_2", "cadeira", -6.9, -5.75, PI),
		_o("cadeira_cw_3", "cadeira", -8.1, -4.15),
		_o("cadeira_cw_4", "cadeira", -6.9, -2.45, PI),
		_o("estante_cw", "estante", -11.55, -5.0, PI / 2.0),
		_o("planta_cw", "planta_grande", -11.3, -8.4),
		# mercadinho
		_o("prateleira_1", "estante_mercado", 5.4, -8.65),
		_o("prateleira_2", "estante_mercado", 9.3, -8.65),
		_o("prateleira_3", "estante_mercado", 5.4, -5.0),
		_o("prateleira_4", "estante_mercado", 9.3, -5.0),
		_o("freezer", "freezer_mercado", 11.55, -2.2, -PI / 2.0),
		_o("caixa", "caixa_mercado", 5.0, -1.2),
		_o("estoque", "caixa_estoque", 11.2, -6.9),
		_o("flores_mercado", "vaso_decorativo", 3.6, 0.4),
		# pátio externo
		_o("horta_1", "canteiro_horta", -11.0, 12.8),
		_o("horta_2", "canteiro_horta", -11.0, 15.3),
		_o("horta_3", "canteiro_horta", -11.0, 17.8),
		_o("fonte", "fonte", 0.0, 16.5),
		_o("banco_patio_1", "banco_praca", 5.5, 13.4, PI),
		_o("banco_patio_2", "banco_praca", -5.5, 13.4, PI),
		_o("banco_patio_3", "banco_praca", 4.5, 20.6),
		_o("mesa_piquenique", "mesa_piquenique", 10.5, 19.5),
	]


static func _basement_objects() -> Array:
	return [
		_o("esteira_1", "esteira", -10.5, -7.6),
		_o("esteira_2", "esteira", -8.6, -7.6),
		_o("supino", "banco_supino", -5.5, -7.3),
		_o("halteres", "halteres", -2.0, -8.75),
		_o("tapete_academia", "tapete", -6.0, -2.6),
		_o("planta_academia", "planta_grande", -11.3, 3.6),
		_o("lavar_1", "maquina_lavar", 2.0, -8.66),
		_o("lavar_2", "maquina_lavar", 3.0, -8.66),
		_o("lavar_3", "maquina_lavar", 4.0, -8.66),
		_o("varal_1", "varal", 8.0, -6.0),
		_o("varal_2", "varal", 8.0, -3.4),
		_o("balcao_lavanderia", "balcao", 10.8, -8.62),
		_o("caixa_dep_1", "caixote", 10.8, 1.2),
		_o("caixa_dep_2", "caixote", 11.2, 2.3, 0.4),
		_o("barril_dep", "barril", 9.6, 1.0),
		_o("estante_dep", "estante", 11.55, 3.4, -PI / 2.0),
		_o("bancada_manutencao", "bancada_trabalho", 2.6, 0.9),
	]


static func _rooftop_objects() -> Array:
	return [
		_o("piscina", "piscina", 4.5, -5.2),
		_o("espreguicadeira_1", "espreguicadeira", 2.6, -1.2),
		_o("espreguicadeira_2", "espreguicadeira", 4.5, -1.2),
		_o("espreguicadeira_3", "espreguicadeira", 6.4, -1.2),
		_o("churrasqueira", "churrasqueira", -8.6, -8.45),
		_o("pergolado", "pergolado", -6.8, -3.2),
		_o("mesa_1", "mesa_redonda", -8.6, -4.4),
		_o("mesa_2", "mesa_redonda", -5.0, -4.4),
		_o("mesa_3", "mesa_redonda", -6.8, -1.6),
		_o("cadeira_m1a", "cadeira_externa", -9.5, -4.4, PI / 2.0),
		_o("cadeira_m1b", "cadeira_externa", -7.7, -4.4, -PI / 2.0),
		_o("cadeira_m2a", "cadeira_externa", -5.9, -4.4, PI / 2.0),
		_o("cadeira_m2b", "cadeira_externa", -4.1, -4.4, -PI / 2.0),
		_o("cadeira_m3a", "cadeira_externa", -7.7, -1.6, PI / 2.0),
		_o("cadeira_m3b", "cadeira_externa", -5.9, -1.6, -PI / 2.0),
		_o("luzinhas_1", "luzinhas", -11.3, -0.4),
		_o("luzinhas_2", "luzinhas", -2.4, -0.4),
		_o("luzinhas_3", "luzinhas", -2.4, -8.4),
		_o("horta_cobertura", "canteiro_horta", 10.6, -8.2),
		_o("planta_c1", "planta_grande", 11.3, -5.5),
		_o("planta_c2", "planta_grande", 11.3, -2.5),
		_o("planta_c3", "planta_grande", -0.6, -8.4),
		_o("telescopio", "telescopio", 9.6, 2.0),
		_o("banco_observatorio", "banco", 8.0, 2.6),
		_o("poltrona_desc_1", "poltrona", -1.2, 2.8, PI / 2.0),
		_o("poltrona_desc_2", "poltrona", 2.2, 2.8, -PI / 2.0),
		_o("mesa_desc", "mesa_centro", 0.5, 2.8),
		_o("tapete_desc", "tapete", 0.5, 2.8),
		_o("vaso_desc", "vaso_decorativo", 0.5, 4.2),
	]


## Pontos onde objetos de enfeite aparecem quando objetivos dos moradores se
## concretizam (estado persistente em world.building.decor).
const DECOR_SPOTS := {
	"hall_plantas": {"floor": "terreo", "items": [["planta_grande", Vector2(-9.0, 2.0)], ["vaso_decorativo", Vector2(-7.0, 1.8)], ["planta_grande", Vector2(9.5, 2.0)], ["vaso_decorativo", Vector2(7.2, 1.8)]]},
	"hall_quadros": {"floor": "terreo", "items": [["quadro", Vector2(-1.5, -8.88)], ["quadro", Vector2(-8.0, -0.88)], ["quadro", Vector2(-10.0, -0.88)]]},
	"convivencia_tecidos": {"floor": "terreo", "items": [["tapete", Vector2(0.0, -2.2)], ["rolos_tecido", Vector2(-2.3, -2.5)]]},
	"correio_organizado": {"floor": "terreo", "items": [["organizador_cartas", Vector2(8.2, 8.75)]]},
	"observatorio": {"floor": "cobertura", "items": [["luzinhas", Vector2(11.0, 3.6)], ["estante", Vector2(11.5, 0.8)]]},
	"piscina_aula": {"floor": "cobertura", "items": [["prancha_surf", Vector2(8.4, -8.5)]]},
}
