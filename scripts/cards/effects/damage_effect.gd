class_name DamageEffect
extends CardEffect
## Inflige daño directo al objetivo (reduce claridad/hp, mitigado por escudo).


func apply(_caster: Combatant, objective: Combatant) -> void:
	objective.take_damage(amount)


func describe() -> String:
	return "Inflige %d de daño" % amount
