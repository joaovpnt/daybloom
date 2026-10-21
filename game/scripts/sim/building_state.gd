class_name BuildingState
extends RefCounted
## Estado persistente do prédio: sujeira dos objetos, plantas regadas, horta
## colhida, móveis da jogadora (posição e rotação), enfeites conquistados pelos
## objetivos dos moradores e o mercadinho. Os objetos fixos vêm do
## BuildingLayout; os móveis da jogadora ficam aqui.

const PLAYER_FLOOR := "andar_9"

var dirt: Dictionary = {}
var watered: Dictionary = {}
var harvested: Dictionary = {}
var decor: Dictionary = {}
var furniture: Array = []
var furniture_seq: int = 0
var shop := Shop.new()
## Quem está usando cada objeto agora (transitório): uid -> id do usuário.
var in_use: Dictionary = {}

static var _fixed_cache: Dictionary = {}


static func fixed_for(floor_id: String) -> Array:
	if not _fixed_cache.has(floor_id):
		_fixed_cache[floor_id] = BuildingLayout.fixed_objects(floor_id)
	return _fixed_cache[floor_id]


## Móveis iniciais do apartamento da jogadora (podem ser rearranjados).
static func starter_furniture() -> Array:
	return [
		{"def": "cama", "pos": Vector2(-9.4, -7.85), "rot": 0.0},
		{"def": "criado_mudo", "pos": Vector2(-11.3, -8.7), "rot": 0.0},
		{"def": "tapete", "pos": Vector2(0.5, -5.6), "rot": 0.0},
		{"def": "tv", "pos": Vector2(0.5, -8.62), "rot": 0.0},
		{"def": "sofa", "pos": Vector2(0.5, -3.5), "rot": PI},
		{"def": "mesa_pequena", "pos": Vector2(0.5, 1.0), "rot": 0.0},
		{"def": "cadeira", "pos": Vector2(0.5, 0.25), "rot": 0.0},
		{"def": "cadeira", "pos": Vector2(0.5, 1.75), "rot": PI},
		{"def": "luminaria", "pos": Vector2(4.4, -8.4), "rot": 0.0},
		{"def": "planta_grande", "pos": Vector2(4.3, 3.8), "rot": 0.0},
	]


func setup_new() -> void:
	dirt = {}
	watered = {}
	harvested = {}
	decor = {}
	furniture = []
	furniture_seq = 0
	shop = Shop.new()
	for f in starter_furniture():
		add_furniture(f["def"], f["pos"], f["rot"])


func add_furniture(def_id: String, pos: Vector2, rot: float) -> Dictionary:
	furniture_seq += 1
	var obj := {"uid": "%s:movel_%d" % [PLAYER_FLOOR, furniture_seq], "def": def_id, "pos": pos, "rot": rot, "floor": PLAYER_FLOOR, "fixed": false}
	furniture.append(obj)
	return obj


func remove_furniture(uid: String) -> Dictionary:
	for i in range(furniture.size()):
		if furniture[i]["uid"] == uid:
			var o: Dictionary = furniture[i]
			furniture.remove_at(i)
			dirt.erase(uid)
			return o
	return {}


func move_furniture(uid: String, pos: Vector2, rot: float) -> bool:
	for o in furniture:
		if o["uid"] == uid:
			o["pos"] = pos
			o["rot"] = rot
			return true
	return false


## Todos os objetos de um andar (fixos + móveis da jogadora + enfeites).
func objects_on_floor(floor_id: String) -> Array:
	var out: Array = fixed_for(floor_id).duplicate()
	if floor_id == PLAYER_FLOOR:
		out += furniture
	for spot_id in decor:
		var spot: Dictionary = BuildingLayout.DECOR_SPOTS.get(spot_id, {})
		if spot.get("floor", "") != floor_id:
			continue
		var i := 0
		for it in spot.get("items", []):
			i += 1
			var extra := {"uid": "%s:decor_%s_%d" % [floor_id, spot_id, i], "def": it[0], "pos": it[1], "rot": 0.0, "floor": floor_id, "fixed": true, "decor_spot": spot_id}
			if it[0] == "quadro":
				extra["wall_y"] = 1.7
			out.append(extra)
	return out


func find_object(floor_id: String, uid: String) -> Dictionary:
	for o in objects_on_floor(floor_id):
		if o["uid"] == uid:
			return o
	return {}


## Objetos com uma ação, opcionalmente só dentro do apartamento ou de um cômodo.
func objects_with(floor_id: String, aff: String, only_apartment: bool = false) -> Array:
	var out := []
	for o in objects_on_floor(floor_id):
		if not FurnitureDB.affordances(str(o["def"])).has(aff):
			continue
		var p := Vector3(o["pos"].x, 0, o["pos"].y)
		if only_apartment and not BuildingLayout.in_apartment(floor_id, p):
			continue
		out.append(o)
	return out


func dirt_of(uid: String) -> float:
	return float(dirt.get(uid, 0.0))


func add_dirt(uid: String, amount: float) -> void:
	dirt[uid] = clampf(dirt_of(uid) + amount, 0.0, 1.0)


func clean(uid: String, amount: float = 1.0) -> void:
	var v := clampf(dirt_of(uid) - amount, 0.0, 1.0)
	if v <= 0.001:
		dirt.erase(uid)
	else:
		dirt[uid] = v


## Limpeza média do apartamento (afeta o conforto de quem está lá).
func cleanliness(floor_id: String) -> float:
	var total := 0.0
	var n := 0
	for o in objects_on_floor(floor_id):
		if FurnitureDB.can_get_dirty(str(o["def"])):
			total += dirt_of(o["uid"])
			n += 1
	return 1.0 - (total / float(maxi(n, 1)))


## Pontos de decoração do apartamento (plantas, quadros, tapetes...).
func decor_score(floor_id: String) -> float:
	var s := 0.0
	for o in objects_on_floor(floor_id):
		s += float(FurnitureDB.get_def(str(o["def"])).get("decor", 0))
	return s


func is_in_use(uid: String) -> String:
	return str(in_use.get(uid, ""))


func reserve(uid: String, user: String) -> bool:
	var cur := is_in_use(uid)
	if cur != "" and cur != user:
		return false
	in_use[uid] = user
	return true


func release(uid: String, user: String) -> void:
	if is_in_use(uid) == user:
		in_use.erase(uid)


func release_all(user: String) -> void:
	for uid in in_use.keys():
		if in_use[uid] == user:
			in_use.erase(uid)


## Sujeira que aparece com o tempo (mesas e tapetes) e novo dia no mercadinho.
func on_new_day(day: int, rng: RandomNumberGenerator) -> void:
	shop.on_new_day(day)
	for floor_id in BuildingLayout.OWNER_FLOOR.values():
		for o in objects_on_floor(floor_id):
			var d := FurnitureDB.get_def(str(o["def"]))
			if d.get("dirt", false) and (d.get("table", false) or d.get("flat", false)):
				add_dirt(o["uid"], rng.randf_range(0.03, 0.09))


func to_dict() -> Dictionary:
	var furn := []
	for o in furniture:
		furn.append({"uid": o["uid"], "def": o["def"], "x": snappedf(o["pos"].x, 0.001), "z": snappedf(o["pos"].y, 0.001), "rot": snappedf(float(o["rot"]), 0.0001)})
	var d := {}
	for k in dirt:
		d[k] = snappedf(float(dirt[k]), 0.001)
	return {"dirt": d, "watered": watered.duplicate(), "harvested": harvested.duplicate(), "decor": decor.keys(), "furniture": furn, "furniture_seq": furniture_seq, "shop": shop.to_dict()}


func load_from(data: Dictionary) -> void:
	dirt = {}
	var dd: Dictionary = data.get("dirt", {})
	for k in dd:
		dirt[str(k)] = clampf(float(dd[k]), 0.0, 1.0)
	watered = {}
	var wd: Dictionary = data.get("watered", {})
	for k in wd:
		watered[str(k)] = int(wd[k])
	harvested = {}
	var hd: Dictionary = data.get("harvested", {})
	for k in hd:
		harvested[str(k)] = int(hd[k])
	decor = {}
	for k in data.get("decor", []):
		if BuildingLayout.DECOR_SPOTS.has(str(k)):
			decor[str(k)] = true
	furniture = []
	var seen := {}
	furniture_seq = int(data.get("furniture_seq", 0))
	for f in data.get("furniture", []):
		var def_id := str(f.get("def", ""))
		var uid := str(f.get("uid", ""))
		if not FurnitureDB.is_movable(def_id) or uid == "" or seen.has(uid):
			continue
		seen[uid] = true
		furniture.append({"uid": uid, "def": def_id, "pos": Vector2(float(f.get("x", 0.0)), float(f.get("z", 0.0))), "rot": float(f.get("rot", 0.0)), "floor": PLAYER_FLOOR, "fixed": false})
		var n := int(uid.get_slice("_", uid.get_slice_count("_") - 1)) if uid.contains("movel_") else 0
		furniture_seq = maxi(furniture_seq, n)
	shop = Shop.new()
	shop.load_from(data.get("shop", {}))
	in_use = {}
