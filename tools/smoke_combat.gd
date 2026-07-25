extends Node
## Smoke test del combate: instancia CombatScene real, comprueba las
## animaciones de personaje, juega una carta y termina un turno. Uso:
##   godot --headless --path . res://tools/SmokeCombat.tscn
## Sale con código 0 si todo va bien; imprime FALLO y sale con 1 si no.

var _frames := 0
var _combat: Node


func _ready() -> void:
	_combat = load("res://scenes/CombatScene.tscn").instantiate()
	add_child(_combat)
	var node := MapNode.new()
	node.node_type = MapNode.NodeType.JEFE_SOMBRA
	node.floor_index = 4
	_combat.setup(node)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10:
		var failures: Array[String] = []
		if _combat._enemy_holder == null:
			failures.append("la Sombra no usa animación de personaje")
		if _combat._viajero_holder == null:
			failures.append("el Viajero no usa animación de personaje")
		if _combat.manager.hand.size() != 5:
			failures.append("mano inicial != 5")
		if _combat.manager.ai == null or _combat.manager.ai.archetype != "jefe_sombra":
			failures.append("la IA no usa el arquetipo del nodo")
		if _combat.manager._intent_description().is_empty():
			failures.append("no hay intención telegrafiada")
		if failures.is_empty():
			_combat.manager.play_card(_combat.manager.hand[0])
			_combat.manager.end_turn()
			if _combat.manager.state != CombatManager.State.JUGADOR_ACCIONA:
				failures.append("el turno no volvió al jugador tras la acción enemiga")
		if not failures.is_empty():
			for f in failures:
				print("FALLO: ", f)
			get_tree().quit(1)
	if _frames == 30:
		print("SMOKE COMBATE: OK (animaciones, intención de la Sombra, carta jugada, turno resuelto)")
		get_tree().quit(0)
