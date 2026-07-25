extends Node
## Smoke test del sistema de eventos/journaling. Uso:
##   godot --headless --path . res://tools/SmokeEvent.tscn
## Instancia EventScene real, guarda una reflexión y comprueba: entrada en el
## diario, persistencia en disco, carta integrada y claridad restaurada.
## Restaura el estado previo al terminar para no ensuciar el diario real.

var _frames := 0
var _event: Node
var _prev_claridad: int
var _prev_journal_size: int
var _prev_integradas: Array[String]


func _ready() -> void:
	_prev_journal_size = GameState.journal_entries.size()
	_prev_integradas = GameState.cartas_integradas.duplicate()
	GameState.player_claridad = maxi(GameState.player_claridad - 10, 1)
	_prev_claridad = GameState.player_claridad

	_event = load("res://scenes/EventScene.tscn").instantiate()
	add_child(_event)
	var node := MapNode.new()
	node.node_type = MapNode.NodeType.EVENTO
	node.floor_index = 2
	_event.setup(node)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames != 10:
		return
	var failures: Array[String] = []

	_event._text_edit.text = "reflexión de prueba (smoke test)"
	var card_name: String = _event._card.card_name
	_event._on_save_pressed()

	if GameState.journal_entries.size() != _prev_journal_size + 1:
		failures.append("la entrada no se añadió al diario")
	elif GameState.journal_entries[-1].get("texto", "") != "reflexión de prueba (smoke test)":
		failures.append("el texto de la entrada no coincide")
	if not GameState.cartas_integradas.has(card_name):
		failures.append("la carta no se integró")
	if GameState.player_claridad <= _prev_claridad:
		failures.append("la claridad no aumentó al reflexionar")

	# Persistencia: recargar el diario desde disco debe recuperar la entrada.
	GameState.journal_entries.clear()
	GameState.load_journal()
	if GameState.journal_entries.size() != _prev_journal_size + 1:
		failures.append("la entrada no persistió en user://journal.save")

	# Restaurar estado previo (no ensuciar el diario real del jugador).
	GameState.journal_entries.resize(_prev_journal_size)
	GameState.save_journal()
	GameState.cartas_integradas = _prev_integradas
	GameState.save_progress()

	if failures.is_empty():
		print("SMOKE EVENTO: OK (diario, persistencia, integración, claridad)")
		get_tree().quit(0)
	else:
		for f in failures:
			print("FALLO: ", f)
		get_tree().quit(1)
