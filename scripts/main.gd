extends Node
## Escena raíz: alterna entre mapa, combate y constructor de mazo.

const TITLE_SCENE := "res://scenes/TitleScene.tscn"
const MAP_SCENE := "res://scenes/MapScene.tscn"
const COMBAT_SCENE := "res://scenes/CombatScene.tscn"
const DECK_SCENE := "res://scenes/DeckBuilderScene.tscn"

var _current: Node


func _ready() -> void:
	show_title()


func show_title() -> void:
	var title: Node = _swap_to(TITLE_SCENE)
	title.continue_requested.connect(show_map)
	title.new_run_requested.connect(func():
		GameState.start_new_run()
		show_map())
	title.deck_requested.connect(show_deck_builder.bind(true))


func show_map() -> void:
	var map: Node = _swap_to(MAP_SCENE)
	map.node_selected.connect(_on_map_node_selected)
	map.deck_requested.connect(show_deck_builder)


func show_deck_builder(from_title: bool = false) -> void:
	var deck: Node = _swap_to(DECK_SCENE)
	deck.back_requested.connect(show_title if from_title else show_map)


func _on_map_node_selected(node: MapNode) -> void:
	match node.node_type:
		MapNode.NodeType.COMBATE, MapNode.NodeType.ELITE, MapNode.NodeType.JEFE_SOMBRA:
			_start_combat(node)
		MapNode.NodeType.DESCANSO:
			GameState.player_claridad = mini(
				GameState.player_claridad + 15, GameState.player_max_claridad)
			GameState.mark_visited(node)
			show_map()
		MapNode.NodeType.TIENDA, MapNode.NodeType.EVENTO:
			# Placeholder: tienda y eventos/journaling llegan en la próxima fase.
			GameState.mark_visited(node)
			show_map()


func _start_combat(node: MapNode) -> void:
	var combat: Node = _swap_to(COMBAT_SCENE)
	combat.setup(node)
	combat.finished.connect(_on_combat_finished.bind(node))


func _on_combat_finished(victory: bool, node: MapNode) -> void:
	if victory:
		GameState.mark_visited(node)
		if GameState.run_completed():
			GameState.start_new_run()
	else:
		GameState.start_new_run()
	show_map()


func _swap_to(scene_path: String) -> Node:
	if _current:
		_current.queue_free()
	_current = load(scene_path).instantiate()
	add_child(_current)
	return _current
