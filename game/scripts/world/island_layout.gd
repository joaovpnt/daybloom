class_name IslandLayout
extends RefCounted
## Geração determinística do layout da ilha (árvores, recursos coletáveis e
## caminhos). A mesma semente sempre gera os mesmos IDs e posições, o que
## mantém os recursos salvos compatíveis entre sessões.

const SEED := 20261019
const FLOWER_ITEMS := ["margarida", "tulipa_coral", "campanula", "girassol"]

static var _cache: Dictionary = {}


static func paths() -> Array:
	var out := []
	for house_id in Places.HOUSES:
		out.append([Vector2.ZERO, _v2(Places.house_door(house_id))])
	for poi in ["jardim", "coreto", "doca", "quiosque", "mirante", "praia_sul", "pomar", "bosque", "praia_leste", "fogueira"]:
		out.append([Vector2.ZERO, Places.POIS[poi]["pos"]])
	return out


static func _v2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func distance_to_paths(p: Vector2) -> float:
	var best := INF
	for seg in paths():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(closest))
	return best


static func is_free(p: Vector2, margin: float = 0.0) -> bool:
	if p.length() > Places.ISLAND_RADIUS - 2.5:
		return false
	for house_id in Places.HOUSES:
		if p.distance_to(Places.HOUSES[house_id]["pos"]) < 5.6 + margin:
			return false
	for poi_id in Places.POIS:
		var poi: Dictionary = Places.POIS[poi_id]
		var extra := 3.0 if poi_id in ["praca", "lago", "jardim"] else 1.6
		if p.distance_to(poi["pos"]) < float(poi["radius"]) + extra + margin:
			return false
	if distance_to_paths(p) < 1.9 + margin:
		return false
	return true


static func generate() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trees := []
	# Pomar: árvores frutíferas organizadas.
	var orchard: Vector2 = Places.POIS["pomar"]["pos"]
	var fruit_index := 0
	for i in range(6):
		var angle := TAU * i / 6.0 + 0.3
		var p := orchard + Vector2(cos(angle), sin(angle)) * 4.6
		trees.append({"pos": p, "type": "fruit", "fruit": "pessego" if fruit_index % 2 == 0 else "maca_verde", "scale": rng.randf_range(0.9, 1.1)})
		fruit_index += 1
	# Bosque: concentração de pinheiros.
	var grove: Vector2 = Places.POIS["bosque"]["pos"]
	for i in range(12):
		var p2 := grove + Vector2(rng.randf_range(-9, 9), rng.randf_range(-7, 7))
		if p2.distance_to(grove) > 3.6 and _tree_ok(p2, trees):
			trees.append({"pos": p2, "type": "pine", "scale": rng.randf_range(0.9, 1.35)})
	# Árvores espalhadas.
	var attempts := 0
	while trees.size() < 70 and attempts < 4000:
		attempts += 1
		var r := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 3.0)
		var a := rng.randf() * TAU
		var p3 := Vector2(cos(a), sin(a)) * r
		if not is_free(p3, 0.8) or not _tree_ok(p3, trees):
			continue
		var kind := "round" if rng.randf() < 0.65 else "pine"
		trees.append({"pos": p3, "type": kind, "scale": rng.randf_range(0.8, 1.3)})

	var resources := []
	# Flores coletáveis em canteiros naturais.
	var flower_count := 0
	attempts = 0
	while flower_count < 30 and attempts < 4000:
		attempts += 1
		var r2 := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 4.0)
		var a2 := rng.randf() * TAU
		var center := Vector2(cos(a2), sin(a2)) * r2
		if not is_free(center, 0.2) or not _tree_ok(center, trees, 1.6):
			continue
		var item: String = FLOWER_ITEMS[flower_count % FLOWER_ITEMS.size()]
		flower_count += 1
		resources.append({"id": "flor_%02d" % flower_count, "kind": "flower", "item_id": item, "pos": center})
	# Flores do jardim comunitário (sempre disponíveis para colher).
	var garden: Vector2 = Places.POIS["jardim"]["pos"]
	for i in range(4):
		var gp := garden + Vector2(-3.0 + i * 2.0, 3.6)
		resources.append({"id": "jardim_%02d" % (i + 1), "kind": "flower", "item_id": FLOWER_ITEMS[i], "pos": gp})
	# Conchas na praia.
	for i in range(12):
		var a3 := TAU * i / 12.0 + rng.randf_range(-0.15, 0.15)
		var r3 := rng.randf_range(Places.ISLAND_RADIUS + 1.5, Places.WALK_RADIUS - 1.0)
		resources.append({"id": "concha_%02d" % (i + 1), "kind": "shell", "item_id": "concha", "pos": Vector2(cos(a3), sin(a3)) * r3})
	# Galhos sob árvores comuns.
	var branch_count := 0
	for t in trees:
		if branch_count >= 9:
			break
		if t["type"] == "fruit" or rng.randf() > 0.25:
			continue
		var bp: Vector2 = t["pos"] + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(1.2, 1.8))
		if bp.length() > Places.ISLAND_RADIUS - 2.0:
			continue
		branch_count += 1
		resources.append({"id": "galho_%02d" % branch_count, "kind": "branch", "item_id": "galho", "pos": bp})
	# Frutas caídas no pomar.
	var fruit_count := 0
	for t in trees:
		if t["type"] != "fruit":
			continue
		fruit_count += 1
		var dir: Vector2 = (t["pos"] - orchard).normalized()
		resources.append({"id": "fruta_%02d" % fruit_count, "kind": "fruit", "item_id": t["fruit"], "pos": t["pos"] + dir * 1.5})
	# Pedras lisas perto do mirante, do bosque e da praia norte.
	var stone_spots := [Places.POIS["mirante"]["pos"] + Vector2(4, 2), Places.POIS["bosque"]["pos"] + Vector2(-4.5, 3), Places.POIS["praia_norte"]["pos"] + Vector2(5, 1), Places.POIS["lago"]["pos"] + Vector2(0, 7.2), Places.POIS["mirante"]["pos"] + Vector2(-3, 4)]
	for i in range(stone_spots.size()):
		resources.append({"id": "pedra_%02d" % (i + 1), "kind": "stone", "item_id": "pedra_lisa", "pos": stone_spots[i]})

	_cache = {"trees": trees, "resources": resources}
	return _cache


static func _tree_ok(p: Vector2, trees: Array, min_dist: float = 3.2) -> bool:
	for t in trees:
		if p.distance_to(t["pos"]) < min_dist:
			return false
	return true
