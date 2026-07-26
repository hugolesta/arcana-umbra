class_name WorldGenerator
extends RefCounted
## Genera el layout del mundo explorable de césped a partir de una seed:
## dimensiones del grid, variante de tile por celda y posición de la entrada
## de cueva. Sin autoloads (testeable desde tools/verify.gd), igual patrón
## que ShadowAI/Zodiac.

const MIN_SIZE := 10
const MAX_SIZE := 20
## Índices de variante de tile de césped (coinciden con las 16 combinaciones
## del Wang tileset de assets/tiles/grass_world.tres; ver world_scene.gd).
const GRASS_VARIANTS := 4

var width: int
var height: int
var spawn: Vector2i
var cave_entrance: Vector2i
var tile_variant: Array = []  # Array[Array[int]], [x][y] -> variante 0..GRASS_VARIANTS-1
var rng_seed: int


func _init(p_seed: int = -1) -> void:
	rng_seed = p_seed if p_seed >= 0 else randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	width = rng.randi_range(MIN_SIZE, MAX_SIZE)
	height = rng.randi_range(MIN_SIZE, MAX_SIZE)
	spawn = Vector2i(width / 2, height / 2)

	tile_variant.resize(width)
	for x in range(width):
		var column: Array = []
		column.resize(height)
		for y in range(height):
			column[y] = rng.randi_range(0, GRASS_VARIANTS - 1)
		tile_variant[x] = column

	cave_entrance = _pick_cave_entrance(rng)


## Elige una celda para la cueva que no coincida con el spawn y quede a una
## distancia mínima (para que el jugador deba caminar y explorar el mundo).
func _pick_cave_entrance(rng: RandomNumberGenerator) -> Vector2i:
	var min_distance: int = (width + height) / 4
	var candidate := spawn
	for attempt in range(50):
		candidate = Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
		if candidate != spawn and _manhattan(candidate, spawn) >= min_distance:
			return candidate
	# Fallback determinista si 50 intentos no alcanzan un punto lejano:
	# la esquina más alejada del spawn, siempre válida y siempre alcanzable.
	var far_x: int = width - 1 if spawn.x < width / 2.0 else 0
	var far_y: int = height - 1 if spawn.y < height / 2.0 else 0
	return Vector2i(far_x, far_y)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height
