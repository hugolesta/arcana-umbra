# CLAUDE.md — Arcana Umbra

Roguelike deckbuilder de tarot e introspección (estilo *Slay the Spire*), en **Godot 4.5 / GDScript**, orientación vertical (720×1280), renderer Mobile, pensado para Android/iOS. El jugador (el Viajero) recorre un mapa procedural enfrentando Sombras con un mazo de cartas Rider-Waite.

## Restricciones del proyecto (del prompt KERNEL original — no negociables)

1. **`/Users/hugo.lesta/Desktop/Projects/hugolesta/Kabbalah` es SOLO LECTURA.** Es el proyecto interno elarboldelavida.com.ar/tarot-rider-waite, fuente de los datos de las 78 cartas (significado al derecho y al reverso, elemento, signo, planeta). Nunca modificar, escribir ni borrar nada ahí.
2. **Solo GDScript.** Nada de C#, ni addons/plugins de terceros (ni AssetLib ni manuales).
3. **Sin export móvil todavía.** No crear presets de export Android/iOS, ni firmas, ni SDKs de ads/monetización en esta fase.
4. Los recursos de carta (`.tres`) **no se editan a mano**: se regeneran con el pipeline de datos (ver abajo).

## Criterio de verificación

Todo cambio debe dejar el proyecto en este estado (Godot está en `/Applications/Godot.app/Contents/MacOS/Godot`):

```bash
# 1. El juego corre headless sin errores ni warnings (exit 0, stderr vacío)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30

# 2. La suite de verificación pasa: 78 CardData completos + reglas del DAG del mapa
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/verify.gd
```

## Pipeline de datos (cartas)

```bash
python3 tools/extract_cards.py    # HTML de Kabbalah -> tools/cards.json
python3 tools/generate_tres.py    # cards.json -> 78 .tres en resources/cards/
cp /Users/hugo.lesta/Desktop/Projects/hugolesta/Kabbalah/cards/*.webp assets/cards/  # solo si cambian imágenes
```

Los enums `SUITS`/`TYPES` de `tools/generate_tres.py` deben coincidir con los de `scripts/cards/card_data.gd`. Si cambias uno, cambia el otro y regenera los `.tres`.

## Arquitectura

```
scenes/Main.tscn                   Raíz; main.gd alterna mapa <-> combate <-> mazo
scripts/autoload/game_state.gd     Autoload GameState: mazo, claridad, mapa del run,
                                   guardado JSON en user://progress.save
scripts/cards/card_data.gd         Resource CardData (enums Suit y CardType)
scripts/cards/card_effect.gd       Efecto base (patrón Strategy)
scripts/cards/effects/*.gd         DamageEffect, HealEffect, ShieldEffect, DisonanciaEffect
scripts/combat/combatant.gd        Estado de Viajero/Sombra (claridad, escudo, disonancia)
scripts/combat/combat_manager.gd   Máquina de estados del combate; emite señales, NO toca UI
scripts/map/map_generator.gd       DAG: 15 pisos, 3-6 nodos (anchura varía ±1 por piso),
                                   conexiones solo a columnas adyacentes, jefe final único
scripts/map/map_node.gd            Nodo del mapa (Resource serializable to_dict/from_dict)
scripts/ui/*.gd                    Escenas de UI: construyen sus nodos por código en _ready()
resources/cards/*.tres             78 cartas GENERADAS (no editar a mano)
assets/cards/*.webp                78 imágenes copiadas de Kabbalah
```

Patrones a respetar:
- **Lógica y UI desacopladas por señales**: `CombatManager` resuelve el combate y emite (`card_played`, `hand_changed`, `combat_ended`…); `combat_scene.gd` solo escucha y renderiza. Mantener esa separación en features nuevas.
- **La UI se construye por código** (las `.tscn` son mínimas: nodo raíz + script). Seguir ese estilo, no añadir árboles de nodos complejos en las escenas.
- **Contenido como Resources**: cartas, efectos y nodos de mapa viven en Resources editables/serializables, no hardcodeados en el motor de combate.
- El estado de combate en `GameState` se guarda tras cada nodo visitado (`mark_visited`) para poder continuar el run si se cierra la app.

## Vocabulario de mecánicas

- **Claridad** = vida (jugador y Sombras). Si llega a 0, fin del combate.
- **Disonancia** = debuff sobre la Sombra: cada punto resta 1 a su próximo ataque, luego se disipa a la mitad.
- **Escudo** = absorbe daño; el del jugador se resetea al terminar su turno.
- **Integración** = tipo de carta de los Arcanos Mayores y futura meta-progresión (`cartas_integradas`).
- Palos → efectos: Espadas=daño, Oros=escudo, Copas=curación, Bastos=disonancia, Arcanos Mayores=dos efectos según su elemento.

## Assets de pixel art (PixelLab MCP)

El arte pixel se genera con las **herramientas MCP de PixelLab** (`mcp__pixellab__*`), solo cuando una tarea lo requiera — no es un addon de Godot, así que no viola la regla de "sin plugins".

- **Iconos de nodos del mapa**: `assets/map_icons/<tipo>.png` — un PNG 64×64 por valor del enum `MapNode.NodeType` en minúscula (`combate.png`, `elite.png`, `descanso.png`, `tienda.png`, `evento.png`, `jefe_sombra.png`). `map_scene.gd` los carga por convención de nombre (`_icon_for`); si falta un icono, el botón cae a solo texto.
- **Sprites de Sombras (combate)**: `assets/sombras/<tipo>.png` — PNG 128×128: `sombra_menor.png`, `sombra_elite.png`, `jefe_sombra.png`. `combat_scene.gd` los carga por convención de nombre según el tipo de nodo; si falta un sprite, el combate sigue sin imagen.
- **Sprite del Viajero (combate)**: `assets/viajero/viajero.png` — PNG 128×128, se muestra junto a las stats del jugador en `combat_scene.gd`; mismo fallback (sin imagen si falta).
- **Estilo fijado**: 64×64 px, paleta oscura mística (violeta/dorado), coherente con `icon.svg` (tarot/ocultismo/sombras). Vista "side", contorno "single color outline". Renderizar con `TEXTURE_FILTER_NEAREST` en la UI.
- **Uso de créditos**: generar en una sola pasada lo acordado con Hugo (p. ej. `create_map_object` básico = 1 generación por icono). **Nunca** usar `create_ui_asset` para iconos sueltos (consume 20-40 generaciones por panel) ni iterar arte de forma exploratoria sin pedirlo.
- Los objetos generados en PixelLab se **auto-borran a las 8 horas**: descargar los PNG al repo apenas terminen.
- `tools/verify.gd` comprueba que los 6 iconos de nodo existan.

## Fuera de alcance en esta fase (no implementar sin que Hugo lo pida)

Tienda y eventos/journaling (hoy son placeholders que marcan el nodo y avanzan), IA de enemigos, balance de cartas, UI final, export móvil, monetización.
