class_name UITheme
extends RefCounted
## Tema global construido en runtime a partir de los assets de PixelLab
## (assets/ui/). Cada pieza tiene fallback: si falta el asset, el control
## conserva el aspecto por defecto de Godot. Se aplica en main.gd:
##   get_window().theme = UITheme.build()

const FONT_PATH := "res://assets/ui/arcana_umbra.ttf"
const PANEL_PATH := "res://assets/ui/panel_arcano.png"
# NOTA: boton_arcano_organico.png (variante "normal" del brief orgánico) SE
# DESCARTÓ como base del tema: el PNG generado por PixelLab tiene un defecto
# real de origen (no introducido por la limpieza del texto horneado) — el
# lado derecho del marco se desvanece de forma asimétrica a blanco/niebla
# (visible incluso en el download pristino, comparar contra
# boton_arcano_organico_primary.png que es simétrico y opaco en ambos
# lados). Usar ese PNG como StyleBoxTexture con 9-slice hace que el defecto
# se repita/estire de forma muy visible. Se usa boton_arcano_organico_primary
# como ÚNICA base para todos los botones (ver build(), variedad "normal" vs
# "primary" se logra con modulate_color, no con un segundo PNG). Si se
# regenera un botón "normal" limpio en el futuro, reintroducir BUTTON_PATH.
const BUTTON_PRIMARY_PATH := "res://assets/ui/boton_arcano_organico_primary.png"
const BAR_PATH := "res://assets/ui/barra_claridad.png"

## Nombre de la theme_type_variation para el boton principal de una pantalla
## (ej. "Comenzar viaje" en TitleScene). Uso: button.theme_type_variation =
## UITheme.PRIMARY_BUTTON_VARIATION
const PRIMARY_BUTTON_VARIATION := "PrimaryButton"

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

	if ResourceLoader.exists(BUTTON_PRIMARY_PATH):
		# Botón "orgánico/mágico": piedra tallada obsidiana/amatista con
		# marco rúnico dorado, gemas en las esquinas y glow radiante
		# (reemplaza el panel liso con filigrana recta). Única base para
		# TODOS los botones (ver nota junto a BUTTON_PRIMARY_PATH): el PNG
		# "normal" del brief tenía un defecto de fabricación irreparable por
		# stylebox. La distinción normal/primary se logra atenuando el
		# modulate del botón normal (dorado apagado) vs. el brillo completo
		# del primary (gemas doradas grandes, glow cálido), no con dos PNG.
		#
		# Región útil real del PNG 512x192 medida con Image.get_pixel (bbox
		# de píxeles opacos); fuera de ella el lienzo es aire transparente.
		# El texto "PRIMARY" horneado por PixelLab en el hueco interior se
		# limpió a mano (misma trampa que boton_arcano.png original,
		# documentada en CLAUDE.md).
		const BUTTON_REGION := Rect2(51, 16, 408, 161)
		var normal := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		normal.modulate_color = Color(0.72, 0.68, 0.62)
		var hover := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		hover.modulate_color = Color(0.85, 0.8, 0.7)
		var pressed := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		pressed.modulate_color = Color(0.6, 0.56, 0.52)
		var disabled := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		# Alpha alto: sobre los fondos ilustrados (mapa/combate) un botón
		# deshabilitado muy transparente se pierde contra la escena.
		disabled.modulate_color = Color(0.5, 0.48, 0.45, 0.92)
		theme.set_stylebox("normal", "Button", normal)
		theme.set_stylebox("hover", "Button", hover)
		theme.set_stylebox("pressed", "Button", pressed)
		theme.set_stylebox("disabled", "Button", disabled)
		theme.set_color("font_color", "Button", COLOR_GOLD)
		theme.set_color("font_hover_color", "Button", Color(1.0, 0.9, 0.5))

		# Variante "primary" (brillo completo, sin atenuar) para UN botón
		# destacado por pantalla (ej. "Comenzar viaje"). Se aplica vía
		# theme_type_variation, NUNCA con add_theme_stylebox_override
		# (prohibido por CLAUDE.md: pisa el estilo del tema).
		theme.set_type_variation(PRIMARY_BUTTON_VARIATION, "Button")
		var p_normal := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		var p_hover := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		p_hover.modulate_color = Color(1.15, 1.15, 1.05)
		var p_pressed := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		p_pressed.modulate_color = Color(0.85, 0.85, 0.8)
		var p_disabled := _nine_slice(BUTTON_PRIMARY_PATH, 50, BUTTON_REGION, 56)
		p_disabled.modulate_color = Color(0.6, 0.58, 0.5, 0.92)
		theme.set_stylebox("normal", PRIMARY_BUTTON_VARIATION, p_normal)
		theme.set_stylebox("hover", PRIMARY_BUTTON_VARIATION, p_hover)
		theme.set_stylebox("pressed", PRIMARY_BUTTON_VARIATION, p_pressed)
		theme.set_stylebox("disabled", PRIMARY_BUTTON_VARIATION, p_disabled)
		# El hueco interior es violeta oscuro casi negro pese al glow
		# dorado del marco: texto dorado, no oscuro.
		theme.set_color("font_color", PRIMARY_BUTTON_VARIATION, Color("ffd76a"))
		theme.set_color("font_hover_color", PRIMARY_BUTTON_VARIATION, Color("fff0b3"))

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
