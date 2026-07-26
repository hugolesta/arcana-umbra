extends Control
## Interior de cueva generado proceduralmente (CaveGenerator: autómata
## celular, cavernas orgánicas con áreas anchas transitables) desde la
## entrada hasta un altar. Al alcanzar el altar se emite altar_reached, que
## main.gd usa para disparar el combate existente. Lógica/UI desacoplada,
## igual patrón que world_scene.gd.

signal altar_reached
signal back_requested

const PERSONAJES_DIR := "res://assets/personajes/viajero"
const TILE_SET_PATH := "res://assets/tiles/cave.tres"
const WATER_TILE_SET_PATH := "res://assets/tiles/cave_water.tres"
const VIAJERO_FALLBACK := "res://assets/viajero/viajero.png"
const ALTAR_ICON_PATH := "res://assets/map_icons/evento.png"
const TILE_PX := 32.0
const PLAYER_HEIGHT_PX := 42.0  # ~1.3x el tile: se distingue del suelo sin taparlo
const PLAYER_RADIUS := 8.0
const MOVE_SPEED := 200.0
const INTERACT_RADIUS := 20.0
const CAMERA_ZOOM := 1.1

var _generator: CaveGenerator
var _tile_map: TileMapLayer
var _water_tile_map: TileMapLayer
var _player: CharacterBody2D
var _player_sprite: AnimatedSprite2D
var _world_root: Node2D
var _camera: Camera2D
var _altar_marker: Node2D
var _reached_altar := false
var _facing := "south"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_generator = CaveGenerator.new()
	_build_cave()
	_build_back_button()


func _build_cave() -> void:
	_world_root = Node2D.new()
	add_child(_world_root)

	_tile_map = TileMapLayer.new()
	_tile_map.tile_set = load(TILE_SET_PATH)
	_world_root.add_child(_tile_map)
	_paint_cave()

	if _generator.has_lagoon and ResourceLoader.exists(WATER_TILE_SET_PATH):
		_water_tile_map = TileMapLayer.new()
		_water_tile_map.tile_set = load(WATER_TILE_SET_PATH)
		_world_root.add_child(_water_tile_map)
		_paint_lagoon()

	_altar_marker = _make_altar_marker()
	_altar_marker.position = _cell_to_world(_generator.altar)
	_world_root.add_child(_altar_marker)

	_player = _make_player()
	_player.position = _cell_to_world(_generator.entrance)
	_world_root.add_child(_player)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * CAMERA_ZOOM
	_player.add_child(_camera)
	_camera.make_current()


## Primero cubre todo el grid de pared (ignore_empty_terrains=false: sin
## esto Godot trata el grid vacío como "sin terreno" y no pinta nada), luego
## repinta las celdas talladas como piso — con las paredes ya pintadas,
## Godot resuelve solo la transición piso/pared en los bordes tallados.
func _paint_cave() -> void:
	var all_cells: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	for x in range(_generator.width):
		for y in range(_generator.height):
			var cell := Vector2i(x, y)
			all_cells.append(cell)
			if _generator.is_floor(cell):
				floor_cells.append(cell)
	_tile_map.set_cells_terrain_connect(all_cells, 0, 0, false)
	_tile_map.set_cells_terrain_connect(floor_cells, 0, 1)


## Capa aparte sobre el piso: Wang set propio de 2 terrenos (piso/agua). Se
## pinta TODO el grid como "Piso" primero (ignore_empty_terrains=false: sin
## esto Godot no resuelve nada en un grid vacío) y luego el agua encima —
## para que esto pinte agua de verdad (y no quede en terreno "Piso" pese a
## la segunda llamada, bug detectado antes de que CaveGenerator garantizara
## un núcleo sólido en _grow_lagoon_blob), el blob de agua necesita tener
## sus celdas centrales rodeadas de agua en las 4 esquinas: con un blob
## disperso el Wang set de 2 terrenos no encuentra combinación de agua pura
## para celdas "sueltas" y cae a piso. Al final se borran las celdas de piso
## que no bordean agua: la capa queda vacía en el resto del mapa (se sigue
## viendo el piso de cave.tres debajo) y solo pinta la laguna + su anillo.
func _paint_lagoon() -> void:
	var all_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	for x in range(_generator.width):
		for y in range(_generator.height):
			var cell := Vector2i(x, y)
			all_cells.append(cell)
			if _generator.is_water(cell):
				water_cells.append(cell)
	_water_tile_map.set_cells_terrain_connect(all_cells, 0, 0, false)
	_water_tile_map.set_cells_terrain_connect(water_cells, 0, 1, false)
	for cell in all_cells:
		if not _generator.is_water(cell) and not _adjacent_to_water(cell):
			_water_tile_map.erase_cell(cell)


func _adjacent_to_water(cell: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if _generator.is_water(cell + Vector2i(dx, dy)):
				return true
	return false


func _make_altar_marker() -> Node2D:
	var marker := Node2D.new()
	if ResourceLoader.exists(ALTAR_ICON_PATH):
		var sprite := Sprite2D.new()
		sprite.texture = load(ALTAR_ICON_PATH)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.add_child(sprite)
	else:
		var rect := ColorRect.new()
		rect.color = Color(0.6, 0.4, 0.9)
		rect.size = Vector2(TILE_PX, TILE_PX)
		rect.position = -rect.size / 2.0
		marker.add_child(rect)
	return marker


func _make_player() -> CharacterBody2D:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	shape.shape = circle
	body.add_child(shape)

	_player_sprite = SpriteStrip.make_multi_animated_sprite_2d({
		"idle": PERSONAJES_DIR.path_join("idle_south"),
		"walk_south": PERSONAJES_DIR.path_join("walk_south"),
		"walk_north": PERSONAJES_DIR.path_join("walk_north"),
		"walk_east": PERSONAJES_DIR.path_join("walk_east"),
		"walk_west": PERSONAJES_DIR.path_join("walk_west"),
	}, PLAYER_HEIGHT_PX)
	if _player_sprite:
		_player_sprite.play("idle")
		body.add_child(_player_sprite)
	elif ResourceLoader.exists(VIAJERO_FALLBACK):
		var fallback := Sprite2D.new()
		fallback.texture = load(VIAJERO_FALLBACK)
		fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fallback.scale = Vector2.ONE * (PLAYER_HEIGHT_PX / fallback.texture.get_height())
		body.add_child(fallback)
	return body


func _build_back_button() -> void:
	var back := Button.new()
	back.text = "← Volver"
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.position = Vector2(16, 16)
	back.pressed.connect(func(): back_requested.emit())
	add_child(back)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_PX + Vector2(TILE_PX, TILE_PX) / 2.0


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / TILE_PX).floor())


func _physics_process(delta: float) -> void:
	if _reached_altar or _player == null:
		return
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if input_vector != Vector2.ZERO:
		_move_with_wall_slide(input_vector.normalized() * MOVE_SPEED * delta)
	_update_facing(input_vector)
	_check_altar_reach()


## Mismo criterio que world_scene.gd: elige walk_south/north/east/west según
## el eje dominante del input, vuelve a idle al soltar.
func _update_facing(input_vector: Vector2) -> void:
	if _player_sprite == null:
		return
	if input_vector == Vector2.ZERO:
		_player_sprite.play("idle")
		return
	if absf(input_vector.x) > absf(input_vector.y):
		_facing = "east" if input_vector.x > 0.0 else "west"
	else:
		_facing = "south" if input_vector.y > 0.0 else "north"
	var anim_name := "walk_" + _facing
	if _player_sprite.sprite_frames.has_animation(anim_name):
		_player_sprite.play(anim_name)
	else:
		_player_sprite.play("idle")


## Mueve al jugador eje por eje (en vez de en bloque) para poder deslizar
## contra una pared en diagonal, y valida el punto de avance por el borde
## del círculo del jugador (no solo su centro) para que el bloqueo coincida
## con lo que se ve en pantalla, no con una celda invisible de más margen.
func _move_with_wall_slide(motion: Vector2) -> void:
	var next_x := _player.position + Vector2(motion.x, 0.0)
	if _can_stand_at(next_x):
		_player.position = next_x
	var next_y := _player.position + Vector2(0.0, motion.y)
	if _can_stand_at(next_y):
		_player.position = next_y


func _can_stand_at(world_pos: Vector2) -> bool:
	# Cuatro puntos en el borde del círculo del jugador: si cualquiera cae
	# en pared, el movimiento se rechaza (evita "colarse" a través de esquinas).
	for offset in [Vector2(PLAYER_RADIUS, 0), Vector2(-PLAYER_RADIUS, 0),
			Vector2(0, PLAYER_RADIUS), Vector2(0, -PLAYER_RADIUS)]:
		if not _generator.is_floor(_world_to_cell(world_pos + offset)):
			return false
	return true


func _check_altar_reach() -> void:
	if _player.position.distance_to(_altar_marker.position) <= INTERACT_RADIUS:
		_reached_altar = true
		altar_reached.emit()
