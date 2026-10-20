class_name IslandLayout
extends RefCounted
## Layout determinístico da ilha (0.2): rede de trilhas orgânicas, vegetação,
## decoração e recursos coletáveis. A mesma semente sempre gera os mesmos IDs,
## mantendo os saves compatíveis (os recursos são salvos por ID).

const SEED := 20261020
const FLOWER_ITEMS := ["margarida", "tulipa_coral", "campanula", "girassol"]

static var _cache: Dictionary = {}
static var _path_points: Array = []
static var _path_segments: Array = []


# ---------------------------------------------------------------------------
# Trilhas
# ---------------------------------------------------------------------------

static func _door(house_id: String) -> Vector2:
	var d := Places.house_door(house_id)
	return Vector2(d.x, d.z)


static func _poi(id: String) -> Vector2:
	return Places.POIS[id]["pos"]


## Polilinhas de controle (curvas suaves são geradas por Catmull-Rom).
static func path_controls() -> Array:
	return [
		# Anel em volta da praça
		_ring(Vector2.ZERO, 7.4, 14),
		# Leste: comércio → Tobias → Marina → praia
		[Vector2(6.0, -4.0), _poi("quiosque") + Vector2(0.8, 1.6), Vector2(12.0, -5.5), _door("casa_tobias"), Vector2(20.0, -4.5), _door("casa_marina"), Vector2(37.0, -6.5), _poi("praia_leste")],
		# Sudeste: coreto → lago → Bento
		[Vector2(6.6, 3.5), Vector2(9.0, 5.0), _poi("coreto") + Vector2(-2.6, -0.4), Vector2(13.0, 12.0), _poi("doca") + Vector2(-1.2, -0.6)],
		[_poi("coreto") + Vector2(2.4, -1.4), Vector2(17.0, 6.0), Vector2(26.5, 12.5), _door("casa_bento")],
		# Sul: parque → casa da jogadora → praia sul
		[Vector2(2.5, 7.0), Vector2(1.5, 12.0), _poi("parque") + Vector2(2.2, -1.5), Vector2(6.0, 21.0), Vector2(8.6, 28.5), _door("casa_jogadora"), Vector2(11.0, 35.0), Vector2(9.0, 39.0), _poi("praia_sul")],
		[_door("casa_jogadora"), Vector2(17.5, 28.5), Vector2(17.0, 23.5), _poi("doca") + Vector2(-0.6, 1.4)],
		# Sudoeste: parque → Dona Celeste → fogueira
		[_poi("parque") + Vector2(-2.6, 1.0), Vector2(-8.0, 23.5), Vector2(-10.5, 30.5), _door("casa_celeste"), Vector2(-14.5, 36.0), _poi("fogueira")],
		# Oeste: estante → jardim → Lila → pomar
		[Vector2(-6.4, 3.6), _poi("estante") + Vector2(-1.2, 1.6), Vector2(-11.5, 9.0), _poi("jardim") + Vector2(2.2, 2.6)],
		[_poi("jardim") + Vector2(-3.0, 1.5), _door("casa_lila"), Vector2(-29.0, 7.5), _poi("pomar")],
		# Noroeste: mural → Ravena → mirante
		[Vector2(-6.8, -2.5), _poi("mural") + Vector2(-1.4, 0.8), Vector2(-12.0, -8.0), _door("casa_ravena"), Vector2(-24.0, -22.0), _poi("mirante") + Vector2(1.5, 2.5)],
		# Norte: mural → Pipa → bosque; Otávio → mirante → praia norte
		[Vector2(-1.5, -7.3), Vector2(0.5, -11.0), _door("casa_pipa"), Vector2(8.5, -15.5), Vector2(13.0, -20.0), Vector2(18.0, -23.0), _poi("bosque")],
		[_poi("mural") + Vector2(0.8, -1.5), Vector2(-6.0, -14.0), _door("casa_otavio"), Vector2(-15.0, -24.5), Vector2(-17.0, -28.0), _poi("mirante")],
		[_door("casa_otavio"), Vector2(-7.0, -24.5), Vector2(-6.5, -30.5), Vector2(-6.0, -36.0), Vector2(-5.0, -40.0), _poi("praia_norte")],
	]


static func _ring(c: Vector2, r: float, n: int) -> Array:
	var out := []
	for i in range(n + 1):
		var a := TAU * i / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _catmull(points: Array, samples_per_seg: int = 6) -> Array:
	var out := []
	if points.size() < 2:
		return points.duplicate()
	for i in range(points.size() - 1):
		var p0: Vector2 = points[max(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[min(i + 2, points.size() - 1)]
		var seg_len := p1.distance_to(p2)
		var n := maxi(2, int(seg_len / 1.2))
		for k in range(n):
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[-1])
	return out


## Trilhas suavizadas (listas de pontos 2D).
static func paths() -> Array:
	if _path_points.is_empty():
		for ctrl in path_controls():
			_path_points.append(_catmull(ctrl))
		_path_segments.clear()
		for pts in _path_points:
			for i in range(pts.size() - 1):
				_path_segments.append([pts[i], pts[i + 1]])
	return _path_points


static func distance_to_paths(p: Vector2) -> float:
	paths()
	var best := INF
	for seg in _path_segments:
		var closest := Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])
		best = minf(best, p.distance_squared_to(closest))
	return sqrt(best)


static func is_free(p: Vector2, margin: float = 0.0) -> bool:
	if p.length() > Places.ISLAND_RADIUS - 2.0:
		return false
	for house_id in Places.HOUSES:
		if p.distance_to(Places.HOUSES[house_id]["pos"]) < 5.4 + margin:
			return false
	for poi_id in Places.POIS:
		var poi: Dictionary = Places.POIS[poi_id]
		var extra := 3.2 if poi_id in ["praca", "lago", "jardim", "parque", "mirante"] else 1.8
		if p.distance_to(poi["pos"]) < float(poi["radius"]) + extra + margin:
			return false
	if distance_to_paths(p) < 1.9 + margin:
		return false
	return true


# ---------------------------------------------------------------------------
# Geração
# ---------------------------------------------------------------------------

static func generate() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trees := []
	# Pomar em fileiras
	var orchard := _poi("pomar")
	for row in range(2):
		for col in range(3):
			var p := orchard + Vector2(-3.4 + col * 3.4, -2.6 + row * 5.2) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			trees.append({"pos": p, "model": "tree_fruit_pessego" if (row + col) % 2 == 0 else "tree_fruit_maca", "scale": rng.randf_range(0.9, 1.05), "rot": rng.randf() * TAU, "kind": "fruit"})
	# Bosque denso de pinheiros e árvores
	var grove := _poi("bosque")
	var attempts := 0
	var grove_count := 0
	while grove_count < 22 and attempts < 800:
		attempts += 1
		var p2 := grove + Vector2(rng.randf_range(-11, 11), rng.randf_range(-9, 9))
		if p2.distance_to(grove) < 4.2 or p2.length() > Places.ISLAND_RADIUS - 2.5 or distance_to_paths(p2) < 1.8 or not _tree_ok(p2, trees, 2.8):
			continue
		var model: String = "tree_pine_a" if rng.randf() < 0.45 else ("tree_pine_b" if rng.randf() < 0.5 else ["tree_round_a", "tree_round_b", "tree_round_c"][rng.randi() % 3])
		trees.append({"pos": p2, "model": model, "scale": rng.randf_range(0.85, 1.3), "rot": rng.randf() * TAU, "kind": "tree"})
		grove_count += 1
	# Cinturão de árvores na borda (emoldura a ilha)
	attempts = 0
	var belt := 0
	while belt < 34 and attempts < 3000:
		attempts += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(33.0, 39.5)
		var p3 := Vector2(cos(a), sin(a)) * r
		if not is_free(p3, 0.4) or not _tree_ok(p3, trees, 3.4):
			continue
		var m3: String = ["tree_round_a", "tree_round_b", "tree_round_c", "tree_pine_a", "tree_pine_b"][rng.randi() % 5]
		trees.append({"pos": p3, "model": m3, "scale": rng.randf_range(0.85, 1.25), "rot": rng.randf() * TAU, "kind": "tree"})
		belt += 1
	# Árvores esparsas nos campos
	attempts = 0
	var scattered := 0
	while scattered < 22 and attempts < 3000:
		attempts += 1
		var r4 := sqrt(rng.randf()) * 31.0
		var a4 := rng.randf() * TAU
		var p4 := Vector2(cos(a4), sin(a4)) * r4
		if not is_free(p4, 1.2) or not _tree_ok(p4, trees, 6.0):
			continue
		trees.append({"pos": p4, "model": ["tree_round_a", "tree_round_b", "tree_round_c"][rng.randi() % 3], "scale": rng.randf_range(0.8, 1.15), "rot": rng.randf() * TAU, "kind": "tree"})
		scattered += 1

	# Arbustos ao lado das casas e nas bordas das trilhas
	var bushes := []
	for house_id in Places.HOUSES:
		var c: Vector2 = Places.HOUSES[house_id]["pos"]
		var f := Places.house_facing(house_id)
		var side := Vector2(f.y, -f.x)
		for s in [-1.0, 1.0]:
			var bp: Vector2 = c - f * 1.6 + side * s * 3.1
			bushes.append({"pos": bp, "model": ["bush_a", "bush_b", "bush_flower_pink", "bush_flower_yellow"][rng.randi() % 4], "scale": rng.randf_range(0.8, 1.1), "rot": rng.randf() * TAU})
	attempts = 0
	while bushes.size() < 46 and attempts < 3000:
		attempts += 1
		var r5 := sqrt(rng.randf()) * 38.0
		var a5 := rng.randf() * TAU
		var p5 := Vector2(cos(a5), sin(a5)) * r5
		var dp := distance_to_paths(p5)
		if dp < 2.0 or dp > 3.6 or not is_free(p5, -1.2) or not _tree_ok(p5, trees, 2.2) or not _tree_ok(p5, bushes, 2.5):
			continue
		bushes.append({"pos": p5, "model": ["bush_a", "bush_b", "bush_flower_pink", "bush_flower_yellow"][rng.randi() % 4], "scale": rng.randf_range(0.7, 1.15), "rot": rng.randf() * TAU})

	# Decoração sem colisão: flores em tufos, cogumelos, samambaias, pedras
	var decor := []
	attempts = 0
	while decor.size() < 70 and attempts < 4000:
		attempts += 1
		var r6 := sqrt(rng.randf()) * 39.0
		var a6 := rng.randf() * TAU
		var p6 := Vector2(cos(a6), sin(a6)) * r6
		var dp6 := distance_to_paths(p6)
		if dp6 < 1.5 or not is_free(p6, -1.5) or not _tree_ok(p6, trees, 1.4):
			continue
		var model6: String = "flowers_%s_cluster" % FLOWER_ITEMS[rng.randi() % 4]
		decor.append({"pos": p6, "model": model6, "scale": rng.randf_range(0.9, 1.3), "rot": rng.randf() * TAU})
	for i in range(14):
		var p7 := grove + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
		if p7.length() < Places.ISLAND_RADIUS - 2.0 and distance_to_paths(p7) > 1.5 and _tree_ok(p7, trees, 1.0):
			decor.append({"pos": p7, "model": ["fern", "mushrooms", "stump", "log", "fern"][i % 5], "scale": rng.randf_range(0.9, 1.2), "rot": rng.randf() * TAU})
	for i in range(18):
		var a8 := rng.randf() * TAU
		var r8 := rng.randf_range(10.0, 40.0)
		var p8 := Vector2(cos(a8), sin(a8)) * r8
		if is_free(p8, -1.0) and _tree_ok(p8, trees, 1.8):
			decor.append({"pos": p8, "model": ["rock_a", "rock_b", "rock_c"][i % 3], "scale": rng.randf_range(0.7, 1.3), "rot": rng.randf() * TAU})
	# Lago: juncos e vitórias-régias
	var pond := _poi("lago")
	for i in range(12):
		var a9 := TAU * i / 12.0 + rng.randf_range(-0.2, 0.2)
		if absf(wrapf(a9 - PI, -PI, PI)) < 0.45:
			continue
		decor.append({"pos": pond + Vector2(cos(a9), sin(a9)) * (5.9 + rng.randf_range(0.0, 0.5)), "model": "reeds" if i % 2 == 0 else "rock_c", "scale": rng.randf_range(0.8, 1.2), "rot": rng.randf() * TAU})
	var pads := []
	for i in range(7):
		pads.append({"pos": pond + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5)), "model": "lily_pad", "scale": rng.randf_range(0.7, 1.2), "rot": rng.randf() * TAU})
	# Praia: pedras
	for i in range(16):
		var a10 := rng.randf() * TAU
		var r10 := rng.randf_range(44.0, 47.5)
		decor.append({"pos": Vector2(cos(a10), sin(a10)) * r10, "model": ["rock_a", "rock_b", "rock_c"][i % 3], "scale": rng.randf_range(0.5, 1.1), "rot": rng.randf() * TAU, "beach": true})

	# Tufos de grama (MultiMesh)
	var tufts := []
	attempts = 0
	while tufts.size() < 1100 and attempts < 12000:
		attempts += 1
		var r11 := sqrt(rng.randf()) * 40.5
		var a11 := rng.randf() * TAU
		var p11 := Vector2(cos(a11), sin(a11)) * r11
		if p11.length() < 7.8 or distance_to_paths(p11) < 1.3 or p11.distance_to(pond) < 6.4:
			continue
		var skip := false
		for house_id in Places.HOUSES:
			if p11.distance_to(Places.HOUSES[house_id]["pos"]) < 3.2:
				skip = true
				break
		if skip:
			continue
		tufts.append({"pos": p11, "model": "grass_tuft_a" if rng.randf() < 0.7 else "grass_tuft_b", "scale": rng.randf_range(0.7, 1.4), "rot": rng.randf() * TAU})
	# Florzinhas soltas (MultiMesh)
	var small_flowers := []
	attempts = 0
	while small_flowers.size() < 240 and attempts < 6000:
		attempts += 1
		var r12 := sqrt(rng.randf()) * 40.0
		var a12 := rng.randf() * TAU
		var p12 := Vector2(cos(a12), sin(a12)) * r12
		var d12 := distance_to_paths(p12)
		if p12.length() < 7.8 or d12 < 1.2 or p12.distance_to(pond) < 6.4:
			continue
		# Mais flores perto das trilhas
		if d12 > 4.0 and rng.randf() < 0.6:
			continue
		small_flowers.append({"pos": p12, "model": "flower_%s" % FLOWER_ITEMS[rng.randi() % 4], "scale": rng.randf_range(0.8, 1.2), "rot": rng.randf() * TAU})

	# Postes de luz ao longo das trilhas
	var lamps := []
	var all_paths := paths()
	for pi in range(1, all_paths.size()):
		var pts: Array = all_paths[pi]
		var acc := 0.0
		for i in range(1, pts.size()):
			acc += (pts[i] as Vector2).distance_to(pts[i - 1])
			if acc > 11.0 and (pts[i] as Vector2).length() < 38.0:
				acc = 0.0
				var dir: Vector2 = ((pts[i] as Vector2) - (pts[i - 1] as Vector2)).normalized()
				var lp: Vector2 = pts[i] + Vector2(dir.y, -dir.x) * 1.5
				if _tree_ok(lp, lamps, 7.0) and _tree_ok(lp, trees, 1.5):
					lamps.append({"pos": lp})

	# Recursos coletáveis (IDs estáveis)
	var resources := []
	var flower_count := 0
	attempts = 0
	while flower_count < 30 and attempts < 6000:
		attempts += 1
		var r13 := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 4.0)
		var a13 := rng.randf() * TAU
		var center := Vector2(cos(a13), sin(a13)) * r13
		if not is_free(center, -0.3) or not _tree_ok(center, trees, 1.6) or not _tree_ok(center, bushes, 1.4):
			continue
		var item: String = FLOWER_ITEMS[flower_count % FLOWER_ITEMS.size()]
		flower_count += 1
		resources.append({"id": "flor_%02d" % flower_count, "kind": "flower", "item_id": item, "pos": center})
	var garden := _poi("jardim")
	for i in range(4):
		resources.append({"id": "jardim_%02d" % (i + 1), "kind": "flower", "item_id": FLOWER_ITEMS[i], "pos": garden + Vector2(-3.0 + i * 2.0, 3.6)})
	for i in range(12):
		var a14 := TAU * i / 12.0 + rng.randf_range(-0.15, 0.15)
		var r14 := rng.randf_range(43.5, Places.WALK_RADIUS - 1.0)
		resources.append({"id": "concha_%02d" % (i + 1), "kind": "shell", "item_id": "concha", "pos": Vector2(cos(a14), sin(a14)) * r14})
	var branch_count := 0
	for t in trees:
		if branch_count >= 9:
			break
		if t["kind"] == "fruit" or rng.randf() > 0.3:
			continue
		var bp2: Vector2 = t["pos"] + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(1.2, 1.8))
		if bp2.length() > Places.ISLAND_RADIUS - 2.0 or distance_to_paths(bp2) < 1.0:
			continue
		branch_count += 1
		resources.append({"id": "galho_%02d" % branch_count, "kind": "branch", "item_id": "galho", "pos": bp2})
	var fruit_count := 0
	for t in trees:
		if t["kind"] != "fruit":
			continue
		fruit_count += 1
		resources.append({"id": "fruta_%02d" % fruit_count, "kind": "fruit", "item_id": "pessego" if t["model"] == "tree_fruit_pessego" else "maca_verde", "pos": t["pos"] + Vector2(1.2, 1.0)})
	var stone_spots := [_poi("mirante") + Vector2(4.5, 1.5), grove + Vector2(-4.5, 4.5), _poi("praia_norte") + Vector2(5, 1), pond + Vector2(0, 7.4), _poi("mirante") + Vector2(-3.5, 4.5)]
	for i in range(stone_spots.size()):
		resources.append({"id": "pedra_%02d" % (i + 1), "kind": "stone", "item_id": "pedra_lisa", "pos": stone_spots[i]})

	_cache = {"trees": trees, "bushes": bushes, "decor": decor, "pads": pads, "tufts": tufts, "small_flowers": small_flowers, "lamps": lamps, "resources": resources}
	return _cache


static func _tree_ok(p: Vector2, items: Array, min_dist: float = 3.2) -> bool:
	for t in items:
		if p.distance_to(t["pos"]) < min_dist:
			return false
	return true
