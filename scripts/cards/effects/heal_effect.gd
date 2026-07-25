class_name HealEffect
extends CardEffect
## Restaura claridad (vida) al lanzador.


func apply(caster: Combatant, _objective: Combatant, override_amount: int = -1) -> void:
	caster.heal(effective(override_amount))


func describe() -> String:
	return "Restaura %d de claridad" % amount
