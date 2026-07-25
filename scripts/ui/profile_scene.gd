extends Control
## Pantalla de perfil: retrato animado del Viajero, nick editable y un
## resumen del progreso del jugador (cartas integradas, entradas del diario).

signal back_requested

const PORTRAIT_SIZE := 200.0
const VIAJERO_IDLE_DIR := "res://assets/personajes/viajero/idle_south"
const VIAJERO_SPRITE := "res://assets/viajero/viajero.png"

var _nick_edit: LineEdit
var _nick_label: Label
var _editing := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24
	layout.offset_right = -24
	layout.offset_top = 24
	layout.offset_bottom = -24
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var back := Button.new()
	back.text = "← Volver"
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)

	var title := Label.new()
	title.text = "Perfil del Viajero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	layout.add_child(title)

	var portrait_slot := CenterContainer.new()
	layout.add_child(portrait_slot)
	var portrait := SpriteStrip.make_animated_control(VIAJERO_IDLE_DIR, PORTRAIT_SIZE)
	if portrait == null and ResourceLoader.exists(VIAJERO_SPRITE):
		portrait = TextureRect.new()
		portrait.texture = load(VIAJERO_SPRITE)
		portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if portrait:
		portrait_slot.add_child(portrait)

	_build_nick_row(layout)

	var stats_panel := PanelContainer.new()
	layout.add_child(stats_panel)
	var stats_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		stats_margin.add_theme_constant_override("margin_" + side, 60)
	stats_panel.add_child(stats_margin)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats_margin.add_child(stats)
	_add_stat_row(stats, "Cartas en el mazo", str(GameState.mazo_permanente.size()))
	_add_stat_row(stats, "Cartas integradas", str(GameState.cartas_integradas.size()))
	_add_stat_row(stats, "Reflexiones en el diario", str(GameState.journal_entries.size()))
	_add_stat_row(stats, "Esencia", str(GameState.esencia))
	_add_stat_row(stats, "Claridad",
		"%d/%d" % [GameState.player_claridad, GameState.player_max_claridad])


func _build_nick_row(layout: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	layout.add_child(row)

	_nick_label = Label.new()
	_nick_label.text = GameState.player_nick
	_nick_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_nick_label)

	_nick_edit = LineEdit.new()
	_nick_edit.text = GameState.player_nick
	_nick_edit.max_length = 20
	_nick_edit.custom_minimum_size.x = 220
	_nick_edit.visible = false
	_nick_edit.text_submitted.connect(func(_t): _confirm_nick())
	_nick_edit.focus_exited.connect(_confirm_nick)
	row.add_child(_nick_edit)

	var edit_button := Button.new()
	edit_button.text = "Editar"
	edit_button.pressed.connect(_start_editing)
	row.add_child(edit_button)


func _start_editing() -> void:
	_editing = true
	_nick_label.visible = false
	_nick_edit.visible = true
	_nick_edit.text = GameState.player_nick
	_nick_edit.grab_focus()
	_nick_edit.select_all()


func _confirm_nick() -> void:
	if not _editing:
		return
	_editing = false
	GameState.set_player_nick(_nick_edit.text)
	_nick_label.text = GameState.player_nick
	_nick_label.visible = true
	_nick_edit.visible = false


func _add_stat_row(container: VBoxContainer, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	row.add_child(value)
