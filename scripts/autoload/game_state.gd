extends Node
## Autoload GameState: meta-progresión, mazo del jugador y estado del run.
## Serializa a user://progress.save en JSON (el mapa se guarda apenas se
## genera para poder continuar el run si se cierra la app).

const SAVE_PATH := "user://progress.save"
const JOURNAL_PATH := "user://journal.save"
const CARDS_DIR := "res://resources/cards"
const EVENT_CLARIDAD_REWARD := 8

# Esencia: moneda del run. Se gana venciendo Sombras, se gasta en la tienda.
const ESENCIA_COMBATE := 12
const ESENCIA_ELITE := 25
const ESENCIA_JEFE := 50
const MIN_DECK_SIZE := 5
const DEFAULT_NICK := "Viajero"

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
var esencia: int = 0
var player_nick: String = DEFAULT_NICK

var map_grid: Array = []  # Array de pisos; cada piso es Array[MapNode]
var current_node_coord: Vector2i = Vector2i(-1, -1)

# Diario del Viajero: persiste entre runs (no se borra al reiniciar el mapa).
var journal_entries: Array = []

# Rutas efectivas de guardado. Con ARCANA_TEST=1 (smokes/simulación) se usan
# archivos aparte y limpios: los tests JAMÁS tocan el progreso real.
var save_path := SAVE_PATH
var journal_path := JOURNAL_PATH


func _ready() -> void:
	if OS.get_environment("ARCANA_TEST") == "1":
		save_path = "user://test_progress.save"
		journal_path = "user://test_journal.save"
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
		if FileAccess.file_exists(journal_path):
			DirAccess.remove_absolute(journal_path)
	_load_all_cards()
	load_journal()
	if not load_progress():
		start_new_run()


func start_new_run() -> void:
	player_claridad = player_max_claridad
	esencia = 0
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


func esencia_reward_for(node_type: MapNode.NodeType) -> int:
	match node_type:
		MapNode.NodeType.ELITE:
			return ESENCIA_ELITE
		MapNode.NodeType.JEFE_SOMBRA:
			return ESENCIA_JEFE
	return ESENCIA_COMBATE


func add_esencia(amount: int) -> void:
	esencia += amount
	save_progress()


func set_player_nick(nick: String) -> void:
	var trimmed := nick.strip_edges()
	player_nick = trimmed if not trimmed.is_empty() else DEFAULT_NICK
	save_progress()


func card_price(card: CardData) -> int:
	var price := 50 if card.suit == CardData.Suit.ARCANO_MAYOR else 25
	if cartas_integradas.has(card.card_name):
		price /= 2  # la Integración abarata la carta: el journaling paga
	return price


func buy_card(card: CardData) -> bool:
	var price := card_price(card)
	if esencia < price:
		return false
	esencia -= price
	mazo_permanente.append(card)
	save_progress()
	return true


func remove_card(card: CardData, price: int) -> bool:
	if esencia < price or mazo_permanente.size() <= MIN_DECK_SIZE:
		return false
	if not mazo_permanente.has(card):
		return false
	esencia -= price
	mazo_permanente.erase(card)
	save_progress()
	return true


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
	var file := FileAccess.open(journal_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"entradas": journal_entries}))


func load_journal() -> bool:
	journal_entries.clear()
	if not FileAccess.file_exists(journal_path):
		return false
	var file := FileAccess.open(journal_path, FileAccess.READ)
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
		"esencia": esencia,
		"nick": player_nick,
		"map": map_data,
		"current_node": [current_node_coord.x, current_node_coord.y],
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))


func load_progress() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
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
	esencia = int(data.get("esencia", 0))
	var nick := str(data.get("nick", DEFAULT_NICK)).strip_edges()
	player_nick = nick if not nick.is_empty() else DEFAULT_NICK
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
