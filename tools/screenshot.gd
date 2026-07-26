extends Node
## Capturas de pantalla reales del juego para inspección visual. Uso:
##   ARCANA_TEST=1 ARCANA_SHOT_DIR=/ruta godot --path . res://tools/Screenshot.tscn
## Abre la ventana, recorre título -> intro (amnesia) -> identidad -> mapa ->
## combate (+ diálogo de fin de combate) -> mazo -> evento -> tienda ->
## diario -> perfil (con signo zodiacal) y guarda un PNG por pantalla en
## ARCANA_SHOT_DIR (o user://shots).

var _main: Node
var _dir := "user://shots"


func _ready() -> void:
	var env := OS.get_environment("ARCANA_SHOT_DIR")
	if not env.is_empty():
		_dir = env
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _shot("01_titulo")
	_main.show_intro()
	await _shot("01a_intro")
	_main.show_identity()
	await _shot("01b_identidad")
	# Simula confirmar el formulario: nombre + una fecha de cada mitad del
	# año, para comprobar que Zodiac.sign_for() se refleja en el perfil.
	GameState.define_identity("Estela", 8, 15)  # 15 ago -> Leo
	_main.show_map()
	await _shot("02_mapa")
	var node := MapNode.new()
	node.node_type = MapNode.NodeType.JEFE_SOMBRA
	node.floor_index = 4
	_main._start_combat(node)
	await _shot("03_combate")
	# Diálogos (AcceptDialog): NO usan el panel ornamentado del tema, así que
	# necesitan verificación visual aparte (ver ui_theme.gd).
	_main._current.manager.enemy.take_damage(9999)
	await _shot("03b_combate_dialogo_fin")
	_main.show_map()
	_main.show_deck_builder()
	await _shot("04_mazo")
	_main._current._show_card_detail(GameState.all_cards[0])
	await _shot("04b_mazo_dialogo_carta")
	_main._start_event(node)
	await _shot("05_evento")
	_main._start_shop(node)
	await _shot("06_tienda")
	_main.show_journal()
	await _shot("07_diario")
	_main.show_profile(_main.show_title)
	await _shot("08_perfil")
	print("CAPTURAS: 12 guardadas en ", _dir)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	# Dos frames para layout + el fundido de entrada casi completo.
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(shot_name + ".png"))
