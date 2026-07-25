class_name UITheme
extends RefCounted
## Tema global construido en runtime a partir de los assets de PixelLab
## (assets/ui/). Cada pieza tiene fallback: si falta el asset, el control
## conserva el aspecto por defecto de Godot. Se aplica en main.gd:
##   get_window().theme = UITheme.build()

const FONT_PATH := "res://assets/ui/arcana_umbra.ttf"
const PANEL_PATH := "res://assets/ui/panel_arcano.png"
const BUTTON_PATH := "res://assets/ui/boton_arcano.png"
const BAR_PATH := "res://assets/ui/barra_claridad.png"

const COLOR_GOLD := Color("c9a227")
const COLOR_BG := Color("13173a")

static var _cached: Theme


## El tema se aplica POR ESCENA en main.gd (_swap_to): la cadena de herencia
## de temas se rompe en nodos que no son Control/Window, y Main es un Node.
static func get_cached() -> Theme:
	if _cached == null:
		_cached = build()
	return _cached


static func build() -> Theme:
	var theme := Theme.new()

	if ResourceLoader.exists(FONT_PATH):
		theme.default_font = load(FONT_PATH)
		theme.default_font_size = 16

	if ResourceLoader.exists(BUTTON_PATH):
		# El botón útil vive en esta región del PNG (el resto es transparente).
		const BUTTON_REGION := Rect2(76, 68, 152, 63)
		var normal := _nine_slice(BUTTON_PATH, 18, BUTTON_REGION)
		var hover := _nine_slice(BUTTON_PATH, 18, BUTTON_REGION)
		hover.modulate_color = Color(1.15, 1.15, 1.1)
		var pressed := _nine_slice(BUTTON_PATH, 18, BUTTON_REGION)
		pressed.modulate_color = Color(0.8, 0.8, 0.85)
		var disabled := _nine_slice(BUTTON_PATH, 18, BUTTON_REGION)
		disabled.modulate_color = Color(0.5, 0.5, 0.55, 0.7)
		theme.set_stylebox("normal", "Button", normal)
		theme.set_stylebox("hover", "Button", hover)
		theme.set_stylebox("pressed", "Button", pressed)
		theme.set_stylebox("disabled", "Button", disabled)
		theme.set_color("font_color", "Button", COLOR_GOLD)
		theme.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.5))

	if ResourceLoader.exists(PANEL_PATH):
		# content_margin generoso: el marco es ornamentado y el contenido
		# debe quedar DENTRO del filigrana, no encima.
		theme.set_stylebox("panel", "Panel", _nine_slice(PANEL_PATH, 56, Rect2(), 46))
		theme.set_stylebox("panel", "PanelContainer", _nine_slice(PANEL_PATH, 56, Rect2(), 46))

	# AcceptDialog NO usa el panel ornamentado: coloca su Label y su Button
	# con márgenes de layout internos fijos que ignoran content_margin, así
	# que la filigrana del marco arcano queda encima del texto/botón. Un
	# StyleBoxFlat liso con borde dorado respeta la paleta sin ese problema.
	var dialog_panel := StyleBoxFlat.new()
	dialog_panel.bg_color = COLOR_BG
	dialog_panel.border_color = COLOR_GOLD
	dialog_panel.set_border_width_all(3)
	dialog_panel.set_corner_radius_all(12)
	dialog_panel.set_content_margin_all(20)
	theme.set_stylebox("panel", "AcceptDialog", dialog_panel)

	if ResourceLoader.exists(BAR_PATH):
		# El asset trae dos piezas; la barra fina vive en esta región del PNG.
		var bar := _nine_slice(BAR_PATH, 12, Rect2(107, 249, 298, 30))
		theme.set_stylebox("background", "ProgressBar", bar)
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLOR_GOLD
		fill.set_corner_radius_all(6)
		fill.set_expand_margin_all(-4)
		theme.set_stylebox("fill", "ProgressBar", fill)

	return theme


static func _nine_slice(path: String, margin: int, region := Rect2(),
		content_margin: float = -1.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	if region.size != Vector2.ZERO:
		style.region_rect = region
	style.set_texture_margin_all(margin)
	style.set_content_margin_all(content_margin if content_margin >= 0.0 else margin * 0.55)
	return style
