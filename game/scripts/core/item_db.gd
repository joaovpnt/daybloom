class_name ItemDB
extends RefCounted
## Catálogo de itens. Cada item tem tags usadas pelas preferências dos
## moradores (gostos e aversões). 0.4: comidas (com valor nutritivo),
## materiais de fabricação e móveis (kind "movel", ligados ao FurnitureDB).

const ITEMS := {
	# Flores e lembranças (0.1–0.3)
	"margarida": {"name": "Margarida", "kind": "flor", "tags": ["flor", "flor_branca"], "color": Color(0.98, 0.97, 0.9), "description": "Uma flor simples e alegre."},
	"tulipa_coral": {"name": "Tulipa-coral", "kind": "flor", "tags": ["flor", "flor_vermelha"], "color": Color(0.96, 0.47, 0.42), "description": "Pétalas cor de coral, perfume suave."},
	"campanula": {"name": "Campânula-azul", "kind": "flor", "tags": ["flor", "flor_azul"], "color": Color(0.45, 0.58, 0.95), "description": "Pequenos sinos azuis que balançam ao vento."},
	"girassol": {"name": "Girassol-mirim", "kind": "flor", "tags": ["flor", "flor_amarela"], "color": Color(1.0, 0.82, 0.25), "description": "Sempre virado para o sol."},
	"concha": {"name": "Concha rosada", "kind": "praia", "tags": ["praia", "concha"], "color": Color(0.98, 0.78, 0.76), "description": "Uma lembrança do mar."},
	"estrela_do_mar": {"name": "Estrela-do-mar", "kind": "praia", "tags": ["praia", "raro"], "color": Color(1.0, 0.6, 0.35), "description": "Rara! Uma lembrança muito especial."},
	"galho": {"name": "Galho seco", "kind": "material", "tags": ["material", "madeira"], "color": Color(0.55, 0.38, 0.24), "description": "Útil para artesanato."},
	"pedra_lisa": {"name": "Pedra lisa", "kind": "material", "tags": ["material", "pedra"], "color": Color(0.62, 0.64, 0.66), "description": "Lisinha, perfeita para colecionar."},
	"pessego": {"name": "Pêssego", "kind": "fruta", "tags": ["fruta", "comida", "doce"], "color": Color(1.0, 0.67, 0.5), "description": "Doce e suculento.", "food": 22},
	"maca_verde": {"name": "Maçã-verde", "kind": "fruta", "tags": ["fruta", "comida", "azedo"], "color": Color(0.55, 0.85, 0.35), "description": "Crocante e um pouco azedinha.", "food": 20},
	# Comidas (0.4)
	"pao": {"name": "Pão fresquinho", "kind": "comida", "tags": ["comida", "pao"], "color": Color(0.88, 0.62, 0.34), "description": "Quentinho, do forno do mercadinho.", "food": 30},
	"leite": {"name": "Leite", "kind": "comida", "tags": ["comida", "bebida"], "color": Color(0.97, 0.97, 0.95), "description": "Uma caixinha de leite gelado.", "food": 15},
	"verduras": {"name": "Verduras da horta", "kind": "comida", "tags": ["comida", "ingrediente", "verdura"], "color": Color(0.45, 0.75, 0.38), "description": "Colhidas na horta comunitária.", "food": 14},
	"ingredientes": {"name": "Cesta de ingredientes", "kind": "comida", "tags": ["ingrediente"], "color": Color(0.95, 0.78, 0.45), "description": "Farinha, ovos e temperos para cozinhar.", "food": 0},
	"refeicao": {"name": "Refeição caseira", "kind": "comida", "tags": ["comida", "caseira"], "color": Color(0.96, 0.70, 0.40), "description": "Feita no seu fogão. Mata a fome de verdade.", "food": 70},
	"pao_de_mel": {"name": "Pão de mel do Tobias", "kind": "comida", "tags": ["comida", "doce", "receita_tobias"], "color": Color(0.62, 0.38, 0.22), "description": "A receita especial do Tobias, vendida no mercadinho.", "food": 35},
	"kit_churrasco": {"name": "Kit de churrasco", "kind": "comida", "tags": ["churrasco", "ingrediente"], "color": Color(0.86, 0.40, 0.32), "description": "Espetinhos de legumes, pão de alho e carvão.", "food": 0},
	# Materiais (0.4)
	"tabua": {"name": "Tábuas de madeira", "kind": "material", "tags": ["material", "madeira"], "color": Color(0.80, 0.62, 0.40), "description": "Para fabricar móveis."},
	"tecido": {"name": "Tecido colorido", "kind": "material", "tags": ["material", "tecido"], "color": Color(0.80, 0.55, 0.85), "description": "Retalhos e panos para estofar e costurar."},
	"argila": {"name": "Argila", "kind": "material", "tags": ["material", "argila"], "color": Color(0.82, 0.52, 0.40), "description": "Para modelar vasos."},
	"lampada": {"name": "Lâmpada", "kind": "material", "tags": ["material", "lampada"], "color": Color(1.0, 0.92, 0.55), "description": "Uma lâmpada amarelinha."},
	"tinta": {"name": "Tintas", "kind": "material", "tags": ["material", "tinta", "arte"], "color": Color(0.36, 0.62, 0.92), "description": "Potinhos de tinta coloridos."},
	# Móveis (0.4)
	"movel_cama": {"name": "Cama", "kind": "movel", "furniture": "cama", "tags": ["movel"], "color": Color(0.96, 0.58, 0.5), "description": "Uma cama de casal confortável."},
	"movel_cama_simples": {"name": "Cama de solteiro", "kind": "movel", "furniture": "cama_simples", "tags": ["movel"], "color": Color(0.95, 0.85, 0.65), "description": "Simples e aconchegante."},
	"movel_sofa": {"name": "Sofá", "kind": "movel", "furniture": "sofa", "tags": ["movel"], "color": Color(0.96, 0.58, 0.5), "description": "Para descansar e assistir TV."},
	"movel_poltrona": {"name": "Poltrona", "kind": "movel", "furniture": "poltrona", "tags": ["movel"], "color": Color(0.98, 0.86, 0.66), "description": "Fofinha."},
	"movel_cadeira": {"name": "Cadeira", "kind": "movel", "furniture": "cadeira", "tags": ["movel"], "color": Color(0.96, 0.58, 0.5), "description": "Uma cadeira estofada."},
	"movel_cadeira_simples": {"name": "Cadeira simples", "kind": "movel", "furniture": "cadeira_simples", "tags": ["movel", "madeira"], "color": Color(0.82, 0.64, 0.44), "description": "Feita à mão."},
	"movel_mesa_jantar": {"name": "Mesa de jantar", "kind": "movel", "furniture": "mesa_jantar", "tags": ["movel"], "color": Color(0.82, 0.64, 0.44), "description": "Para refeições com amigos."},
	"movel_mesa_pequena": {"name": "Mesa pequena", "kind": "movel", "furniture": "mesa_pequena", "tags": ["movel", "madeira"], "color": Color(0.84, 0.66, 0.46), "description": "Feita à mão."},
	"movel_mesa_centro": {"name": "Mesa de centro", "kind": "movel", "furniture": "mesa_centro", "tags": ["movel"], "color": Color(0.82, 0.64, 0.44), "description": "Para a sala."},
	"movel_tv": {"name": "TV", "kind": "movel", "furniture": "tv", "tags": ["movel"], "color": Color(0.25, 0.28, 0.34), "description": "Filmes e desenhos."},
	"movel_estante": {"name": "Estante", "kind": "movel", "furniture": "estante", "tags": ["movel", "madeira"], "color": Color(0.84, 0.66, 0.46), "description": "Cheia de livros."},
	"movel_vaso": {"name": "Vaso decorativo", "kind": "movel", "furniture": "vaso_decorativo", "tags": ["movel", "flor", "decoracao"], "color": Color(0.86, 0.54, 0.42), "description": "Um vaso com florzinhas."},
	"movel_banco": {"name": "Banco", "kind": "movel", "furniture": "banco", "tags": ["movel", "madeira"], "color": Color(0.84, 0.66, 0.46), "description": "Um banco de madeira."},
	"movel_luminaria": {"name": "Luminária", "kind": "movel", "furniture": "luminaria", "tags": ["movel"], "color": Color(1.0, 0.9, 0.6), "description": "Luz amarelinha para as noites."},
	"movel_tapete": {"name": "Tapete", "kind": "movel", "furniture": "tapete", "tags": ["movel", "tecido"], "color": Color(0.98, 0.86, 0.66), "description": "Deixa tudo mais aconchegante."},
	"movel_planta": {"name": "Planta grande", "kind": "movel", "furniture": "planta_grande", "tags": ["movel", "planta", "decoracao"], "color": Color(0.42, 0.70, 0.36), "description": "Verde e cheia de vida."},
	"movel_criado_mudo": {"name": "Criado-mudo", "kind": "movel", "furniture": "criado_mudo", "tags": ["movel"], "color": Color(0.82, 0.64, 0.44), "description": "Com abajur."},
}

const FEMININE := ["ingredientes", "margarida", "tulipa_coral", "campanula", "concha", "estrela_do_mar", "pedra_lisa", "maca_verde", "cesta", "refeicao", "tinta", "argila", "lampada", "cadeira", "mesa", "estante", "luminaria", "planta", "cama", "tv", "poltrona"]


static func exists(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func display_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("name", item_id)


static func kind(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("kind", ""))


static func tags(item_id: String) -> Array:
	var tags_list: Array = ITEMS.get(item_id, {}).get("tags", [])
	return [item_id] + tags_list


static func color(item_id: String) -> Color:
	return ITEMS.get(item_id, {}).get("color", Color.WHITE)


## Valor nutritivo (quanto da fome recupera ao comer). 0 = não se come puro.
static func food_value(item_id: String) -> float:
	return float(ITEMS.get(item_id, {}).get("food", 0))


static func is_food(item_id: String) -> bool:
	return food_value(item_id) > 0.0


static func furniture_of(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("furniture", ""))


static func item_for_furniture(def_id: String) -> String:
	for item_id in ITEMS:
		if ITEMS[item_id].get("furniture", "") == def_id:
			return item_id
	return ""


## Artigo indefinido em português ("uma Margarida", "um Galho seco").
static func with_article(item_id: String) -> String:
	var base := item_id.trim_prefix("movel_")
	var fem := item_id in FEMININE
	for f in FEMININE:
		if base.begins_with(f):
			fem = true
	if base in ["tabua", "tinta", "verduras", "argila", "leite", "tecido"]:
		return display_name(item_id).to_lower() if base != "tabua" else "tábuas de madeira"
	return ("uma " if fem else "um ") + display_name(item_id)
