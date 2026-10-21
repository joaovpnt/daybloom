# Changelog

## 0.3.0 — Living Minds: inteligência, memória e vida social

### Adicionado
- **Orquestrador central de IA** no backend: um modelo compartilhado pelos oito
  moradores, fila com prioridade (conversa da jogadora primeiro), uma inferência
  por vez, deduplicação, cancelamento, descarte de pedidos obsoletos, timeout,
  limite de contexto e métricas (latência, tokens, erros).
- **Saídas estruturadas** do Ollama com JSON Schema, validadas com Pydantic
  (fala, emoção, intenção, memórias citadas, ação sugerida e parâmetros).
- **ContextBuilder**: o modelo recebe só o que o morador sabe, com fatos,
  opiniões e rumores separados e permissões calculadas pelo simulador.
- **Perfis conversacionais** dos oito moradores (vocabulário, temperamento,
  valores, assuntos, limites, reações, estilo de amizade).
- **Memória avançada**: categorias (recente, episódica, social, longo prazo),
  origem do conhecimento, fato × interpretação, validade, consolidação, promoção
  e expiração.
- **Conhecimento limitado**: por participação, observação (até 14 m) e
  comunicação (rumores com fonte).
- **Objetivos em etapas** que só avançam por acontecimentos reais, com marcos e
  conclusão no Diário; o modelo pode escolher entre planos válidos.
- **Evolução gradual da personalidade** com limites e **gostos aprendidos**.
- **Ações autorizadas**: pedir item, convidar para atividade, registrar promessa
  e compartilhar lembrança — sempre validadas pelo simulador.
- **Iniciativa dos moradores**: agradecer, pedir ajuda, contar novidades,
  convidar e perguntar, com prioridade e cooldowns; a jogadora pode ignorar.
- **Falas entre moradores** acima da cabeça quando a jogadora está por perto.
- Diálogo: cancelar resposta, indicador discreto de diálogo clássico, emoção
  validada no rosto e no painel, avisos amigáveis.
- Diário: novas amizades, confiança, objetivos (início, etapa, conclusão),
  promessas e convites.
- Painel F3: modelo, fila, inferência em andamento, latência, tokens, erros e
  memórias por morador.
- `start-all.bat` e verificação do serviço MongoDB e do Ollama/modelo nos scripts.
- Script de integração real (`game/tests/integracao/ia_real.tscn`) e benchmark
  (`backend/tools/benchmark_ollama.py`).

### Alterado
- Diálogos clássicos agora respeitam o conhecimento do morador (antes liam o
  Diário global e não sabiam dizer “não vi”).
- O contexto enviado ao modelo não inclui mais o Diário da Ilha.
- `/health` informa se o modelo está instalado; o jogo só usa IA com o modelo presente.

### Compatibilidade
- Saves da 0.1 e 0.2 carregam: os campos novos de memória, objetivos e
  personalidade são opcionais e preenchidos na carga.

## 0.2.0 — Refino visual, Blender e identidade artística

### Adicionado
- Pipeline Blender reproduzível (`tools/blender/`): geração por código, 12 fontes
  `.blend`, 73 modelos `.glb`, exportação e validação automáticas.
- Jogadora e oito moradores remodelados, com silhuetas distintas, armature,
  animações (idle, walk, run, interact, talk, happy, sad, surprised) e malhas de
  expressão facial ligadas ao humor e às reações do sistema de emoções.
- Nove casas personalizadas (IDs preservados) e biblioteca de vegetação e props.
- Mapa redesenhado: praça, bairro residencial, jardim, centro comercial, lago com
  píer, bosque, pomar, três praias, mirante elevado e área de lazer; caminhos
  orgânicos; terreno com elevações; água estilizada com espuma.
- Novo sistema de design da interface (Fredoka + Nunito), retratos e ícones
  renderizados no Blender.
- Menu principal com a ilha em 3D ao fundo, Configurações, indicadores discretos
  dos serviços locais.
- HUD limpo, painel de diagnóstico (F3), dica de controles (F1).
- Inventário em grade com detalhes; diálogo com retrato, humor, corações e
  indicador de digitação; Diário com filtros, cartões por dia e cartões de moradores.
- Configurações gráficas (tela cheia, VSync, MSAA, sombras, SSAO, glow, resolução
  3D, tamanho da interface, FPS), salvas em `user://settings.cfg`.
- Câmera com transparência de oclusão sem alterar materiais e zoom suave.
- Escala automática da interface acima de 1080p.
- Testes: modelos, animações, expressões, materiais compartilhados, interface em
  quatro resoluções, navegação para todos os lugares, oclusão da câmera, reação
  visual a presentes e compatibilidade com saves da 0.1 (fixture congelada).

### Alterado
- Iluminação: Filmic com exposição contida, saturação maior, neblina leve e luz
  ambiente azulada (escolhida por comparação em Forward+).
- A jogadora começa na porta de casa.

### Removido
- Personagens procedurais da 0.1 (`character_builder.gd`), substituídos pelos modelos.

### Compatibilidade
- Saves da 0.1 abrem na 0.2 sem migração de schema: IDs de moradores, casas e
  recursos foram preservados; posições antigas são ajustadas para a área
  caminhável mais próxima no mapa novo.

## 0.1.0 — Fundação jogável e primeira comunidade viva

### Adicionado
- Projeto Godot 4.7 com ilha 3D procedural estilizada e ciclo de dia/noite.
- Jogadora com WASD, câmera elevada, colisões, interação com E e corrida.
- Oito moradores originais com personalidade, necessidades, rotina, hobbies,
  objetivos, preferências e aparência própria.
- Utility AI + máquina de estados, navegação com NavigationAgent3D, decisões
  distribuídas e detecção de travamento.
- Relacionamentos direcionais (afinidade, confiança, histórico, último encontro,
  conflitos) entre os moradores e com a jogadora.
- Interações sociais reais: conversa, atividade compartilhada, desentendimento e
  reconciliação; encontro comunitário ao entardecer.
- Memórias com deduplicação e recuperação por contexto; Diário da Ilha.
- Inventário, coleta com renascimento diário, presentes com reação por preferência.
- Diálogo livre com Ollama/Qwen3 4B opcional e diálogos clássicos contextualizados.
- Backend FastAPI + MongoDB com saves atômicos, validação, checksum e revisões.
- Interface aconchegante em português: menu, HUD, inventário, diário, diálogo e pausa.
- Scripts Windows e testes automatizados (pytest e Godot headless).
