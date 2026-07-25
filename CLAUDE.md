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

# 3. Smoke test del combate (escena real con autoloads: animaciones, carta, turno)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeCombat.tscn

# 4. Smoke test de eventos/journaling (diario, persistencia, integración, claridad)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeEvent.tscn

# 5. Smoke test de la tienda (compra, descuento de integrada, quitar carta, topes)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeShop.tscn

# 6. Simulación de balance: 200 combates/arquetipo, semilla fija, bandas de win-rate
#    (Menor >=85%, Élite >=50%, Jefe 30-95% con mazo inicial)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SimBalance.tscn
```

Nota: los scripts `-s` no pueden tocar código que use el autoload `GameState` (no compila fuera del juego); para tests que lo necesiten, usar una escena como `SmokeCombat.tscn`.

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
scripts/combat/shadow_ai.gd        IA de intenciones: patrón por arquetipo (sin autoloads,
                                   testeable desde verify.gd)
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
- **Integración** = tipo de carta de los Arcanos Mayores y meta-progresión (`cartas_integradas`): las cartas se integran al reflexionar sobre ellas en eventos.
- **Balance**: las curvas por palo viven SOLO en `gameplay()` de `tools/generate_tres.py` (Espadas `6+rank//2` daño, Oros `5+rank//2` escudo, Copas `4+rank//2` curación, Bastos `2+rank//2` disonancia, Mayores `6+num//4` doble efecto; coste `1+(rank-1)//5`). Las cartas **integradas rinden +25%** en combate (`INTEGRATED_BONUS` en `combat_manager.gd`, aplicado sin mutar los `.tres`). Cualquier cambio de números u orden de patrones de IA debe pasar `SimBalance.tscn` — el balance se verifica, no se opina.
- **Intenciones de las Sombras** (`shadow_ai.gd`): cada arquetipo cicla un patrón telegrafiado antes del turno del jugador — Atacar, Golpe Fuerte (×1.75), Defender (escudo), Acechar (el próximo golpe hace ×1.5) y Drenar (daña la mitad y se cura). Menor = [atacar, atacar, defender] con 25% de caos; Élite = [atacar, acechar, golpe fuerte, defender]; Jefe = [acechar, golpe fuerte, atacar, drenar], ambos deterministas. La disonancia resta al golpe y la descripción de la intención se re-emite en vivo al cambiar. El escudo de la Sombra expira al comenzar su propia acción.
- **Esencia** = moneda del run: `ESENCIA_COMBATE/ELITE/JEFE` al vencer Sombras; se gasta en la tienda; se resetea con cada run (viaja en `progress.save`).
- **Tienda ("El Mercader de Umbrales")**: en un nodo TIENDA (`shop_scene.gd`) se ofrecen 3 cartas al azar (menores 25, mayores 50, **mitad de precio si está integrada** — el journaling paga) y quitar una carta del mazo por 30 (una por visita, nunca por debajo de `MIN_DECK_SIZE`).
- **Eventos/journaling ("El Espejo del Viajero")**: en un nodo EVENTO se roba una carta del mazo propio (50% invertida), se muestra su significado real (derecho o reverso, datos de Kabbalah) y una pregunta introspectiva según su elemento (`event_scene.gd`). Escribir y guardar la reflexión da `+EVENT_CLARIDAD_REWARD` de claridad e integra la carta; saltar no da nada. El diario persiste **entre runs** en `user://journal.save` (separado de `progress.save`, que se resetea con cada run) y se consulta desde el botón "Diario" del título (`journal_scene.gd`).
- Palos → efectos: Espadas=daño, Oros=escudo, Copas=curación, Bastos=disonancia, Arcanos Mayores=dos efectos según su elemento.

## Assets de pixel art (PixelLab MCP)

El arte pixel se genera con las **herramientas MCP de PixelLab** (`mcp__pixellab__*`), solo cuando una tarea lo requiera — no es un addon de Godot, así que no viola la regla de "sin plugins".

- **Iconos de nodos del mapa**: `assets/map_icons/<tipo>.png` — un PNG 64×64 por valor del enum `MapNode.NodeType` en minúscula (`combate.png`, `elite.png`, `descanso.png`, `tienda.png`, `evento.png`, `jefe_sombra.png`). `map_scene.gd` los carga por convención de nombre (`_icon_for`); si falta un icono, el botón cae a solo texto.
- **Personajes animados (combate)**: `assets/personajes/<clave>/{idle_south,attack_south}/<n>.png` — carpetas de frames cuadrados numerados desde 0 (el 0 es el frame de referencia; ver `scripts/ui/sprite_strip.gd`). Claves: `viajero`, `sombra_menor`, `sombra_elite`, `jefe_sombra`. `combat_scene.gd` reproduce idle en bucle y dispara attack con las señales (`card_played` → Viajero, `TURNO_ENEMIGO` → Sombra). Personajes creados con `create_character` v3; los `character_id` NO se guardan (los personajes viven en la cuenta PixelLab, listables con `list_characters`).
- **Sprites estáticos legacy (fallback)**: `assets/sombras/<tipo>.png` y `assets/viajero/viajero.png` (128×128) — se usan si faltan las tiras animadas. No borrarlos: son el fallback de `combat_scene.gd`.
- **Cartas pixel art**: `assets/cartas_pixel/<NN>-<slug>.png` — PNG 128×192 (formato carta), mismo nombre base que el `.webp` de `assets/cards/`. Las **78 cartas completas** (mayores y menores) tienen pixel art con iconografía Rider-Waite. `generate_tres.py` usa el pixel art como `icon` del CardData **si el PNG existe**; si no, cae al `.webp` de Kabbalah — tras añadir/quitar pixel art hay que regenerar los `.tres`.
- **UI de título**: `assets/ui/titulo_emblema.png` — emblema 256×256 usado por `title_scene.gd` (pantalla de inicio, construida por código con `StyleBoxFlat`; sin paneles de `create_ui_asset`). Ojo: este PNG tiene **fondo opaco** `#13173a`; `COLOR_BG` de `title_scene.gd` usa ese mismo color para fundirlo. Si se regenera el emblema, revisar el color de fondo real del PNG y ajustar la constante.
- **Estilo fijado**: 64×64 px, paleta oscura mística (violeta/dorado), coherente con `icon.svg` (tarot/ocultismo/sombras). Vista "side", contorno "single color outline". Renderizar con `TEXTURE_FILTER_NEAREST` en la UI.
- **Qué herramienta usar por tipo de asset** (plan Tier 1 activo, pero seguir siendo frugal):
  - Iconos, emblemas e ilustraciones estáticas (cartas): `create_map_object` básico — 1 generación.
  - Personajes animables (Viajero, Sombras): `create_character` en modo `v3` (~3 gen, 8 direcciones) + `animate_character` — idle con template (`breathing-idle`, 1 gen/dirección) y acciones custom en v3 (coste según tamaño). El combate solo usa la dirección **south**: animar solo esa salvo que se pida otra cosa.
  - Retratos para diálogo/eventos: `create_portrait_character` (cuando llegue el journaling).
  - Paneles 9-slice: `create_ui_asset` (20-40 gen/panel) solo para un set cohesivo aprobado explícitamente por Hugo; para botones sueltos, `StyleBoxFlat` por código.
- **Uso de créditos**: generar en una sola pasada lo acordado con Hugo. No iterar arte de forma exploratoria sin pedirlo; para regenerar algo, borrar antes la versión anterior (`delete_*`).
- Los objetos generados en PixelLab se **auto-borran a las 8 horas**: descargar los PNG al repo apenas terminen.
- `tools/verify.gd` comprueba que los 6 iconos de nodo existan.

## Fuera de alcance en esta fase (no implementar sin que Hugo lo pida)

UI final, export móvil, monetización.
