class_name Combatant
extends RefCounted
## Estado de un participante del combate (el Viajero o una Sombra).
## La "claridad" funciona como la vida: si llega a 0, el combate termina.

signal claridad_changed(new_value: int, max_value: int)
signal shield_changed(new_value: int)
signal disonancia_changed(new_value: int)
signal defeated

var display_name: String = "Viajero"
var max_claridad: int = 50
var claridad: int = 50
var shield: int = 0
var disonancia: int = 0
var base_attack: int = 6


func _init(p_name: String = "Viajero", p_max_claridad: int = 50, p_attack: int = 6) -> void:
	display_name = p_name
	max_claridad = p_max_claridad
	claridad = p_max_claridad
	base_attack = p_attack


func take_damage(amount: int) -> void:
	var absorbed: int = mini(shield, amount)
	shield -= absorbed
	shield_changed.emit(shield)
	var remaining: int = amount - absorbed
	if remaining > 0:
		claridad = maxi(claridad - remaining, 0)
		claridad_changed.emit(claridad, max_claridad)
		if claridad == 0:
			defeated.emit()


func heal(amount: int) -> void:
	claridad = mini(claridad + amount, max_claridad)
	claridad_changed.emit(claridad, max_claridad)


func add_shield(amount: int) -> void:
	shield += amount
	shield_changed.emit(shield)


func add_disonancia(amount: int) -> void:
	disonancia += amount
	disonancia_changed.emit(disonancia)


func attack_value() -> int:
	# La disonancia debilita el próximo ataque y luego se disipa a la mitad.
	var value: int = maxi(base_attack - disonancia, 1)
	disonancia = disonancia / 2
	disonancia_changed.emit(disonancia)
	return value


func reset_shield() -> void:
	shield = 0
	shield_changed.emit(shield)
