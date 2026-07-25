extends Control
## Nodo de EVENTO — El Espejo del Viajero: se roba una carta del propio mazo
## (al derecho o invertida), se muestra su significado real y una pregunta
## introspectiva según su elemento. El jugador puede escribir en su diario:
## reflexionar restaura claridad e integra la carta (cartas_integradas).

signal finished

const REFLECTION_QUESTIONS := {
	"Fuego": [
		"¿Qué deseo estás postergando, y qué paso pequeño podrías dar hoy?",
		"¿Dónde pondrías tu energía si no temieras fallar?",
	],
	"Agua": [
		"¿Qué emoción llevas contigo ahora, y dónde la sientes en el cuerpo?",
		"¿Qué necesitarías perdonar —o perdonarte— para seguir adelante?",
	],
	"Aire": [
		"¿Qué pensamiento repites últimamente? ¿Es tuyo o heredado?",
		"¿Qué verdad estás evitando nombrar en voz alta?",
	],
	"Tierra": [
		"¿Qué te sostiene ahora mismo? ¿Qué cuidas y qué descuidas?",
		"¿Qué hábito pequeño te acercaría a la vida que quieres?",
	],
}
const FALLBACK_QUESTION := "¿Qué te muestra esta carta de ti que preferías no mirar?"

var _node: MapNode
var _card: CardData
var _reversed := false
var _question := FALLBACK_QUESTION
var _text_edit: TextEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(node: MapNode) -> void:
	_node = node
	var pool: Array[CardData] = GameState.mazo_permanente
	if pool.is_empty():
		pool = GameState.all_cards
	_card = pool.pick_random()
	_reversed = randf() < 0.5
	var questions: Array = REFLECTION_QUESTIONS.get(_card.element, [FALLBACK_QUESTION])
	_question = questions.pick_random()
	_build_ui()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24
	layout.offset_right = -24
	layout.offset_top = 24
	layout.offset_bottom = -24
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	var header := Label.new()
	header.text = "El Espejo del Viajero"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color("c9a227"))
	layout.add_child(header)

	if _card.icon:
		var image := TextureRect.new()
		image.texture = _card.icon
		image.custom_minimum_size = Vector2(140, 210)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.flip_h = _reversed
		image.flip_v = _reversed
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		layout.add_child(image)

	var card_label := Label.new()
	card_label.text = _card.card_name + (" (invertida)" if _reversed else "")
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(card_label)

	# El significado va dentro del panel arcano del tema (marco PixelLab).
	var meaning_panel := PanelContainer.new()
	meaning_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meaning_panel.custom_minimum_size.y = 260
	layout.add_child(meaning_panel)

	# MarginContainer explícito: el content_margin del StyleBoxTexture no
	# desplaza a los hijos de un PanelContainer con scroll dentro.
	var meaning_margin := MarginContainer.new()
	# 60px: la filigrana del marco arcano ocupa ~56px por lado.
	for side in ["left", "right", "top", "bottom"]:
		meaning_margin.add_theme_constant_override("margin_" + side, 60)
	meaning_panel.add_child(meaning_margin)

	var meaning_scroll := ScrollContainer.new()
	meaning_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	meaning_margin.add_child(meaning_scroll)

	# VBoxContainer con ALIGNMENT_CENTER: a diferencia de CenterContainer,
	# respeta el ancho disponible del padre (el texto envuelve dentro del
	# marco) mientras centra el bloque verticalmente si sobra espacio.
	var meaning_center := VBoxContainer.new()
	meaning_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meaning_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meaning_center.alignment = BoxContainer.ALIGNMENT_CENTER
	meaning_scroll.add_child(meaning_center)

	var meaning := Label.new()
	meaning.text = _card.reversed_meaning if _reversed else _card.upright_meaning
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meaning_center.add_child(meaning)

	var question_label := Label.new()
	question_label.text = _question
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.modulate = Color(1.0, 0.9, 0.6)
	question_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(question_label)

	_text_edit = TextEdit.new()
	_text_edit.placeholder_text = "Escribe aquí tu reflexión (opcional)…"
	_text_edit.custom_minimum_size.y = 140
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	layout.add_child(_text_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	var skip := Button.new()
	skip.text = "Seguir el camino"
	skip.custom_minimum_size.y = 56
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(func(): finished.emit())
	buttons.add_child(skip)

	var save := Button.new()
	save.text = "Guardar en el diario (+%d claridad)" % GameState.EVENT_CLARIDAD_REWARD
	save.custom_minimum_size.y = 56
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_on_save_pressed)
	buttons.add_child(save)


func _on_save_pressed() -> void:
	GameState.reflect_on_card(_card, _reversed, _question, _text_edit.text.strip_edges())
	finished.emit()
