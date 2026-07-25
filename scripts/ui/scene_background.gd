class_name SceneBackground
extends RefCounted
## Fondo ambiental pixel art para pantallas de juego (mapa, combate). Cubre
## el viewport completo detrás del contenido, con una capa de oscurecimiento
## para que texto/botones sigan siendo legibles encima. Con fallback: si
## falta el PNG, la escena conserva el fondo violeta sólido del tema.

const DIM_COLOR := Color(0.02, 0.02, 0.06, 0.45)


## Inserta el fondo como PRIMER hijo de parent (detrás de todo lo demás
## que ya se haya añadido, o de lo que se añada después si se llama al
## principio de _ready()). Devuelve el TextureRect o null si falta el PNG.
##
## Las ilustraciones fuente se generan en 384×688 (create_ui_asset, 9:16),
## la misma proporción que el viewport 720×1280: STRETCH_KEEP_ASPECT_COVERED
## las cubre sin estirar la composición ni recortar de forma agresiva.
static func add_to(parent: Control, image_path: String) -> TextureRect:
	if not ResourceLoader.exists(image_path):
		return null

	# CanvasLayer propio (igual que el fondo global de main.gd) en vez de
	# depender de move_child dentro del Control: más explícito y confiable
	# para garantizar que quede detrás de todo el contenido de la escena.
	var layer := CanvasLayer.new()
	layer.layer = -5
	parent.add_child(layer)

	# Algunas ilustraciones tienen forma orgánica (transparencia real en las
	# esquinas, no un rectángulo opaco): un color sólido detrás evita que
	# se vea el fondo por defecto del viewport en esas zonas.
	var solid := ColorRect.new()
	solid.color = UITheme.COLOR_BG
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(solid)

	var bg := TextureRect.new()
	bg.texture = load(image_path)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)

	return bg
