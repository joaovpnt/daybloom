class_name GoalLibrary
extends RefCounted
## Objetivos pessoais em etapas (0.3). Cada etapa só avança com acontecimentos
## reais do simulador — nunca porque o modelo de linguagem disse algo.
##
## Tipos de etapa (conjunto fechado):
##  - trabalho:                 concluir o trabalho do dia (no local de trabalho)
##  - hobby:                    concluir uma atividade de lazer com o hobby indicado
##  - receber_item:             receber da jogadora um item com a tag indicada
##  - atividade_compartilhada:  fazer uma atividade em dupla (no lugar indicado, se houver)
##  - conversar_jogadora:       conversar com a jogadora (contar, pedir opinião)

const STEP_TYPES := ["trabalho", "hobby", "receber_item", "atividade_compartilhada", "conversar_jogadora"]

const GOALS := {
	"jardim_florido": {
		"motivation": "quer que o jardim comunitário seja o lugar mais alegre da ilha",
		"steps": [
			{"id": "canteiros", "label": "preparar os canteiros do jardim", "type": "trabalho", "count": 2},
			{"id": "flores", "label": "juntar flores para plantar", "type": "receber_item", "tag": "flor", "count": 3},
			{"id": "regar_junto", "label": "regar o jardim junto com alguém", "type": "atividade_compartilhada", "place": "jardim", "count": 1},
			{"id": "plantar", "label": "plantar as flores novas", "type": "hobby", "hobby": "jardinagem", "count": 2},
		],
	},
	"torta_perfeita": {
		"motivation": "quer fazer uma torta que deixe todo mundo feliz",
		"steps": [
			{"id": "massa", "label": "testar receitas de massa", "type": "trabalho", "count": 2},
			{"id": "pessegos", "label": "conseguir pêssegos maduros", "type": "receber_item", "tag": "pessego", "count": 2},
			{"id": "provar", "label": "dar um pedaço para alguém provar", "type": "atividade_compartilhada", "place": "quiosque", "count": 1},
			{"id": "assar", "label": "assar a torta final", "type": "hobby", "hobby": "culinaria", "count": 1},
		],
	},
	"colecao_conchas": {
		"motivation": "quer provar que conhece cada cantinho da praia",
		"steps": [
			{"id": "procurar", "label": "procurar conchas na praia", "type": "hobby", "hobby": "colecionar_conchas", "count": 2},
			{"id": "conchas", "label": "conseguir conchas rosadas", "type": "receber_item", "tag": "concha", "count": 2},
			{"id": "rara", "label": "encontrar uma peça rara", "type": "receber_item", "tag": "raro", "count": 1},
			{"id": "mostrar", "label": "mostrar a coleção para alguém", "type": "atividade_compartilhada", "count": 1},
		],
	},
	"mapa_estelar": {
		"motivation": "quer entender o céu da ilha e registrar tudo",
		"steps": [
			{"id": "observar", "label": "observar as estrelas do mirante", "type": "hobby", "hobby": "observar_estrelas", "count": 3},
			{"id": "estudar", "label": "estudar os livros da estante", "type": "trabalho", "count": 2},
			{"id": "contar", "label": "contar as descobertas para alguém", "type": "conversar_jogadora", "count": 1},
		],
	},
	"cartas_entregues": {
		"motivation": "quer que ninguém na ilha fique sem notícias",
		"steps": [
			{"id": "rotas", "label": "fazer as rotas de entrega", "type": "trabalho", "count": 3},
			{"id": "ouvir", "label": "saber as novidades da nova moradora", "type": "conversar_jogadora", "count": 1},
			{"id": "entregar_junto", "label": "entregar recados junto com alguém", "type": "atividade_compartilhada", "count": 1},
			{"id": "ultima_rota", "label": "terminar a última rota", "type": "trabalho", "count": 1},
		],
	},
	"cancoes": {
		"motivation": "quer que cada morador tenha uma música que combine com ele",
		"steps": [
			{"id": "compor", "label": "compor melodias no coreto", "type": "hobby", "hobby": "musica", "count": 2},
			{"id": "tocar_junto", "label": "tocar uma música com alguém no coreto", "type": "atividade_compartilhada", "place": "coreto", "count": 1},
			{"id": "percussao", "label": "conseguir uma pedra lisa para a percussão", "type": "receber_item", "tag": "pedra", "count": 1},
			{"id": "ensaiar", "label": "ensaiar a canção final", "type": "hobby", "hobby": "musica", "count": 1},
		],
	},
	"paisagem_perfeita": {
		"motivation": "quer capturar a luz exata do entardecer da ilha",
		"steps": [
			{"id": "esbocos", "label": "fazer esboços no mirante", "type": "hobby", "hobby": "pintura", "count": 2},
			{"id": "cor", "label": "conseguir uma flor vermelha como referência de cor", "type": "receber_item", "tag": "flor_vermelha", "count": 1},
			{"id": "opiniao", "label": "ouvir uma opinião sincera", "type": "conversar_jogadora", "count": 1},
			{"id": "pintar", "label": "pintar a versão final", "type": "trabalho", "count": 2},
		],
	},
	"colcha": {
		"motivation": "quer uma colcha que guarde um pedacinho de cada vizinho",
		"steps": [
			{"id": "retalhos", "label": "costurar os primeiros retalhos", "type": "hobby", "hobby": "costura", "count": 2},
			{"id": "tingir", "label": "conseguir flores para tingir os retalhos", "type": "receber_item", "tag": "flor", "count": 2},
			{"id": "costurar_junto", "label": "passar uma tarde de costura com alguém", "type": "atividade_compartilhada", "count": 1},
			{"id": "arremate", "label": "fazer o arremate final", "type": "hobby", "hobby": "costura", "count": 1},
		],
	},
}


static func has_goal(goal_id: String) -> bool:
	return GOALS.has(goal_id)


static func steps(goal_id: String) -> Array:
	return GOALS.get(goal_id, {}).get("steps", [])


static func step_at(goal_id: String, index: int) -> Dictionary:
	var s := steps(goal_id)
	return s[index] if index >= 0 and index < s.size() else {}


## A etapa aceita este acontecimento?
static func matches(step: Dictionary, event_type: String, params: Dictionary) -> bool:
	if step.is_empty() or step.get("type", "") != event_type:
		return false
	match event_type:
		"hobby":
			return str(params.get("hobby", "")) == str(step.get("hobby", ""))
		"receber_item":
			return ItemDB.tags(str(params.get("item_id", ""))).has(step.get("tag", ""))
		"atividade_compartilhada":
			return not step.has("place") or str(params.get("place", "")) == str(step["place"])
	return true


## Itens que fazem a etapa avançar (para pedir ajuda à jogadora).
static func items_for(step: Dictionary) -> Array:
	if step.get("type", "") != "receber_item":
		return []
	var out := []
	for item_id in ItemDB.ITEMS:
		if ItemDB.tags(item_id).has(step.get("tag", "")):
			out.append(item_id)
	return out
