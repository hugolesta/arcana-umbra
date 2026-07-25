class_name ShieldEffect
extends CardEffect
## Otorga escudo temporal al lanzador (absorbe daño este turno).


func apply(caster: Combatant, _objective: Combatant, override_amount: int = -1) -> void:
	caster.add_shield(effective(override_amount))


func describe() -> String:
	return "Otorga %d de escudo" % amount
