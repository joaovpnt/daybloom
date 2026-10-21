class_name Inventory
extends RefCounted
## Inventário da jogadora: pilhas únicas por item, com limites.

signal changed()

const MAX_SLOTS := 30
const MAX_STACK := 99

var _order: Array = []
var _counts: Dictionary = {}


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func slots_used() -> int:
	return _order.size()


## Quantas unidades deste item ainda cabem.
func room_for(item_id: String) -> int:
	if not ItemDB.exists(item_id):
		return 0
	if _counts.has(item_id):
		return MAX_STACK - int(_counts[item_id])
	return MAX_STACK if _order.size() < MAX_SLOTS else 0


## Adiciona itens e retorna quantos couberam de fato.
func add(item_id: String, amount: int = 1) -> int:
	if amount <= 0 or not ItemDB.exists(item_id):
		return 0
	if not _counts.has(item_id):
		if _order.size() >= MAX_SLOTS:
			return 0
		_order.append(item_id)
		_counts[item_id] = 0
	var room := MAX_STACK - int(_counts[item_id])
	var added: int = min(room, amount)
	_counts[item_id] = int(_counts[item_id]) + added
	if added > 0:
		changed.emit()
	return added


func remove(item_id: String, amount: int = 1) -> bool:
	if not has(item_id, amount):
		return false
	_counts[item_id] = int(_counts[item_id]) - amount
	if int(_counts[item_id]) <= 0:
		_counts.erase(item_id)
		_order.erase(item_id)
	changed.emit()
	return true


func items() -> Array:
	var out := []
	for item_id in _order:
		out.append({"item_id": item_id, "count": int(_counts[item_id])})
	return out


func to_array() -> Array:
	return items()


func load_from(list: Array) -> void:
	_order.clear()
	_counts.clear()
	for slot in list:
		var item_id := str(slot["item_id"])
		var n := int(slot["count"])
		if n <= 0 or not ItemDB.exists(item_id):
			continue
		if _counts.has(item_id):
			_counts[item_id] = min(MAX_STACK, int(_counts[item_id]) + n)
		elif _order.size() < MAX_SLOTS:
			_order.append(item_id)
			_counts[item_id] = min(MAX_STACK, n)
	changed.emit()
