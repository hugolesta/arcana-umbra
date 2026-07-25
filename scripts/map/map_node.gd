class_name MapNode
extends Resource
## Un nodo del mapa procedural (DAG por pisos, estilo Slay the Spire).

enum NodeType { COMBATE, ELITE, DESCANSO, TIENDA, EVENTO, JEFE_SOMBRA }

@export var node_type: NodeType
@export var floor_index: int = 0
@export var column: int = 0
@export var connections: Array[Vector2i] = []  # (floor_index, column) de nodos siguientes
@export var visited: bool = false
@export var available: bool = false


func type_label() -> String:
	match node_type:
		NodeType.COMBATE: return "Combate"
		NodeType.ELITE: return "Élite"
		NodeType.DESCANSO: return "Descanso"
		NodeType.TIENDA: return "Tienda"
		NodeType.EVENTO: return "Evento"
		NodeType.JEFE_SOMBRA: return "Jefe Sombra"
	return "?"


func to_dict() -> Dictionary:
	var conns: Array = []
	for c in connections:
		conns.append([c.x, c.y])
	return {
		"node_type": node_type,
		"floor_index": floor_index,
		"column": column,
		"connections": conns,
		"visited": visited,
		"available": available,
	}


static func from_dict(data: Dictionary) -> MapNode:
	var node := MapNode.new()
	node.node_type = int(data.get("node_type", NodeType.COMBATE)) as NodeType
	node.floor_index = int(data.get("floor_index", 0))
	node.column = int(data.get("column", 0))
	for c in data.get("connections", []):
		node.connections.append(Vector2i(int(c[0]), int(c[1])))
	node.visited = bool(data.get("visited", false))
	node.available = bool(data.get("available", false))
	return node
