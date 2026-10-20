# Relatório da versão 0.2 — Refino visual, Blender e identidade artística

Branch: `feature/0.2-refino-visual-blender` · PR #1 → `develop` (sem merge).

## Resumo

A 0.2 troca a aparência procedural da 0.1 por **assets originais modelados e
animados no Blender** (gerados por código), redesenha o mapa, a iluminação e toda a
interface, sem mexer na IA nem no formato dos saves. Saves da 0.1 continuam abrindo.

## Blender

- **Fontes**: 12 arquivos `.blend` em `assets/blender/` (jogadora, 8 moradores,
  casas, props e vegetação), gerados por `tools/blender/generate_assets.py`.
- **Exportação**: 73 modelos `.glb` em `game/assets/models/` (9 casas, 9 personagens,
  30 de vegetação, 25 props) e 19 PNGs (9 retratos e 10 ícones).
- **Validação**: `validate_assets.py` → `assets/validation_report.json` com 0 problemas.
- Como regenerar: [`pipeline_blender.md`](pipeline_blender.md).

## Personagens

| Personagem | Animações | Expressões |
|---|---|---|
| Jogadora | idle, walk, run, interact, talk, happy | 7 malhas (olhos e boca) |
| 8 moradores | idle, walk, talk, happy, sad, surprised | 7 malhas (olhos e boca) |

As reações são disparadas pela simulação real (`EventBus.npc_reaction`): presentes
adorados, aceitos ou recusados, fim de conversas boas ou desentendimentos e
ações sugeridas pelo modelo de linguagem. O rosto acompanha o humor do morador.

## Construções e mapa

- 9 casas personalizadas com os **mesmos IDs** da 0.1 (`casa_jogadora`, `casa_lila`…).
- Mapa novo: praça, bairro residencial, jardim comunitário, centro comercial, lago
  com píer, bosque, pomar, praias norte, leste e sul, mirante elevado, parque e fogueira.
- Terreno com elevações e transição suave para a praia; água com espuma.
- Vegetação em `MultiMeshInstance3D`; materiais compartilhados entre instâncias.

## Interface

Menu principal (ilha 3D ao fundo), Configurações, HUD, inventário, diálogo, diário
(acontecimentos e moradores), pausa e diagnóstico (F3). Fontes Fredoka e Nunito.
Testada em 1280×720, 1600×900, 1920×1080 e 2560×1440, com escala automática acima de 1080p.

## Iluminação e câmera

Detalhes em [`direcao_de_arte.md`](direcao_de_arte.md). Escolha feita comparando
seis variantes em Forward+ (`capturas/0.2/comparacao_iluminacao_*.jpg`). A câmera
deixa transparente o que tapa a jogadora, sem alterar materiais e sem piscar.

## Testes executados

| Conjunto | Onde | Resultado |
|---|---|---|
| Godot headless (62 testes, 11 novos) | nuvem, Godot 4.7.1 | **62/62** |
| Backend unittest | nuvem, sem MongoDB | 41 ok, 13 pulados (sem MongoDB) |
| Backend unittest **com MongoDB real** | Windows, banco `daybloom_test` | **41/41** (incluindo integração e API) |
| Ponta a ponta jogo → FastAPI → **MongoDB real** | Windows, Godot 4.7.2, banco `daybloom_e2e_test` (removido ao final) | **10/10** |
| Capturas e desempenho em **Forward+** | Windows, RTX 3050 6 GB | ver abaixo |

O teste ponta a ponta salvou, salvou de novo (revisão 1 → 2), carregou e conferiu
nome, inventário e afinidade. Também abriu um **save real da 0.1**, gravou pela 0.2
e recarregou.

## Desempenho (Forward+, RTX 3050 Laptop 6 GB, VSync desligado)

| Resolução | Menu | Praça (dia) | Vista alta | Noite |
|---|---|---|---|---|
| 1600×900 | 171 FPS | 230 FPS | 180 FPS | 182 FPS |
| 1920×1080 | 194 FPS | 190 FPS | 168 FPS | 184 FPS |
| 2560×1440 | 167 FPS | 109 FPS | 97 FPS | 112 FPS |

Em 1080p: ~670 draw calls na praça e ~915 na vista alta; ~366 MB de memória de
vídeo; o mundo fica pronto em ~0,6 s (navmesh incluso).

## Capturas

`docs/capturas/0.2/`:

- `forwardplus_*` — **Forward+ real** no Windows (menu, praça, vista alta, lago e
  casa da jogadora, casa da Lila e jardim, bosque, entardecer, noite e 2560×1440).
- `compat_ui_*` — telas de interface capturadas na nuvem com o renderizador de
  **Compatibilidade (OpenGL, software)**. Servem só para mostrar a interface: a cena
  3D ali aparece mais clara e desbotada que no jogo real, e foi capturada antes do
  ajuste final de iluminação.

## Problemas conhecidos

- O **entardecer** ainda deixa a grama levemente oliva; precisa de mais ajuste.
- No modo **Compatibilidade (OpenGL)** a cena fica bem mais clara que em Forward+.
- Moradores não têm animação de corrida (a especificação pede só para a jogadora).
- Com `fastapi`/`starlette` recentes, `starlette.testclient` avisa que `httpx` está
  obsoleto e pede `httpx2`; com `requirements-dev.txt` os testes passam.
- O aviso de “Falha ao salvar” do salvamento automático pode aparecer junto com o
  aviso de backend desligado (redundante, mas correto).

## Pendente para as próximas versões

- Ajuste fino do entardecer e do modo Compatibilidade.
- Animação de sentar e de dormir para os moradores.
- Testes de captura visual automatizados em Forward+ dentro do `executar_testes.bat`.
