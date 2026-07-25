class_name DisonanciaEffect
extends CardEffect
## Aplica disonancia a la Sombra: cada punto reduce en 1 su próximo ataque.


func apply(_caster: Combatant, objective: Combatant, override_amount: int = -1) -> void:
	objective.add_disonancia(effective(override_amount))


func describe() -> String:
	return "Aplica %d de disonancia" % amount
