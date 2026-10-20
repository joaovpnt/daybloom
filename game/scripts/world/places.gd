class_name Places
extends RefCounted
## Mapa lógico da ilha (versão 0.2): vila com bairros, centro comercial, lago,
## bosque, pomar, mirante, praia e área de lazer. Usado pelo construtor da ilha
## e pela IA. Os IDs de casas e pontos de interesse são persistentes e nunca
## mudam entre versões; apenas as posições foram redesenhadas.

const ISLAND_RADIUS := 42.0      # borda da grama
const BEACH_RADIUS := 49.0       # borda da areia
const WALK_RADIUS := 47.0        # limite caminhável

## Casas: posição (x, z) e direção da porta (`face`). Como nos jogos de vila
## aconchegantes, as fachadas ficam voltadas para a câmera (+Z).
const HOUSES := {
	"casa_jogadora": {"pos": Vector2(13, 26), "label": "Sua casa", "face": Vector2(0, 1)},
	"casa_lila": {"pos": Vector2(-26, 14), "label": "Casa da Lila", "face": Vector2(0, 1)},
	"casa_tobias": {"pos": Vector2(16, -9), "label": "Casa do Tobias", "face": Vector2(0, 1)},
	"casa_otavio": {"pos": Vector2(-11, -27), "label": "Casa do Otávio", "face": Vector2(0, 1)},
	"casa_pipa": {"pos": Vector2(4, -20), "label": "Casa da Pipa", "face": Vector2(0, 1)},
	"casa_marina": {"pos": Vector2(31, -7), "label": "Casa da Marina", "face": Vector2(0, 1)},
	"casa_bento": {"pos": Vector2(31, 8), "label": "Casa do Bento", "face": Vector2(0, 1)},
	"casa_ravena": {"pos": Vector2(-28, -14), "label": "Casa da Ravena", "face": Vector2(0, 1)},
	"casa_celeste": {"pos": Vector2(-15, 28), "label": "Casa da Dona Celeste", "face": Vector2(0, 1)},
}

const POIS := {
	"praca": {"pos": Vector2(0, 0), "radius": 6.0, "label": "praça central"},
	"jardim": {"pos": Vector2(-16, 11), "radius": 4.0, "label": "jardim comunitário"},
	"lago": {"pos": Vector2(21, 18), "radius": 5.5, "label": "lago"},
	"doca": {"pos": Vector2(14.6, 18.4), "radius": 1.5, "label": "píer do lago"},
	"quiosque": {"pos": Vector2(7.5, -6.0), "radius": 2.0, "label": "quiosque de pães"},
	"mural": {"pos": Vector2(-5.5, -6.5), "radius": 1.5, "label": "mural de recados"},
	"estante": {"pos": Vector2(-7.0, 5.5), "radius": 1.5, "label": "estante comunitária"},
	"coreto": {"pos": Vector2(11, 8), "radius": 2.5, "label": "coreto"},
	"banco_praca": {"pos": Vector2(4.2, 4.6), "radius": 1.2, "label": "banco da praça"},
	"mirante": {"pos": Vector2(-21, -31), "radius": 3.0, "label": "mirante"},
	"pomar": {"pos": Vector2(-34, 3), "radius": 4.0, "label": "pomar"},
	"bosque": {"pos": Vector2(24, -27), "radius": 4.0, "label": "bosque"},
	"parque": {"pos": Vector2(-3, 21), "radius": 3.5, "label": "parque"},
	"praia_sul": {"pos": Vector2(9, 44), "radius": 3.0, "label": "praia do sul"},
	"praia_leste": {"pos": Vector2(44, -5), "radius": 3.0, "label": "praia do leste"},
	"praia_norte": {"pos": Vector2(-4, -45), "radius": 3.0, "label": "praia do norte"},
	"fogueira": {"pos": Vector2(-14, 42), "radius": 2.5, "label": "fogueira da praia"},
}

## Hobbies: onde são praticados e como aparecem na tela/diário.
const HOBBY_SPOTS := {
	"jardinagem": {"place": "jardim", "text": "cuidando do jardim", "topic": "flores e mudas"},
	"musica": {"place": "coreto", "text": "tocando violão", "topic": "música"},
	"leitura": {"place": "estante", "text": "lendo um livro", "topic": "livros"},
	"pintura": {"place": "mirante", "text": "pintando a paisagem", "topic": "pintura"},
	"colecionar_conchas": {"place": "praia_leste", "text": "procurando conchas", "topic": "conchas"},
	"observar_estrelas": {"place": "mirante", "text": "observando as estrelas", "topic": "as estrelas"},
	"culinaria": {"place": "quiosque", "text": "testando receitas", "topic": "receitas"},
	"contemplar_lago": {"place": "doca", "text": "contemplando o lago", "topic": "o lago"},
	"costura": {"place": "home", "text": "costurando na varanda", "topic": "costura"},
	"conversar": {"place": "praca", "text": "puxando conversa", "topic": "as novidades da ilha"},
	"corrida": {"place": "praia_sul", "text": "correndo na praia", "topic": "exercícios"},
	"passear": {"place": "random", "text": "passeando", "topic": "os cantinhos da ilha"},
	"colher_frutas": {"place": "pomar", "text": "colhendo frutas", "topic": "frutas"},
}

## Locais que um morador curioso pode explorar.
const EXPLORE_SPOTS := ["mirante", "pomar", "bosque", "praia_sul", "praia_leste", "praia_norte", "fogueira", "lago", "jardim", "coreto", "parque"]

## Atividades que podem ser feitas em dupla em cada local.
const SHARED_ACTIVITIES := {
	"jardim": "regaram os canteiros do jardim comunitário",
	"coreto": "tocaram uma música juntos no coreto",
	"doca": "ficaram observando os peixinhos do lago",
	"lago": "ficaram observando os peixinhos do lago",
	"mirante": "admiraram a vista do mirante",
	"praia_sul": "fizeram um castelo de areia na praia",
	"praia_leste": "procuraram conchas juntos na praia",
	"praia_norte": "caminharam juntos pela praia",
	"pomar": "colheram frutas juntos no pomar",
	"quiosque": "dividiram um pãozinho no quiosque",
	"praca": "jogaram uma partida de damas na praça",
	"estante": "trocaram indicações de livros na estante",
	"bosque": "exploraram o bosque juntos",
	"fogueira": "conversaram ao redor da fogueira",
	"banco_praca": "dividiram o banco da praça vendo o movimento",
	"parque": "fizeram um piquenique no parque",
}


## Posição 3D apoiada no terreno.
static func pos3(p: Vector2) -> Vector3:
	return Vector3(p.x, IslandTerrain.height(p.x, p.y), p.y)


static func house_pos(house_id: String) -> Vector3:
	return pos3(HOUSES.get(house_id, {"pos": Vector2.ZERO})["pos"])


## Direção (no plano) para onde a porta da casa está voltada.
static func house_facing(house_id: String) -> Vector2:
	var h: Dictionary = HOUSES.get(house_id, {"pos": Vector2.ZERO})
	# `face` é a direção da porta (a frente das casas fica voltada para a câmera)
	var d: Vector2 = h.get("face", -Vector2(h["pos"]))
	if d.length() < 0.01:
		d = Vector2(0, 1)
	return d.normalized()


static func house_rotation(house_id: String) -> float:
	var f := house_facing(house_id)
	return atan2(f.x, f.y)


## Ponto em frente à porta.
static func house_door(house_id: String) -> Vector3:
	var c: Vector2 = HOUSES.get(house_id, {"pos": Vector2.ZERO})["pos"]
	return pos3(c + house_facing(house_id) * 3.4)


static func house_porch(house_id: String) -> Vector3:
	var c: Vector2 = HOUSES.get(house_id, {"pos": Vector2.ZERO})["pos"]
	var f := house_facing(house_id)
	var side := Vector2(f.y, -f.x)
	return pos3(c + f * 3.4 + side * 1.6)


static func poi_pos(poi_id: String) -> Vector3:
	return pos3(POIS.get(poi_id, {"pos": Vector2.ZERO})["pos"])


static func poi_label(poi_id: String) -> String:
	if POIS.has(poi_id):
		return POIS[poi_id]["label"]
	if HOUSES.has(poi_id):
		return HOUSES[poi_id]["label"]
	return poi_id


static func poi_radius(poi_id: String) -> float:
	return POIS.get(poi_id, {}).get("radius", 1.5)


## Lugar nomeado mais próximo de uma posição (para descrever eventos).
static func nearest_place(p: Vector3) -> String:
	var best := "praca"
	var best_d := INF
	var flat := Vector2(p.x, p.z)
	for id in POIS:
		var d: float = flat.distance_to(POIS[id]["pos"]) - float(POIS[id]["radius"])
		if d < best_d:
			best_d = d
			best = id
	for id in HOUSES:
		var d2: float = flat.distance_to(HOUSES[id]["pos"]) - 4.0
		if d2 < best_d:
			best_d = d2
			best = id
	return best
