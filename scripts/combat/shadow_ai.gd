class_name ShadowAI
extends RefCounted
## IA de intenciones de las Sombras: cada arquetipo cicla un patrón de
## acciones que se telegrafía al jugador antes de su turno (estilo Slay
## the Spire). Sin dependencias de autoloads: testeable desde verify.gd.

enum Intent { ATACAR, ATAQUE_FUERTE, DEFENDER, ACECHAR, DRENAR }

const PATTERNS := {
	"sombra_menor": [Intent.ATACAR, Intent.ATACAR, Intent.DEFENDER],
	"sombra_elite": [Intent.ATACAR, Intent.ACECHAR, Intent.ATAQUE_FUERTE, Intent.DEFENDER],
	"jefe_sombra": [Intent.ACECHAR, Intent.ATAQUE_FUERTE, Intent.ATACAR, Intent.DRENAR],
}
# La Menor es errática: a veces rompe su patrón con una acción aleatoria.
const MENOR_CHAOS_CHANCE := 0.25

var archetype: String
var _step := -1


func _init(p_archetype: String = "sombra_menor") -> void:
	archetype = p_archetype if PATTERNS.has(p_archetype) else "sombra_menor"


func next_intent() -> Intent:
	var pattern: Array = PATTERNS[archetype]
	_step = (_step + 1) % pattern.size()
	if archetype == "sombra_menor" and randf() < MENOR_CHAOS_CHANCE:
		return pattern.pick_random()
	return pattern[_step]


## Valor base de la acción a partir del ataque de la Sombra (sin disonancia
## ni carga: eso lo resuelve CombatManager al ejecutar y al describir).
static func intent_value(intent: Intent, base_attack: int) -> int:
	match intent:
		Intent.ATACAR:
			return base_attack
		Intent.ATAQUE_FUERTE:
			return int(round(base_attack * 1.75))
		Intent.DEFENDER:
			return base_attack
		Intent.DRENAR:
			return maxi(base_attack / 2, 1)
	return 0  # ACECHAR no tiene valor propio


static func describe(intent: Intent, value: int) -> String:
	match intent:
		Intent.ATACAR:
			return "⚔ La Sombra atacará con %d" % value
		Intent.ATAQUE_FUERTE:
			return "💥 La Sombra prepara un golpe fuerte: %d" % value
		Intent.DEFENDER:
			return "🛡 La Sombra se ocultará (escudo %d)" % value
		Intent.ACECHAR:
			return "👁 La Sombra acecha: su próximo golpe hará ×1.5"
		Intent.DRENAR:
			return "🩸 La Sombra drenará %d de claridad (y se curará)" % value
	return ""
