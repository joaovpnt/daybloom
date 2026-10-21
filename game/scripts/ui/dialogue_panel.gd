class_name DialoguePanel
extends PanelContainer
## Conversa com um morador: retrato, humor e relação à esquerda; mensagens,
## indicador de resposta e campo de texto à direita. Respostas vêm do Ollama
## (quando disponível) ou dos diálogos contextualizados, sem congelar o jogo.

signal closed()
signal gift_requested()

const LLM_TIMEOUT := 32.0

var npc_id: String = ""
var portrait: PortraitFrame
var header: Label
var subheader: Label
var mood_holder: HBoxContainer
var hearts: Label
var log_text: RichTextLabel
var log_scroll: ScrollContainer
var input: LineEdit
var send_button: Button
var gift_button: Button
var thinking_label: Label
var typing: TypingDots
var cancel_button: Button
var mode_chip: Label
var emotion_chip_holder: HBoxContainer
var last_emotion: String = ""
var last_response: Dictionary = {}
var current_initiative: Dictionary = {}
var history: Array = []
var waiting_exchange: String = ""
var rng := RandomNumberGenerator.new()
var last_source: String = ""


func _ready() -> void:
	theme = UiTheme.make()
	rng.randomize()
	custom_minimum_size = Vector2(1000, 330)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.SPACE_L)
	add_child(h)
	# Coluna do morador
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	var pc := CenterContainer.new()
	left.add_child(pc)
	portrait = PortraitFrame.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	pc.add_child(portrait)
	header = UiTheme.title("", 26)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(header)
	subheader = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(subheader)
	mood_holder = HBoxContainer.new()
	mood_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	mood_holder.add_theme_constant_override("separation", 6)
	left.add_child(mood_holder)
	hearts = UiTheme.hearts_label(0.0, 20)
	hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(hearts)
	emotion_chip_holder = HBoxContainer.new()
	emotion_chip_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(emotion_chip_holder)
	# Coluna da conversa
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", UiTheme.SPACE_S)
	h.add_child(right)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, 18, UiTheme.LINE, 2, false, 12))
	bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(bubble)
	log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(0, 190)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bubble.add_child(log_scroll)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.fit_content = true
	log_text.scroll_following = true
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.add_theme_font_size_override("normal_font_size", 19)
	log_text.add_theme_font_size_override("bold_font_size", 19)
	log_text.add_theme_constant_override("line_separation", 4)
	log_scroll.add_child(log_text)
	log_text.finished.connect(_scroll_end)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	right.add_child(status)
	typing = TypingDots.new()
	typing.custom_minimum_size = Vector2(46, 20)
	typing.visible = false
	status.add_child(typing)
	thinking_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	thinking_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(thinking_label)
	cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.flat = true
	cancel_button.visible = false
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_button.add_theme_color_override("font_color", UiTheme.CORAL_DARK)
	cancel_button.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	cancel_button.pressed.connect(cancel_request)
	status.add_child(cancel_button)
	mode_chip = UiTheme.label("", 13, UiTheme.INK_FAINT, true)
	mode_chip.tooltip_text = "As respostas usam os diálogos clássicos do jogo (IA local indisponível)."
	status.add_child(mode_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_S)
	right.add_child(row)
	input = LineEdit.new()
	input.placeholder_text = "Escreva uma mensagem e aperte Enter..."
	input.max_length = 300
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(_t): _on_send())
	row.add_child(input)
	send_button = UiTheme.button("Enviar")
	send_button.pressed.connect(_on_send)
	row.add_child(send_button)
	gift_button = UiTheme.button("Dar presente", "gold")
	gift_button.pressed.connect(func(): gift_requested.emit())
	row.add_child(gift_button)
	var bye := UiTheme.secondary_button("Tchau")
	bye.pressed.connect(close_panel)
	row.add_child(bye)
	visible = false


func _scroll_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func open(p_npc_id: String, initiative: Dictionary = {}) -> void:
	npc_id = p_npc_id
	history.clear()
	waiting_exchange = ""
	thinking_label.text = ""
	typing.visible = false
	cancel_button.visible = false
	log_text.text = ""
	last_emotion = ""
	for c in emotion_chip_holder.get_children():
		c.queue_free()
	current_initiative = initiative
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	portrait.npc_id = npc_id
	sim.register_player_talk(npc_id)
	_set_mode(ApiClient.last_health.get("ollama", false))
	_refresh_header()
	visible = true
	if initiative.is_empty():
		_append_npc(FallbackDialogue.greeting(npc, sim, rng))
	else:
		_open_with_initiative(npc, initiative)
	UiTheme.place(self, Control.PRESET_CENTER_BOTTOM, 24)
	UiTheme.pop_in(self, 0.98)
	input.editable = true
	send_button.disabled = false
	input.grab_focus()


func _refresh_header() -> void:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
	header.text = npc.display_name()
	subheader.text = "%s · %s" % [npc.def.species.capitalize(), npc.def.occupation]
	for c in mood_holder.get_children():
		c.queue_free()
	# A reação do momento (validada) substitui o humor geral no chip, para não
	# mostrar estados contraditórios ("radiante" e "triste" ao mesmo tempo).
	var base: String = EMOTION_LABELS.get(last_emotion, "")
	if base != "":
		var lbl := base if base.ends_with("e") else base + npc.def.article()
		mood_holder.add_child(UiTheme.chip(lbl.capitalize(), EMOTION_COLORS.get(last_emotion, UiTheme.SKY)))
	else:
		mood_holder.add_child(UiTheme.chip(npc.mood.capitalize(), UiTheme.mood_color(npc.mood)))
	mood_holder.add_child(UiTheme.chip(RelationshipSystem.label_for(float(rel["affinity"])).capitalize(), UiTheme.CORAL))
	hearts.text = UiTheme.hearts_text(float(rel["affinity"]))
	hearts.tooltip_text = "Afinidade %.0f · Confiança %.0f" % [float(rel["affinity"]), float(rel["trust"])]


func _append_npc(text: String, source: String = "") -> void:
	var npc: NpcState = GameState.sim.npcs[npc_id]
	var color := npc.def.primary_color.darkened(0.5).to_html(false)
	log_text.append_text("[b][color=#%s]%s[/color][/b]  %s\n" % [color, npc.display_name(), _escape(text)])
	history.append({"role": "morador", "text": text})
	_trim_history()
	last_source = source


func _append_player(text: String) -> void:
	log_text.append_text("[b][color=#c0604f]%s[/color][/b]  %s\n" % [GameState.sim.player_name, _escape(text)])
	history.append({"role": "jogadora", "text": text})
	_trim_history()


func _trim_history() -> void:
	while history.size() > 8:
		history.pop_front()


static func _escape(t: String) -> String:
	return t.replace("[", "[lb]")


func _on_send() -> void:
	var text := input.text.strip_edges()
	if text == "" or waiting_exchange != "":
		return
	input.text = ""
	_append_player(text)
	await respond_to(text)


## Obtém a resposta do morador (modelo de linguagem ou diálogos clássicos).
## A interface nunca trava: a resposta chega de forma assíncrona e pode ser
## cancelada; respostas atrasadas de trocas antigas são descartadas.
func respond_to(text: String) -> void:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var exchange := "%s_%d_%d" % [npc_id, Time.get_ticks_msec(), rng.randi() % 100000]
	waiting_exchange = exchange
	input.editable = false
	send_button.disabled = true
	var reply := ""
	var source := "fallback"
	var data: Dictionary = {}
	var use_llm: bool = ApiClient.last_health.get("ollama", false)
	if use_llm:
		typing.visible = true
		cancel_button.visible = true
		thinking_label.text = "%s está pensando..." % npc.display_name()
		var hist := history.slice(0, history.size() - 1)
		var body := {
			"exchange_id": exchange,
			"save_slot_id": GameState.save_slot_id,
			"island_id": GameState.island_id,
			"player_id": sim.player_id,
			"npc_id": npc_id,
			"message": text,
			"context": ContextBuilder.build(npc, sim, text, hist),
			"history": hist.slice(max(0, hist.size() - 6)),
		}
		var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/dialogue", body, LLM_TIMEOUT + 20.0)
		if waiting_exchange != exchange or not visible:
			return  # cancelada ou conversa encerrada: descarta a resposta atrasada
		if res["ok"] and res["data"].get("source", "") == "ollama" and str(res["data"].get("reply", "")) != "":
			data = res["data"]
			reply = str(data["reply"])
			source = "ollama"
		elif res["ok"]:
			data = res["data"]
	if reply == "":
		reply = FallbackDialogue.respond(npc, sim, text, rng)["text"]
	_finish_reply(text, reply, source, data, use_llm)
	if FallbackDialogue.detect_intent(text, npc_id)["intent"] == "bye" and is_inside_tree():
		await get_tree().create_timer(1.2).timeout
		if visible and waiting_exchange == "":
			close_panel()


func _finish_reply(player_text: String, reply: String, source: String, data: Dictionary, tried_llm: bool) -> void:
	var sim := GameState.sim
	waiting_exchange = ""
	typing.visible = false
	cancel_button.visible = false
	last_response = data
	if source == "ollama":
		thinking_label.text = ""
		_apply_validated(data, player_text)
	else:
		var reason := str(data.get("reason", ""))
		thinking_label.text = _friendly_reason(reason) if tried_llm else ""
	_set_mode(source == "ollama" or (ApiClient.last_health.get("ollama", false) and not tried_llm))
	_append_npc(reply, source)
	_remember_exchange(player_text)
	_refresh_header()
	input.editable = true
	send_button.disabled = false
	if is_inside_tree():
		input.grab_focus()


## Aplica só o que foi validado: emoção (visual + leve efeito no humor),
## memórias citadas (reforço) e ação autorizada pelo simulador.
func _apply_validated(data: Dictionary, player_text: String) -> void:
	var sim := GameState.sim
	var emotion := str(data.get("emotion", "neutra"))
	sim.apply_ai_emotion(npc_id, emotion)
	EventBus.npc_reaction.emit(npc_id, "emotion_" + emotion)
	_show_emotion(emotion)
	var mem_ids: Array = data.get("memory_ids", [])
	if not mem_ids.is_empty():
		sim.memories.recall(npc_id, mem_ids)
	var action = data.get("action")
	if action != null and str(action) != "":
		var result := sim.apply_ai_action(npc_id, str(action), data.get("action_params", {}), player_text)
		if result.get("applied", false) and str(result.get("effect", "")) != "":
			log_text.append_text("[i][color=#8a7562]%s[/color][/i]\n" % _escape(str(result["effect"])))


## Memória recente da conversa (para continuidade em outra visita).
func _remember_exchange(player_text: String) -> void:
	var clean := player_text.strip_edges().replace("\n", " ")
	if clean.length() < 12:
		return
	var sim := GameState.sim
	sim.memories.add_memory(npc_id, "player_conversation", [npc_id, sim.player_id], "%s disse: «%s»" % [sim.player_name, clean.substr(0, 140)], 0.3, [], "conversa_%d" % sim.day, sim.time_dict(), "conversa|%s|%d" % [sim.player_id, sim.day], {"origin": "jogadora"})


func cancel_request() -> void:
	if waiting_exchange == "":
		return
	var exchange := waiting_exchange
	ApiClient.cancel_ai(exchange)
	waiting_exchange = ""
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var last_player := ""
	for i in range(history.size() - 1, -1, -1):
		if history[i]["role"] == "jogadora":
			last_player = history[i]["text"]
			break
	var reply: String = FallbackDialogue.respond(npc, sim, last_player, rng)["text"]
	_finish_reply(last_player, reply, "fallback", {"reason": "cancelada"}, true)


func _open_with_initiative(npc: NpcState, cand: Dictionary) -> void:
	var sim := GameState.sim
	var line := FallbackDialogue.initiative_line(npc, sim, cand, rng)
	if ApiClient.last_health.get("ollama", false):
		var exchange := "ini_%s_%d" % [npc_id, Time.get_ticks_msec()]
		waiting_exchange = exchange
		typing.visible = true
		cancel_button.visible = true
		input.editable = false
		thinking_label.text = "%s está pensando..." % npc.display_name()
		var body := {"exchange_id": exchange, "npc_id": npc_id, "reason": cand.get("reason", "pergunta"),
			"detail": str(cand.get("detail", "")).substr(0, 190), "context": ContextBuilder.build(npc, sim, str(cand.get("detail", "")))}
		var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/ai/initiative", body, 45.0)
		if waiting_exchange != exchange or not visible:
			return
		typing.visible = false
		cancel_button.visible = false
		input.editable = true
		waiting_exchange = ""
		thinking_label.text = ""
		if res["ok"] and res["data"].get("source", "") == "ollama":
			line = str(res["data"]["reply"])
			var emotion := str(res["data"].get("emotion", "alegre"))
			EventBus.npc_reaction.emit(npc_id, "emotion_" + emotion)
			_show_emotion(emotion)
	_append_npc(line)
	input.grab_focus()


func _friendly_reason(reason: String) -> String:
	match reason:
		"timeout":
			return "A resposta demorou demais; usei um diálogo clássico."
		"cancelada":
			return "Pedido cancelado; usei um diálogo clássico."
		"ollama_desativado", "indisponivel", "modelo_indisponivel":
			return "IA local indisponível; usando diálogos clássicos."
		"":
			return "Backend indisponível; usando diálogos clássicos."
	return "Para não inventar nada, usei um diálogo clássico."


func _set_mode(llm: bool) -> void:
	mode_chip.text = "" if llm else "diálogo clássico"


const EMOTION_LABELS := {"alegre": "alegre", "animada": "animad", "triste": "triste", "surpresa": "surpres",
	"pensativa": "pensativ", "envergonhada": "envergonhad", "irritada": "irritad", "neutra": ""}
const EMOTION_COLORS := {"alegre": Color("f6c25b"), "animada": Color("f6c25b"), "triste": Color("7fb8e6"),
	"surpresa": Color("f0a35c"), "pensativa": Color("b49be0"), "envergonhada": Color("e58fb0"), "irritada": Color("e07b62")}


func _show_emotion(emotion: String) -> void:
	last_emotion = emotion
	for c in emotion_chip_holder.get_children():
		c.queue_free()
	if EMOTION_LABELS.get(emotion, "") == "":
		return
	var hint := UiTheme.label("reação do momento", 12, UiTheme.INK_FAINT, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emotion_chip_holder.add_child(hint)
	_refresh_header()


func give_item(item_id: String) -> Dictionary:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var result := sim.give_gift(npc_id, item_id, GameState.inventory)
	if result["ok"]:
		log_text.append_text("[i][color=#8a7562]Você entregou %s.[/color][/i]\n" % ItemDB.with_article(item_id).to_lower())
		_append_npc(FallbackDialogue.gift_reaction(npc, item_id, result, rng))
		var reaction_kind := "gift_liked"
		if result["reaction"] == "adorou":
			reaction_kind = "gift_loved"
		elif result["reaction"] == "não gostou":
			reaction_kind = "gift_disliked"
		EventBus.npc_reaction.emit(npc_id, reaction_kind)
		var delta: float = result["affinity_delta"]
		if delta != 0.0:
			EventBus.toast_requested.emit("%s: afinidade %+.0f" % [npc.display_name(), delta])
		if result.get("request_fulfilled", false):
			log_text.append_text("[i][color=#4e9e5d]Era exatamente o que %s tinha pedido![/color][/i]\n" % npc.display_name())
		if result.get("learned_like", false):
			log_text.append_text("[i][color=#8a7562]%s passou a gostar de %s.[/color][/i]\n" % [npc.display_name(), ItemDB.display_name(item_id).to_lower()])
		var goal: Dictionary = result.get("goal", {})
		if goal.get("advanced", false):
			log_text.append_text("[i][color=#8a7562]Isso ajudou %s no objetivo: %s.[/color][/i]\n" % [npc.display_name(), goal.get("step_label", "")])
	else:
		_append_npc("Hmm... (%s)" % result["reason"])
	_refresh_header()
	return result


func close_panel() -> void:
	if visible:
		if waiting_exchange != "":
			ApiClient.cancel_ai(waiting_exchange)
		visible = false
		waiting_exchange = ""
		closed.emit()


class TypingDots:
	extends Control

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for i in range(3):
			var y := size.y * 0.5 - absf(sin(t * 5.0 - i * 0.6)) * 5.0
			draw_circle(Vector2(8 + i * 14, y), 5.0, UiTheme.INK_FAINT)
