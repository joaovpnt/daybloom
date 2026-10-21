class_name Crafting
extends RefCounted
## Fabricação de móveis na bancada do apartamento. Os materiais são
## reservados (saem do inventário) quando a fabricação começa; se ela for
## interrompida, voltam todos. O móvel só entra no inventário ao concluir.

const RECIPES := {
	"cadeira_simples": {"result": "movel_cadeira_simples", "ingredients": {"tabua": 3, "tecido": 1}, "minutes": 20.0},
	"mesa_pequena": {"result": "movel_mesa_pequena", "ingredients": {"tabua": 4}, "minutes": 30.0},
	"estante": {"result": "movel_estante", "ingredients": {"tabua": 5}, "minutes": 40.0},
	"vaso_decorativo": {"result": "movel_vaso", "ingredients": {"argila": 2}, "minutes": 20.0},
	"banco": {"result": "movel_banco", "ingredients": {"tabua": 2}, "minutes": 15.0},
	"luminaria": {"result": "movel_luminaria", "ingredients": {"tabua": 1, "tecido": 1, "lampada": 1}, "minutes": 25.0},
	"tapete": {"result": "movel_tapete", "ingredients": {"tecido": 4}, "minutes": 30.0},
	"cama_simples": {"result": "movel_cama_simples", "ingredients": {"tabua": 6, "tecido": 3}, "minutes": 60.0},
}


static func has(recipe_id: String) -> bool:
	return RECIPES.has(recipe_id)


static func recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})


static func result_name(recipe_id: String) -> String:
	return ItemDB.display_name(str(RECIPES.get(recipe_id, {}).get("result", "")))


static func missing(recipe_id: String, inventory: Inventory) -> Dictionary:
	var out := {}
	var ing: Dictionary = RECIPES.get(recipe_id, {}).get("ingredients", {})
	for item_id in ing:
		var lack := int(ing[item_id]) - inventory.count(item_id)
		if lack > 0:
			out[item_id] = lack
	return out


static func can_craft(recipe_id: String, inventory: Inventory) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {"ok": false, "reason": "receita desconhecida", "missing": {}}
	var miss := missing(recipe_id, inventory)
	if not miss.is_empty():
		var parts := []
		for item_id in miss:
			parts.append("%d %s" % [miss[item_id], ItemDB.display_name(item_id)])
		return {"ok": false, "reason": "Faltam: " + ", ".join(parts), "missing": miss}
	# Depois de consumir os materiais, o móvel precisa caber no inventário.
	var result: String = RECIPES[recipe_id]["result"]
	var frees := 0
	var ing: Dictionary = RECIPES[recipe_id]["ingredients"]
	for item_id in ing:
		if inventory.count(item_id) == int(ing[item_id]):
			frees += 1
	if inventory.room_for(result) < 1 and frees == 0:
		return {"ok": false, "reason": "Inventário cheio", "missing": {}}
	return {"ok": true, "reason": "", "missing": {}}


## Começa: valida e retira os materiais. Retorna a reserva (para concluir ou devolver).
static func begin(recipe_id: String, inventory: Inventory) -> Dictionary:
	var check := can_craft(recipe_id, inventory)
	if not check["ok"]:
		return check
	var ing: Dictionary = RECIPES[recipe_id]["ingredients"]
	for item_id in ing:
		inventory.remove(item_id, int(ing[item_id]))
	return {"ok": true, "recipe": recipe_id, "reserved": ing.duplicate(), "minutes": float(RECIPES[recipe_id]["minutes"])}


## Conclui: entrega o móvel. Se não couber, devolve os materiais.
static func finish(reservation: Dictionary, inventory: Inventory) -> Dictionary:
	var recipe_id: String = reservation.get("recipe", "")
	if not RECIPES.has(recipe_id):
		return {"ok": false, "reason": "receita desconhecida"}
	var result: String = RECIPES[recipe_id]["result"]
	if inventory.add(result, 1) != 1:
		cancel(reservation, inventory)
		return {"ok": false, "reason": "Inventário cheio: os materiais voltaram para a mochila."}
	return {"ok": true, "item_id": result}


static func cancel(reservation: Dictionary, inventory: Inventory) -> void:
	var reserved: Dictionary = reservation.get("reserved", {})
	for item_id in reserved:
		inventory.add(item_id, int(reserved[item_id]))
