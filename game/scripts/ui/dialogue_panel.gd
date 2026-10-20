class_name DialoguePanel
extends PanelContainer
## Conversa com um morador: mensagens livres da jogadora, respostas pelo
## Ollama (quando disponível) ou pelos diálogos contextualizados. Nunca congela
## o jogo: a espera pelo modelo é assíncrona.

signal closed()
signal gift_requested()

const LLM_TIMEOUT := 32.0

var npc_id: String = ""
var log_text: RichTextLabel
var input: LineEdit
var send_button: Button
var gift_button: Button
var header: Label
var subheader: Label
var thinking_label: Label
var history: Array = []
var waiting_exchange: String = ""
var rng := RandomNumberGenerator.new()
var last_source: String = ""


func _ready() -> void:
	theme = UiTheme.make()
	rng.randomize()
	custom_minimum_size = Vector2(860, 380)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	header = UiTheme.label("", 28)
	tv.add_child(header)
	subheader = UiTheme.label("", 16, UiTheme.INK_SOFT)
	tv.add_child(subheader)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.fit_content = true
	log_text.scroll_following = true
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.add_theme_font_size_override("normal_font_size", 19)
	log_text.add_theme_font_size_override("bold_font_size", 19)
	scroll.add_child(log_text)
	log_text.finished.connect(func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value))
	thinking_label = UiTheme.label("", 16, UiTheme.INK_SOFT)
	v.add_child(thinking_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	input = LineEdit.new()
	input.placeholder_text = "Escreva uma mensagem e aperte Enter..."
	input.max_length = 300
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(t): _on_send())
	row.add_child(input)
	send_button = UiTheme.button("Enviar")
	send_button.pressed.connect(_on_send)
	row.add_child(send_button)
	gift_button = UiTheme.button("Dar presente", UiTheme.GOLD.darkened(0.1))
	gift_button.pressed.connect(func(): gift_requested.emit())
	row.add_child(gift_button)
	var bye := UiTheme.button("Tchau", UiTheme.CORAL)
	bye.pressed.connect(close_panel)
	row.add_child(bye)
	visible = false


func open(p_npc_id: String) -> void:
	npc_id = p_npc_id
	history.clear()
	waiting_exchange = ""
	thinking_label.text = ""
	log_text.text = ""
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var greeting := FallbackDialogue.greeting(npc, sim, rng)
	sim.register_player_talk(npc_id)
	_refresh_header()
	_append_npc(greeting)
	visible = true
	UiTheme.place(self, Control.PRESET_CENTER_BOTTOM, 24)
	input.editable = true
	send_button.disabled = false
	input.grab_focus()


func _refresh_header() -> void:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
	header.text = "%s · %s" % [npc.display_name(), npc.def.occupation]
	subheader.text = "Humor: %s · Relação: %s (afinidade %.0f, confiança %.0f)" % [npc.mood, RelationshipSystem.label_for(float(rel["affinity"])), float(rel["affinity"]), float(rel["trust"])]


func _append_npc(text: String, source: String = "") -> void:
	var npc: NpcState = GameState.sim.npcs[npc_id]
	var color := npc.def.primary_color.darkened(0.45).to_html(false)
	log_text.append_text("[b][color=#%s]%s:[/color][/b] %s\n" % [color, npc.display_name(), _escape(text)])
	history.append({"role": "morador", "text": text})
	_trim_history()
	last_source = source


func _append_player(text: String) -> void:
	log_text.append_text("[b][color=#c0604f]%s:[/color][/b] %s\n" % [GameState.sim.player_name, _escape(text)])
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


## Obtém a resposta do morador (modelo de linguagem ou fallback).
func respond_to(text: String) -> void:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var exchange := "%s_%d_%d" % [npc_id, Time.get_ticks_msec(), rng.randi() % 100000]
	waiting_exchange = exchange
	input.editable = false
	send_button.disabled = true
	var reply := ""
	var source := "fallback"
	var use_llm: bool = ApiClient.last_health.get("ollama", false)
	if use_llm:
		thinking_label.text = "%s está pensando..." % npc.display_name()
		var hist := history.slice(0, history.size() - 1)
		var body := {
			"exchange_id": exchange,
			"save_slot_id": GameState.save_slot_id,
			"island_id": GameState.island_id,
			"player_id": sim.player_id,
			"npc_id": npc_id,
			"message": text,
			"context": DialogueContext.build(npc, sim, text),
			"history": hist.slice(max(0, hist.size() - 6)),
		}
		var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/dialogue", body, LLM_TIMEOUT)
		if waiting_exchange != exchange or not visible:
			return  # conversa encerrada enquanto esperava
		if res["ok"] and res["data"].get("source", "") == "ollama" and str(res["data"].get("reply", "")) != "":
			reply = str(res["data"]["reply"])
			source = "ollama"
			var action := str(res["data"].get("suggested_action", "nenhuma"))
			if action != "nenhuma":
				sim.apply_suggested_action(npc_id, action, text)
	if reply == "":
		reply = FallbackDialogue.respond(npc, sim, text, rng)["text"]
	waiting_exchange = ""
	thinking_label.text = "" if source == "ollama" else "(diálogo clássico — Ollama indisponível)" if use_llm else ""
	_append_npc(reply, source)
	_refresh_header()
	input.editable = true
	send_button.disabled = false
	input.grab_focus()
	if FallbackDialogue.detect_intent(text, npc_id)["intent"] == "bye":
		await get_tree().create_timer(1.2).timeout
		if visible and waiting_exchange == "":
			close_panel()


func give_item(item_id: String) -> Dictionary:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var result := sim.give_gift(npc_id, item_id, GameState.inventory)
	if result["ok"]:
		log_text.append_text("[i]Você entregou %s.[/i]\n" % ItemDB.with_article(item_id).to_lower())
		_append_npc(FallbackDialogue.gift_reaction(npc, item_id, result, rng))
		var delta: float = result["affinity_delta"]
		if delta != 0.0:
			EventBus.toast_requested.emit("%s: afinidade %+.0f" % [npc.display_name(), delta])
	else:
		_append_npc("Hmm... (%s)" % result["reason"])
	_refresh_header()
	return result


func close_panel() -> void:
	if visible:
		visible = false
		waiting_exchange = ""
		closed.emit()
