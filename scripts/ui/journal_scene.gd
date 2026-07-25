extends Control
## Diario del Viajero: lista las reflexiones guardadas en los eventos
## (persisten entre runs en user://journal.save). Tocar una entrada abre
## el texto completo con su carta y su pregunta.

signal back_requested


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_right = -16
	layout.offset_top = 16
	layout.offset_bottom = -16
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var back := Button.new()
	back.text = "← Volver"
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "  Diario del Viajero — %d reflexiones · %d cartas integradas" % [
		GameState.journal_entries.size(), GameState.cartas_integradas.size()]
	top.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	if GameState.journal_entries.is_empty():
		var empty := Label.new()
		empty.text = "Aún no hay reflexiones.\nLas escribirás en los nodos de Evento del mapa."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(1, 1, 1, 0.6)
		list.add_child(empty)
		return

	var entries := GameState.journal_entries.duplicate()
	entries.reverse()  # más recientes primero
	for entry in entries:
		var button := Button.new()
		var orientation := " (invertida)" if entry.get("invertida", false) else ""
		button.text = "%s — %s%s" % [
			str(entry.get("fecha", "")).split("T")[0],
			entry.get("carta", "¿?"), orientation]
		button.custom_minimum_size.y = 48
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_entry.bind(entry))
		list.add_child(button)


func _show_entry(entry: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	var orientation := " (invertida)" if entry.get("invertida", false) else ""
	dialog.title = str(entry.get("carta", "Reflexión")) + orientation
	var text: String = str(entry.get("texto", ""))
	if text.is_empty():
		text = "(sin texto)"
	dialog.dialog_text = "%s\n\n%s\n\n%s" % [
		entry.get("fecha", ""), entry.get("pregunta", ""), text]
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(600, 0)
	add_child(dialog)
	dialog.popup_centered()
