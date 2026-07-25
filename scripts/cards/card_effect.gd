class_name CardEffect
extends Resource
## Efecto base de una carta (patrón Strategy).
## Cada subclase en scripts/cards/effects/ implementa apply().
## caster y objective son Combatant (ver combat_manager.gd).

@export var amount: int = 0
@export var target: String = "enemy"  # "enemy" | "self"


func apply(_caster: Combatant, _objective: Combatant) -> void:
	push_warning("CardEffect.apply() sin implementar en la subclase")


func describe() -> String:
	return "Efecto genérico (%d)" % amount
