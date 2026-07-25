extends Node
## Autoload GameState: meta-progresión, mazo del jugador y estado del run.
## Serializa a user://progress.save en JSON (el mapa se guarda apenas se
## genera para poder continuar el run si se cierra la app).

const SAVE_PATH := "user://progress.save"
const JOURNAL_PATH := "user://journal.save"
const CARDS_DIR := "res://resources/cards"
const EVENT_CLARIDAD_REWARD := 8

const STARTER_DECK_NAMES: Array[String] = [
	"As de Espadas", "2 de Espadas", "3 de Espadas",
	"As de Oros", "2 de Oros",
	"As de Copas", "2 de Copas",
	"As de Bastos", "2 de Bastos",
	"El Loco",
]

var all_cards: Array[CardData] = []
var mazo_permanente: Array[CardData] = []
var cartas_integradas: Array[String] = []

var player_max_claridad: int = 50
var player_claridad: int = 50

var map_grid: Array = []  # Array de pisos; cada piso es Array[MapNode]
var current_node_coord: Vector2i = Vector2i(-1, -1)

# Diario del Viajero: persiste entre runs (no se borra al reiniciar el mapa).
var journal_entries: Array = []


func _ready() -> void:
	_load_all_cards()
	load_journal()
	if not load_progress():
		start_new_run()


func start_new_run() -> void:
	player_claridad = player_max_claridad
	if mazo_permanente.is_empty():
		_build_starter_deck()
	map_grid = MapGenerator.new().generate_map()
	current_node_coord = Vector2i(-1, -1)
	save_progress()


func get_node_at(coord: Vector2i) -> MapNode:
	if coord.x < 0 or coord.x >= map_grid.size():
		return null
	var floor_nodes: Array = map_grid[coord.x]
	if coord.y < 0 or coord.y >= floor_nodes.size():
		return null
	return floor_nodes[coord.y]


func mark_visited(node: MapNode) -> void:
	node.visited = true
	current_node_coord = Vector2i(node.floor_index, node.column)
	for floor_nodes in map_grid:
		for other in floor_nodes:
			other.available = false
	for coord in node.connections:
		var target := get_node_at(coord)
		if target:
			target.available = true
	save_progress()


func run_completed() -> bool:
	return current_node_coord.x == map_grid.size() - 1


func reflect_on_card(card: CardData, reversed: bool, question: String, text: String) -> void:
	journal_entries.append({
		"fecha": Time.get_datetime_string_from_system(),
		"carta": card.card_name,
		"invertida": reversed,
		"piso": current_node_coord.x,
		"pregunta": question,
		"texto": text,
	})
	save_journal()
	if not cartas_integradas.has(card.card_name):
		cartas_integradas.append(card.card_name)
	player_claridad = mini(player_claridad + EVENT_CLARIDAD_REWARD, player_max_claridad)
	save_progress()


func save_journal() -> void:
	var file := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"entradas": journal_entries}))


func load_journal() -> bool:
	journal_entries.clear()
	if not FileAccess.file_exists(JOURNAL_PATH):
		return false
	var file := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		return false
	for entry in parsed.get("entradas", []):
		if entry is Dictionary:
			journal_entries.append(entry)
	return true


func find_card(card_name: String) -> CardData:
	for card in all_cards:
		if card.card_name == card_name:
			return card
	return null


func save_progress() -> void:
	var map_data: Array = []
	for floor_nodes in map_grid:
		var floor_dicts: Array = []
		for node in floor_nodes:
			floor_dicts.append(node.to_dict())
		map_data.append(floor_dicts)
	var deck_names: Array = []
	for card in mazo_permanente:
		deck_names.append(card.card_name)
	var save_dict := {
		"integradas": cartas_integradas,
		"deck": deck_names,
		"claridad": player_claridad,
		"max_claridad": player_max_claridad,
		"map": map_data,
		"current_node": [current_node_coord.x, current_node_coord.y],
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))


func load_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	cartas_integradas.clear()
	for n in data.get("integradas", []):
		cartas_integradas.append(str(n))
	mazo_permanente.clear()
	for n in data.get("deck", []):
		var card := find_card(str(n))
		if card:
			mazo_permanente.append(card)
	if mazo_permanente.is_empty():
		_build_starter_deck()
	player_max_claridad = int(data.get("max_claridad", 50))
	player_claridad = int(data.get("claridad", player_max_claridad))
	map_grid.clear()
	for floor_dicts in data.get("map", []):
		var floor_nodes: Array = []
		for node_dict in floor_dicts:
			floor_nodes.append(MapNode.from_dict(node_dict))
		map_grid.append(floor_nodes)
	if map_grid.is_empty():
		return false
	var coord: Array = data.get("current_node", [-1, -1])
	current_node_coord = Vector2i(int(coord[0]), int(coord[1]))
	return true


func _build_starter_deck() -> void:
	mazo_permanente.clear()
	for card_name in STARTER_DECK_NAMES:
		var card := find_card(card_name)
		if card:
			mazo_permanente.append(card)


func _load_all_cards() -> void:
	all_cards.clear()
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		push_error("No se encontró %s — ejecuta tools/generate_tres.py" % CARDS_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card: CardData = load(CARDS_DIR.path_join(file_name))
			if card:
				all_cards.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()
	all_cards.sort_custom(func(a, b): return a.card_name < b.card_name)
