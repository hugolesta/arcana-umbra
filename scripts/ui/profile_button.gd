class_name ProfileButton
extends Button
## Botón circular con el retrato animado del Viajero y su nick, para usar
## en la esquina superior de título/mapa. Tocarlo emite profile_requested;
## el llamador decide a qué pantalla navegar (mantiene esta pieza tonta).

signal profile_requested

const AVATAR_SIZE := 56.0
const VIAJERO_IDLE_DIR := "res://assets/personajes/viajero/idle_south"
const VIAJERO_SPRITE := "res://assets/viajero/viajero.png"


func _init() -> void:
	custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	pressed.connect(func(): profile_requested.emit())
	_build_content()


func _build_content() -> void:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var portrait := SpriteStrip.make_animated_control(VIAJERO_IDLE_DIR, AVATAR_SIZE)
	if portrait == null:
		portrait = _static_fallback()
	if portrait:
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(portrait)

	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = UITheme.COLOR_GOLD
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(int(AVATAR_SIZE / 2.0))
	add_theme_stylebox_override("normal", ring)
	add_theme_stylebox_override("hover", ring)
	add_theme_stylebox_override("pressed", ring)
	add_theme_stylebox_override("focus", ring)


func _static_fallback() -> Control:
	if not ResourceLoader.exists(VIAJERO_SPRITE):
		return null
	var rect := TextureRect.new()
	rect.texture = load(VIAJERO_SPRITE)
	rect.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
