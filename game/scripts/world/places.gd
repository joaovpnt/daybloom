class_name Places
extends RefCounted
## Mapa lógico do Daybloom Residence (0.4): lugares nomeados com andar,
## posição local, raio e rótulo. Usado pela simulação, pela IA e pelo
## construtor dos andares. IDs são persistentes.

const POIS := {
	# Térreo
	"hall": {"floor": "terreo", "pos": Vector2(-1.5, 6.4), "radius": 2.2, "label": "hall de entrada"},
	"convivencia": {"floor": "terreo", "pos": Vector2(0.0, -1.6), "radius": 2.2, "label": "sala de convivência"},
	"mercadinho": {"floor": "terreo", "pos": Vector2(7.4, -3.2), "radius": 1.8, "label": "mercadinho"},
	"coworking": {"floor": "terreo", "pos": Vector2(-7.5, -4.95), "radius": 1.6, "label": "espaço de trabalho"},
	"patio": {"floor": "terreo", "pos": Vector2(2.5, 12.6), "radius": 3.0, "label": "pátio"},
	"horta": {"floor": "terreo", "pos": Vector2(-9.0, 15.3), "radius": 1.6, "label": "horta comunitária"},
	# Subsolo
	"academia": {"floor": "subsolo", "pos": Vector2(-6.0, -4.0), "radius": 2.5, "label": "academia"},
	"lavanderia": {"floor": "subsolo", "pos": Vector2(5.5, -5.0), "radius": 2.0, "label": "lavanderia"},
	"deposito": {"floor": "subsolo", "pos": Vector2(6.5, 2.4), "radius": 1.6, "label": "depósito"},
	# Cobertura
	"piscina": {"floor": "cobertura", "pos": Vector2(4.5, -1.0), "radius": 2.0, "label": "piscina"},
	"churrasqueira": {"floor": "cobertura", "pos": Vector2(-8.6, -6.9), "radius": 1.3, "label": "churrasqueira"},
	"mesas_cobertura": {"floor": "cobertura", "pos": Vector2(-6.8, -2.9), "radius": 2.2, "label": "mesas da cobertura"},
	"jardim_cobertura": {"floor": "cobertura", "pos": Vector2(9.6, -5.5), "radius": 1.6, "label": "jardim da cobertura"},
	"observatorio": {"floor": "cobertura", "pos": Vector2(8.8, 3.4), "radius": 1.4, "label": "observatório da cobertura"},
	"descanso_cobertura": {"floor": "cobertura", "pos": Vector2(0.5, 1.2), "radius": 2.0, "label": "área de descanso da cobertura"},
}

## Apartamentos: "apto_<morador>" (ponto central da sala).
const APT_CENTER := Vector2(0.5, -0.8)

## Hobbies: onde são praticados. `aff` = ação em um objeto do próprio
## apartamento (quando `place` é "home") ou do lugar indicado.
const HOBBY_SPOTS := {
	"jardinagem": {"place": "horta", "aff": "cuidar_horta", "text": "cuidando da horta", "topic": "flores e mudas"},
	"musica": {"place": "home", "aff": "tocar", "text": "tocando música", "topic": "música", "loud": true},
	"leitura": {"place": "home", "aff": "ler", "text": "lendo um livro", "topic": "livros"},
	"pintura": {"place": "home", "aff": "pintar", "text": "pintando no ateliê", "topic": "pintura"},
	"natacao": {"place": "piscina", "aff": "nadar", "text": "nadando na piscina", "topic": "natação"},
	"observar_estrelas": {"place": "observatorio", "aff": "observar", "text": "observando as estrelas", "topic": "as estrelas"},
	"culinaria": {"place": "home", "aff": "cozinhar", "text": "testando receitas", "topic": "receitas"},
	"contemplar": {"place": "descanso_cobertura", "aff": "sentar", "text": "admirando a vista da cobertura", "topic": "a vista da cidade"},
	"costura": {"place": "home", "aff": "costurar", "text": "costurando", "topic": "costura"},
	"conversar": {"place": "convivencia", "aff": "sentar", "text": "puxando conversa", "topic": "as novidades do prédio"},
	"corrida": {"place": "academia", "aff": "exercitar", "text": "correndo na esteira", "topic": "exercícios"},
	"passear": {"place": "patio", "aff": "", "text": "passeando pelo pátio", "topic": "os cantinhos do prédio"},
	"horta": {"place": "horta", "aff": "cuidar_horta", "text": "colhendo verduras na horta", "topic": "verduras"},
	"cartas": {"place": "home", "aff": "organizar_cartas", "text": "organizando cartas", "topic": "cartas e recados"},
}

## Lugares que um morador curioso pode explorar.
const EXPLORE_SPOTS := ["patio", "horta", "convivencia", "piscina", "jardim_cobertura", "descanso_cobertura", "observatorio", "academia", "hall"]

## Atividades que podem ser feitas em dupla em cada lugar.
const SHARED_ACTIVITIES := {
	"horta": "cuidaram juntos da horta comunitária",
	"convivencia": "tomaram um café juntos na convivência",
	"patio": "passearam juntos pelo pátio",
	"piscina": "nadaram juntos na piscina",
	"mesas_cobertura": "dividiram um lanche nas mesas da cobertura",
	"descanso_cobertura": "admiraram a vista da cobertura",
	"observatorio": "observaram as estrelas na cobertura",
	"jardim_cobertura": "regaram o jardim da cobertura",
	"academia": "treinaram juntos na academia",
	"coworking": "trabalharam lado a lado no espaço de trabalho",
	"mercadinho": "fizeram compras juntos no mercadinho",
	"hall": "conversaram no hall de entrada",
}


static func apt_id(owner: String) -> String:
	return "apto_" + owner


static func is_apartment(place: String) -> bool:
	return place.begins_with("apto_")


static func apt_owner(place: String) -> String:
	return place.trim_prefix("apto_") if is_apartment(place) else ""


static func floor_of(place: String) -> String:
	if POIS.has(place):
		return POIS[place]["floor"]
	if is_apartment(place):
		return BuildingLayout.floor_of_owner(apt_owner(place))
	if place.begins_with("corredor_"):
		return place.trim_prefix("corredor_")
	return ""


## Posição local (no andar do lugar).
static func poi_pos(place: String) -> Vector3:
	if POIS.has(place):
		var p: Vector2 = POIS[place]["pos"]
		return Vector3(p.x, 0.0, p.y)
	if is_apartment(place):
		return Vector3(APT_CENTER.x, 0.0, APT_CENTER.y)
	if place.begins_with("corredor_"):
		return Vector3(2.5, 0.0, 6.8)
	return Vector3.ZERO


static func poi_radius(place: String) -> float:
	if POIS.has(place):
		return float(POIS[place]["radius"])
	return 1.5


static func poi_label(place: String) -> String:
	if POIS.has(place):
		return POIS[place]["label"]
	if is_apartment(place):
		var owner := apt_owner(place)
		if owner == "player":
			return "apartamento da jogadora"
		var t: Dictionary = BuildingLayout.THEMES.get(owner, {})
		var l := str(t.get("label", "Apartamento"))
		return l.substr(0, 1).to_lower() + l.substr(1)
	if place.begins_with("corredor_"):
		return "corredor do " + BuildingLayout.floor_label(place.trim_prefix("corredor_"))
	return place


## Lugar nomeado mais próximo (no mesmo andar).
static func nearest_place(p: Vector3, floor_id: String) -> String:
	if BuildingLayout.in_apartment(floor_id, p):
		return apt_id(BuildingLayout.owner_of(floor_id))
	if BuildingLayout.is_apartment_floor(floor_id):
		return "corredor_" + floor_id
	var best := ""
	var best_d := INF
	for id in POIS:
		if POIS[id]["floor"] != floor_id:
			continue
		var d: float = Vector2(p.x, p.z).distance_to(POIS[id]["pos"]) - float(POIS[id]["radius"])
		if d < best_d:
			best_d = d
			best = id
	return best if best != "" else "corredor_" + floor_id


## Descrição curta de onde alguém está ("no mercadinho", "na sala do
## apartamento da Lila").
static func describe_location(floor_id: String, p: Vector3) -> String:
	var place := nearest_place(p, floor_id)
	if is_apartment(place):
		var room := BuildingLayout.room_at(floor_id, p)
		return "%s (%s)" % [poi_label(place), BuildingLayout.room_label(floor_id, room)]
	return "%s, %s" % [poi_label(place), BuildingLayout.floor_label(floor_id).to_lower()]
