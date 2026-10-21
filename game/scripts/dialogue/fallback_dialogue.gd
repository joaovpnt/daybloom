class_name FallbackDialogue
extends RefCounted
## Diálogos convencionais contextualizados, usados quando o Ollama não está
## disponível. As falas usam a personalidade, o humor, a relação com a
## jogadora, memórias reais e acontecimentos confirmados da simulação.

## Vozes individuais: trechos que dão a cada morador um jeito próprio de falar.
const VOICES := {
	"lila": {"hi": ["Oiê, %s!", "Aaai, %s! Que bom te ver!"], "tail": [" Que coisa mais fofa!", " Hihi!", ""], "bye": ["Tchauzinho! Volta logo, tá?", "Até mais, florzinha!"], "unknown": ["Hmm, não entendi direitinho, mas adorei conversar!", "Que interessante! Me conta mais depois, tá?"]},
	"tobias": {"hi": ["Ah... olá, %s. Hum-hum.", "Bem-vinda, %s. Sente-se, sem pressa."], "tail": [" Hum-hum.", " Sem pressa.", ""], "bye": ["Vá com calma, %s.", "Até logo. Passe no quiosque quando quiser."], "unknown": ["Hum... deixa eu pensar nisso com calma.", "Não sei bem o que dizer, mas fico feliz com a conversa."]},
	"marina": {"hi": ["E aí, %s! Bora nessa?", "Opa, %s! Chegou na hora certa!"], "tail": [" Bora nessa!", " Show!", ""], "bye": ["Falou, %s! Até a próxima onda!", "Partiu! A gente se vê!"], "unknown": ["Hã? Viajei agora... fala de novo?", "Saquei mais ou menos, mas tá valendo!"]},
	"otavio": {"hi": ["Boa %s, %s. Fascinante encontrá-la.", "Ah, %s. Estava refletindo sobre o céu."], "tail": [" Fascinante...", " Curioso, não?", ""], "bye": ["Até breve. Observe as estrelas hoje.", "Foi uma conversa instrutiva, %s."], "unknown": ["Interessante. Preciso de mais dados para responder.", "Hmm... uma questão intrigante."]},
	"pipa": {"hi": ["%s! %s! Tenho novidade!", "Oi oi oi, %s!"], "tail": [" Tenho novidade!", " Ai, que agito!", ""], "bye": ["Tchau! Preciso correr, tem carta pra entregar!", "Até! Se souber de fofoca, me conta!"], "unknown": ["Hein? Ah, sim, sim! Quer dizer... o quê mesmo?", "Nossa, nem sei o que dizer — e eu sempre sei!"]},
	"bento": {"hi": ["Oi, %s, que som bonito te ver!", "E aí, %s, tudo na mesma melodia?"], "tail": [" Que som bonito!", " Lá-rá-lá.", ""], "bye": ["Até mais, %s, com melodia e paz!", "Tchau! Vou compor alguma coisa agora."], "unknown": ["Hmm, essa eu não sei, mas daria uma boa canção.", "Não entendi, mas gostei do ritmo."]},
	"ravena": {"hi": ["Ah, é você, %s. Hmpf, nada mal.", "%s. Veio ver minha arte?"], "tail": [" Hmpf.", " Nada mal.", ""], "bye": ["Tá, tá. Até mais.", "Vai lá. Tenho um quadro pra terminar."], "unknown": ["Não entendi. Seja mais direta.", "Hmpf. Isso não faz muito sentido pra mim."]},
	"celeste": {"hi": ["Ai, que graça, %s! Venha cá, querida.", "Olá, querida %s! Já comeu hoje?"], "tail": [" Ai, que graça.", " Querida.", ""], "bye": ["Vá com Deus, querida. Leve um casaquinho!", "Até logo, %s. Volte sempre!"], "unknown": ["Ah, querida, minha memória já não é a mesma... o que disse?", "Que bonito isso, mesmo que eu não tenha entendido tudo."]},
}

const NPC_NAME_KEYS := {
	"lila": ["lila"], "tobias": ["tobias", "tobi"], "marina": ["marina"], "otavio": ["otavio"],
	"pipa": ["pipa"], "bento": ["bento"], "ravena": ["ravena"], "celeste": ["celeste", "dona celeste"],
}


static func normalize(text: String) -> String:
	var t := text.to_lower()
	var from := ["á", "à", "â", "ã", "é", "ê", "í", "ó", "ô", "õ", "ú", "ç"]
	var to := ["a", "a", "a", "a", "e", "e", "i", "o", "o", "o", "u", "c"]
	for i in range(from.size()):
		t = t.replace(from[i], to[i])
	return t


static func _has_any(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false


static func detect_intent(message: String, npc_id: String) -> Dictionary:
	var t := normalize(message)
	var conflict_words := ["briga", "brigad", "brigou", "brigaram", "discut", "desentend", "pazes"]
	if _has_any(t, conflict_words):
		var targets := []
		for other_id in NPC_NAME_KEYS:
			for key in NPC_NAME_KEYS[other_id]:
				if t.contains(key) and not targets.has(other_id):
					targets.append(other_id)
		return {"intent": "conflict", "targets": targets}
	if _has_any(t, ["presente", "dei pra voce", "te dei", "te entreguei"]) and _has_any(t, ["lembra", "gostou", "dei", "entreguei", "usando", "guardou"]):
		return {"intent": "gift_memory"}
	for other_id in NPC_NAME_KEYS:
		if other_id == npc_id:
			continue
		for key in NPC_NAME_KEYS[other_id]:
			if t.contains(key):
				return {"intent": "other_npc", "target": other_id}
	if _has_any(t, ["tchau", "ate mais", "ate logo", "adeus", "falou", "fui"]):
		return {"intent": "bye"}
	if _has_any(t, ["obrigad", "valeu", "agradec"]):
		return {"intent": "thanks"}
	if _has_any(t, ["novidade", "como foi", "o que voce fez", "o que fez", "aconteceu", "fofoca"]):
		return {"intent": "news"}
	if _has_any(t, ["tudo bem", "como vai", "como voce esta", "como esta", "como ce ta", "beleza", "tudo bom", "se sente"]):
		return {"intent": "how"}
	if _has_any(t, ["gosta", "favorit", "prefere", "presente ideal", "o que te agrada"]):
		return {"intent": "likes"}
	if _has_any(t, ["sonho", "objetivo", "plano", "meta", "deseja"]):
		return {"intent": "goal"}
	if _has_any(t, ["trabalh", "profiss", "faz da vida", "ocupacao", "fazendo"]):
		return {"intent": "work"}
	if _has_any(t, ["lembra", "memoria", "lembrou"]):
		return {"intent": "memory"}
	if _has_any(t, ["bonit", "legal", "gosto de voce", "adoro voce", "fofa", "fofo", "incrivel", "amo voce", "querid"]):
		return {"intent": "compliment"}
	if _has_any(t, ["hora", "clima", "tempo", "noite", "manha", "tarde", "sol", "estrela"]):
		return {"intent": "time"}
	if _has_any(t, ["oi", "ola", "bom dia", "boa tarde", "boa noite", "eai", "e ai", "hey", "opa"]):
		return {"intent": "greet"}
	return {"intent": "unknown"}


static func _voice(npc: NpcState) -> Dictionary:
	return VOICES.get(npc.id, VOICES["lila"])


static func _pick(arr: Array, rng: RandomNumberGenerator) -> String:
	return arr[rng.randi() % arr.size()]


static func _fmt(line: String, sim: Simulation) -> String:
	var count := line.count("%s")
	if count == 0:
		return line
	if count == 1:
		return line % sim.player_name
	# Otávio: "Boa %s, %s" -> período e nome
	return line % [_greeting_period(sim.minute), sim.player_name] if line.begins_with("Boa") else line % [sim.player_name, sim.player_name]


static func _greeting_period(minute: float) -> String:
	var p := GameClock.period_for(minute)
	return "tarde" if p == "tarde" else "noite" if p in ["noite", "entardecer"] else "dia"


static func greeting(npc: NpcState, sim: Simulation, rng: RandomNumberGenerator) -> String:
	var voice := _voice(npc)
	var rel: Dictionary = sim.relationships.get_rel(npc.id, sim.player_id)
	var aff: float = rel["affinity"]
	var line := _fmt(_pick(voice["hi"], rng), sim)
	if int(rel["interactions"]) == 0:
		return line + " Você é a nova moradora, né? Eu sou %s, %s da ilha." % [npc.display_name(), npc.def.occupation]
	if aff >= 55.0:
		line += " Sempre fico feliz quando você aparece."
	elif aff < -8.0:
		line = "Ah... é você. " + line
	var gift_mem := _latest_gift_memory(npc, sim)
	if gift_mem != "" and rng.randf() < 0.5:
		line += " " + gift_mem
	return line + mood_comment(npc, rng)


static func mood_comment(npc: NpcState, rng: RandomNumberGenerator) -> String:
	if npc.mood.begins_with("cansad"):
		return " Estou meio cansad%s hoje..." % npc.def.article()
	if npc.mood.begins_with("chatead") or npc.mood == "triste":
		return " Não estou nos meus melhores dias."
	if npc.mood == "radiante":
		return " Hoje está um dia maravilhoso!"
	if npc.mood.begins_with("solit"):
		return " Que bom ter alguém pra conversar."
	return ""


static func _latest_gift_memory(npc: NpcState, sim: Simulation) -> String:
	var mems := sim.memories.retrieve(npc.id, {"participants": [sim.player_id], "types": ["gift_received"], "now_abs": sim.now_abs()}, 3)
	for m in mems:
		if m["type"] == "gift_received" and str(m["description"]).contains("adorou"):
			return "Ainda lembro do presente que você me deu!"
	return ""


static func respond(npc: NpcState, sim: Simulation, message: String, rng: RandomNumberGenerator) -> Dictionary:
	var info := detect_intent(message, npc.id)
	var intent: String = info["intent"]
	var voice := _voice(npc)
	var def := npc.def
	var text := ""
	match intent:
		"greet":
			text = greeting(npc, sim, rng)
		"bye":
			text = _fmt(_pick(voice["bye"], rng), sim)
		"thanks":
			text = _pick(["Imagina! Estou sempre por aqui.", "Não precisa agradecer!", "De nada!"], rng) + _pick(voice["tail"], rng)
		"how":
			text = _how_are_you(npc, sim, rng)
		"news":
			text = _news(npc, sim, rng)
		"likes":
			text = "Eu gosto muito de %s. Já %s... não é muito a minha praia." % [_tags_text(def.likes), _tags_text(def.dislikes)] + _pick(voice["tail"], rng)
		"goal":
			text = _goal_line(npc, sim) + _pick(voice["tail"], rng)
		"conflict":
			text = _conflict_line(npc, sim, info.get("targets", []))
		"gift_memory":
			text = _gift_memory_line(npc, sim)
		"work":
			text = "Sou %s aqui na ilha. Agora mesmo eu estava %s." % [def.occupation, npc.activity if npc.activity != "conversando com " + sim.player_name else "por aí"] + _pick(voice["tail"], rng)
		"memory":
			text = _memory_line(npc, sim, rng)
		"compliment":
			text = _pick(["Ah, assim você me deixa sem graça!", "Que gentileza a sua!", "Você é um amor, sabia?"], rng) + _pick(voice["tail"], rng)
			if def.gentileza < 0.4:
				text = "Hmpf... obrigada, eu acho. Mas não se acostume."
		"time":
			text = _time_line(npc, sim, rng)
		"other_npc":
			text = _opinion_about(npc, sim, info["target"], rng)
		_:
			text = _pick(voice["unknown"], rng)
	return {"text": text.strip_edges(), "intent": intent}


static func _how_are_you(npc: NpcState, sim: Simulation, rng: RandomNumberGenerator) -> String:
	var line := ""
	match npc.mood:
		"radiante":
			line = "Estou ótim%s! Nada pode estragar meu dia." % npc.def.article()
		"alegre":
			line = "Estou bem, obrigad%s por perguntar!" % npc.def.article()
		"triste":
			line = "Ah... não muito bem, pra ser sincer%s." % npc.def.article()
		_:
			if npc.mood.begins_with("cansad"):
				line = "Um pouco cansad%s. Acho que vou descansar logo." % npc.def.article()
			elif npc.mood.begins_with("chatead"):
				line = "Já estive melhor..."
			elif npc.mood.begins_with("solit"):
				line = "Estava me sentindo meio sozinh%s. Sua visita ajudou!" % npc.def.article()
			elif npc.mood.begins_with("entediad"):
				line = "Entediad%s! Preciso de algo divertido pra fazer." % npc.def.article()
			else:
				line = "Tudo tranquilo por aqui."
	# Menciona um acontecimento real recente, se houver.
	var recent := _recent_social_memory(npc, sim)
	if recent != "":
		line += " " + recent
	return line + _pick(_voice(npc)["tail"], rng)


static func _recent_social_memory(npc: NpcState, sim: Simulation) -> String:
	var mems := sim.memories.retrieve(npc.id, {"types": ["npc_interaction"], "now_abs": sim.now_abs()}, 4)
	for m in mems:
		if m["type"] != "npc_interaction" or int(m["day"]) < sim.day - 1:
			continue
		var others: Array = (m["participants"] as Array).filter(func(p): return p != npc.id)
		if others.is_empty() or not sim.npcs.has(others[0]):
			continue
		var other_name: String = sim.npcs[others[0]].display_name()
		var desc: String = m["description"]
		if desc.begins_with("Desentendeu"):
			return "Tive um desentendimento com %s há pouco... ainda estou pensando nisso." % other_name
		if desc.begins_with("Fez as pazes"):
			return "Fiz as pazes com %s, que alívio!" % other_name
		if desc.begins_with("Conversou"):
			return "Estive conversando com %s mais cedo." % other_name
		return "Passei um tempo bom com %s." % other_name
	return ""


static func _news(npc: NpcState, sim: Simulation, rng: RandomNumberGenerator) -> String:
	# Só conta o que este morador sabe: participou, viu ou ouviu de alguém.
	for m in sim.memories.known_events(npc.id, 1, sim.day, 6):
		var fact := str(m.get("public_fact", m.get("fact", m["description"])))
		if fact == "":
			continue
		match str(m.get("origin", "participacao")):
			"comunicacao":
				var src: String = sim.npcs[m["source_id"]].display_name() if sim.npcs.has(str(m.get("source_id", ""))) else "alguém"
				return "%s me contou que %s Mas eu não vi, hein?" % [src, _lower_first(fact)] + _pick(_voice(npc)["tail"], rng)
			"observacao":
				return "Eu vi com estes olhos: " + _lower_first(str(m.get("fact", fact)).trim_prefix("Viu ")) + _pick(_voice(npc)["tail"], rng)
			_:
				return "Olha só: " + _lower_first(fact) + _pick(_voice(npc)["tail"], rng)
	return "Que eu saiba, nada de novo. Eu estava %s." % (npc.activity if not npc.activity.begins_with("conversando com " + sim.player_name) else "cuidando das minhas coisas")


static func _lower_first(t: String) -> String:
	# Mantém nomes próprios com maiúscula.
	for npc_id in NPC_NAME_KEYS:
		if normalize(t).begins_with(npc_id) or t.begins_with("Dona"):
			return t
	return t.substr(0, 1).to_lower() + t.substr(1)


static func _goal_line(npc: NpcState, sim: Simulation) -> String:
	var g := sim.goal_context(npc.id)
	if g.get("completed", false):
		return "Eu consegui: %s! Ainda estou nas nuvens." % str(g["title"]).to_lower()
	var line := "Meu sonho? %s. Agora estou tentando %s (uns %d%% do caminho)." % [g["title"], g["current_step"], int(g["progress_pct"])]
	if not (g["needs"] as Array).is_empty():
		line += " Se você encontrar %s, me ajudaria muito!" % " ou ".join((g["needs"] as Array).slice(0, 2)).to_lower()
	return line


## Perguntas sobre brigas: responde só com o que sabe; se não sabe, diz.
static func _conflict_line(npc: NpcState, sim: Simulation, targets: Array) -> String:
	var others: Array = targets.filter(func(t): return t != npc.id)
	var about_self := targets.has(npc.id) or others.size() <= 1
	if about_self and others.size() == 1:
		var other: NpcState = sim.npcs[others[0]]
		var rel: Dictionary = sim.relationships.get_rel(npc.id, other.id)
		if bool(rel.get("conflict_open", false)):
			return "Com %s? É... a gente se desentendeu e ainda não fizemos as pazes." % other.display_name()
		for m in sim.memories.retrieve(npc.id, {"participants": [other.id], "keywords": ["desentendeu", "pazes"], "now_abs": sim.now_abs()}, 4):
			if str(m["description"]).begins_with("Fez as pazes") and (m["participants"] as Array).has(other.id):
				return "Com %s? Já fizemos as pazes, ainda bem." % other.display_name()
		return "Brigad%s com %s? Que eu saiba, não tivemos briga nenhuma." % [npc.def.article(), other.display_name()]
	# Briga entre outros: só se viu, participou ou ouviu falar.
	for m in sim.memories.list_for(npc.id):
		var parts: Array = m["participants"]
		var mentions_all := true
		for o in others:
			if not parts.has(o):
				mentions_all = false
		var fact := str(m.get("fact", m["description"]))
		if not mentions_all or not (normalize(fact).contains("discut") or normalize(fact).contains("desentend")):
			continue
		match str(m.get("origin", "")):
			"observacao":
				return "Eu vi, sim: " + _lower_first(fact.trim_prefix("Viu "))
			"comunicacao":
				return "Só ouvi falar... " + fact + " Mas não sei se é verdade."
	var names := []
	for o in others:
		names.append(sim.npcs[o].display_name())
	if names.is_empty():
		return "Briga? Não fiquei sabendo de nada disso."
	return "Não vi nem ouvi nada sobre briga entre %s. Prefiro não inventar." % " e ".join(names)


static func _gift_memory_line(npc: NpcState, sim: Simulation) -> String:
	var mems := sim.memories.retrieve(npc.id, {"participants": [sim.player_id], "types": ["gift_received"], "keywords": ["presente"], "now_abs": sim.now_abs()}, 4)
	for m in mems:
		if m["type"] == "gift_received" and str(m["description"]).begins_with("Recebeu"):
			var d := str(m["description"]).trim_prefix("Recebeu ")
			return "Claro que lembro! No dia %d você me deu %s" % [int(m["day"]), d.substr(0, d.find(" de ")) + "."] + (" Eu adorei!" if d.contains("adorou") else "")
	return "Presente? Acho que você ainda não me deu nenhum... ou eu esqueci, mas não acho que esqueceria!"


static func _memory_line(npc: NpcState, sim: Simulation, rng: RandomNumberGenerator) -> String:
	var mems := sim.memories.retrieve(npc.id, {"participants": [sim.player_id], "now_abs": sim.now_abs()}, 3)
	for m in mems:
		if (m["participants"] as Array).has(sim.player_id) and m["type"] != "community_event":
			return "Claro que lembro: %s" % str(m["description"]).substr(0, 1).to_lower() + str(m["description"]).substr(1)
	return "Ainda não temos muitas histórias juntas, mas tenho certeza de que teremos!"


static func _time_line(npc: NpcState, sim: Simulation, rng: RandomNumberGenerator) -> String:
	var period := GameClock.period_for(sim.minute)
	var hm := GameClock.format_hm(sim.minute)
	match npc.id:
		"otavio":
			return "São %s. %s" % [hm, "O céu já está ótimo para observar estrelas." if period == "noite" else "Daqui a pouco escurece e as estrelas aparecem. Fascinante..."]
		"marina":
			return "São %s! %s" % [hm, "Dia perfeito pra praia!" if period in ["manhã", "tarde"] else "O mar à noite é lindo também."]
	return "Agora são %s, %s. %s" % [hm, period, "Que dia gostoso." if period in ["manhã", "tarde"] else "Já está ficando tarde, hein?"]


static func _opinion_about(npc: NpcState, sim: Simulation, other_id: String, rng: RandomNumberGenerator) -> String:
	var other: NpcState = sim.npcs[other_id]
	var rel: Dictionary = sim.relationships.get_rel(npc.id, other_id)
	var aff: float = rel["affinity"]
	var label := RelationshipSystem.label_for(aff)
	var line := ""
	if bool(rel.get("conflict_open", false)):
		line = "%s? A gente teve um desentendimento... ainda não fizemos as pazes." % other.display_name()
	elif aff >= 55.0:
		line = "%s é uma das minhas pessoas favoritas na ilha!" % other.display_name()
	elif aff >= 30.0:
		line = "Eu e %s somos amigos. Gosto muito da companhia." % other.display_name()
	elif aff >= 10.0:
		line = "%s é legal. A gente se dá bem." % other.display_name()
	elif aff >= -8.0:
		line = "Ainda não conheço %s tão bem assim." % other.display_name()
	else:
		line = "Hmm... eu e %s não nos damos muito bem." % other.display_name()
	var mems := sim.memories.retrieve(npc.id, {"participants": [other_id], "now_abs": sim.now_abs()}, 2)
	for m in mems:
		if (m["participants"] as Array).has(other_id) and m["type"] == "npc_interaction":
			line += " Da última vez, " + _past_tense(str(m["description"]))
			break
	return line + _pick(_voice(npc)["tail"], rng) + " (Somos %s.)" % label


static func _past_tense(desc: String) -> String:
	var d := desc.substr(0, 1).to_lower() + desc.substr(1)
	if d.begins_with("conversou"):
		return "a gente " + d.replace("conversou", "conversou").replace("Conversou", "conversou")
	return d


static func _tags_text(tags: PackedStringArray) -> String:
	var parts := []
	for t in tags:
		parts.append(SocialRules._tag_label(t))
	if parts.is_empty():
		return "um pouco de tudo"
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " e " + parts[-1]


static func gift_reaction(npc: NpcState, item_id: String, result: Dictionary, rng: RandomNumberGenerator) -> String:
	var item := ItemDB.display_name(item_id)
	var tail := _pick(_voice(npc)["tail"], rng)
	if int(result.get("gifts_today", 1)) > 2:
		return "Ah, mais um presente? Obrigad%s, mas você já me deu tanta coisa hoje!" % npc.def.article()
	match result.get("reaction", ""):
		"adorou":
			match npc.id:
				"ravena":
					return "%s? ...Tá bom, admito: eu adorei. Obrigada." % item
				"otavio":
					return "%s! Fascinante... é exatamente o tipo de coisa que eu aprecio. Muito obrigado." % ItemDB.with_article(item_id).capitalize()
				"celeste":
					return "Ai, que graça! %s! Querida, você me conhece tão bem!" % item
			return "Uau, %s! Eu AMEI! Muito obrigad%s!" % [item, npc.def.article()] + tail
		"não gostou":
			if npc.def.gentileza > 0.7:
				return "Ah... %s. Obrigad%s pela intenção, de verdade." % [item.to_lower(), npc.def.article()]
			return "%s? Hmm... não é bem o meu estilo." % item
	return "Que gentil, %s! Obrigad%s." % [ItemDB.with_article(item_id).to_lower(), npc.def.article()] + tail


## Primeira fala quando o morador procura a jogadora por iniciativa própria.
static func initiative_line(npc: NpcState, sim: Simulation, cand: Dictionary, rng: RandomNumberGenerator) -> String:
	var name := sim.player_name
	var tail := _pick(_voice(npc)["tail"], rng)
	match str(cand.get("reason", "")):
		"agradecer_presente":
			return "%s! Queria te agradecer de novo pelo presente (%s). Fiquei pensando nele o dia todo!" % [name, str(cand.get("detail", "")).to_lower()] + tail
		"pedir_ajuda":
			var g := sim.goal_context(npc.id)
			var needs: Array = g.get("needs", [])
			return "Ei, %s! Posso te pedir uma ajudinha? Estou tentando %s e precisaria de %s." % [name, g.get("current_step", "avançar no meu projeto"), " ou ".join(needs.slice(0, 2)).to_lower()] + tail
		"contar_novidade":
			var detail := str(cand.get("detail", ""))
			if cand.get("is_rumor", false):
				return "%s, você ficou sabendo? %s Mas é só o que me contaram, tá?" % [name, detail.substr(detail.find(")") + 2) if detail.begins_with("(") else detail]
			return "%s! Tenho uma novidade: %s" % [name, _lower_first(detail)] + tail
		"convidar":
			return "Oi, %s! Vou passar um tempinho n%s %s. Quer ir comigo?" % [name, Simulation._prep(str(cand.get("detail", ""))), cand.get("detail", "")] + tail
		"pergunta":
			var topics: Array = Array(npc.def.favorite_topics)
			var topic: String = topics[rng.randi() % topics.size()] if not topics.is_empty() else "a ilha"
			return "%s, posso perguntar uma coisa? Você gosta de %s?" % [name, topic] + tail
	return greeting(npc, sim, rng)


## Falas curtas para conversas entre moradores (quando a jogadora está perto).
static func npc_chat_lines(a: NpcState, b: NpcState, kind: String, topic: String, rng: RandomNumberGenerator) -> Array:
	match kind:
		SocialRules.KIND_DISAGREEMENT:
			return ["Sinceramente, não concordo com você.", "Hmm... a gente pensa bem diferente."]
		SocialRules.KIND_RECONCILIATION:
			return ["Desculpa por aquele dia, tá?", "Tudo bem. Já passou."]
		SocialRules.KIND_SHARED:
			return ["Que tarde boa!" + _pick(_voice(a)["tail"], rng), "Vamos repetir isso mais vezes!" + _pick(_voice(b)["tail"], rng)]
	return ["E aí, o que acha de %s?" % topic, "Ah, eu adoro falar disso!" + _pick(_voice(b)["tail"], rng)]
