# Arquitetura do Daybloom 0.1

## Visão geral

```
┌──────────────── Godot 4.7 (GDScript tipado) ────────────────┐
│  UI (HUD, diálogo, diário)   Cena da ilha (World)            │
│        │                      ├─ IslandBuilder / DayNight    │
│        │                      ├─ Player + CameraRig          │
│        ▼                      └─ NpcDirector ─► 8 NpcActor   │
│  EventBus ◄── GameState ──► Simulation (pura, testável)      │
│                 │            ├─ NpcState ×8                  │
│                 │            ├─ UtilityBrain / SocialRules   │
│                 │            ├─ RelationshipSystem           │
│                 │            ├─ MemorySystem / IslandJournal │
│                 ▼            └─ Inventory                    │
│            SaveManager ─► SaveBackend (Api | ArquivoLocal)   │
└─────────────────│──────────────────────────────────────────┘
                  │ HTTP 127.0.0.1:8765 (assíncrono)
┌─────────────── Backend FastAPI ─────────────┐     ┌────────┐
│ /health  /api/v1/saves/{slot}  /dialogue    │────►│ Ollama │ (opcional)
│ SaveService (validação, checksum, revisão)  │     └────────┘
│ SaveRepository (Mongo | memória)            │
└─────────────────│───────────────────────────┘
                  ▼
           MongoDB `daybloom`
```

## Princípios

1. **A simulação é a fonte da verdade.** `Simulation` e as classes em `scripts/sim`
   não dependem de cenas: dá para testar toda a vida social sem renderizar nada.
   Os nós (`NpcActor`) apenas executam planos e reportam chegadas.
2. **O modelo de linguagem nunca altera o mundo.** Ele recebe um contexto limitado
   (identidade, humor, relação, horário, até 5 memórias, até 6 fatos recentes) e
   devolve uma fala e, no máximo, uma ação de uma lista fechada
   (`sorrir`, `ficar_triste`, `lembrar_conversa`). O jogo valida e limita cada ação.
3. **Nada de acontecimento fictício.** Interações só são registradas quando as
   condições reais são cumpridas (distância ≤ 2,6 m, ambos disponíveis, sem
   cooldown) e a interação chega ao fim. Interações interrompidas não deixam rastro.
4. **Desempenho.** Decisões da Utility AI são distribuídas (no máximo 2 por frame),
   necessidades atualizam uma vez por minuto de jogo, encontros espontâneos são
   checados a cada 1,5 s, decoração usa MultiMesh e o navmesh é gerado em thread.
5. **Persistência honesta.** O save é um snapshot canônico único, validado no
   backend, gravado atomicamente com controle de revisão e confirmação em journal.
   Falhas aparecem na interface com a frase "o progresso NÃO foi salvo".

## IA dos moradores

### Estados (máquina de estados do `NpcActor`)
`IDLE`, `WALKING`, `RESTING`, `WORKING`, `SOCIALIZING`, `EXPLORING`, `LEISURE`.

### Utility AI (`UtilityBrain`)
Cada ação recebe uma pontuação a partir de necessidades, traços e horário:

| Ação | Fatores principais |
|---|---|
| `sleep` | janela de sono da rotina; exaustão (cúbica) fora dela |
| `rest` | falta de conforto e de energia |
| `work` | horário de trabalho, traço energia |
| `socialize` | falta de social × sociabilidade; alvo escolhido por afinidade, distância e conflitos |
| `leisure` | falta de diversão; hobby escolhido conforme horário |
| `explore` | curiosidade; à noite multiplicada pela coragem |
| `gathering` | 17h30–19h30, sociabilidade |
| `wander` | opção de baixa prioridade |

Há penalidade para repetir a mesma ação, redução de atividades intensas com pouca
energia e ruído pequeno para evitar previsibilidade. Atividades longas são
interrompidas quando chega a hora de dormir ou a energia acaba.

### Interações sociais (`SocialRules`)
- **Conversa amistosa** — padrão; tópico vem dos hobbies em comum.
- **Atividade compartilhada** — em locais propícios (jardim, coreto, praia...),
  mais provável com hobbies em comum e afinidade alta.
- **Desentendimento** — mais provável com pouca gentileza, mau humor, cansaço e
  gostos opostos; abre um conflito e tem cooldown de 2 dias.
- **Reconciliação** — só depois de 2 horas de jogo, com chance proporcional à gentileza.

Cada resultado altera afinidade/confiança dos dois lados, gera memórias com
referência ao evento, memória de mudança de relação quando o rótulo muda
(colegas → amigos...), entra no Diário (conversas comuns no máximo a cada 6 h por dupla).

### Memórias (`MemorySystem`)
Campos: id, tipo, participantes, dia/minuto, descrição, relevância, consequências,
evento de origem, ocorrências. Memórias equivalentes (mesma chave de deduplicação)
são reforçadas em vez de duplicadas. Recuperação por pontuação: relevância ×
recência + participantes + tipo + palavras-chave. Capacidade de 80 por morador.

## Navegação
`NavigationRegion3D` gerada em tempo de execução a partir dos colisores estáticos
(filtro de altura ignora telhados). `NavigationAgent3D` por morador. Detecção de
travamento: após 2 s sem progresso tenta um desvio; após 4 s abandona o plano e
volta ao navmesh mais próximo. Moradores não colidem entre si (evita bloqueios),
mas colidem com o cenário; a jogadora colide com todos.

## Backend
- `app/schemas.py` — modelos pydantic do snapshot (exatamente 8 moradores, IDs
  únicos, intervalos de necessidades/traços, relações válidas, diário sem duplicatas).
  Campos desconhecidos são preservados.
- `app/services/save_service.py` — migração → validação → checksum SHA-256 →
  gravação atômica → eventos auxiliares.
- `app/persistence/` — `SaveRepository` (protocolo), `MongoSaveRepository`,
  `MemorySaveRepository`. Uma implementação local embutida poderá substituir o
  MongoDB no jogo distribuído sem mudar a API.
- `app/services/ollama_client.py` — biblioteca padrão + thread + timeout duplo.

## Preparação para multiplayer
IDs únicos e aleatórios para jogadora (`jogadora_…`) e ilha (`ilha_…`), slots de
save independentes e relações direcionais que já aceitam qualquer ID de jogador.
