# Changelog

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
