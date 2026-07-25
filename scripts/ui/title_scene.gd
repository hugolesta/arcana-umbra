extends Control
## Pantalla de inicio: emblema pixel art, título y menú principal.
## Como el resto de la UI, se construye por código; el emblema viene de
## assets/ui/titulo_emblema.png (PixelLab) con fallback a solo texto.

signal continue_requested
signal new_run_requested
signal deck_requested
signal journal_requested

const EMBLEM_PATH := "res://assets/ui/titulo_emblema.png"

# Mismo color que el fondo opaco del emblema PixelLab, para fundirlo sin bordes.
const COLOR_BG := Color("13173a")
const COLOR_PANEL := Color("2d1b4e")
const COLOR_GOLD := Color("c9a227")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 60
	layout.offset_right = -60
	layout.offset_top = 80
	layout.offset_bottom = -80
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)

	if ResourceLoader.exists(EMBLEM_PATH):
		var emblem := TextureRect.new()
		emblem.texture = load(EMBLEM_PATH)
		emblem.custom_minimum_size = Vector2(320, 320)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layout.add_child(emblem)

	var title := Label.new()
	title.text = "Arcana Umbra"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Un viaje hacia la sombra"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	layout.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	layout.add_child(spacer)

	var has_run := not GameState.map_grid.is_empty() and GameState.current_node_coord.x >= 0
	if has_run:
		layout.add_child(_make_button("Continuar viaje", func(): continue_requested.emit()))
	layout.add_child(_make_button(
		"Nuevo viaje" if has_run else "Comenzar viaje",
		func(): new_run_requested.emit()))
	layout.add_child(_make_button("Ver mazo", func(): deck_requested.emit()))
	layout.add_child(_make_button(
		"Diario (%d)" % GameState.journal_entries.size(),
		func(): journal_requested.emit()))


func _make_button(text: String, on_pressed: Callable) -> Button:
	# Sin overrides de estilo: el botón arcano del tema global (ui_theme.gd)
	# es quien viste estos botones.
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(on_pressed)
	return button
