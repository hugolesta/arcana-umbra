extends Control
## Pantalla de opciones: preferencias del jugador que no son parte de la
## identidad ni del progreso del run. Por ahora solo el mundo explorable
## (WorldScene/CaveScene) antes del combate; se guarda en GameState y
## persiste entre sesiones (progress.save).

signal back_requested


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_right = -16
	layout.offset_top = 16
	layout.offset_bottom = -16
	layout.add_theme_constant_override("separation", 16)
	add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var back := Button.new()
	back.text = "← Volver"
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "  Opciones"
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)

	layout.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)

	var toggle := CheckButton.new()
	toggle.button_pressed = GameState.explorable_world_enabled
	toggle.toggled.connect(func(pressed: bool):
		GameState.set_explorable_world_enabled(pressed))
	row.add_child(toggle)

	var label := VBoxContainer.new()
	row.add_child(label)
	var label_title := Label.new()
	label_title.text = "Mundo explorable antes del combate"
	label.add_child(label_title)
	var label_hint := Label.new()
	label_hint.text = "Explorar un mundo de césped y una cueva antes de cada combate."
	label_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_hint.modulate = Color(1, 1, 1, 0.6)
	label_hint.add_theme_font_size_override("font_size", 14)
	label.add_child(label_hint)
