# Daybloom

Jogo original de simulação de vida 3D, aconchegante e colorido, para PC Windows.
Você mora em uma pequena ilha com **oito moradores animais que têm vida própria**:
personalidade, necessidades, rotina, memórias, emoções e amizades que evoluem
mesmo quando você não está olhando.

> Versão atual: **0.3 — Living Minds: inteligência, memória e vida social**

## Novidades da 0.3 — Living Minds

- Os oito moradores conversam com um **modelo local (Qwen3 4B via Ollama)** compartilhado,
  cada um com seu jeito de falar, suas memórias e só o que realmente sabe.
- **Memória** com fatos, opiniões e rumores; quem não viu não inventa.
- **Objetivos em etapas** que avançam com acontecimentos reais; **personalidade** que
  muda aos poucos; **iniciativa**: moradores vêm agradecer, pedir ajuda, contar
  novidades e convidar (dá para ignorar).
- Conversa cancelável que nunca trava o jogo; sem Ollama, diálogos clássicos.
- Painel **F3** com o estado da IA. Detalhes em [`docs/ia_living_minds.md`](docs/ia_living_minds.md)
  e resultados em [`docs/relatorio_0.3.md`](docs/relatorio_0.3.md).

## Novidades da 0.2

- Visual novo: personagens, casas, vegetação e props modelados e animados no
  **Blender** (gerados por código, veja [`docs/pipeline_blender.md`](docs/pipeline_blender.md)).
- Mapa redesenhado com bairros, lago e píer, bosque, pomar, praias e mirante.
- Moradores com expressões e animações que reagem às emoções reais da simulação.
- Interface redesenhada, menu com a ilha em 3D e menu de Configurações.
- Iluminação revista e câmera que deixa transparente o que tapa a jogadora.

Direção de arte e decisões de iluminação: [`docs/direcao_de_arte.md`](docs/direcao_de_arte.md).

## O que já dá para fazer

- Explorar uma ilha 3D com praça, fonte, nove casas, lago com píer, praia, jardim
  comunitário, mirante, pomar, bosque, coreto, quiosque e fogueira.
- Ciclo de dia e noite (1 dia de jogo = 24 minutos reais), com postes e janelas
  acendendo à noite.
- Andar com WASD, coletar flores, conchas, frutas, galhos e pedras, e guardar no inventário.
- Conversar digitando livremente com os moradores (Qwen3 4B via Ollama, opcional;
  sem Ollama, diálogos clássicos contextualizados).
- Dar presentes: cada morador tem gostos e aversões, e a afinidade muda de verdade.
- Observar os moradores trabalhando, passeando, explorando, descansando e
  **interagindo entre si**: conversas, atividades em dupla, pequenos
  desentendimentos e reconciliações, além de um encontro na praça ao entardecer.
- Consultar o **Diário da Ilha** (só acontecimentos confirmados pela simulação) e a
  aba **Moradores** (humor, atividade, relação com você, amizades e memórias).
- Salvar no MongoDB local e continuar depois sem perder itens, memórias ou relacionamentos.

## Requisitos

| Ferramenta | Uso | Obrigatório |
|---|---|---|
| Windows 10/11 64 bits | plataforma | sim |
| [Godot 4.7](https://godotengine.org/download) | motor do jogo | sim |
| [Blender 5.2 LTS](https://www.blender.org/download/) | só para regenerar os modelos 3D | não |
| Python 3.10+ | backend local | sim (para salvar) |
| [MongoDB Community Server](https://www.mongodb.com/try/download/community) | persistência | sim (para salvar) |
| [Ollama](https://ollama.com) + `qwen3:4b` | conversas por IA | não |

Referência de hardware: 16 GB de RAM e RTX 3050 6 GB. Sem Docker e sem serviços pagos.

## Instalação rápida

```bat
scripts\preparar_ambiente.bat
```

Isso cria `backend\.venv`, instala as dependências, gera `backend\.env`, verifica o
MongoDB/Ollama e localiza o Godot (procura em `GODOT_BIN`, `tools\godot`, PATH,
Downloads, Área de Trabalho, Steam e WinGet). Se o Godot não for encontrado:

```bat
set GODOT_BIN=C:\caminho\para\Godot_v4.7.1-stable_win64.exe
rem ou baixe automaticamente para tools\godot:
scripts\preparar_ambiente.bat -BaixarGodot
```

Para conversas com IA (opcional):

```bat
ollama pull qwen3:4b
```

## Como jogar

```bat
start-all.bat
```

(ou `scripts\iniciar_jogo.bat`, que faz o mesmo). O script verifica o serviço do MongoDB
e o Ollama/modelo, sobe o backend e abre o jogo.

O script sobe o backend (se ainda não estiver rodando), espera ele responder, abre o
jogo e desliga o backend quando você fecha o Daybloom.

| Tecla | Ação |
|---|---|
| W A S D / setas | andar |
| Shift | correr |
| E | interagir (conversar, coletar) |
| I | inventário |
| J | Diário da Ilha e painel dos moradores |
| F5 | salvar |
| Esc | pausa / fechar painéis |
| Roda do mouse | zoom |
| F1 | mostrar a dica de controles |
| F3 | painel de diagnóstico (backend, MongoDB, Ollama, FPS) |

A partida também é salva automaticamente a cada nova manhã e ao fechar a janela.
Se o salvamento falhar, o jogo avisa claramente e **não** finge que salvou.

## Scripts (pasta `scripts`)

| Script | Função |
|---|---|
| `preparar_ambiente.bat` | prepara tudo (Python, dependências, `.env`, MongoDB, Godot) |
| `instalar_dependencias.bat` | cria `backend\.venv` e instala os pacotes |
| `iniciar_backend.bat` | inicia só o backend (127.0.0.1:8765) |
| `iniciar_godot.bat` | abre só o jogo |
| `iniciar_editor.bat` | abre o projeto no editor do Godot |
| `iniciar_jogo.bat` | backend + jogo |
| `executar_testes.bat` | testes do backend (pytest) e do jogo (Godot headless) |
| `verificar_ambiente.bat` | diagnóstico rápido (MongoDB, Ollama/modelo, Godot, backend) |
| `..\start-all.bat` | atalho na raiz: verifica tudo e abre o jogo |

Defina `DAYBLOOM_SEM_PAUSA=1` para os `.bat` não esperarem uma tecla no final.

## Configuração (variáveis de ambiente)

Arquivo `backend\.env` (criado a partir de `backend\.env.example`):

| Variável | Padrão |
|---|---|
| `DAYBLOOM_MONGO_URI` | `mongodb://127.0.0.1:27017` |
| `DAYBLOOM_MONGO_DB` | `daybloom` |
| `DAYBLOOM_HOST` | `127.0.0.1` (o backend nunca escuta fora da máquina) |
| `DAYBLOOM_PORT` | `8765` |
| `DAYBLOOM_OLLAMA_ENABLED` | `true` |
| `DAYBLOOM_OLLAMA_URL` | `http://127.0.0.1:11434` |
| `DAYBLOOM_OLLAMA_MODEL` | `qwen3:4b` |
| `DAYBLOOM_OLLAMA_TIMEOUT_S` | `25` |
| `DAYBLOOM_AI_MAX_CONCURRENT` | `1` (inferências simultâneas) |

No jogo: `DAYBLOOM_API_URL` (ou `DAYBLOOM_PORT`) aponta para o backend, e
`DAYBLOOM_SAVE_BACKEND=local` usa saves em arquivo (`user://saves`) em vez do MongoDB.

### MongoDB

Banco `daybloom`, coleções:

- `save_slots` — documento principal do save (snapshot canônico completo, `revision`, `checksum`), gravado atomicamente com `replace_one` condicionado à revisão e *write concern* com journal.
- `world_events` — cópia auxiliar e idempotente dos acontecimentos do Diário (chave `ilha:slot:evento`).
- `dialogue_history` — trocas de diálogo respondidas pelo modelo (idempotentes por `exchange_id`).

Os testes de integração usam o banco separado `daybloom_test`.

## Testes

```bat
scripts\executar_testes.bat
```

- **Backend**: validação do snapshot, revisões e conflitos, eventos idempotentes,
  detecção de corrupção, API FastAPI, MongoDB real, fallback sem Ollama e timeout do modelo.
- **Jogo (headless)**: relógio e pausa, oito moradores únicos e distintos, Utility AI,
  rotinas, interações sociais com proximidade real, afinidade, memórias,
  inventário, coleta, presentes, diálogos, persistência completa sem duplicação e
  integração com a cena (navegação, colisão, conversa e rotina autônoma).
- **IA (0.3)**: orquestrador (fila, prioridade, cancelamento, deduplicação), contrato
  estruturado, barreiras contra invenção, contexto com conhecimento limitado, rumores,
  objetivos, ações autorizadas, iniciativas, evolução de personalidade e cenários A–F.
  Integração real com Ollama + MongoDB: `game/tests/integracao/ia_real.tscn`; benchmark:
  `python -m tools.benchmark_ollama` (na pasta `backend`).
- **Visual (0.2)**: todos os modelos `.glb`, animações e expressões, materiais
  compartilhados, interface em 1280×720 a 2560×1440, caminhos para todos os lugares do
  mapa novo, transparência de oclusão da câmera, reação visual a presentes e
  abertura de um save real da 0.1.

## Estrutura

```
backend/            API local FastAPI + PyMongo
  app/              config, schemas, persistência (MongoDB/memória), serviços
  tests/            pytest (inclui fixture de snapshot exportada pelo Godot)
game/               projeto Godot 4.7 (GDScript tipado)
  data/npcs/        os oito moradores (Resources NpcDefinition .tres)
  scenes/           menu principal e ilha
  scripts/
    autoload/       EventBus, GameClock, ApiClient, GameState, SaveManager
    sim/            simulação pura: NpcState, UtilityBrain, SocialRules,
                    RelationshipSystem, MemorySystem, IslandJournal, Inventory
    npc/            definição, ator físico, diretor, visual animado e balões de emoção
    world/          terreno, layout, construtor da ilha, modelos, dia/noite, recursos
    dialogue/       contexto do modelo e diálogos clássicos
    save/           interface de persistência (API e arquivo local), migração
    ui/             tema, HUD, inventário, diário, diálogo, pausa, menu
  tests/            testes headless (test_runner.tscn)
  assets/           modelos .glb, retratos, ícones e fontes
assets/blender/     fontes .blend geradas pelos scripts
tools/blender/      geração, exportação e validação dos modelos (bpy)
docs/               arquitetura, moradores, save, pipeline Blender, direção de arte, changelog
scripts/            scripts Windows
```

Mais detalhes em [`docs/arquitetura.md`](docs/arquitetura.md),
[`docs/moradores.md`](docs/moradores.md) e [`docs/formato_do_save.md`](docs/formato_do_save.md).

## Fluxo de Git

- `main` — versões estáveis
- `develop` — integração
- `feature/0.1-fundacao-jogavel` — 0.1
- `feature/0.2-refino-visual-blender` — 0.2
- `feature/0.3-living-minds-ia` — esta versão

Próximas: `0.3-atividades-e-progresso`, `0.4-ia-social-avancada`,
`0.5-memorias-e-personalidade`, `0.6-dialogos-inteligentes`,
`0.7-economia-e-comunidade`, `0.8-decoracao-e-personalizacao`, `0.9-eventos-e-mundo-vivo`.
