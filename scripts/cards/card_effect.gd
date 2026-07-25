class_name CardEffect
extends Resource
## Efecto base de una carta (patrón Strategy).
## Cada subclase en scripts/cards/effects/ implementa apply().
## caster y objective son Combatant (ver combat_manager.gd).

@export var amount: int = 0
@export var target: String = "enemy"  # "enemy" | "self"


## override_amount permite aplicar un valor efectivo distinto (p. ej. el bonus
## de carta integrada) sin mutar este Resource, que se comparte entre usos.
func apply(_caster: Combatant, _objective: Combatant, _override_amount: int = -1) -> void:
	push_warning("CardEffect.apply() sin implementar en la subclase")


func effective(override_amount: int) -> int:
	return override_amount if override_amount >= 0 else amount


func describe() -> String:
	return "Efecto genérico (%d)" % amount
