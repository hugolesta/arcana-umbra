class_name ProfileButton
extends Button
## Botón circular con el retrato del Viajero, para usar en la esquina
## superior de título/mapa. Tocarlo emite profile_requested; el llamador
## decide a qué pantalla navegar (mantiene esta pieza tonta).
##
## Tamaño configurable por constructor: MapScene usa el default pequeño
## (AVATAR_SIZE, cabe en su TOP_BAR_HEIGHT de 72px); TitleScene pide un
## tamaño grande (~220px) para el busto con marco. Prioridad de arte:
## 1) retrato estático de busto (assets/ui/retrato_viajero.png) si el
##    tamaño pedido es "grande" (> LARGE_THRESHOLD) — recorte de busto,
##    se ve mejor a tamaño grande que el idle animado en bucle.
## 2) idle animado del Viajero (combate) — lo que usaba MapScene hasta ahora.
## 3) sprite estático legacy 128x128.

signal profile_requested

const AVATAR_SIZE := 56.0
const LARGE_THRESHOLD := 100.0
const VIAJERO_IDLE_DIR := "res://assets/personajes/viajero/idle_south"
const VIAJERO_SPRITE := "res://assets/viajero/viajero.png"
const PORTRAIT_BUST_PATH := "res://assets/ui/retrato_viajero.png"

var _size: float


func _init(size: float = AVATAR_SIZE) -> void:
	_size = size
	custom_minimum_size = Vector2(_size, _size)
	pressed.connect(func(): profile_requested.emit())
	_build_content()


func _build_content() -> void:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var portrait: Control = null
	if _size > LARGE_THRESHOLD and ResourceLoader.exists(PORTRAIT_BUST_PATH):
		portrait = _bust_portrait()
	if portrait == null:
		portrait = SpriteStrip.make_animated_control(VIAJERO_IDLE_DIR, _size)
	if portrait == null:
		portrait = _static_fallback()
	if portrait:
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(portrait)

	# Anillo dorado: StyleBoxFlat con bg_color transparente pero borde
	# opaco. Nunca usar Button.flat = true (pisa el stylebox "normal" y el
	# anillo deja de pintarse, trampa ya documentada en CLAUDE.md).
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = UITheme.COLOR_GOLD
	ring.set_border_width_all(2 if _size <= LARGE_THRESHOLD else 4)
	ring.set_corner_radius_all(int(_size / 2.0))
	add_theme_stylebox_override("normal", ring)
	add_theme_stylebox_override("hover", ring)
	add_theme_stylebox_override("pressed", ring)
	add_theme_stylebox_override("focus", ring)


func _bust_portrait() -> Control:
	var rect := TextureRect.new()
	rect.texture = load(PORTRAIT_BUST_PATH)
	rect.custom_minimum_size = Vector2(_size, _size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _static_fallback() -> Control:
	if not ResourceLoader.exists(VIAJERO_SPRITE):
		return null
	var rect := TextureRect.new()
	rect.texture = load(VIAJERO_SPRITE)
	rect.custom_minimum_size = Vector2(_size, _size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
