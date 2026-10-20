# Changelog

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
