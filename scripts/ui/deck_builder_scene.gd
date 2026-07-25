extends Control
## Constructor de mazo placeholder: lista el mazo actual y la colección
## completa de 78 cartas. Tocar una carta muestra su ficha de tarot.

signal back_requested


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 16
	layout.offset_right = -16
	layout.offset_top = 16
	layout.offset_bottom = -16
	add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var back := Button.new()
	back.text = "← Volver"
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "  Mazo: %d cartas · Colección: %d" % [
		GameState.mazo_permanente.size(), GameState.all_cards.size()]
	top.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for card in GameState.all_cards:
		var card_ui := CardUI.new(card)
		if card in GameState.mazo_permanente:
			card_ui.modulate = Color(1.0, 0.9, 0.5)
		card_ui.pressed.connect(_show_card_detail.bind(card))
		grid.add_child(card_ui)


func _show_card_detail(card: CardData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = card.card_name
	var meta: Array[String] = []
	if card.planet:
		meta.append("Planeta: %s" % card.planet)
	if card.zodiac_sign:
		meta.append("Signo: %s" % card.zodiac_sign)
	if card.element:
		meta.append("Elemento: %s" % card.element)
	if GameState.cartas_integradas.has(card.card_name):
		meta.append("✦ Integrada")
	dialog.dialog_text = "%s\n%s\n\n%s\n\nJugadas: %s" % [
		" · ".join(meta), card.description,
		card.upright_meaning.left(400) + "…", card.possible_plays]
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(600, 0)
	add_child(dialog)
	dialog.popup_centered()
