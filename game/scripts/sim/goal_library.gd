class_name GoalLibrary
extends RefCounted
## Objetivos pessoais em etapas (0.4: adaptados ao Daybloom Residence). Cada
## etapa só avança com acontecimentos reais do simulador — nunca porque o
## modelo de linguagem disse algo ou porque o tempo passou.
##
## Tipos de etapa (conjunto fechado):
##  - trabalho:                 concluir um turno do trabalho do morador
##  - hobby:                    concluir uma atividade de lazer com o hobby indicado
##  - receber_item:             receber da jogadora um item com a tag indicada
##  - atividade_compartilhada:  fazer uma atividade em dupla (no lugar indicado, se houver)
##  - conversar_jogadora:       conversar com a jogadora
##  - visita:                   receber ou fazer uma visita de apartamento até o fim
##  - evento:                   participar de um evento comunitário que aconteceu de verdade
##  - decorar:                  ir até o lugar e executar a ação final (muda o mundo)

const STEP_TYPES := ["trabalho", "hobby", "receber_item", "atividade_compartilhada", "conversar_jogadora", "visita", "evento", "decorar"]

## Objetivos da 0.3 (ilha), guardados como histórico nos saves migrados.
const LEGACY_IDS := ["jardim_florido", "torta_perfeita", "colecao_conchas", "mapa_estelar", "cartas_entregues", "cancoes", "paisagem_perfeita", "colcha"]

const GOALS := {
	"hall_florido": {
		"motivation": "quer que todo mundo seja recebido por flores ao entrar no prédio",
		"steps": [
			{"id": "horta", "label": "cuidar das mudas na horta", "type": "hobby", "hobby": "jardinagem", "count": 2},
			{"id": "flores", "label": "juntar flores e vasos para o hall", "type": "receber_item", "tag": "flor", "count": 2},
			{"id": "opiniao", "label": "pedir a opinião de alguém sobre o arranjo", "type": "conversar_jogadora", "count": 1},
			{"id": "decorar", "label": "decorar o hall com plantas", "type": "decorar", "place": "hall", "activity": "decorando o hall com plantas", "effect": {"decor": "hall_plantas"}, "count": 1},
		],
	},
	"receita_mercadinho": {
		"motivation": "quer criar uma receita tão gostosa que mereça estar no mercadinho",
		"steps": [
			{"id": "testes", "label": "testar receitas no forno", "type": "trabalho", "count": 2},
			{"id": "ingredientes", "label": "conseguir ingredientes especiais", "type": "receber_item", "tag": "ingrediente", "count": 1},
			{"id": "provar", "label": "dar a receita para alguém provar", "type": "visita", "count": 1},
			{"id": "vender", "label": "levar a receita para o mercadinho", "type": "decorar", "place": "mercadinho", "activity": "entregando o pão de mel no mercadinho", "effect": {"unlock": "pao_de_mel"}, "count": 1},
		],
	},
	"aulas_piscina": {
		"motivation": "quer que o prédio inteiro aproveite a piscina com segurança",
		"steps": [
			{"id": "treino", "label": "treinar na piscina", "type": "hobby", "hobby": "natacao", "count": 2},
			{"id": "convidar", "label": "contar a ideia das aulas para alguém", "type": "conversar_jogadora", "count": 1},
			{"id": "nadar_junto", "label": "nadar junto com alguém", "type": "atividade_compartilhada", "place": "piscina", "count": 1},
			{"id": "organizar", "label": "organizar o cantinho das aulas na piscina", "type": "decorar", "place": "piscina", "activity": "organizando as aulas de natação", "effect": {"decor": "piscina_aula"}, "count": 1},
		],
	},
	"observatorio_cobertura": {
		"motivation": "quer transformar a cobertura em um observatório para todos",
		"steps": [
			{"id": "observar", "label": "observar as estrelas da cobertura", "type": "hobby", "hobby": "observar_estrelas", "count": 3},
			{"id": "lampada", "label": "conseguir uma lâmpada para a luz de leitura", "type": "receber_item", "tag": "lampada", "count": 1},
			{"id": "observar_junto", "label": "observar o céu junto com alguém", "type": "atividade_compartilhada", "place": "observatorio", "count": 1},
			{"id": "montar", "label": "montar o observatório da cobertura", "type": "decorar", "place": "observatorio", "activity": "montando o observatório", "effect": {"decor": "observatorio"}, "count": 1},
		],
	},
	"correio_condominio": {
		"motivation": "quer que nenhuma carta do prédio se perca",
		"steps": [
			{"id": "rotas", "label": "fazer as rotas de entrega pelos andares", "type": "trabalho", "count": 3},
			{"id": "ouvir", "label": "ouvir as novidades da nova vizinha", "type": "conversar_jogadora", "count": 1},
			{"id": "organizar", "label": "organizar o correio do hall", "type": "decorar", "place": "hall", "activity": "organizando o correio do hall", "effect": {"decor": "correio_organizado"}, "count": 1},
		],
	},
	"show_evento": {
		"motivation": "quer tocar para o prédio inteiro em uma festa",
		"steps": [
			{"id": "compor", "label": "compor músicas novas", "type": "hobby", "hobby": "musica", "count": 2},
			{"id": "tocar_junto", "label": "ensaiar junto com alguém", "type": "atividade_compartilhada", "count": 1},
			{"id": "percussao", "label": "conseguir uma pedra lisa para a percussão", "type": "receber_item", "tag": "pedra", "count": 1},
			{"id": "show", "label": "tocar em um evento comunitário", "type": "evento", "count": 1},
		],
	},
	"colecao_quadros": {
		"motivation": "quer pintar uma coleção que mostre a alma do prédio",
		"steps": [
			{"id": "pintar", "label": "pintar os quadros da coleção", "type": "hobby", "hobby": "pintura", "count": 3},
			{"id": "tintas", "label": "conseguir tintas novas", "type": "receber_item", "tag": "tinta", "count": 1},
			{"id": "opiniao", "label": "ouvir uma opinião sincera", "type": "conversar_jogadora", "count": 1},
			{"id": "expor", "label": "expor a coleção no térreo", "type": "decorar", "place": "convivencia", "activity": "pendurando os quadros", "effect": {"decor": "hall_quadros"}, "count": 1},
		],
	},
	"tecidos_artesanais": {
		"motivation": "quer deixar as áreas comuns aconchegantes com tecidos feitos à mão",
		"steps": [
			{"id": "costurar", "label": "costurar as primeiras peças", "type": "hobby", "hobby": "costura", "count": 2},
			{"id": "tecido", "label": "conseguir tecidos coloridos", "type": "receber_item", "tag": "tecido", "count": 2},
			{"id": "visita", "label": "receber alguém para uma tarde de costura", "type": "visita", "count": 1},
			{"id": "decorar", "label": "decorar a convivência com os tecidos", "type": "decorar", "place": "convivencia", "activity": "arrumando os tecidos na convivência", "effect": {"decor": "convivencia_tecidos"}, "count": 1},
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
		"atividade_compartilhada", "decorar":
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
