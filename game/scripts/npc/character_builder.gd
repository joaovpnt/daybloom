class_name CharacterBuilder
extends RefCounted
## Monta personagens estilizados a partir de primitivas (arte provisória
## original). Cada espécie tem silhueta própria. As partes recebem nomes fixos
## (Body, Head, LegL, LegR, ArmL, ArmR, Tail) para a animação procedural.

const EYE := Color(0.13, 0.1, 0.12)


static func build_animal(def: NpcDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var p := def.primary_color
	var s := def.secondary_color
	var a := def.accent_color
	var mp := MaterialLib.toon(p)
	var ms := MaterialLib.toon(s)
	var ma := MaterialLib.toon(a)
	var shape := def.body_shape

	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# Pernas
	for side in [-1, 1]:
		var leg := MaterialLib.mesh(MaterialLib.capsule(0.11, 0.42), mp, Vector3(0.14 * side, 0.21, 0), root)
		leg.name = "LegL" if side < 0 else "LegR"
		if shape == "sapo":
			leg.scale = Vector3(1.3, 0.8, 1.3)
	# Tronco
	var torso_r := 0.3
	if shape in ["urso", "ovelha"]:
		torso_r = 0.36
	elif shape in ["esquilo", "coruja"]:
		torso_r = 0.28
	var torso := MaterialLib.mesh(MaterialLib.sphere(torso_r, torso_r * 2.4), mp, Vector3(0, 0.62, 0), body)
	torso.name = "Torso"
	MaterialLib.mesh(MaterialLib.sphere(torso_r * 0.72, torso_r * 1.7), ms, Vector3(0, 0.6, torso_r * 0.38), body)
	# Roupa/acessório (cor de destaque)
	match shape:
		"urso":
			MaterialLib.mesh(MaterialLib.cylinder(torso_r * 0.85, torso_r * 0.98, 0.42), ma, Vector3(0, 0.55, 0.05), body)
		"sapo":
			var bow := MaterialLib.mesh(MaterialLib.box(Vector3(0.26, 0.1, 0.06)), ma, Vector3(0, 0.9, torso_r * 0.85), body)
			bow.name = "Bowtie"
		"raposa":
			pass
		_:
			MaterialLib.mesh(MaterialLib.cylinder(torso_r * 0.78, torso_r * 0.9, 0.12), ma, Vector3(0, 0.86, 0), body)
	# Braços
	for side in [-1, 1]:
		var arm_pivot := Node3D.new()
		arm_pivot.name = "ArmL" if side < 0 else "ArmR"
		arm_pivot.position = Vector3((torso_r + 0.04) * side, 0.82, 0)
		body.add_child(arm_pivot)
		var arm_mat := mp
		if shape == "coruja":
			var wing := MaterialLib.mesh(MaterialLib.sphere(0.14, 0.5), mp, Vector3(0.03 * side, -0.2, -0.02), arm_pivot)
			wing.scale = Vector3(0.6, 1.0, 1.0)
		else:
			MaterialLib.mesh(MaterialLib.capsule(0.08, 0.36), arm_mat, Vector3(0.02 * side, -0.16, 0), arm_pivot)
	# Cabeça
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.18, 0)
	body.add_child(head)
	var head_r := 0.34
	if shape in ["coruja", "sapo"]:
		head_r = 0.38
	var skull := MaterialLib.mesh(MaterialLib.sphere(head_r), mp, Vector3.ZERO, head)
	if shape == "sapo":
		skull.scale = Vector3(1.15, 0.8, 1.0)
	if shape == "ovelha":
		# Lã: bolinhas ao redor da cabeça e do corpo.
		var wool := MaterialLib.toon(p.lightened(0.05))
		for i in range(8):
			var ang := TAU * i / 8.0
			MaterialLib.mesh(MaterialLib.sphere(0.15), wool, Vector3(cos(ang) * 0.28, 0.2 + sin(ang * 2.0) * 0.04, sin(ang) * 0.22 - 0.05), head)
		for i in range(10):
			var ang2 := TAU * i / 10.0
			MaterialLib.mesh(MaterialLib.sphere(0.17), wool, Vector3(cos(ang2) * torso_r, 0.62 + (i % 2) * 0.15, sin(ang2) * torso_r * 0.9), body)
		skull.material_override = ms
	# Focinho/rosto
	var face_z := head_r * 0.82
	match shape:
		"coruja":
			for side in [-1, 1]:
				MaterialLib.mesh(MaterialLib.sphere(0.14), ms, Vector3(0.13 * side, 0.04, face_z - 0.04), head)
			MaterialLib.mesh(MaterialLib.cylinder(0.0, 0.05, 0.12, 8), MaterialLib.toon(Color(0.95, 0.7, 0.25)), Vector3(0, -0.06, face_z + 0.06), head).rotation_degrees = Vector3(-100, 0, 0)
		"sapo":
			MaterialLib.mesh(MaterialLib.sphere(0.24, 0.16), ms, Vector3(0, -0.12, face_z - 0.08), head)
		"ovelha":
			pass
		_:
			var snout := MaterialLib.mesh(MaterialLib.sphere(0.15, 0.2), ms, Vector3(0, -0.08, face_z), head)
			if shape in ["raposa", "lontra"]:
				snout.scale = Vector3(0.9, 0.8, 1.4)
			MaterialLib.mesh(MaterialLib.sphere(0.045), MaterialLib.toon(EYE), Vector3(0, -0.04, face_z + 0.13 if shape != "raposa" else face_z + 0.18), head)
	# Olhos
	var eye_y := 0.06
	var eye_x := 0.13
	var eye_z := face_z - 0.02
	if shape == "sapo":
		eye_y = 0.3
		eye_x = 0.17
		eye_z = 0.05
		for side in [-1, 1]:
			MaterialLib.mesh(MaterialLib.sphere(0.12), mp, Vector3(eye_x * side, 0.24, 0.05), head)
	elif shape == "coruja":
		eye_z = face_z + 0.08
	for side in [-1, 1]:
		var eye := MaterialLib.mesh(MaterialLib.sphere(0.055, 0.08), MaterialLib.toon(EYE), Vector3(eye_x * side, eye_y, eye_z), head)
		eye.name = "Eye"
		MaterialLib.mesh(MaterialLib.sphere(0.018), MaterialLib.toon(Color.WHITE, 0.3, 0.6), Vector3(eye_x * side + 0.015, eye_y + 0.02, eye_z + 0.04), head)
	# Bochechas
	if shape not in ["coruja", "sapo"]:
		for side in [-1, 1]:
			MaterialLib.mesh(MaterialLib.sphere(0.05, 0.03), MaterialLib.toon(Color(1.0, 0.6, 0.62)), Vector3(0.21 * side, -0.06, face_z - 0.08), head)
	# Orelhas por espécie
	match shape:
		"coelho":
			for side in [-1, 1]:
				var ear := Node3D.new()
				ear.position = Vector3(0.12 * side, 0.28, -0.02)
				ear.rotation_degrees = Vector3(-8, 0, -10 * side)
				head.add_child(ear)
				MaterialLib.mesh(MaterialLib.capsule(0.08, 0.55), mp, Vector3(0, 0.25, 0), ear)
				MaterialLib.mesh(MaterialLib.capsule(0.045, 0.4), ms, Vector3(0, 0.25, 0.05), ear)
		"urso":
			for side in [-1, 1]:
				MaterialLib.mesh(MaterialLib.sphere(0.11, 0.18), mp, Vector3(0.24 * side, 0.26, -0.04), head)
				MaterialLib.mesh(MaterialLib.sphere(0.06, 0.1), ms, Vector3(0.24 * side, 0.26, 0.02), head)
		"raposa", "esquilo":
			for side in [-1, 1]:
				var cone := MaterialLib.mesh(MaterialLib.cylinder(0.0, 0.11, 0.26, 10), mp, Vector3(0.18 * side, 0.32, -0.02), head)
				cone.rotation_degrees = Vector3(0, 0, -14 * side)
				if shape == "raposa":
					MaterialLib.mesh(MaterialLib.cylinder(0.0, 0.05, 0.12, 8), MaterialLib.toon(EYE), Vector3(0.21 * side, 0.43, -0.02), head).rotation_degrees = Vector3(0, 0, -14 * side)
		"lontra":
			for side in [-1, 1]:
				MaterialLib.mesh(MaterialLib.sphere(0.06), mp, Vector3(0.27 * side, 0.14, -0.04), head)
		"coruja":
			for side in [-1, 1]:
				var tuft := MaterialLib.mesh(MaterialLib.cylinder(0.0, 0.07, 0.2, 8), mp, Vector3(0.2 * side, 0.36, -0.02), head)
				tuft.rotation_degrees = Vector3(0, 0, -25 * side)
		"ovelha":
			for side in [-1, 1]:
				var ear2 := MaterialLib.mesh(MaterialLib.sphere(0.08, 0.2), ms, Vector3(0.3 * side, 0.02, 0.0), head)
				ear2.rotation_degrees = Vector3(0, 0, 70 * side)
	# Acessórios de cabeça
	match def.id:
		"ravena":
			var beret := MaterialLib.mesh(MaterialLib.cylinder(0.2, 0.24, 0.08), ma, Vector3(0.05, 0.32, -0.03), head)
			beret.rotation_degrees = Vector3(0, 0, 12)
		"lila":
			MaterialLib.mesh(MaterialLib.sphere(0.07), MaterialLib.toon(Color(1.0, 0.85, 0.3)), Vector3(-0.2, 0.28, 0.12), head)
			for i in range(5):
				var ang3 := TAU * i / 5.0
				MaterialLib.mesh(MaterialLib.sphere(0.055), MaterialLib.toon(Color(0.98, 0.55, 0.65)), Vector3(-0.2 + cos(ang3) * 0.07, 0.28 + sin(ang3) * 0.07, 0.1), head)
		"otavio":
			for side in [-1, 1]:
				var lens := MaterialLib.mesh(MaterialLib.cylinder(0.075, 0.075, 0.02, 16), MaterialLib.toon(Color(0.25, 0.2, 0.15)), Vector3(0.13 * side, 0.06, face_z + 0.12), head)
				lens.rotation_degrees = Vector3(90, 0, 0)
		"pipa":
			var bag := MaterialLib.mesh(MaterialLib.box(Vector3(0.22, 0.2, 0.1)), ma, Vector3(-0.28, 0.6, 0.1), body)
			bag.rotation_degrees = Vector3(0, 0, 10)
		"marina":
			MaterialLib.mesh(MaterialLib.cylinder(0.24, 0.26, 0.06), ma, Vector3(0, 0.9, 0), body)
		"celeste":
			var glasses := MaterialLib.mesh(MaterialLib.box(Vector3(0.36, 0.03, 0.02)), MaterialLib.toon(Color(0.85, 0.7, 0.3)), Vector3(0, 0.07, face_z + 0.02), head)
			glasses.name = "Glasses"
		"tobias":
			var hat := MaterialLib.mesh(MaterialLib.cylinder(0.2, 0.18, 0.24), MaterialLib.toon(Color(0.98, 0.98, 0.96)), Vector3(0, 0.38, -0.02), head)
			hat.name = "ChefHat"
			MaterialLib.mesh(MaterialLib.sphere(0.24, 0.2), MaterialLib.toon(Color(0.98, 0.98, 0.96)), Vector3(0, 0.52, -0.02), head)
	# Cauda
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.5, -torso_r * 0.9)
	body.add_child(tail)
	match shape:
		"coelho", "ovelha", "urso":
			MaterialLib.mesh(MaterialLib.sphere(0.1), ms if shape == "coelho" else mp, Vector3(0, 0, -0.05), tail)
		"raposa":
			var t1 := MaterialLib.mesh(MaterialLib.capsule(0.14, 0.7), mp, Vector3(0, 0.1, -0.25), tail)
			t1.rotation_degrees = Vector3(-55, 0, 0)
			MaterialLib.mesh(MaterialLib.sphere(0.12), ms, Vector3(0, 0.33, -0.5), tail)
		"esquilo":
			var t2 := MaterialLib.mesh(MaterialLib.capsule(0.18, 0.9), mp, Vector3(0, 0.38, -0.18), tail)
			t2.rotation_degrees = Vector3(-15, 0, 0)
			MaterialLib.mesh(MaterialLib.sphere(0.2), mp, Vector3(0, 0.82, -0.05), tail)
		"lontra":
			var t3 := MaterialLib.mesh(MaterialLib.capsule(0.08, 0.6), mp, Vector3(0, -0.2, -0.22), tail)
			t3.rotation_degrees = Vector3(-60, 0, 0)
		"coruja":
			var t4 := MaterialLib.mesh(MaterialLib.box(Vector3(0.22, 0.04, 0.2)), mp, Vector3(0, -0.15, -0.05), tail)
			t4.rotation_degrees = Vector3(30, 0, 0)
	root.scale = Vector3.ONE * def.height_scale
	return root


static func build_player() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var skin := MaterialLib.toon(Color(0.98, 0.82, 0.68))
	var hair := MaterialLib.toon(Color(0.36, 0.22, 0.16))
	var shirt := MaterialLib.toon(Color(0.98, 0.62, 0.5))
	var pants := MaterialLib.toon(Color(0.35, 0.48, 0.72))
	var shoes := MaterialLib.toon(Color(0.95, 0.95, 0.95))
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(0.12 * side, 0.45, 0)
		root.add_child(leg)
		MaterialLib.mesh(MaterialLib.capsule(0.1, 0.45), pants, Vector3(0, -0.2, 0), leg)
		MaterialLib.mesh(MaterialLib.sphere(0.11, 0.12), shoes, Vector3(0, -0.42, 0.04), leg)
	MaterialLib.mesh(MaterialLib.capsule(0.26, 0.62), shirt, Vector3(0, 0.72, 0), body)
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(0.3 * side, 0.92, 0)
		body.add_child(arm)
		MaterialLib.mesh(MaterialLib.capsule(0.075, 0.42), shirt, Vector3(0, -0.15, 0), arm)
		MaterialLib.mesh(MaterialLib.sphere(0.07), skin, Vector3(0, -0.36, 0), arm)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.32, 0)
	body.add_child(head)
	MaterialLib.mesh(MaterialLib.sphere(0.33), skin, Vector3.ZERO, head)
	var cap := MaterialLib.mesh(MaterialLib.sphere(0.35, 0.5), hair, Vector3(0, 0.1, -0.03), head)
	cap.scale = Vector3(1.0, 0.9, 1.0)
	MaterialLib.mesh(MaterialLib.sphere(0.15), hair, Vector3(0, 0.05, -0.32), head)
	for side in [-1, 1]:
		MaterialLib.mesh(MaterialLib.sphere(0.045, 0.07), MaterialLib.toon(EYE), Vector3(0.11 * side, 0.0, 0.29), head)
		MaterialLib.mesh(MaterialLib.sphere(0.045, 0.025), MaterialLib.toon(Color(1, 0.62, 0.6)), Vector3(0.19 * side, -0.08, 0.25), head)
	# Pequena flor no cabelo: assinatura visual da jogadora.
	MaterialLib.mesh(MaterialLib.sphere(0.06), MaterialLib.toon(Color(1.0, 0.85, 0.3)), Vector3(0.22, 0.2, 0.15), head)
	return root
