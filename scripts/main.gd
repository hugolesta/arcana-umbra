extends Node
## Escena raíz: alterna entre mapa, combate y constructor de mazo.

const TITLE_SCENE := "res://scenes/TitleScene.tscn"
const MAP_SCENE := "res://scenes/MapScene.tscn"
const COMBAT_SCENE := "res://scenes/CombatScene.tscn"
const DECK_SCENE := "res://scenes/DeckBuilderScene.tscn"
const EVENT_SCENE := "res://scenes/EventScene.tscn"
const JOURNAL_SCENE := "res://scenes/JournalScene.tscn"
const SHOP_SCENE := "res://scenes/ShopScene.tscn"

var _current: Node
var _fade: ColorRect


func _ready() -> void:
	get_window().theme = UITheme.get_cached()
	_build_background()
	_build_fade_overlay()
	show_title()


func _build_background() -> void:
	# Fondo global del juego: sin él, las escenas Control muestran el gris
	# por defecto de Godot entre sus elementos.
	var background := ColorRect.new()
	background.color = UITheme.COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	layer.add_child(background)


func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.12, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func show_title() -> void:
	var title: Node = _swap_to(TITLE_SCENE)
	title.continue_requested.connect(show_map)
	title.new_run_requested.connect(func():
		GameState.start_new_run()
		show_map())
	title.deck_requested.connect(show_deck_builder.bind(true))
	title.journal_requested.connect(show_journal)


func show_journal() -> void:
	var journal: Node = _swap_to(JOURNAL_SCENE)
	journal.back_requested.connect(show_title)


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
		MapNode.NodeType.EVENTO:
			_start_event(node)
		MapNode.NodeType.TIENDA:
			_start_shop(node)


func _start_shop(node: MapNode) -> void:
	var shop: Node = _swap_to(SHOP_SCENE)
	shop.setup(node)
	shop.finished.connect(func():
		GameState.mark_visited(node)
		show_map())


func _start_event(node: MapNode) -> void:
	var event: Node = _swap_to(EVENT_SCENE)
	event.setup(node)
	event.finished.connect(func():
		GameState.mark_visited(node)
		show_map())


func _start_combat(node: MapNode) -> void:
	var combat: Node = _swap_to(COMBAT_SCENE)
	combat.setup(node)
	combat.finished.connect(_on_combat_finished.bind(node))


func _on_combat_finished(victory: bool, node: MapNode) -> void:
	if victory:
		GameState.add_esencia(GameState.esencia_reward_for(node.node_type))
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
	# La herencia de temas se corta en Main (Node plano): aplicar por escena.
	if _current is Control:
		_current.theme = UITheme.get_cached()
	add_child(_current)
	# Transición: la escena nueva entra con un fundido desde el color de fondo.
	if _fade:
		_fade.color.a = 1.0
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 0.0, 0.35) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return _current
