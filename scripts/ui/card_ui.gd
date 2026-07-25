class_name CardUI
extends Button
## Botón que representa una carta en mano o en el constructor de mazo.

var card: CardData


func _init(p_card: CardData) -> void:
	card = p_card
	custom_minimum_size = Vector2(150, 230)
	clip_text = true
	_build_content()
	# Juice: la carta responde al tacto con un pequeño pop.
	resized.connect(func(): pivot_offset = size / 2.0)
	button_down.connect(func(): _pop(0.94))
	button_up.connect(func(): _pop(1.0))
	mouse_entered.connect(func(): _pop(1.04))
	mouse_exited.connect(func(): _pop(1.0))


func _pop(target: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * target, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_content() -> void:
	# Margen interior: el marco del botón arcano es ornamentado y el
	# contenido debe quedar dentro, no encima de la filigrana.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var name_label := Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
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
	info.text = "%s · %d" % [card.type_name(), card.cost]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(info)

	var plays := Label.new()
	plays.text = card.possible_plays
	plays.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plays.add_theme_font_size_override("font_size", 9)
	plays.clip_text = true
	plays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plays)
