extends Control
## Renderiza el mapa procedural: nodos como botones, conexiones con Line2D.
## Solo los nodos con available = true son clickeables.

signal node_selected(node: MapNode)
signal deck_requested
signal profile_requested

const FLOOR_HEIGHT := 150.0
const NODE_SIZE := Vector2(96, 96)
const TOP_BAR_HEIGHT := 72.0
const ICON_DIR := "res://assets/map_icons"
const BACKGROUND_PATH := "res://assets/backgrounds/mapa_bosque.png"

var _canvas: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SceneBackground.add_to(self, BACKGROUND_PATH)
	_build_top_bar()
	_build_scrollable_map()


func _build_top_bar() -> void:
	# Fondo opaco propio (ColorRect, no stylebox: HBoxContainer no pinta
	# "panel"): la barra debe leerse encima de la ilustración de fondo.
	var bar_bg := ColorRect.new()
	bar_bg.color = UITheme.COLOR_BG
	bar_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_bg.custom_minimum_size.y = TOP_BAR_HEIGHT
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = TOP_BAR_HEIGHT
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	var profile := ProfileButton.new()
	profile.profile_requested.connect(func(): profile_requested.emit())
	bar.add_child(profile)

	var claridad := Label.new()
	claridad.text = "  Claridad: %d/%d · Esencia: %d" % [
		GameState.player_claridad, GameState.player_max_claridad, GameState.esencia]
	claridad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(claridad)

	var deck_button := Button.new()
	deck_button.text = "Mazo (%d)  " % GameState.mazo_permanente.size()
	deck_button.flat = true
	deck_button.pressed.connect(func(): deck_requested.emit())
	bar.add_child(deck_button)


func _build_scrollable_map() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = TOP_BAR_HEIGHT
	add_child(scroll)

	var floors: int = GameState.map_grid.size()
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(720, floors * FLOOR_HEIGHT + 60)
	scroll.add_child(_canvas)

	for floor_nodes in GameState.map_grid:
		for node in floor_nodes:
			_draw_connections(node)
	for floor_nodes in GameState.map_grid:
		for node in floor_nodes:
			_place_node_button(node)

	# Empezar el scroll abajo (piso 0), donde arranca el run.
	scroll.get_v_scroll_bar().value = _canvas.custom_minimum_size.y
	await get_tree().process_frame
	scroll.scroll_vertical = int(_canvas.custom_minimum_size.y)


func _node_position(node: MapNode) -> Vector2:
	var floors: int = GameState.map_grid.size()
	var count: int = GameState.map_grid[node.floor_index].size()
	var spacing := 720.0 / (count + 1)
	var x := spacing * (node.column + 1)
	var y := (floors - node.floor_index) * FLOOR_HEIGHT
	return Vector2(x, y)


func _draw_connections(node: MapNode) -> void:
	var from := _node_position(node)
	for coord in node.connections:
		var target: MapNode = GameState.get_node_at(coord)
		if target == null:
			continue
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(1, 1, 1, 0.25)
		line.add_point(from)
		line.add_point(_node_position(target))
		_canvas.add_child(line)


func _place_node_button(node: MapNode) -> void:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.position = _node_position(node) - NODE_SIZE / 2.0
	button.disabled = not node.available or node.visited
	if node.visited:
		button.modulate = Color(0.5, 0.5, 0.5)
	elif node.available:
		button.modulate = Color(1.0, 0.9, 0.5)
	button.pressed.connect(func(): node_selected.emit(node))

	# Icono pixel art (assets/map_icons/<tipo>.png) sobre la etiqueta.
	var icon := _icon_for(node)
	if icon:
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)

		var image := TextureRect.new()
		image.texture = icon
		image.custom_minimum_size = Vector2(48, 48)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(image)

		var label := Label.new()
		label.text = node.type_label()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	else:
		button.text = node.type_label()
	_canvas.add_child(button)


func _icon_for(node: MapNode) -> Texture2D:
	var key: String = MapNode.NodeType.keys()[node.node_type].to_lower()
	var path := ICON_DIR.path_join(key + ".png")
	if ResourceLoader.exists(path):
		return load(path)
	return null
