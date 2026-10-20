class_name Places
extends RefCounted
## Mapa lógico da ilha: posições de casas, pontos de interesse e atividades.
## É usado tanto pelo construtor da ilha quanto pela IA dos moradores.

const ISLAND_RADIUS := 42.0      # borda da grama
const BEACH_RADIUS := 49.0       # borda da areia
const WALK_RADIUS := 47.0        # limite caminhável

## Casas: posição (x, z) e direção da porta (ângulo em radianos, 0 = +Z).
const HOUSES := {
	"casa_jogadora": {"pos": Vector2(2, 25), "label": "Sua casa"},
	"casa_lila": {"pos": Vector2(-14, -16), "label": "Casa da Lila"},
	"casa_tobias": {"pos": Vector2(-25, -2), "label": "Casa do Tobias"},
	"casa_otavio": {"pos": Vector2(-6, -29), "label": "Casa do Otávio"},
	"casa_pipa": {"pos": Vector2(9, -27), "label": "Casa da Pipa"},
	"casa_marina": {"pos": Vector2(25, -14), "label": "Casa da Marina"},
	"casa_bento": {"pos": Vector2(29, 4), "label": "Casa do Bento"},
	"casa_ravena": {"pos": Vector2(-31, 18), "label": "Casa da Ravena"},
	"casa_celeste": {"pos": Vector2(-17, 31), "label": "Casa da Dona Celeste"},
}

const POIS := {
	"praca": {"pos": Vector2(0, 0), "radius": 6.0, "label": "praça central"},
	"jardim": {"pos": Vector2(-15, 13), "radius": 4.0, "label": "jardim comunitário"},
	"lago": {"pos": Vector2(18, 17), "radius": 5.5, "label": "lago"},
	"doca": {"pos": Vector2(11.2, 17.5), "radius": 1.5, "label": "píer do lago"},
	"quiosque": {"pos": Vector2(-8, -7), "radius": 2.0, "label": "quiosque de pães"},
	"mural": {"pos": Vector2(6.5, 5.5), "radius": 1.5, "label": "mural de recados"},
	"estante": {"pos": Vector2(-6.5, 6.5), "radius": 1.5, "label": "estante comunitária"},
	"coreto": {"pos": Vector2(10, 7), "radius": 2.5, "label": "coreto"},
	"banco_praca": {"pos": Vector2(4.5, -5.0), "radius": 1.2, "label": "banco da praça"},
	"mirante": {"pos": Vector2(-22, -30), "radius": 3.0, "label": "mirante"},
	"pomar": {"pos": Vector2(-33, -12), "radius": 4.0, "label": "pomar"},
	"bosque": {"pos": Vector2(24, -30), "radius": 4.0, "label": "bosque"},
	"praia_sul": {"pos": Vector2(8, 44), "radius": 3.0, "label": "praia do sul"},
	"praia_leste": {"pos": Vector2(44, -6), "radius": 3.0, "label": "praia do leste"},
	"praia_norte": {"pos": Vector2(-6, -45), "radius": 3.0, "label": "praia do norte"},
	"fogueira": {"pos": Vector2(-10, 43), "radius": 2.5, "label": "fogueira da praia"},
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
const EXPLORE_SPOTS := ["mirante", "pomar", "bosque", "praia_sul", "praia_leste", "praia_norte", "fogueira", "lago", "jardim", "coreto"]

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
}


static func pos3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


static func house_pos(house_id: String) -> Vector3:
	return pos3(HOUSES.get(house_id, {"pos": Vector2.ZERO})["pos"])


## Ponto em frente à porta (a porta sempre olha para a praça).
static func house_door(house_id: String) -> Vector3:
	var c := house_pos(house_id)
	var dir := (Vector3.ZERO - c)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	return c + dir.normalized() * 3.4


static func house_porch(house_id: String) -> Vector3:
	var door := house_door(house_id)
	var c := house_pos(house_id)
	var side := (door - c).normalized().cross(Vector3.UP)
	return door + side * 1.6


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
	for id in POIS:
		var d := pos3(POIS[id]["pos"]).distance_to(Vector3(p.x, 0, p.z)) - float(POIS[id]["radius"])
		if d < best_d:
			best_d = d
			best = id
	for id in HOUSES:
		var d2 := house_pos(id).distance_to(Vector3(p.x, 0, p.z)) - 4.0
		if d2 < best_d:
			best_d = d2
			best = id
	return best
