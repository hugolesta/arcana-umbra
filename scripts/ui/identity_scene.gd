extends Control
## Pantalla de identidad: se muestra ANTES del primer "nuevo viaje". Pide
## nombre (fijo de por vida) y fecha de nacimiento (mes/día -> signo
## zodiacal calculado por Zodiac). Al confirmar, llama a
## GameState.define_identity() y emite confirmed; si falla la validación,
## muestra el motivo y no avanza.

signal confirmed

const ZODIAC_DIR := "res://assets/zodiaco"
const MONTHS := [
	"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
	"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]

var _nick_edit: LineEdit
var _month_option: OptionButton
var _day_spin: SpinBox
var _sign_preview: TextureRect
var _sign_label: Label
var _error_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_update_sign_preview()


func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 32
	layout.offset_right = -32
	layout.offset_top = 40
	layout.offset_bottom = -40
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	add_child(layout)

	var title := Label.new()
	title.text = "¿Quién eres, Viajero?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UITheme.COLOR_GOLD)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tu nombre y tu fecha de nacimiento quedarán marcados para siempre en este viaje."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.modulate = Color(1, 1, 1, 0.7)
	layout.add_child(subtitle)

	_nick_edit = LineEdit.new()
	_nick_edit.placeholder_text = "Tu nombre"
	_nick_edit.max_length = 20
	_nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_edit.custom_minimum_size.x = 320
	_nick_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(_nick_edit)

	var date_row := HBoxContainer.new()
	date_row.alignment = BoxContainer.ALIGNMENT_CENTER
	date_row.add_theme_constant_override("separation", 12)
	layout.add_child(date_row)

	# custom_minimum_size explícito: un OptionButton vacío al añadirse no
	# recalcula su ancho de layout al poblarse por código en el mismo frame,
	# y queda visualmente colapsado aunque tenga items seleccionados.
	_month_option = OptionButton.new()
	_month_option.custom_minimum_size = Vector2(170, 48)
	for i in range(MONTHS.size()):
		_month_option.add_item(MONTHS[i], i + 1)
	_month_option.item_selected.connect(func(_i): _update_day_range())
	date_row.add_child(_month_option)

	# SpinBox en vez de OptionButton: para un rango numérico de 31 valores
	# es más robusto (flechas +/-, sin desplegable largo) y evita un defecto
	# de renderizado del tema donde el texto de un OptionButton poblado con
	# dígitos cortos ("1") no llegaba a pintarse en el frame capturado,
	# mientras que textos más largos ("Enero") sí. Ver tools/Screenshot.tscn.
	_day_spin = SpinBox.new()
	_day_spin.min_value = 1
	_day_spin.max_value = 31
	_day_spin.value = 1
	_day_spin.custom_minimum_size = Vector2(100, 48)
	_day_spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_row.add_child(_day_spin)

	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 10)
	layout.add_child(preview_row)

	_sign_preview = TextureRect.new()
	_sign_preview.custom_minimum_size = Vector2(48, 48)
	_sign_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sign_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sign_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_row.add_child(_sign_preview)

	_sign_label = Label.new()
	_sign_label.add_theme_font_size_override("font_size", 20)
	preview_row.add_child(_sign_label)

	_month_option.item_selected.connect(func(_i): _update_sign_preview())
	_day_spin.value_changed.connect(func(_v): _update_sign_preview())

	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.modulate = Color(1.0, 0.5, 0.5)
	_error_label.visible = false
	layout.add_child(_error_label)

	var confirm := Button.new()
	confirm.text = "Comenzar el viaje"
	confirm.custom_minimum_size.y = 56
	confirm.pressed.connect(_on_confirm_pressed)
	layout.add_child(confirm)


func _update_day_range() -> void:
	var month := _month_option.get_selected_id()
	const DAYS_IN_MONTH := [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var max_day: int = DAYS_IN_MONTH[month - 1]
	_day_spin.max_value = max_day
	if _day_spin.value > max_day:
		_day_spin.value = max_day


func _update_sign_preview() -> void:
	var month := _month_option.get_selected_id()
	var day := int(_day_spin.value)
	var sign_name := Zodiac.sign_for(month, day)
	_sign_label.text = sign_name
	var icon_path := ZODIAC_DIR.path_join(Zodiac.sign_key(sign_name) + ".png")
	_sign_preview.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null


func _on_confirm_pressed() -> void:
	var month := _month_option.get_selected_id()
	var day := int(_day_spin.value)
	if _nick_edit.text.strip_edges().is_empty():
		_show_error("Escribe un nombre para tu Viajero.")
		return
	if GameState.define_identity(_nick_edit.text, month, day):
		confirmed.emit()
	else:
		_show_error("No se pudo guardar tu identidad. Intenta de nuevo.")


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true
