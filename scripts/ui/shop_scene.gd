extends Control
## Tienda — El Mercader de Umbrales: 3 cartas al azar en venta (las cartas
## integradas cuestan la mitad) y la opción de quitar una carta del mazo
## (una por visita). Todo se paga con esencia, la moneda del run.

signal finished

const REMOVE_PRICE := 30
const OFFER_COUNT := 3

var _node: MapNode
var _offers: Array[CardData] = []
var _removed_this_visit := false
var _esencia_label: Label
var _offers_box: HBoxContainer
var _remove_button: Button
var _status_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(node: MapNode) -> void:
	_node = node
	var pool: Array[CardData] = GameState.all_cards.duplicate()
	pool.shuffle()
	for i in range(mini(OFFER_COUNT, pool.size())):
		_offers.append(pool[i])
	_build_ui()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24
	layout.offset_right = -24
	layout.offset_top = 24
	layout.offset_bottom = -24
	layout.add_theme_constant_override("separation", 14)
	add_child(layout)

	var header := Label.new()
	header.text = "El Mercader de Umbrales"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color("c9a227"))
	layout.add_child(header)

	_esencia_label = Label.new()
	_esencia_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_esencia_label)

	var offers_scroll := ScrollContainer.new()
	offers_scroll.custom_minimum_size.y = 320
	offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(offers_scroll)

	_offers_box = HBoxContainer.new()
	_offers_box.add_theme_constant_override("separation", 16)
	offers_scroll.add_child(_offers_box)
	_rebuild_offers()

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(1.0, 0.9, 0.6)
	layout.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	_remove_button = Button.new()
	_remove_button.custom_minimum_size.y = 56
	_remove_button.pressed.connect(_open_remove_dialog)
	layout.add_child(_remove_button)

	var leave := Button.new()
	leave.text = "Seguir el camino"
	leave.custom_minimum_size.y = 56
	leave.pressed.connect(func(): finished.emit())
	layout.add_child(leave)

	_refresh()


func _rebuild_offers() -> void:
	for child in _offers_box.get_children():
		child.queue_free()
	for card in _offers:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		_offers_box.add_child(slot)

		var card_ui := CardUI.new(card)
		card_ui.pressed.connect(_buy.bind(card))
		slot.add_child(card_ui)

		var price := Label.new()
		var integrated := GameState.cartas_integradas.has(card.card_name)
		price.text = "%d esencia%s" % [GameState.card_price(card), " ✦" if integrated else ""]
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(price)


func _refresh() -> void:
	_esencia_label.text = "Esencia: %d" % GameState.esencia
	var can_remove := not _removed_this_visit \
			and GameState.mazo_permanente.size() > GameState.MIN_DECK_SIZE
	_remove_button.text = "Quitar una carta del mazo (%d esencia)" % REMOVE_PRICE
	_remove_button.disabled = not can_remove or GameState.esencia < REMOVE_PRICE


func _buy(card: CardData) -> void:
	if GameState.buy_card(card):
		_offers.erase(card)
		_status_label.text = "%s se une a tu mazo." % card.card_name
		_rebuild_offers()
	else:
		_status_label.text = "No tienes esencia suficiente."
	_refresh()


func _open_remove_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Quitar una carta (%d esencia)" % REMOVE_PRICE
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)
	dialog.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for card in GameState.mazo_permanente:
		var button := Button.new()
		button.text = "%s · %s" % [card.card_name, card.type_name()]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func():
			_remove(card)
			dialog.hide()
			dialog.queue_free())
		list.add_child(button)
	add_child(dialog)
	dialog.popup_centered()


func _remove(card: CardData) -> void:
	if GameState.remove_card(card, REMOVE_PRICE):
		_removed_this_visit = true
		_status_label.text = "%s se disuelve en la umbra." % card.card_name
	else:
		_status_label.text = "No puedes quitar esa carta."
	_refresh()
