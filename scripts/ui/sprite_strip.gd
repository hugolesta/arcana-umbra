class_name SpriteStrip
extends RefCounted
## Utilidades para las animaciones de personaje de PixelLab, guardadas como
## carpetas de frames: assets/personajes/<clave>/<anim>/0.png, 1.png, ...
## (frames cuadrados; el 0 es el frame de referencia).

const MAX_FRAMES := 32


static func load_frames(dir_path: String, fps: float, loop: bool) -> SpriteFrames:
	var textures: Array[Texture2D] = []
	for i in range(MAX_FRAMES):
		var frame_path := dir_path.path_join("%d.png" % i)
		if not ResourceLoader.exists(frame_path):
			break
		textures.append(load(frame_path))
	if textures.is_empty():
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("default")
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", loop)
	for texture in textures:
		frames.add_frame("default", texture)
	return frames


## Crea un Control con un AnimatedSprite2D centrado y escalado a display_size.
## Devuelve null si no existe la carpeta idle (el llamador usa su fallback).
static func make_animated_control(idle_dir: String, display_size: float) -> Control:
	var idle := load_frames(idle_dir, 6.0, true)
	if idle == null:
		return null
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(display_size, display_size)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = idle
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# El lienzo de PixelLab deja mucho aire alrededor del personaje: escalar
	# por el alto real del arte (no del frame) para que llene el hueco.
	var first := idle.get_frame_texture("default", 0)
	var frame_size: float = first.get_width()
	var art := _art_rect(first)
	var reference: float = art.size.y if art.size.y > 0.0 else frame_size
	var factor := display_size / reference
	sprite.scale = Vector2.ONE * factor
	# Centrar por el arte visible, no por el lienzo (PixelLab deja aire).
	var art_center := art.position + art.size / 2.0 if art.size.y > 0.0 \
			else Vector2(frame_size, frame_size) / 2.0
	sprite.position = Vector2(display_size, display_size) / 2.0 \
			+ (Vector2(frame_size, frame_size) / 2.0 - art_center) * factor
	sprite.play("default")
	holder.add_child(sprite)
	return holder


## Rectángulo del arte visible dentro del lienzo (ignora el aire transparente).
static func _art_rect(texture: Texture2D) -> Rect2:
	var image := texture.get_image()
	var used := image.get_used_rect()
	return Rect2(used.position, used.size)


## Crea un AnimatedSprite2D para mundo/cueva (Node2D, no Control) a partir de
## varias carpetas de animación con nombre propio (ej. {"idle": ".../idle_south",
## "walk_south": ".../walk_south", ...}): escala por el alto real del arte de
## la PRIMERA animación (igual criterio que make_animated_control) para que
## el personaje quede a target_height px sin importar el aire que deje el
## lienzo de PixelLab, y deja las demás animaciones listas para sprite.play().
## Devuelve null si falta la primera animación del diccionario (fallback del
## llamador). Las animaciones ausentes se omiten en silencio: sprite.play()
## sobre un nombre no cargado no rompe, solo no cambia de pose.
static func make_multi_animated_sprite_2d(anim_dirs: Dictionary, target_height: float) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var first_texture: Texture2D = null
	for anim_name: String in anim_dirs:
		var dir_path: String = anim_dirs[anim_name]
		var textures: Array[Texture2D] = []
		for i in range(MAX_FRAMES):
			var frame_path := dir_path.path_join("%d.png" % i)
			if not ResourceLoader.exists(frame_path):
				break
			textures.append(load(frame_path))
		if textures.is_empty():
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 6.0)
		frames.set_animation_loop(anim_name, true)
		for texture in textures:
			frames.add_frame(anim_name, texture)
		if first_texture == null:
			first_texture = textures[0]
	if first_texture == null:
		return null

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art := _art_rect(first_texture)
	var reference: float = art.size.y if art.size.y > 0.0 else first_texture.get_height()
	sprite.scale = Vector2.ONE * (target_height / reference)
	# Centrar el sprite sobre su propio origen (0,0) sumando el offset entre
	# el centro del lienzo y el centro real del arte, para que el nodo padre
	# (CharacterBody2D) quede alineado con los pies/centro del personaje.
	var frame_size := Vector2(first_texture.get_width(), first_texture.get_height())
	var art_center := art.position + art.size / 2.0 if art.size.y > 0.0 else frame_size / 2.0
	sprite.offset = (frame_size / 2.0 - art_center)
	sprite.centered = true
	return sprite


## Reproduce una animación una vez sobre el AnimatedSprite2D de un holder
## creado con make_animated_control; al terminar vuelve a la idle.
static func play_once(holder: Control, anim_dir: String, fps: float) -> void:
	if holder == null:
		return
	var sprite: AnimatedSprite2D = holder.get_node_or_null("Sprite")
	if sprite == null:
		return
	var one_shot := load_frames(anim_dir, fps, false)
	if one_shot == null:
		return
	var idle_frames := sprite.sprite_frames
	sprite.sprite_frames = one_shot
	sprite.play("default")
	var back_to_idle := func():
		sprite.sprite_frames = idle_frames
		sprite.play("default")
	sprite.animation_finished.connect(back_to_idle, CONNECT_ONE_SHOT)
