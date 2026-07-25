class_name CardUI
extends Button
## Botón que representa una carta en mano o en el constructor de mazo.

var card: CardData


func _init(p_card: CardData) -> void:
	card = p_card
	custom_minimum_size = Vector2(140, 210)
	clip_text = true
	_build_content()


func _build_content() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var name_label := Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	if card.icon:
		var image := TextureRect.new()
		image.texture = card.icon
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(image)

	var info := Label.new()
	info.text = "%s · Coste %d" % [card.type_name(), card.cost]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(info)

	var plays := Label.new()
	plays.text = card.possible_plays
	plays.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plays.add_theme_font_size_override("font_size", 11)
	plays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plays)
