class_name MapGenerator
extends RefCounted
## Genera el DAG del mapa: 15 pisos, 3-6 nodos por piso, conexiones solo a
## columnas adyacentes del piso siguiente, y todo nodo alcanzable.

const FLOORS := 15
const MIN_NODES_PER_FLOOR := 3
const MAX_NODES_PER_FLOOR := 6


func generate_map() -> Array:
	var grid: Array = []
	# La anchura varía como paseo aleatorio (±1 por piso): así todo nodo del
	# piso siguiente siempre tiene una columna adyacente en el actual y las
	# conexiones nunca cruzan más de una columna.
	var count := randi_range(MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)
	for floor_index in range(FLOORS):
		var nodes_this_floor: Array = []
		# El último piso es siempre un único Jefe Sombra (clímax del acto).
		if floor_index == FLOORS - 1:
			count = 1
		for col in range(count):
			var node := MapNode.new()
			node.floor_index = floor_index
			node.column = col
			node.node_type = _assign_type(floor_index)
			nodes_this_floor.append(node)
		grid.append(nodes_this_floor)
		count = clampi(count + randi_range(-1, 1), MIN_NODES_PER_FLOOR, MAX_NODES_PER_FLOOR)

	for floor_index in range(FLOORS - 1):
		_connect_floors(grid[floor_index], grid[floor_index + 1])

	# El jugador elige libremente su punto de entrada en el piso 0.
	for node in grid[0]:
		node.available = true
	return grid


func _assign_type(floor_index: int) -> MapNode.NodeType:
	if floor_index == 0:
		return MapNode.NodeType.COMBATE
	if floor_index == FLOORS - 1 or floor_index % 5 == 4:
		return MapNode.NodeType.JEFE_SOMBRA
	var roll := randf()
	if roll < 0.45:
		return MapNode.NodeType.COMBATE
	elif roll < 0.60:
		return MapNode.NodeType.EVENTO
	elif roll < 0.75:
		return MapNode.NodeType.ELITE
	elif roll < 0.88:
		return MapNode.NodeType.DESCANSO
	return MapNode.NodeType.TIENDA


func _connect_floors(current: Array, next: Array) -> void:
	# El piso del jefe (un solo nodo) recibe a todos: las líneas convergen.
	if next.size() == 1:
		for node in current:
			node.connections.append(Vector2i(next[0].floor_index, 0))
		return
	for node in current:
		var possible_targets: Array = []
		for offset in [-1, 0, 1]:
			var target_col: int = node.column + offset
			if target_col >= 0 and target_col < next.size():
				possible_targets.append(next[target_col])
		var num_connections := randi_range(1, mini(2, possible_targets.size()))
		possible_targets.shuffle()
		for i in range(num_connections):
			var target: MapNode = possible_targets[i]
			var coord := Vector2i(target.floor_index, target.column)
			if not node.connections.has(coord):
				node.connections.append(coord)
	_ensure_all_reachable(current, next)


func _ensure_all_reachable(current: Array, next: Array) -> void:
	for target in next:
		var has_incoming := false
		for node in current:
			if node.connections.has(Vector2i(target.floor_index, target.column)):
				has_incoming = true
				break
		if has_incoming:
			continue
		# Conectar desde el nodo del piso actual con columna más cercana.
		var best: MapNode = current[0]
		for node in current:
			if absi(node.column - target.column) < absi(best.column - target.column):
				best = node
		best.connections.append(Vector2i(target.floor_index, target.column))
