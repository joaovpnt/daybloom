class_name DecorRules
extends RefCounted
## Regras do modo decoração no apartamento da jogadora: limites, paredes,
## sobreposição, portas, acesso aos objetos e espaço de circulação (busca em
## grade a partir da porta de entrada: nenhum cômodo ou objeto essencial pode
## ficar inacessível).

const GRID := 0.25
const AGENT_RADIUS := 0.3
const SNAP := 0.25


static func snap(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x, SNAP), snappedf(p.y, SNAP))


static func snap_rot(r: float) -> float:
	return wrapf(snappedf(r, PI / 2.0), -PI, PI)


static func _wall_rects(floor_id: String, grow: float = 0.0) -> Array:
	var out := []
	for w in BuildingLayout.walls(floor_id):
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))).grow(BuildingLayout.WALL_THICK * 0.5 + grow)
		out.append(r)
	return out


## Zonas em frente às portas que precisam ficar livres.
static func door_zones() -> Array:
	return [
		Rect2(-0.9, 2.9, 1.8, 1.6),        # porta de entrada (lado de dentro)
		Rect2(-5.2, -5.4, 2.4, 1.8),       # porta do quarto
		Rect2(-5.2, 0.8, 2.4, 1.8),        # porta do banheiro
		Rect2(3.8, 1.2, 2.4, 1.8),         # porta do cantinho dos hobbies
	]


static func _blocking_rects(objects: Array, grow: float) -> Array:
	var out := []
	for o in objects:
		var d := FurnitureDB.get_def(str(o["def"]))
		if d.get("flat", false) or d.get("wall", false):
			continue
		var r := FurnitureDB.rect_of(str(o["def"]), o["pos"], float(o.get("rot", 0.0)))
		if r.size == Vector2.ZERO:
			continue
		out.append(r.grow(grow))
	return out


## Valida a colocação de um móvel. `others`: os demais objetos do
## apartamento (fixos e móveis), sem o que está sendo movido.
static func validate(def_id: String, pos: Vector2, rot: float, others: Array, floor_id: String) -> Dictionary:
	if not FurnitureDB.is_movable(def_id):
		return {"ok": false, "reason": "Este objeto não pode ser movido."}
	var rect := FurnitureDB.rect_of(def_id, pos, rot)
	var inner := BuildingLayout.APARTMENT_RECT.grow(-BuildingLayout.WALL_THICK * 0.5)
	if not inner.encloses(rect):
		return {"ok": false, "reason": "Fora do apartamento."}
	for wr in _wall_rects(floor_id):
		if (wr as Rect2).intersects(rect):
			return {"ok": false, "reason": "Encostado demais na parede."}
	var flat := bool(FurnitureDB.get_def(def_id).get("flat", false))
	if not flat:
		for dz in door_zones():
			if (dz as Rect2).intersects(rect):
				return {"ok": false, "reason": "Bloqueia uma porta."}
		for o in others:
			var od := FurnitureDB.get_def(str(o["def"]))
			if od.get("flat", false) or od.get("wall", false):
				continue
			var orect := FurnitureDB.rect_of(str(o["def"]), o["pos"], float(o.get("rot", 0.0)))
			if orect.size != Vector2.ZERO and orect.intersects(rect.grow(-0.02)):
				return {"ok": false, "reason": "Em cima de %s." % FurnitureDB.label(str(o["def"])).to_lower()}
			if not od.get("aff", []).is_empty():
				var up := FurnitureDB.use_point(o)
				if rect.grow(0.15).has_point(Vector2(up.x, up.z)):
					return {"ok": false, "reason": "Bloqueia o acesso a %s." % FurnitureDB.label(str(o["def"])).to_lower()}
	else:
		for o in others:
			if bool(FurnitureDB.get_def(str(o["def"])).get("flat", false)):
				var orect2 := FurnitureDB.rect_of(str(o["def"]), o["pos"], float(o.get("rot", 0.0)))
				if orect2.intersects(rect.grow(-0.02)):
					return {"ok": false, "reason": "Já há um tapete aqui."}
	var candidate := {"def": def_id, "pos": pos, "rot": rot}
	var all := others.duplicate()
	all.append(candidate)
	var conn := check_circulation(all, floor_id)
	if not conn["ok"]:
		return conn
	return {"ok": true, "reason": ""}


## Busca em grade a partir da porta: os cômodos e os pontos de uso dos objetos
## com ações precisam continuar alcançáveis.
static func check_circulation(objects: Array, floor_id: String) -> Dictionary:
	var area := BuildingLayout.APARTMENT_RECT
	var cols := int(area.size.x / GRID)
	var rows := int(area.size.y / GRID)
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	var rects := _wall_rects(floor_id, AGENT_RADIUS) + _blocking_rects(objects, AGENT_RADIUS)
	for r in range(rows):
		for c in range(cols):
			var p := area.position + Vector2((c + 0.5) * GRID, (r + 0.5) * GRID)
			for rect in rects:
				if (rect as Rect2).has_point(p):
					blocked[r * cols + c] = 1
					break
	var start := _cell(Vector2(BuildingLayout.APT_DOOR_IN.x, BuildingLayout.APT_DOOR_IN.z), area, cols, rows)
	if start < 0 or blocked[start] == 1:
		return {"ok": false, "reason": "Bloqueia a entrada do apartamento."}
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var queue: Array[int] = [start]
	seen[start] = 1
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var r := i / cols
		var c := i % cols
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nc: int = c + d[0]
			var nr: int = r + d[1]
			if nc < 0 or nr < 0 or nc >= cols or nr >= rows:
				continue
			var j := nr * cols + nc
			if seen[j] == 1 or blocked[j] == 1:
				continue
			seen[j] = 1
			queue.append(j)
	for room in BuildingLayout.ROOMS:
		if not _any_reached((BuildingLayout.ROOMS[room] as Rect2).grow(-0.4), area, cols, rows, seen):
			return {"ok": false, "reason": "Bloquearia a passagem para o %s." % BuildingLayout.room_label(floor_id, room)}
	for o in objects:
		if FurnitureDB.affordances(str(o["def"])).is_empty():
			continue
		var up := FurnitureDB.use_point(o)
		var zone := Rect2(Vector2(up.x, up.z) - Vector2(0.6, 0.6), Vector2(1.2, 1.2))
		if not _any_reached(zone, area, cols, rows, seen):
			return {"ok": false, "reason": "Deixaria %s sem acesso." % FurnitureDB.label(str(o["def"])).to_lower()}
	return {"ok": true, "reason": ""}


static func _cell(p: Vector2, area: Rect2, cols: int, rows: int) -> int:
	var c := int((p.x - area.position.x) / GRID)
	var r := int((p.y - area.position.y) / GRID)
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return -1
	return r * cols + c


static func _any_reached(zone: Rect2, area: Rect2, cols: int, rows: int, seen: PackedByteArray) -> bool:
	var c0 := maxi(0, int((zone.position.x - area.position.x) / GRID))
	var r0 := maxi(0, int((zone.position.y - area.position.y) / GRID))
	var c1 := mini(cols - 1, int((zone.end.x - area.position.x) / GRID))
	var r1 := mini(rows - 1, int((zone.end.y - area.position.y) / GRID))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if seen[r * cols + c] == 1:
				return true
	return false
