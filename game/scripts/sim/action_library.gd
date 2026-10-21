class_name ActionLibrary
extends RefCounted
## Ações domésticas e de lazer usadas pela jogadora e pelos moradores. Cada
## ação tem duração (minutos de jogo), objeto-alvo (affordance), pré-condições,
## efeitos por minuto, efeitos ao concluir e pode ser interrompida.
##
## rates: variação por minuto das necessidades enquanto a ação acontece.
## end: variação única ao concluir. mood: [id, causa, estado, intensidade, duração].
## time_scale: aceleração do relógio enquanto a JOGADORA executa a ação.

const ACTIONS := {
	"dormir": {"label": "Dormir", "minutes": 480.0, "pose": "sleep", "activity": "dormindo", "rates": {"energia": 0.32, "fome": -0.04, "higiene": -0.02, "banheiro": -0.06, "diversao": 0.0, "social": 0.0}, "comfort_object": true, "time_scale": 40.0, "until_wake": true, "mood": ["dormiu_bem", "Dormiu bem", "feliz", 0.35, 360.0]},
	"cochilar": {"label": "Tirar um cochilo", "minutes": 60.0, "pose": "sleep", "activity": "dormindo", "rates": {"energia": 0.28, "fome": -0.05, "banheiro": -0.07, "diversao": 0.0, "social": 0.0}, "comfort_object": true, "time_scale": 12.0, "mood": ["cochilo", "Tirou um cochilo", "feliz", 0.15, 120.0]},
	"sentar": {"label": "Sentar e descansar", "minutes": 20.0, "pose": "sit", "activity": "descansando", "rates": {"energia": 0.05}, "comfort_object": true, "time_scale": 4.0},
	"relaxar": {"label": "Relaxar", "minutes": 30.0, "pose": "sit", "activity": "descansando", "rates": {"diversao": 0.5, "energia": 0.08}, "comfort_object": true, "time_scale": 4.0, "mood": ["relaxou", "Relaxou na cobertura", "feliz", 0.25, 180.0]},
	"assistir_tv": {"label": "Assistir TV", "minutes": 30.0, "pose": "sit", "activity": "lazer", "rates": {"diversao": 1.25, "energia": -0.02}, "comfort_object": true, "needs_seat": true, "time_scale": 4.0},
	"ler": {"label": "Ler um livro", "minutes": 30.0, "pose": "read", "activity": "lazer", "rates": {"diversao": 0.8}, "time_scale": 4.0, "mood": ["leu", "Leu um bom livro", "inspirado", 0.3, 180.0]},
	"regar": {"label": "Regar as plantas", "minutes": 5.0, "pose": "use", "activity": "lazer", "rates": {"diversao": 0.6}, "time_scale": 2.0, "daily": true, "mood": ["plantas", "Cuidou das plantas", "feliz", 0.12, 120.0]},
	"comer_lanche": {"label": "Comer um lanche", "minutes": 10.0, "pose": "eat", "activity": "comendo", "consume_food": true, "time_scale": 3.0},
	"cozinhar": {"label": "Cozinhar uma refeição", "minutes": 25.0, "pose": "cook", "activity": "cozinhando", "rates": {"diversao": 0.3}, "requires_ingredient": true, "end": {"fome": 65.0}, "dirty": {"self": 0.4, "pia_cozinha": 0.35, "mesa": 0.2}, "time_scale": 4.0, "mood": ["comida_caseira", "Comeu uma comida caseira", "feliz", 0.3, 240.0]},
	"banho": {"label": "Tomar banho", "minutes": 14.0, "pose": "shower", "activity": "tomando banho", "rates": {"higiene": 6.5}, "dirty": {"self": 0.08}, "time_scale": 3.0, "mood": ["banho", "Tomou um banho relaxante", "feliz", 0.15, 120.0]},
	"banheiro": {"label": "Usar o banheiro", "minutes": 4.0, "pose": "sit", "activity": "no banheiro", "rates": {"banheiro": 26.0}, "dirty": {"self": 0.1}, "time_scale": 2.0, "private": true},
	"lavar_maos": {"label": "Lavar as mãos", "minutes": 2.0, "pose": "use", "activity": "lavando as mãos", "rates": {"higiene": 3.0}, "time_scale": 1.0},
	"limpar": {"label": "Limpar", "minutes": 8.0, "pose": "clean", "activity": "limpando", "rates": {"energia": -0.08, "higiene": -0.1}, "cleans": true, "time_scale": 3.0, "mood": ["limpeza", "Deixou tudo limpinho", "feliz", 0.2, 240.0]},
	"costurar": {"label": "Costurar", "minutes": 40.0, "pose": "use", "activity": "lazer", "rates": {"diversao": 1.0}, "hobby": "costura", "time_scale": 4.0, "mood": ["costura", "Costurou algo bonito", "inspirado", 0.35, 180.0]},
	"pintar": {"label": "Pintar", "minutes": 40.0, "pose": "paint", "activity": "lazer", "rates": {"diversao": 1.0}, "hobby": "pintura", "time_scale": 4.0, "mood": ["pintura", "Pintou um quadro", "inspirado", 0.4, 180.0]},
	"tocar": {"label": "Tocar música", "minutes": 40.0, "pose": "play", "activity": "lazer", "rates": {"diversao": 1.0}, "hobby": "musica", "loud": true, "time_scale": 4.0, "mood": ["musica", "Tocou música", "inspirado", 0.35, 180.0]},
	"observar": {"label": "Observar o céu", "minutes": 40.0, "pose": "look", "activity": "lazer", "rates": {"diversao": 0.9}, "hobby": "observar_estrelas", "time_scale": 4.0, "mood": ["estrelas", "Observou o céu", "inspirado", 0.4, 240.0]},
	"organizar_cartas": {"label": "Organizar cartas", "minutes": 30.0, "pose": "use", "activity": "trabalhando", "rates": {"diversao": 0.3}, "hobby": "cartas", "time_scale": 4.0},
	"estudar": {"label": "Estudar", "minutes": 40.0, "pose": "use", "activity": "trabalhando", "rates": {"diversao": 0.2}, "time_scale": 4.0, "mood": ["estudo", "Aprendeu algo novo", "inspirado", 0.2, 180.0]},
	"cuidar_horta": {"label": "Cuidar da horta", "minutes": 20.0, "pose": "garden", "activity": "lazer", "rates": {"diversao": 0.6}, "hobby": "jardinagem", "harvest": "verduras", "time_scale": 4.0, "mood": ["horta", "Cuidou da horta", "feliz", 0.22, 180.0]},
	"exercitar": {"label": "Exercitar-se", "minutes": 30.0, "pose": "exercise", "activity": "exercicio", "rates": {}, "hobby": "corrida", "time_scale": 4.0, "mood": ["treino", "Treinou na academia", "animado", 0.4, 180.0]},
	"lavar_roupa": {"label": "Lavar roupa", "minutes": 20.0, "pose": "use", "activity": "lavando roupa", "rates": {}, "end": {"higiene": 12.0, "conforto": 10.0}, "time_scale": 4.0, "mood": ["roupa_limpa", "Roupas limpinhas", "feliz", 0.15, 240.0]},
	"nadar": {"label": "Nadar", "minutes": 30.0, "pose": "swim", "activity": "lazer", "rates": {"diversao": 1.2, "higiene": 0.4, "energia": -0.15, "fome": -0.16}, "hobby": "natacao", "time_scale": 4.0, "mood": ["piscina", "Nadou na piscina", "animado", 0.45, 180.0]},
	"cafe": {"label": "Tomar um café", "minutes": 6.0, "pose": "eat", "activity": "tomando café", "rates": {"energia": 2.0, "fome": 1.2}, "time_scale": 2.0},
	"repor": {"label": "Repor prateleira", "minutes": 4.0, "pose": "use", "activity": "trabalhando", "rates": {"energia": -0.1}, "job": true, "time_scale": 2.0},
	"organizar": {"label": "Organizar prateleira", "minutes": 3.0, "pose": "use", "activity": "trabalhando", "rates": {"energia": -0.08}, "job": true, "time_scale": 2.0},
	"atender": {"label": "Atender cliente", "minutes": 3.0, "pose": "use", "activity": "trabalhando", "rates": {"energia": -0.05, "social": 1.0}, "job": true, "time_scale": 2.0},
	"pegar_estoque": {"label": "Pegar caixa de produtos", "minutes": 1.0, "pose": "use", "activity": "trabalhando", "job": true, "time_scale": 1.0},
	"churrasco": {"label": "Preparar o churrasco", "minutes": 20.0, "pose": "cook", "activity": "cozinhando", "rates": {"diversao": 0.6, "social": 0.2}, "event": true, "dirty": {"self": 0.5}, "time_scale": 3.0},
}

## Ações que abrem uma interface em vez de passar tempo.
const UI_ACTIONS := ["fabricar", "comprar", "emprego", "correio"]


static func has(action_id: String) -> bool:
	return ACTIONS.has(action_id)


static func get_action(action_id: String) -> Dictionary:
	return ACTIONS.get(action_id, {})


static func label(action_id: String) -> String:
	if ACTIONS.has(action_id):
		return str(ACTIONS[action_id]["label"])
	return str(FurnitureDB.AFF_LABELS.get(action_id, action_id))


static func minutes(action_id: String) -> float:
	return float(ACTIONS.get(action_id, {}).get("minutes", 10.0))


static func is_loud(action_id: String) -> bool:
	return bool(ACTIONS.get(action_id, {}).get("loud", false))


## Primeiro ingrediente disponível para cozinhar (consumo real do inventário).
static func ingredient_plan(inventory: Inventory) -> Dictionary:
	if inventory.has("ingredientes", 1):
		return {"ingredientes": 1}
	if inventory.has("verduras", 2):
		return {"verduras": 2}
	if inventory.has("kit_churrasco", 1):
		return {"kit_churrasco": 1}
	return {}


## Melhor comida do inventário para um lanche (a que mais mata a fome sem desperdiçar).
static func pick_food(inventory: Inventory, hunger_missing: float) -> String:
	var best := ""
	var best_score := -INF
	for slot in inventory.items():
		var item_id: String = slot["item_id"]
		var food := ItemDB.food_value(item_id)
		if food <= 0.0:
			continue
		var score := -absf(food - hunger_missing)
		if score > best_score:
			best_score = score
			best = item_id
	return best


## Pré-condições da jogadora. ctx: {needs: NeedsComponent, inventory, hour,
## object: Dictionary, dirt: float, watered_today: bool, harvested_today: bool,
## in_use_by: String, allowed: bool}
static func check_player(action_id: String, ctx: Dictionary) -> Dictionary:
	if not ACTIONS.has(action_id):
		return {"ok": false, "reason": "Não dá para fazer isso aqui."}
	if not bool(ctx.get("allowed", true)):
		return {"ok": false, "reason": str(ctx.get("denied_reason", "Isso não é seu."))}
	var who := str(ctx.get("in_use_by", ""))
	if who != "":
		return {"ok": false, "reason": "%s está usando agora." % who}
	var needs: NeedsComponent = ctx.get("needs")
	var hour := float(ctx.get("hour", 12.0))
	var inv: Inventory = ctx.get("inventory")
	match action_id:
		"dormir":
			if needs and needs.get_value("energia") >= 80.0 and hour >= 6.0 and hour < 20.5:
				return {"ok": false, "reason": "Você ainda não está com sono."}
		"cochilar":
			if needs and needs.get_value("energia") >= 75.0:
				return {"ok": false, "reason": "Você está bem disposta, sem sono agora."}
		"comer_lanche":
			if inv == null or pick_food(inv, 50.0) == "":
				return {"ok": false, "reason": "Não há comida. Compre algo no mercadinho do térreo."}
			if needs and needs.get_value("fome") >= 95.0:
				return {"ok": false, "reason": "Você está satisfeita."}
		"cozinhar":
			if inv == null or ingredient_plan(inv).is_empty():
				return {"ok": false, "reason": "Faltam ingredientes (uma cesta de ingredientes ou 2 verduras da horta)."}
		"banho":
			if needs and needs.get_value("higiene") >= 97.0:
				return {"ok": false, "reason": "Você já está limpinha."}
		"banheiro":
			if needs and needs.get_value("banheiro") >= 92.0:
				return {"ok": false, "reason": "Você não precisa agora."}
		"limpar":
			if float(ctx.get("dirt", 0.0)) < 0.2:
				return {"ok": false, "reason": "Já está limpo."}
		"regar":
			if bool(ctx.get("watered_today", false)):
				return {"ok": false, "reason": "Já foi regada hoje."}
		"observar":
			if hour >= 6.0 and hour < 18.5:
				return {"ok": false, "reason": "As estrelas só aparecem à noite."}
	return {"ok": true, "reason": ""}
