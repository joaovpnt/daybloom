extends TestCase
## Inventário, coleta de recursos e entrega de presentes.


func test_inventario_basico() -> void:
	var inv := Inventory.new()
	assert_eq(inv.add("margarida", 3), 3)
	assert_eq(inv.add("item_inexistente", 1), 0, "itens desconhecidos são recusados")
	assert_true(inv.remove("margarida", 2))
	assert_false(inv.remove("margarida", 5), "não remove mais do que tem")
	assert_eq(inv.count("margarida"), 1)
	assert_eq(inv.add("concha", 200), Inventory.MAX_STACK, "pilha limitada")
	assert_eq(inv.items().size(), 2, "uma pilha por item")


func test_limite_de_espacos() -> void:
	var inv := Inventory.new()
	var ids := ItemDB.ITEMS.keys()
	for id in ids:
		inv.add(id, 1)
	assert_eq(inv.slots_used(), ids.size())
	assert_true(inv.slots_used() <= Inventory.MAX_SLOTS)


func test_coleta_altera_estado_real() -> void:
	GameState.new_game("Ana", "Daybloom", 3)
	var id := "flor_01"
	var item: String = GameState.resources[id]["item_id"]
	var before := GameState.inventory.count(item)
	var res := GameState.collect_resource(id)
	assert_true(res["ok"], "coleta deve funcionar")
	assert_eq(GameState.inventory.count(item), before + 1, "item foi para o inventário")
	assert_false(GameState.resources[id]["available"], "recurso fica indisponível")
	assert_false(GameState.collect_resource(id)["ok"], "não coleta duas vezes")
	assert_eq(int(GameState.resources[id]["respawn_day"]), GameClock.day + 1, "renasce no dia seguinte")
	GameState._on_day_started(GameClock.day + 1)
	assert_true(GameState.resources[id]["available"], "recurso renasce no novo dia")
	GameState.end_session()


func test_presente_preferido() -> void:
	var sim := new_sim()
	var inv := Inventory.new()
	inv.add("tulipa_coral", 1)
	sim.npcs["lila"].set_state("IDLE", "parado")
	sim.npcs["lila"].inside_home = false
	var before := sim.relationships.affinity("lila", sim.player_id)
	var res := sim.give_gift("lila", "tulipa_coral", inv)
	assert_true(res["ok"])
	assert_eq(res["reaction"], "adorou", "Lila adora flores")
	assert_eq(inv.count("tulipa_coral"), 0, "item saiu do inventário")
	assert_gt(sim.relationships.affinity("lila", sim.player_id), before, "afinidade aumentou")
	var mems := sim.memories.list_for("lila").filter(func(m): return m["type"] == "gift_received")
	assert_eq(mems.size(), 1, "memória de presente registrada")
	assert_eq(sim.journal.entries[-1]["kind"], "gift_received", "presente no Diário da Ilha")


func test_presente_detestado() -> void:
	var sim := new_sim()
	var inv := Inventory.new()
	inv.add("galho", 1)
	sim.npcs["lila"].set_state("IDLE", "parado")
	var before := sim.relationships.affinity("lila", sim.player_id)
	var res := sim.give_gift("lila", "galho", inv)
	assert_eq(res["reaction"], "não gostou")
	assert_lt(sim.relationships.affinity("lila", sim.player_id), before, "afinidade caiu")


func test_presentes_repetidos_rendem_menos() -> void:
	var sim := new_sim()
	var inv := Inventory.new()
	inv.add("concha", 5)
	sim.npcs["marina"].set_state("IDLE", "parado")
	var d1: float = sim.give_gift("marina", "concha", inv)["affinity_delta"]
	var d2: float = sim.give_gift("marina", "concha", inv)["affinity_delta"]
	var d3: float = sim.give_gift("marina", "concha", inv)["affinity_delta"]
	assert_gt(d1, d2, "segundo presente do dia rende menos")
	assert_eq(d3, 0.0, "terceiro presente do dia não altera afinidade")
	assert_eq(sim.memories.list_for("marina").filter(func(m): return m["type"] == "gift_received").size(), 1, "presentes iguais no mesmo dia viram uma memória reforçada")


func test_presente_sem_item_falha() -> void:
	var sim := new_sim()
	var inv := Inventory.new()
	var entries := sim.journal.entries.size()
	var res := sim.give_gift("bento", "campanula", inv)
	assert_false(res["ok"], "não é possível dar o que não tem")
	assert_eq(sim.journal.entries.size(), entries, "nada registrado")
