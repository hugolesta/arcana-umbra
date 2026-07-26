extends Control
## Mundo explorable de césped, generado proceduralmente (seed aleatoria en
## cada visita) al entrar a un nodo de combate del mapa. El Viajero se mueve
## libremente por un TileMapLayer hasta encontrar la entrada de una cueva.
## Lógica/UI desacoplada: la generación vive en WorldGenerator (RefCounted,
## sin autoloads); esta escena solo construye nodos y escucha input.

signal cave_entered
signal back_requested

const PERSONAJES_DIR := "res://assets/personajes/viajero"
const TILE_SET_PATH := "res://assets/tiles/grass_world.tres"
const VIAJERO_FALLBACK := "res://assets/viajero/viajero.png"
const CAVE_ICON_PATH := "res://assets/map_icons/combate.png"
const TILE_PX := 32.0
const PLAYER_HEIGHT_PX := 42.0  # ~1.3x el tile: se distingue del suelo sin taparlo
const MOVE_SPEED := 220.0
const INTERACT_RADIUS := 24.0
const CAMERA_ZOOM := 1.1

var _generator: WorldGenerator
var _tile_map: TileMapLayer
var _player: CharacterBody2D
var _player_sprite: AnimatedSprite2D
var _world_root: Node2D
var _camera: Camera2D
var _cave_marker: Node2D
var _entered_cave := false
var _facing := "south"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_generator = WorldGenerator.new()
	_build_world()
	_build_back_button()


func _build_world() -> void:
	_world_root = Node2D.new()
	add_child(_world_root)

	_tile_map = TileMapLayer.new()
	_tile_map.tile_set = load(TILE_SET_PATH)
	_world_root.add_child(_tile_map)
	_paint_grass()

	_cave_marker = _make_cave_marker()
	_cave_marker.position = _cell_to_world(_generator.cave_entrance)
	_world_root.add_child(_cave_marker)

	_player = _make_player()
	_player.position = _cell_to_world(_generator.spawn)
	_world_root.add_child(_player)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * CAMERA_ZOOM
	_player.add_child(_camera)
	_camera.make_current()


## Pinta todo el grid como terreno "Cesped" (id 1): con un único terreno
## activo, cada celda usa el tile base (todas las esquinas iguales) sin
## necesidad de mezclar con "Camino" — la variación visual la da el tileset.
func _paint_grass() -> void:
	var cells: Array[Vector2i] = []
	for x in range(_generator.width):
		for y in range(_generator.height):
			cells.append(Vector2i(x, y))
	# ignore_empty_terrains=false: sin esto, Godot trata las celdas vecinas
	# aún sin pintar como "sin terreno" y no conecta nada en un grid nuevo.
	_tile_map.set_cells_terrain_connect(cells, 0, 1, false)


func _make_cave_marker() -> Node2D:
	var marker := Node2D.new()
	if ResourceLoader.exists(CAVE_ICON_PATH):
		var sprite := Sprite2D.new()
		sprite.texture = load(CAVE_ICON_PATH)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.add_child(sprite)
	else:
		var rect := ColorRect.new()
		rect.color = Color(0.1, 0.05, 0.15)
		rect.size = Vector2(TILE_PX, TILE_PX)
		rect.position = -rect.size / 2.0
		marker.add_child(rect)
	return marker


func _make_player() -> CharacterBody2D:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
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


func _physics_process(delta: float) -> void:
	if _entered_cave or _player == null:
		return
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	_player.velocity = input_vector.normalized() * MOVE_SPEED if input_vector != Vector2.ZERO \
			else Vector2.ZERO
	_player.move_and_slide()
	_clamp_to_world()
	_update_facing(input_vector)
	_check_cave_entry()


## Elige la animación de caminar según el eje dominante del input (4
## direcciones, igual criterio que el resto del proyecto: "el combate solo
## usa south" — acá walk_south/north/east/west cubren las 4 direcciones de
## movimiento libre) y vuelve a idle al soltar el input.
func _update_facing(input_vector: Vector2) -> void:
	if _player_sprite == null:
		return
	if input_vector == Vector2.ZERO:
		_player_sprite.play("idle")
		return
	var new_facing := _facing
	if absf(input_vector.x) > absf(input_vector.y):
		new_facing = "east" if input_vector.x > 0.0 else "west"
	else:
		new_facing = "south" if input_vector.y > 0.0 else "north"
	_facing = new_facing
	var anim_name := "walk_" + _facing
	if _player_sprite.sprite_frames.has_animation(anim_name):
		_player_sprite.play(anim_name)
	else:
		_player_sprite.play("idle")


func _clamp_to_world() -> void:
	var min_pos := Vector2.ZERO
	var max_pos := Vector2(_generator.width, _generator.height) * TILE_PX
	_player.position = _player.position.clamp(min_pos, max_pos)


func _check_cave_entry() -> void:
	if _player.position.distance_to(_cave_marker.position) <= INTERACT_RADIUS:
		_entered_cave = true
		cave_entered.emit()
