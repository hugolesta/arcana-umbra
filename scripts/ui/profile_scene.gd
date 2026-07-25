extends Control
## Pantalla de perfil: retrato animado del Viajero, nombre y signo zodiacal
## (fijos de por vida, definidos en IdentityScene) y un resumen del progreso
## del jugador (cartas integradas, entradas del diario).

signal back_requested

const PORTRAIT_SIZE := 200.0
const VIAJERO_IDLE_DIR := "res://assets/personajes/viajero/idle_south"
const VIAJERO_SPRITE := "res://assets/viajero/viajero.png"
const ZODIAC_DIR := "res://assets/zodiaco"


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

	_build_identity_row(layout)

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


func _build_identity_row(layout: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)

	var nick_label := Label.new()
	nick_label.text = GameState.player_nick
	nick_label.add_theme_font_size_override("font_size", 22)
	row.add_child(nick_label)

	if not GameState.zodiac_sign.is_empty():
		var icon_path := ZODIAC_DIR.path_join(
			Zodiac.sign_key(GameState.zodiac_sign) + ".png")
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(icon)

		var sign_label := Label.new()
		sign_label.text = GameState.zodiac_sign
		sign_label.add_theme_font_size_override("font_size", 16)
		sign_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
		row.add_child(sign_label)


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
