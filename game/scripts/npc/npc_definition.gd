class_name NpcDefinition
extends Resource
## Definição configurável de um morador (identidade, personalidade, gostos e
## rotina). O estado dinâmico fica em NpcState.

@export_group("Identidade")
@export var id: String = ""
@export var display_name: String = ""
@export var species: String = ""
## Forma usada pelo construtor de personagens: coelho, urso, lontra, coruja,
## esquilo, sapo, raposa, ovelha.
@export var body_shape: String = "coelho"
@export var pronoun: String = "ela"
@export var occupation: String = ""
@export var home_id: String = ""
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.WHITE
@export var accent_color: Color = Color.WHITE
@export var height_scale: float = 1.0

@export_group("Personalidade (0 a 1)")
@export_range(0.0, 1.0) var sociabilidade: float = 0.5
@export_range(0.0, 1.0) var gentileza: float = 0.5
@export_range(0.0, 1.0) var curiosidade: float = 0.5
@export_range(0.0, 1.0) var coragem: float = 0.5
@export_range(0.0, 1.0) var energia: float = 0.5
@export var personality_summary: String = ""
@export var speech_style: String = ""
@export var catchphrase: String = ""

@export_group("Conversa (0.3)")
## Palavras e expressões típicas do jeito de falar.
@export var vocabulary: PackedStringArray = []
@export var temperament: String = ""
@export var values: PackedStringArray = []
@export var favorite_topics: PackedStringArray = []
@export var disliked_topics: PackedStringArray = []
@export var long_term_goals: PackedStringArray = []
## O que o morador não faz ou não aceita socialmente.
@export var social_limits: String = ""
@export var characteristic_reactions: String = ""
@export var friendship_style: String = ""
## Nomes pelos quais os outros se referem a este morador (para detectar menções).
@export var aliases: PackedStringArray = []

@export_group("Preferências")
## IDs ou tags de itens (ver ItemDB): "flor", "concha", "pessego"...
@export var likes: PackedStringArray = []
@export var dislikes: PackedStringArray = []
## Tópicos de conversa e hobbies (ids de atividade, ver Places.HOBBY_SPOTS).
@export var hobbies: PackedStringArray = []
@export var favorite_place: String = "praca"
@export var work_place: String = "praca"
@export var work_activity: String = "trabalhando"

@export_group("Vida pessoal")
@export var personal_goal: String = ""
@export var personal_goal_id: String = ""
@export var wake_hour: float = 7.0
@export var sleep_hour: float = 22.0
@export var work_start_hour: float = 9.0
@export var work_end_hour: float = 14.0


func traits() -> Dictionary:
	return {
		"sociabilidade": sociabilidade,
		"gentileza": gentileza,
		"curiosidade": curiosidade,
		"coragem": coragem,
		"energia": energia,
	}


## O morador gosta (1), não gosta (-1) ou é indiferente (0) a um item.
func preference_for(item_id: String) -> int:
	var item_tags := ItemDB.tags(item_id)
	for tag in item_tags:
		if dislikes.has(tag):
			return -1
	for tag in item_tags:
		if likes.has(tag):
			return 1
	return 0


func article() -> String:
	return "a" if pronoun == "ela" else "o"
