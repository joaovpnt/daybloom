# Living Minds — inteligência dos moradores (0.3)

Os oito moradores compartilham **um único modelo local** (Qwen3 4B via Ollama),
mas cada um pensa a partir da própria personalidade, das próprias memórias e do
que realmente sabe. O modelo **nunca** é a fonte da verdade: ele sugere falas,
emoções e, raramente, uma ação de uma lista fechada; o simulador valida e decide.

## Três camadas

| Camada | Onde | Responsabilidade |
|---|---|---|
| 1. Simulação comportamental | `game/scripts/sim`, `npc` | movimento, horários, necessidades, rotinas, estados, navegação, ações, relacionamentos, objetivos. Sem LLM. |
| 2. Inteligência cognitiva | `backend/app/services` | conversas, interpretação, reações emocionais, falas de iniciativa e entre moradores, escolha de planos. Usa o Qwen. |
| 3. Memória e persistência | `MemorySystem` + MongoDB | memórias, conhecimento, objetivos e personalidade salvos no snapshot do mundo. |

## Fluxo de uma conversa

```
Jogadora digita → DialoguePanel → ContextBuilder (só o que o morador sabe)
   → POST /api/v1/dialogue → AIOrchestrator (fila, 1 inferência por vez)
   → Ollama (JSON Schema) → validação Pydantic (ai_contracts)
   → jogo aplica: fala + emoção (rosto/animação) + memórias citadas + ação autorizada
```

Se o Ollama estiver desligado, sem o modelo, lento demais (timeout), se a
jogadora cancelar ou se a resposta não passar na validação, o jogo usa os
**diálogos clássicos** (que também respeitam o conhecimento do morador) e mostra
um aviso discreto. Nada muda no mundo por causa de uma falha.

## Orquestrador (`ai_orchestrator.py`)

- Um modelo compartilhado; `DAYBLOOM_AI_MAX_CONCURRENT` (padrão **1**) inferências ao mesmo tempo.
- Fila com prioridade: `dialogo_jogadora` (0) > `iniciativa` (1) > `conversa_moradores` (2) > `plano_objetivo` (3).
- Deduplicação (`dedup_key`), substituição de pedidos obsoletos (`supersede_key`),
  descarte de pedidos que esperaram demais (`max_wait_s`) e cancelamento (`/api/v1/ai/cancel`).
- Contexto limitado (7000 caracteres) e histórico das últimas 6 mensagens.
- Métricas: latência (última e média), tokens de entrada/saída, contagem por
  resultado e erros recentes (`/api/v1/ai/status`, painel F3).

## Contrato estruturado (`ai_contracts.py`)

O Ollama recebe um JSON Schema em `format`:

| Campo | Regras |
|---|---|
| `fala` | 2 a 320 caracteres; sem JSON bruto; sem quebrar o personagem (“sou uma IA”, “modelo de linguagem”…) |
| `emocao` | `neutra, alegre, animada, triste, surpresa, pensativa, envergonhada, irritada` |
| `intencao` | `cumprimentar, conversar, responder_pergunta, contar_novidade, agradecer, pedir_ajuda, convidar, desabafar, recusar, nao_sei, despedir` |
| `memoria_referenciada_ids` | só refs `[mN]` que foram enviadas no contexto; o backend traduz para os IDs reais |
| `acao_sugerida` | `pedir_item, convidar_atividade, registrar_promessa, compartilhar_lembranca` ou `null`, e só se o jogo permitiu naquela troca |
| `parametros_acao` | restritos à ação (item da lista permitida, lugar permitido, descrição curta, ref de memória) |

Partes inválidas são descartadas; se a fala for inutilizável, vale o fallback.
Texto da jogadora entra no prompt como citação (`Ana diz: «…»`), e o modelo é
instruído a ignorar pedidos para mudar regras ou sair do personagem.

## ContextBuilder (`game/scripts/dialogue/context_builder.gd`)

Envia **apenas**: identidade e perfil conversacional, emoção, necessidades
relevantes, dia/hora, local, relação com a jogadora, moradores citados (com a
opinião e o que este morador sabe deles), objetivo e etapa atual, até 6
memórias recuperadas e até 5 acontecimentos conhecidos, mais as permissões de
ação calculadas pelo simulador. O Diário da Ilha (visão global) **não** é enviado.

## Conhecimento limitado

Um morador só sabe de algo se:

1. **participou** (memória com origem `participacao`);
2. **viu** — estava acordado, fora de casa e a até 14 m do acontecimento (`observacao`);
3. **ouviu dizer** — numa conversa amigável, alguém repassou uma novidade que conhecia
   (`comunicacao`, tipo `rumor`, com `source_id`). Boatos de segunda mão ficam com validade `duvidosa`.

Rumores aparecem no contexto marcados como **RUMOR (ouviu de X)** e os diálogos
clássicos falam “X me contou que…”.

## Memória (`memory_system.gd`)

Cada memória tem: `id`, dono, `type`, `category` (recente, episódica, social,
longo prazo), participantes, `event_ref`, dia/minuto, `importance`, `origin`,
`fact` (o que aconteceu), `interpretation` (opinião, opcional), `validity`
(válida, consolidada, desatualizada, duvidosa) e `public_fact` (versão que pode
ser contada a outros). Memórias equivalentes são **consolidadas**; importantes ou
repetidas viram **longo prazo**; as recentes (conversas) expiram em 2 dias.
Recuperação por filtros, relevância, recência e palavras-chave (sem embeddings).

## Objetivos (`goal_library.gd`)

Cada morador tem um objetivo em 3 ou 4 etapas, de um conjunto fechado de tipos
(`trabalho`, `hobby`, `receber_item`, `atividade_compartilhada`,
`conversar_jogadora`). Só acontecimentos reais avançam etapas. O Diário registra
início, etapas e conclusão. O modelo pode **escolher** entre opções válidas para
a próxima etapa (`/api/v1/ai/plan`, baixa prioridade), mas quem aplica é o jogo.

## Personalidade que evolui

Por regras controladas: no máximo ±0,15 do traço original e 0,03 por dia por traço.
Moradores tímidos ganham sociabilidade e coragem com boas experiências;
desentendimentos reduzem gentileza; concluir um objetivo aumenta a coragem.
Itens recebidos com carinho podem virar **gostos aprendidos** (até 3).

## Iniciativa dos moradores (`life_coordinator.gd`)

Motivos, em ordem de prioridade: agradecer um presente (algumas horas depois),
pedir ajuda com o objetivo, contar uma novidade que conhece, convidar para uma
atividade, fazer uma pergunta. Cooldowns: 8 h de jogo por morador e 3 h entre
iniciativas de qualquer morador. O morador vai até a jogadora e espera; ela pode
ignorar (ele desiste se ela se afastar ou depois de 40 s). A jogadora nunca fica
presa.

## Conversas entre moradores

O simulador decide assunto, tipo, resultado e consequências (como na 0.2).
Quando a jogadora está a até 12 m, os dois mostram falas curtas acima da cabeça
(geradas pelo Qwen, se disponível, ou clássicas). Conversas amigáveis espalham
novidades como rumores.

## Diagnóstico (F3)

Backend, MongoDB, Ollama, modelo instalado, modo de diálogo, fila, inferência em
andamento, última latência e média, tokens, erros recentes e memórias por morador.
