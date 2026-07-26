class_name CaveGenerator
extends RefCounted
## Genera el interior de la cueva a partir de una seed con un autómata
## celular (ruido inicial + suavizado por vecindad, técnica estándar de
## roguelikes para cavernas orgánicas con áreas anchas transitables — sin
## pasillos de 1 tile). Sin autoloads (testeable desde tools/verify.gd),
## igual patrón que WorldGenerator.

const MIN_SIZE := 18
const MAX_SIZE := 26
const INITIAL_WALL_CHANCE := 0.45
const SMOOTH_ITERATIONS := 5
const LAGOON_SEED_ATTEMPTS := 12
const LAGOON_MIN_RADIUS := 2
const LAGOON_MAX_RADIUS := 4
const LAGOON_GROWTH_CHANCE := 0.55

enum Tile { WALL, FLOOR, WATER }

var width: int
var height: int
var entrance: Vector2i
var altar: Vector2i
var tiles: Array = []  # Array[Array[Tile]], [x][y]
var rng_seed: int
var has_lagoon := false


func _init(p_seed: int = -1) -> void:
	rng_seed = p_seed if p_seed >= 0 else randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	width = rng.randi_range(MIN_SIZE, MAX_SIZE)
	height = rng.randi_range(MIN_SIZE, MAX_SIZE)

	_randomize_noise(rng)
	for i in range(SMOOTH_ITERATIONS):
		_smooth_step()

	entrance = Vector2i(width / 2, height - 1)
	_carve_open_circle(entrance, 2)
	_connect_to_open_area(entrance)

	var distances := _flood_fill_distances(entrance)
	altar = _farthest_cell(distances)
	_carve_open_circle(altar, 1)

	_try_place_lagoon(rng)


## Elige un punto al azar dentro del área de piso conectada (lejos de
## entrada/altar) y hace crecer ahí un blob orgánico de agua (mismo espíritu
## que el autómata celular: crecimiento por vecindad con algo de ruido, no
## un círculo perfecto). Si el agua resultante corta el único camino entre
## entrada y altar, se descarta esa laguna — "siempre que el espacio lo
## permita" significa que nunca se sacrifica la alcanzabilidad garantizada.
func _try_place_lagoon(rng: RandomNumberGenerator) -> void:
	var floor_cells := _flood_fill_distances(entrance).keys()
	if floor_cells.size() < 40:
		return  # cueva demasiado chica: no hay margen para una laguna y el altar

	var backup: Array = tiles.duplicate(true)
	for attempt in range(LAGOON_SEED_ATTEMPTS):
		var seed_cell: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		if seed_cell.distance_to(entrance) < 4.0 or seed_cell.distance_to(altar) < 4.0:
			continue
		var radius := rng.randi_range(LAGOON_MIN_RADIUS, LAGOON_MAX_RADIUS)
		var lagoon_cells := _grow_lagoon_blob(seed_cell, radius, rng)
		if lagoon_cells.is_empty():
			continue
		for cell in lagoon_cells:
			tiles[cell.x][cell.y] = Tile.WATER
		var distances := _flood_fill_distances(entrance)
		if distances.has(altar):
			has_lagoon = true
			return
		tiles = backup.duplicate(true)  # esta laguna tapó el único paso: descartar e intentar otra semilla


## Genera un blob desde seed_cell: el núcleo (radio - 1) es SIEMPRE agua
## sólida —imprescindible para que el Wang set de 2 terrenos resuelva esas
## celdas como agua pura (4 esquinas iguales); un blob dev todas las celdas
## con probabilidad decreciente dejaba demasiadas celdas "sueltas" con pocos
## vecinos de agua, que el algoritmo de conexión resolvía como piso en vez
## de agua (bug detectado inspeccionando terrain_peering_bit por celda: la
## forma dispersa nunca alcanzaba las 4 esquinas necesarias). Solo el anillo
## más externo (entre radius-1 y radius) tiene ruido, para una silueta
## orgánica sin sacrificar la masa sólida del centro. Nunca invade pared ni
## el círculo abierto de entrada/altar.
func _grow_lagoon_blob(seed_cell: Vector2i, radius: int, rng: RandomNumberGenerator) -> Array:
	var blob: Array = []
	var core_radius: float = maxf(radius - 1.0, 1.0)
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := seed_cell + Vector2i(dx, dy)
			var dist := Vector2(dx, dy).length()
			if dist > radius or not is_floor(cell):
				continue
			if cell.distance_to(entrance) < 3.0 or cell.distance_to(altar) < 3.0:
				continue
			if dist <= core_radius or rng.randf() < LAGOON_GROWTH_CHANCE:
				blob.append(cell)
	return blob


func _randomize_noise(rng: RandomNumberGenerator) -> void:
	tiles.resize(width)
	for x in range(width):
		var column: Array = []
		column.resize(height)
		for y in range(height):
			var on_border: bool = x == 0 or y == 0 or x == width - 1 or y == height - 1
			column[y] = Tile.WALL if (on_border or rng.randf() < INITIAL_WALL_CHANCE) \
					else Tile.FLOOR
		tiles[x] = column


## Regla clásica 4-5: una celda se vuelve pared si tiene >=5 paredes vecinas
## (radio 1, 8 direcciones), piso en caso contrario. Varias pasadas agrupan
## el ruido inicial en cavernas anchas con bordes suaves.
func _smooth_step() -> void:
	var next: Array = []
	next.resize(width)
	for x in range(width):
		var column: Array = []
		column.resize(height)
		for y in range(height):
			var wall_neighbors := _wall_neighbor_count(x, y)
			var on_border: bool = x == 0 or y == 0 or x == width - 1 or y == height - 1
			if on_border:
				column[y] = Tile.WALL
			else:
				column[y] = Tile.WALL if wall_neighbors >= 5 else Tile.FLOOR
		next[x] = column
	tiles = next


func _wall_neighbor_count(cx: int, cy: int) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := cx + dx
			var ny := cy + dy
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				count += 1  # fuera del grid cuenta como pared: cierra los bordes
			elif tiles[nx][ny] == Tile.WALL:
				count += 1
	return count


## Talla un círculo de piso alrededor de un punto (garantiza que la entrada
## y el altar queden en área abierta, nunca dentro de una pared que el
## autómata celular haya generado ahí encima).
func _carve_open_circle(center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if is_inside(cell) and Vector2(dx, dy).length() <= radius:
				tiles[cell.x][cell.y] = Tile.FLOOR


## El autómata celular no garantiza que la entrada quede en la región
## conexa principal: si _flood_fill_distances no alcanza suficientes celdas
## desde la entrada, talla un túnel recto hacia el centro del grid (que el
## suavizado deja abierto con alta probabilidad) hasta tocar piso existente.
func _connect_to_open_area(from: Vector2i) -> void:
	var distances := _flood_fill_distances(from)
	if distances.size() >= (width * height) / 4:
		return
	var target := Vector2i(width / 2, height / 2)
	var current := from
	while current != target:
		tiles[current.x][current.y] = Tile.FLOOR
		if current.x != target.x:
			current.x += signi(target.x - current.x)
		elif current.y != target.y:
			current.y += signi(target.y - current.y)
	tiles[target.x][target.y] = Tile.FLOOR
	_carve_open_circle(target, 2)


## BFS desde una celda de piso: distancia (en pasos) a cada celda alcanzable.
func _flood_fill_distances(from: Vector2i) -> Dictionary:
	var distances := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + dir
			if is_floor(next) and not distances.has(next):
				distances[next] = distances[current] + 1
				queue.append(next)
	return distances


func _farthest_cell(distances: Dictionary) -> Vector2i:
	var best: Vector2i = entrance
	var best_distance := -1
	for cell: Vector2i in distances:
		if distances[cell] > best_distance:
			best_distance = distances[cell]
			best = cell
	return best


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func is_floor(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return tiles[cell.x][cell.y] == Tile.FLOOR


func is_water(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return tiles[cell.x][cell.y] == Tile.WATER
