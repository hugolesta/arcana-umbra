class_name DisonanciaEffect
extends CardEffect
## Aplica disonancia a la Sombra: cada punto reduce en 1 su próximo ataque.


func apply(_caster: Combatant, objective: Combatant) -> void:
	objective.add_disonancia(amount)


func describe() -> String:
	return "Aplica %d de disonancia" % amount
