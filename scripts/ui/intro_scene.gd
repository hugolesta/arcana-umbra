extends Control
## Escena narrativa de apertura: se muestra UNA SOLA VEZ, antes de
## IdentityScene, la primera vez que el jugador inicia "Nuevo viaje"
## (misma condición que identity_defined == false). El Viajero despierta
## sin memoria, sentado ante una mesa, jugando a las cartas: el guion
## presenta el mundo de Arcana Umbra y termina pidiendo al jugador nombre
## y fecha de nacimiento, punto en el que la escena delega a IdentityScene
## (no captura esos datos ella misma).

signal finished

const SCRIPT_BLOCKS: Array[String] = [
	"Abres los ojos y no reconoces el lugar.\n\nUna mesa de madera vieja, iluminada por una vela que no titila. Frente a ti, un mazo de cartas boca abajo, como si alguien —tú, quizás— lo hubiera dejado a medio repartir hace un instante o hace mil años.",
	"No recuerdas cómo llegaste aquí.\nNo recuerdas el camino, ni la puerta, ni el paso anterior a este.\n\nSolo la mesa. Solo las cartas. Solo esta quietud que pesa como el fondo de un pozo.",
	"Levantas la primera carta. En el dorso, un patrón que no habías visto y que sin embargo reconoces, del mismo modo en que se reconoce una voz en sueños.\n\nEste lugar tiene un nombre. Te llega despacio, como si lo dijeras por primera vez y por enésima vez a la vez: Arcana Umbra.",
	"Aquí, dicen las cartas, cada persona carga una Sombra propia. No un monstruo externo: un reflejo. Duda, miedo, orgullo, pérdida — todo lo que no se mira de frente, vuelto forma y filo.\n\nY dicen también que la única manera de cruzar Arcana Umbra es enfrentarlas. No con espada. Con Claridad.",
	"La Claridad es lo que queda cuando dejas de mentirte. Se gasta al chocar contra una Sombra, y se recupera al mirarte de verdad.\n\nLas cartas que sostienes —Espadas, Oros, Copas, Bastos, y los Arcanos Mayores que pesan más que el resto— no son solo herramientas de combate. Son preguntas con forma de imagen.",
	"Alguien más lejos las llama Rider-Waite. Aquí simplemente las llaman el idioma con el que este lugar te habla.\n\nEn el camino encontrarás un Espejo del Viajero: un momento para detenerte, robar una carta del propio mazo y preguntarte qué te muestra de ti que preferirías no mirar. Eso también es parte del viaje.",
	"Buscas algo con lo que anclarte —un nombre, una fecha, cualquier hilo que te devuelva a quien eras—. Y no está.\n\nNo recuerdas tu nombre.\nNo recuerdas el día en que naciste.",
	"La última carta del reparto sigue boca abajo. No hace falta darla vuelta para saber cuál es: la sientes en el pecho, ligera, sin peso, sin miedo todavía porque no sabe lo que le espera.\n\nEl Loco. El cero. El que parte sin mapa, con un atado al hombro y un perro a los pies, un paso antes del abismo o un paso antes del vuelo — nadie lo sabe hasta después de dar el paso.",
	"Así empieza cada viaje por Arcana Umbra: sin memoria de lo recorrido, sin certeza de lo que sigue. Solo el impulso de seguir jugando la mano que te tocó.\n\nPero para que este viaje sea tuyo, necesito que me digas quién eres.\n\n¿Cómo te llamas? ¿Cuándo naciste?",
]

var _index := 0
var _script_label: Label
var _continue_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SceneBackground.add_to(self, "res://assets/backgrounds/combate_santuario.png")
	_build_ui()
	_render_block()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24
	layout.offset_right = -24
	layout.offset_top = 40
	layout.offset_bottom = -40
	layout.add_theme_constant_override("separation", 18)
	add_child(layout)

	var title := Label.new()
	title.text = "El Loco despierta"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	layout.add_child(title)

	# Panel arcano con MarginContainer explícito: el content_margin del
	# StyleBoxTexture no desplaza a los hijos de un PanelContainer.
	var text_panel := PanelContainer.new()
	text_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(text_panel)

	var text_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		text_margin.add_theme_constant_override("margin_" + side, 60)
	text_panel.add_child(text_margin)

	var text_scroll := ScrollContainer.new()
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_margin.add_child(text_scroll)

	# VBoxContainer con ALIGNMENT_CENTER en vez de CenterContainer: respeta
	# el ancho del padre para que el texto envuelva sin desbordar el marco.
	var text_center := VBoxContainer.new()
	text_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_center.alignment = BoxContainer.ALIGNMENT_CENTER
	text_scroll.add_child(text_center)

	_script_label = Label.new()
	_script_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_center.add_child(_script_label)

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.custom_minimum_size.y = 56
	_continue_button.pressed.connect(_on_continue_pressed)
	layout.add_child(_continue_button)


func _render_block() -> void:
	_script_label.text = SCRIPT_BLOCKS[_index]
	var is_last := _index == SCRIPT_BLOCKS.size() - 1
	_continue_button.text = "Decir quién soy" if is_last else "Continuar"


func _on_continue_pressed() -> void:
	if _index < SCRIPT_BLOCKS.size() - 1:
		_index += 1
		_render_block()
	else:
		finished.emit()
