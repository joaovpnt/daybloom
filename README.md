# Daybloom

Jogo original de simulação de vida 3D, aconchegante e colorido, para PC Windows.
Você mora em uma pequena ilha com **oito moradores animais que têm vida própria**:
personalidade, necessidades, rotina, memórias, emoções e amizades que evoluem
mesmo quando você não está olhando.

> Versão atual: **0.1 — Fundação jogável e primeira comunidade viva**

## O que já dá para fazer (0.1)

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
scripts\iniciar_jogo.bat
```

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
| `verificar_ambiente.bat` | diagnóstico rápido |

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
    npc/            definição, ator físico, diretor e construtor de personagens
    world/          layout, construtor da ilha, dia/noite, recursos
    dialogue/       contexto do modelo e diálogos clássicos
    save/           interface de persistência (API e arquivo local), migração
    ui/             tema, HUD, inventário, diário, diálogo, pausa, menu
  tests/            testes headless (test_runner.tscn)
docs/               arquitetura, moradores, formato do save, relatório e changelog
scripts/            scripts Windows
```

Mais detalhes em [`docs/arquitetura.md`](docs/arquitetura.md),
[`docs/moradores.md`](docs/moradores.md) e [`docs/formato_do_save.md`](docs/formato_do_save.md).

## Fluxo de Git

- `main` — versões estáveis
- `develop` — integração
- `feature/0.1-fundacao-jogavel` — esta versão

Próximas: `feature/0.2-atividades-e-progresso`, `0.3-ia-social-avancada`,
`0.4-memorias-e-personalidade`, `0.5-dialogos-inteligentes`,
`0.6-economia-e-comunidade`, `0.7-decoracao-e-personalizacao`, `0.8-eventos-e-mundo-vivo`.
