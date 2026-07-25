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

# 3-6. Tests de gameplay: SIEMPRE con ARCANA_TEST=1 (usa saves aislados y limpios
#      user://test_*.save — sin la variable contaminarían el progreso real del jugador)
ARCANA_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeCombat.tscn
ARCANA_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeEvent.tscn
ARCANA_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SmokeShop.tscn
# SimBalance: 200 combates/arquetipo, semilla fija, bandas de win-rate con mazo inicial
# (Menor >=85%, Élite >=50%, Jefe 30-95%)
ARCANA_TEST=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/SimBalance.tscn

# 7. Capturas reales de 11 pantallas (título, identidad, mapa, combate + su
#    diálogo de fin, mazo + su diálogo de detalle de carta, evento, tienda,
#    diario, perfil). OBLIGATORIO tras cualquier cambio de UI: el headless NO
#    detecta texto desbordado, sprites diminutos, temas que no se aplican,
#    diálogos mal encuadrados ni widgets que no pintan su texto.
ARCANA_TEST=1 ARCANA_SHOT_DIR=/tmp/shots /Applications/Godot.app/Contents/MacOS/Godot \
  --path . res://tools/Screenshot.tscn --resolution 720x1280
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
scripts/ui/profile_button.gd       Avatar circular del Viajero (título/mapa) -> abre ProfileScene
scripts/ui/profile_scene.gd        Perfil: retrato, nombre y signo (fijos), resumen de progreso
scripts/ui/identity_scene.gd       Primer "nuevo viaje": nombre + fecha de nacimiento (una sola vez)
scripts/autoload/zodiac.gd         Zodiac.sign_for(mes,día): signo occidental (sin autoloads,
                                   testeable desde verify.gd)
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
- **Identidad del jugador**: en el PRIMER "nuevo viaje" (`identity_defined == false`), `main.gd` desvía a `IdentityScene` en vez de arrancar el run directamente. Ahí se define nombre (**fijo de por vida**, sin UI de edición — a diferencia de la esencia/mazo, sobrevive a `start_new_run()`) y fecha de nacimiento, que calcula el signo zodiacal vía `Zodiac.sign_for()`. `GameState.define_identity()` solo tiene efecto la primera vez; llamadas posteriores no hacen nada. El signo se muestra en `ProfileScene` junto al nombre.

## Assets de pixel art (PixelLab MCP)

El arte pixel se genera con las **herramientas MCP de PixelLab** (`mcp__pixellab__*`), solo cuando una tarea lo requiera — no es un addon de Godot, así que no viola la regla de "sin plugins".

- **Iconos de nodos del mapa**: `assets/map_icons/<tipo>.png` — un PNG 64×64 por valor del enum `MapNode.NodeType` en minúscula (`combate.png`, `elite.png`, `descanso.png`, `tienda.png`, `evento.png`, `jefe_sombra.png`). `map_scene.gd` los carga por convención de nombre (`_icon_for`); si falta un icono, el botón cae a solo texto.
- **Personajes animados (combate)**: `assets/personajes/<clave>/{idle_south,attack_south}/<n>.png` — carpetas de frames cuadrados numerados desde 0 (el 0 es el frame de referencia; ver `scripts/ui/sprite_strip.gd`). Claves: `viajero`, `sombra_menor`, `sombra_elite`, `jefe_sombra`. `combat_scene.gd` reproduce idle en bucle y dispara attack con las señales (`card_played` → Viajero, `TURNO_ENEMIGO` → Sombra). Personajes creados con `create_character` v3; los `character_id` NO se guardan (los personajes viven en la cuenta PixelLab, listables con `list_characters`).
- **Sprites estáticos legacy (fallback)**: `assets/sombras/<tipo>.png` y `assets/viajero/viajero.png` (128×128) — se usan si faltan las tiras animadas. No borrarlos: son el fallback de `combat_scene.gd`.
- **Iconos zodiacales**: `assets/zodiaco/<signo>.png` — 12 PNG 64×64, uno por signo occidental (`Zodiac.sign_key()` da la clave en minúsculas sin acentos: `geminis`, `cancer`, etc.). Mismos 12 nombres que `SIGNS` en `tools/extract_cards.py`, coherencia entre el perfil del jugador y el vocabulario de las cartas.
- **Cartas pixel art**: `assets/cartas_pixel/<NN>-<slug>.png` — PNG 128×192 (formato carta), mismo nombre base que el `.webp` de `assets/cards/`. Las **78 cartas completas** (mayores y menores) tienen pixel art con iconografía Rider-Waite. `generate_tres.py` usa el pixel art como `icon` del CardData **si el PNG existe**; si no, cae al `.webp` de Kabbalah — tras añadir/quitar pixel art hay que regenerar los `.tres`.
- **UI de título**: `assets/ui/titulo_emblema.png` — emblema 256×256 usado por `title_scene.gd`. Ojo: este PNG tiene **fondo opaco** `#13173a`; `COLOR_BG` de `title_scene.gd` usa ese mismo color para fundirlo. Si se regenera el emblema, revisar el color de fondo real del PNG y ajustar la constante.
- **Tema global (UI final)**: `scripts/ui/ui_theme.gd` construye un `Theme` en runtime desde `assets/ui/` y se aplica en `main.gd` (`get_window().theme`). Piezas de `create_ui_asset` (aprobadas por Hugo, 40 gen c/u): `panel_arcano.png` (9-slice de Panel/PanelContainer; su centro transparente se rellenó de violeta a mano), `boton_arcano.png` (estados por modulación; región útil `Rect2(76,68,152,63)`, el texto "Button" horneado se borró del PNG) y `barra_claridad.png` (ProgressBar; la barra fina vive en `Rect2(107,249,298,30)`). Tipografía: `arcana_umbra.ttf` (pixel font Bold de `create_font`, 20 gen), fuente por defecto del tema. **Si se regenera un asset de UI hay que recalcular sus regiones/rellenos** (los PNG commiteados están post-procesados). Cada pieza tiene fallback si falta el archivo.
- **Fondos ambientales**: `assets/backgrounds/mapa_bosque.png` (claro de bosque con círculo ritual y cartas de tarot flotando) y `combate_santuario.png` (altar de piedra con arco rúnico) — 384×688 (`create_ui_asset`, 40 gen c/u), aplicados por `scripts/ui/scene_background.gd` (`SceneBackground.add_to`) en `map_scene.gd` y `combat_scene.gd`. Van en un `CanvasLayer` propio (`layer=-5`, encima del fondo global de `main.gd` en `layer=-10`), con `STRETCH_KEEP_ASPECT_COVERED` (proporción casi idéntica al viewport 720×1280) y una capa de oscurecimiento (`DIM_COLOR`) para que texto/botones sigan legibles. Ambos PNG fueron limpiados de un patrón checker horneado (ver trampa de `no_background: false` abajo) — no regenerarlos sin repetir esa limpieza.
- **Transiciones y juice**: fundido de 0.35s entre escenas (overlay en `main.gd`), pop de cartas al tocarlas (`card_ui.gd`), sacudida al recibir daño y barra de claridad animada con flash (`combat_scene.gd`). Todo con `create_tween()`, sin AnimationPlayer.
- **Trampas de UI ya pisadas** (no repetirlas):
  - El tema **debe aplicarse por escena** en `_swap_to()`: la herencia de temas se corta en `Main`, que es un `Node` plano, así que `get_window().theme` por sí solo no viste nada.
  - **Nada de overrides `StyleBoxFlat`** en botones (`add_theme_stylebox_override`): pisan el botón arcano del tema. Si un botón debe verse distinto, cambiar el tema.
  - El `content_margin` de un `StyleBoxTexture` **no desplaza** a los hijos de un `PanelContainer`; hace falta un `MarginContainer` explícito (~60px, el ancho de la filigrana) o el texto se dibuja encima del marco.
  - `AcceptDialog` posiciona su `Label` y su `Button` con márgenes de layout **internos y fijos** que ignoran `content_margin` por completo — el panel ornamentado (con filigrana ancha) queda encima del texto y del botón "OK". Por eso `AcceptDialog` en `ui_theme.gd` usa un `StyleBoxFlat` liso con borde dorado en vez del panel arcano de `create_ui_asset`; no intentar volver a asignarle el panel.
  - `Main` es un `Node`, así que las escenas `Control` mostraban el gris por defecto de Godot: hay un `ColorRect` de fondo global en `CanvasLayer` layer −10 (`_build_background`).
  - Los lienzos de PixelLab dejan mucho aire alrededor del arte: `sprite_strip.gd` escala y centra por `get_used_rect()`, no por el tamaño del frame, o los personajes salen diminutos y descentrados.
  - `CenterContainer` **no expande a su hijo horizontalmente** (siempre le da su tamaño mínimo natural): un `Label` con `autowrap_mode` dentro calcula un ancho descontrolado y el panel se desborda del viewport. Para centrar texto dentro de un marco, usar `VBoxContainer` con `alignment = ALIGNMENT_CENTER` (respeta el ancho del padre, el texto envuelve) — no `CenterContainer`.
  - `Button.flat = true` pisa el `StyleBoxTexture`/`StyleBoxFlat` del estado `normal` aunque se asigne después con `add_theme_stylebox_override`: el anillo dorado de `ProfileButton` no se pintaba. No usar `flat` en botones tematizados; si se necesita "sin relleno visible", definir un stylebox con `bg_color` transparente pero borde opaco (como hace `ProfileButton`).
  - Un `VBoxContainer` de pantalla completa con `alignment = ALIGNMENT_CENTER` deja hueco muerto cuando el contenido es poco (se reparte igual arriba y abajo). En pantallas con contenido variable (perfil, mazo, diario) seguir el patrón de `deck_builder_scene.gd`: el layout fluye de arriba hacia abajo sin `ALIGNMENT_CENTER`, con el botón "← Volver" como primer hijo del mismo `VBoxContainer` (no en un `HBoxContainer` anclado aparte).
  - **No usar `OptionButton` con el tema arcano para listas de números cortos** (ej. días 1-31): se comprobó por consola que `text`, `font_color` y `size` son correctos, pero el glifo no se pinta en el frame capturado cuando el ítem es un texto corto tipo dígito, mientras que textos más largos (nombres de mes) sí se renderizan con el mismo código. No se identificó la causa exacta (posible interacción entre el `StyleBoxTexture` del botón y el layout interno del `OptionButton`); en vez de perseguir el bug, `identity_scene.gd` usa `SpinBox` para el día — más robusto para rangos numéricos y sin el defecto.
  - **`create_ui_asset` con `no_background: false` NO deja fondo transparente ni sólido**: hornea un patrón checker gris de dos tonos como píxeles RGBA opacos (`alpha=255`), indistinguible a simple vista de la transparencia real que muestra el visor de imágenes. Detectarlo llevó varias hipótesis descartadas (orden de capas, `CanvasLayer` vs `move_child`, importación corrupta) hasta verificar con `Image.detect_alpha()` en Godot y decodificar el PNG a mano — el color de la "zona sospechosa" resultó ser un gris opaco real, no transparencia. Fix: tras descargar, convertir a `alpha=0` cualquier píxel gris claro y desaturado (`min(r,g,b) > 195` y `max-min < 10`) con un script; **o generar directamente con `no_background: true`** para evitar el problema de raíz. `assets/backgrounds/*.png` ya están limpiados; si se regeneran, repetir la limpieza.
  - **Fondos ambientales full-bleed necesitan proporción 9:16 real**, no cuadrada: `create_map_object` tiene tope 400×400 (aspecto 1:1), que al cubrir un viewport 720×1280 con `STRETCH_KEEP_ASPECT_COVERED` recorta la composición de forma extrema. `create_ui_asset` sí permite 384×688 (9:16, 40 gen c/u) — úsalo para fondos de pantalla completa aunque cueste más que `create_map_object`.
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

Export móvil y monetización.
