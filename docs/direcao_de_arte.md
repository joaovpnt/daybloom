# Direção de arte (0.2)

**Cozy 3D · Stylized Low-Poly · Soft Organic · Pastel Nature.** Identidade própria,
sem copiar personagens, construções ou interfaces de outros jogos.

## Princípios

- **Formas arredondadas e facetadas**: low-poly suave, sem arestas agressivas.
- **Paleta pastel quente**: verdes de folha, areia, coral, céu e lilás; o marrom
  escuro (`#4a3a2c`) é reservado para texto e contornos.
- **Leitura clara de cima**: a câmera é elevada, então telhados, copas e
  caminhos precisam se destacar uns dos outros.
- **Cada morador reconhecível pela silhueta**: orelhas longas (Lila), chapéu de
  padeiro (Tobias), olhos enormes e penas (Otávio), boné e cauda volumosa (Pipa),
  lenço (Marina), corpo largo e gravata-borboleta (Bento), lã (Dona Celeste),
  boina de pintora (Ravena).
- **Casas que contam quem mora nelas**: floreiras e treliça de flores (Lila),
  toldo listrado de padaria (Tobias), cúpula de observatório (Otávio), cores e
  materiais próprios em cada uma.

## Mapa

A ilha foi redesenhada com bairros orgânicos ao redor da **praça central**:
bairro residencial, **jardim comunitário**, **centro comercial** (quiosque, mural),
**lago com píer**, **bosque**, **pomar**, **praias** norte/leste/sul, **mirante**
elevado e **área de lazer** (parque, balanço, mesas de piquenique). Os caminhos
são faixas sinuosas de terra com bordas irregulares. O terreno tem pequenas
elevações (mirante, bosque) e desce suave até a praia.

## Interface

Sistema de design em `game/scripts/ui/ui_theme.gd`:

- **Tipografia**: Fredoka (títulos e logo) e Nunito (texto), ambas sob OFL.
- **Componentes**: painéis creme com borda quente e sombra suave, botões em pílula
  com “degrau” inferior, chips de humor e relação, corações de afinidade,
  teclas desenhadas (keycaps), retratos circulares renderizados no Blender.
- **Hierarquia do HUD**: relógio no canto, avisos de salvamento só quando importam,
  dica de controles que some sozinha (F1 mostra de novo), diagnóstico técnico
  separado (F3).
- **Responsividade**: testado em 1280×720, 1600×900, 1920×1080 e 2560×1440. Acima
  de 1080p a interface cresce proporcionalmente (`Settings.effective_ui_scale`).

## Iluminação

Escolha feita comparando seis configurações em **Forward+ numa RTX 3050** (as
capturas da comparação estão no relatório da versão):

| Variante | Resultado |
|---|---|
| AGX (0.1) | acinzentado e enevoado |
| Filmic / ACES padrão | claro demais, pouco contraste |
| Filmic + saturação, sem neblina | vivo, mas estourado |
| Linear | natural, porém duro nos realces |
| **Filmic, exposição 0,78, saturação 1,18, neblina leve** | **escolhida** |

Ajustes adicionais:

- **Luz ambiente** mistura horizonte e topo do céu (sombras levemente azuladas),
  com energia 0,72× a anterior. Isso evita que o entardecer deixe tudo marrom.
- **Sol ao entardecer** menos saturado (`#ffd1a8`) para a grama não ficar oliva.
- **Neblina** reduzida de 0,0025 para 0,0008; no menu, 0,0005.
- Configurações de sombras, SSAO, glow, MSAA e resolução 3D ficam no menu
  **Configurações**, aplicadas na hora.

> O renderizador de **Compatibilidade (OpenGL)** usado nas capturas automáticas em
> nuvem fica bem mais claro e desbotado que o Forward+. A aparência de referência é
> sempre a do Forward+.

## Câmera

- Objetos entre a câmera e a jogadora (casas, coreto, copas de árvores) ficam
  semitransparentes por `GeometryInstance3D.transparency`, **sem alterar materiais
  compartilhados** e com histerese (atraso para soltar), o que evita piscar.
- Zoom suave com a roda do mouse.
