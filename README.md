# Arcana Umbra

Roguelike deckbuilder de tarot e introspección (estilo *Slay the Spire*), construido en **Godot 4.5 / GDScript** con orientación vertical y renderer Mobile, pensado para Android/iOS.

Las 78 cartas Rider-Waite (significado al derecho y al reverso, elemento, signo, planeta y jugadas posibles) provienen del proyecto interno **elarboldelavida.com.ar/tarot-rider-waite** (`/Users/hugo.lesta/Desktop/Projects/hugolesta/Kabbalah`, fuente de solo lectura).

> Nota de versión: el prompt original fijaba Godot 4.4 stable, pero la versión instalada en esta máquina es **Godot 4.5.1 stable**, así que el proyecto se configuró para 4.5 (`config/features`). Todo el código es GDScript estándar compatible con 4.4+.

## Cómo abrir y ejecutar

1. Abre **Godot 4.5** → *Import* → selecciona `project.godot` de esta carpeta.
2. Pulsa **F5** (ejecutar proyecto). La escena principal es `scenes/Main.tscn`.
3. Flujo jugable actual:
   - **Mapa procedural** (15 pisos, 3-6 nodos por piso, DAG estilo Slay the Spire). Los nodos dorados son elegibles.
   - **Combate placeholder**: mano de 5 cartas, 3 de energía por turno; Espadas dañan, Oros dan escudo, Copas curan, Bastos aplican disonancia, Arcanos Mayores combinan dos efectos según su elemento.
   - **Descanso** recupera claridad; **Tienda/Evento** son placeholders (marcan el nodo y avanzan).
   - Botón **Mazo** en el mapa: colección completa de 78 cartas con su ficha de tarot.
4. El progreso del run (mapa, mazo, claridad) se guarda automáticamente en `user://progress.save` (JSON).

## Estructura

```
project.godot                  Godot 4.5, renderer Mobile, 720x1280 portrait
scenes/                        Main, MapScene, CombatScene, DeckBuilderScene (UI construida por código)
scripts/
├── autoload/game_state.gd     Meta-progresión, mazo, guardado JSON (autoload GameState)
├── cards/card_data.gd         Resource CardData (78 .tres en resources/cards/)
├── cards/card_effect.gd       Efecto base (patrón Strategy)
├── cards/effects/             DamageEffect, HealEffect, ShieldEffect, DisonanciaEffect
├── combat/combatant.gd        Estado de Viajero/Sombra (claridad, escudo, disonancia)
├── combat/combat_manager.gd   Máquina de estados del combate (señales, sin UI)
├── map/map_node.gd            Nodo del mapa (Resource serializable)
└── map/map_generator.gd       Generador del DAG (15 pisos, columnas adyacentes, todo alcanzable)
resources/cards/               78 CardData .tres generados desde los datos de Kabbalah
assets/cards/                  78 imágenes .webp (copiadas de Kabbalah)
tools/                         Pipeline de datos (ver abajo)
```

## Regenerar las cartas si cambia la fuente

```bash
# 1. Re-extraer datos del HTML de Kabbalah -> tools/cards.json
python3 tools/extract_cards.py

# 2. Regenerar los 78 .tres en resources/cards/
python3 tools/generate_tres.py

# 3. (Si cambiaron las imágenes) re-copiarlas
cp /Users/hugo.lesta/Desktop/Projects/hugolesta/Kabbalah/cards/*.webp assets/cards/
```

El proyecto Kabbalah nunca se modifica: es únicamente fuente de datos.

## Fuera de alcance en esta fase (por diseño)

- IA de enemigos, balance de cartas y UI final.
- Tienda, eventos/journaling y sistema de Integración completo.
- Presets de export Android/iOS, monetización, addons de terceros (solo GDScript nativo).
