class_name ItemDB
extends RefCounted
## Catálogo de itens do Daybloom 0.1. Cada item tem tags usadas pelas
## preferências dos moradores (gostos e aversões).

const ITEMS := {
	"margarida": {"name": "Margarida", "kind": "flor", "tags": ["flor", "flor_branca"], "color": Color(0.98, 0.97, 0.9), "description": "Uma flor simples e alegre."},
	"tulipa_coral": {"name": "Tulipa-coral", "kind": "flor", "tags": ["flor", "flor_vermelha"], "color": Color(0.96, 0.47, 0.42), "description": "Pétalas cor de coral, perfume suave."},
	"campanula": {"name": "Campânula-azul", "kind": "flor", "tags": ["flor", "flor_azul"], "color": Color(0.45, 0.58, 0.95), "description": "Pequenos sinos azuis que balançam ao vento."},
	"girassol": {"name": "Girassol-mirim", "kind": "flor", "tags": ["flor", "flor_amarela"], "color": Color(1.0, 0.82, 0.25), "description": "Sempre virado para o sol."},
	"concha": {"name": "Concha rosada", "kind": "praia", "tags": ["praia", "concha"], "color": Color(0.98, 0.78, 0.76), "description": "Encontrada na areia da praia."},
	"estrela_do_mar": {"name": "Estrela-do-mar", "kind": "praia", "tags": ["praia", "raro"], "color": Color(1.0, 0.6, 0.35), "description": "Rara! Aparece de vez em quando na praia."},
	"galho": {"name": "Galho seco", "kind": "material", "tags": ["material", "madeira"], "color": Color(0.55, 0.38, 0.24), "description": "Útil para artesanato."},
	"pedra_lisa": {"name": "Pedra lisa", "kind": "material", "tags": ["material", "pedra"], "color": Color(0.62, 0.64, 0.66), "description": "Lisinha, perfeita para colecionar."},
	"pessego": {"name": "Pêssego", "kind": "fruta", "tags": ["fruta", "comida", "doce"], "color": Color(1.0, 0.67, 0.5), "description": "Doce e suculento, colhido das árvores da ilha."},
	"maca_verde": {"name": "Maçã-verde", "kind": "fruta", "tags": ["fruta", "comida", "azedo"], "color": Color(0.55, 0.85, 0.35), "description": "Crocante e um pouco azedinha."},
}


static func exists(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func display_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("name", item_id)


static func tags(item_id: String) -> Array:
	var tags_list: Array = ITEMS.get(item_id, {}).get("tags", [])
	return [item_id] + tags_list


static func color(item_id: String) -> Color:
	return ITEMS.get(item_id, {}).get("color", Color.WHITE)


## Artigo indefinido em português ("uma Margarida", "um Galho seco").
static func with_article(item_id: String) -> String:
	var feminine := ["margarida", "tulipa_coral", "campanula", "concha", "estrela_do_mar", "pedra_lisa", "maca_verde"]
	return ("uma " if item_id in feminine else "um ") + display_name(item_id)
