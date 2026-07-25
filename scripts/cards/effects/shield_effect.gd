class_name ShieldEffect
extends CardEffect
## Otorga escudo temporal al lanzador (absorbe daño este turno).


func apply(caster: Combatant, _objective: Combatant) -> void:
	caster.add_shield(amount)


func describe() -> String:
	return "Otorga %d de escudo" % amount
