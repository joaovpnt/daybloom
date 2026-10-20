# Pipeline Blender → Godot

Todos os modelos 3D do Daybloom são **originais e gerados por código** (bpy) a
partir de `tools/blender/`. O código é a fonte da verdade; os `.blend` são fontes
editáveis geradas por ele, e os `.glb` são o que o jogo usa.

Testado com **Blender 5.2.2 LTS** e **Godot 4.7.1/4.7.2**.

## Estrutura

```
tools/blender/
  dbkit.py            utilitários: materiais flat/pastel, bmesh, rig, ações NLA, exportação glTF
  characters.py       jogadora e os 8 moradores (corpo, cabeça, orelhas/bico/focinho, roupas,
                      malhas de expressão, armature e animações)
  environment.py      vegetação, 9 casas personalizadas e props
  renders.py          retratos (UI) e ícones de itens renderizados no Eevee
  generate_assets.py  gera tudo (ponto de entrada)
  export_assets.py    reexporta .glb a partir dos .blend (após edições manuais)
  validate_assets.py  valida .blend e .glb e grava assets/validation_report.json
  preview_sheet.py    prancha de conferência visual (QA)
assets/blender/       .blend gerados (characters/, environment/{buildings,props,vegetation})
game/assets/models/   .glb usados pelo jogo (buildings/, characters/, environment/, props/)
game/assets/ui/       portraits/*.png e icons/*.png
```

## Comandos (Windows, na raiz do repositório)

```bat
set BLENDER="C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"

rem Gerar tudo (ou só algumas categorias)
%BLENDER% --background --factory-startup --python tools\blender\generate_assets.py -- characters vegetation buildings props renders

rem Depois de editar um .blend à mão, reexportar os .glb
%BLENDER% --background --factory-startup --python tools\blender\export_assets.py

rem Validar (código de saída 1 se houver problema)
%BLENDER% --background --factory-startup --python tools\blender\validate_assets.py
```

Depois de gerar ou exportar, abra o projeto no Godot (ou rode
`godot --headless --path game --import`) para reimportar os `.glb`.

## Convenções

- **Escala**: 1 unidade = 1 metro. Moradores têm cerca de 1,1 m; a jogadora, 1,2 m.
- **Origem**: no chão, centro da base. **Frente**: −Y no Blender (vira +Z no Godot).
- **Materiais**: poucos, compartilhados, cores pastel e `roughness` alto. O jogo reaproveita
  as mesmas instâncias de material (`ModelLib.adapt_materials`).
- **Personagens**: um armature simples (raiz, quadril, tronco, cabeça, braços, pernas) e
  malhas de expressão com nomes fixos que o jogo liga e desliga:
  `Eyes_Open`, `Eyes_Happy`, `Eyes_Closed`, `Eyes_Sad`, `Mouth_Smile`, `Mouth_Open`, `Mouth_Frown`.
- **Animações** (uma ação NLA cada, exportadas com `export_animation_mode="NLA_TRACKS"`):
  - moradores: `idle`, `walk`, `talk`, `happy`, `sad`, `surprised`
  - jogadora: `idle`, `walk`, `run`, `interact`, `talk`, `happy`
- **Nomes de arquivo** seguem os IDs persistentes do jogo: `casa_<id>.glb`,
  `villager_<id>.glb`. Nunca renomeie IDs: os saves dependem deles.

## Como o jogo usa os modelos

- `ModelLib` (`game/scripts/world/model_lib.gd`) carrega e instancia os `.glb` com cache.
- `IslandBuilder` posiciona casas, props e vegetação (árvores e tufos via `MultiMeshInstance3D`).
- `CharacterVisual` toca as animações e troca as expressões conforme o humor e as
  reações vindas do sistema de emoções (`EventBus.npc_reaction`).

## Testes que cobrem o pipeline

`game/tests/test_assets.gd` verifica se todos os `.glb` carregam com geometria e
material, se as casas existem para os 9 IDs, se cada personagem tem todas as
animações e malhas de expressão, e se as instâncias compartilham materiais.
