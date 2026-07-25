extends SceneTree
## Verificación headless del scaffold:
##   godot --headless --path . -s tools/verify.gd
## Comprueba: 78 CardData válidos, DAG del mapa alcanzable y con reglas.


func _initialize() -> void:
	var failures := 0

	# 1. Las 78 cartas cargan y tienen datos de tarot completos.
	var dir := DirAccess.open("res://resources/cards")
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card: CardData = load("res://resources/cards/" + file_name)
			if card == null:
				print("FALLO: no carga ", file_name)
				failures += 1
			else:
				count += 1
				if card.card_name.is_empty() or card.element.is_empty() \
						or card.upright_meaning.is_empty() or card.effects.is_empty() \
						or card.icon == null:
					print("FALLO: datos incompletos en ", card.card_name)
					failures += 1
		file_name = dir.get_next()
	if count != 78:
		print("FALLO: se esperaban 78 cartas, hay ", count)
		failures += 1
	else:
		print("OK: 78 CardData cargan con tarot, efectos e icono")

	# 2. El mapa cumple las reglas y todos los nodos son alcanzables.
	for i in range(5):
		var grid: Array = MapGenerator.new().generate_map()
		if grid.size() != 15:
			print("FALLO: pisos = ", grid.size())
			failures += 1
		var reachable := {}
		for node in grid[0]:
			reachable[Vector2i(0, node.column)] = true
		for floor_index in range(grid.size()):
			for node in grid[floor_index]:
				var coord := Vector2i(node.floor_index, node.column)
				if floor_index > 0 and not reachable.has(coord):
					print("FALLO: nodo inalcanzable ", coord)
					failures += 1
				for next_coord in node.connections:
					# Adyacencia estricta salvo el piso del jefe (converge todo).
					if grid[next_coord.x].size() > 1 and absi(next_coord.y - node.column) > 1:
						print("FALLO: conexión no adyacente ", coord, "->", next_coord)
						failures += 1
					reachable[next_coord] = true
		if grid[14].size() != 1 or grid[14][0].node_type != MapNode.NodeType.JEFE_SOMBRA:
			print("FALLO: el último piso no es un Jefe Sombra único")
			failures += 1
	print("OK: 5 mapas generados — DAG alcanzable, jefe final presente" if failures == 0 else "")

	# 3. Los 6 iconos de nodo de mapa existen (assets/map_icons/<tipo>.png).
	var missing_icons := 0
	for type_name in MapNode.NodeType.keys():
		var icon_path := "res://assets/map_icons/%s.png" % type_name.to_lower()
		if not FileAccess.file_exists(icon_path):
			print("FALLO: falta el icono ", icon_path)
			failures += 1
			missing_icons += 1
	if missing_icons == 0:
		print("OK: 6 iconos de nodo presentes en assets/map_icons/")

	# 4. Los 3 sprites de Sombras existen (assets/sombras/<tipo>.png).
	var missing_sprites := 0
	for sprite_name in ["sombra_menor", "sombra_elite", "jefe_sombra"]:
		var sprite_path := "res://assets/sombras/%s.png" % sprite_name
		if not FileAccess.file_exists(sprite_path):
			print("FALLO: falta el sprite ", sprite_path)
			failures += 1
			missing_sprites += 1
	if missing_sprites == 0:
		print("OK: 3 sprites de Sombras presentes en assets/sombras/")

	# 5. El sprite del Viajero existe (assets/viajero/viajero.png).
	if FileAccess.file_exists("res://assets/viajero/viajero.png"):
		print("OK: sprite del Viajero presente en assets/viajero/")
	else:
		print("FALLO: falta res://assets/viajero/viajero.png")
		failures += 1

	# 6. Las 78 cartas tienen pixel art y sus CardData lo usan de icono.
	var missing_pixel := 0
	var pixel_dir := DirAccess.open("res://assets/cartas_pixel")
	var pixel_count := 0
	if pixel_dir:
		pixel_dir.list_dir_begin()
		var pixel_file := pixel_dir.get_next()
		while pixel_file != "":
			if pixel_file.ends_with(".png"):
				pixel_count += 1
			pixel_file = pixel_dir.get_next()
		pixel_dir.list_dir_end()
	if pixel_count != 78:
		print("FALLO: se esperaban 78 cartas pixel art, hay ", pixel_count)
		failures += 1
		missing_pixel += 1
	# El icono de cada carta debe apuntar a cartas_pixel (lo fija generate_tres.py).
	for card in _load_all_card_data():
		if card.icon == null or not card.icon.resource_path.begins_with("res://assets/cartas_pixel/"):
			print("FALLO: %s no usa pixel art de icono" % card.card_name)
			failures += 1
			missing_pixel += 1
	if missing_pixel == 0:
		print("OK: 78 cartas con pixel art en assets/cartas_pixel/")

	# 7. Assets de UI: emblema del título, tema PixelLab y tipografía.
	var missing_ui := 0
	for ui_file in ["titulo_emblema.png", "panel_arcano.png", "boton_arcano.png",
			"barra_claridad.png", "arcana_umbra.ttf"]:
		var ui_path: String = "res://assets/ui/" + ui_file
		if not FileAccess.file_exists(ui_path):
			print("FALLO: falta ", ui_path)
			failures += 1
			missing_ui += 1
	if missing_ui == 0:
		print("OK: assets de UI presentes en assets/ui/ (emblema, panel, botón, barra, fuente)")

	# 8. IA de intenciones: patrones válidos y ciclado determinista.
	var ai_failures := 0
	for archetype in ["sombra_menor", "sombra_elite", "jefe_sombra"]:
		if not ShadowAI.PATTERNS.has(archetype):
			print("FALLO: falta patrón de IA para ", archetype)
			failures += 1
			ai_failures += 1
	# Élite y Jefe ciclan su patrón en orden exacto (sin azar).
	for archetype in ["sombra_elite", "jefe_sombra"]:
		var ai := ShadowAI.new(archetype)
		var pattern: Array = ShadowAI.PATTERNS[archetype]
		for cycle in range(2):
			for expected in pattern:
				if ai.next_intent() != expected:
					print("FALLO: %s no cicla su patrón en orden" % archetype)
					failures += 1
					ai_failures += 1
	# Valores de intención coherentes con el ataque base.
	if ShadowAI.intent_value(ShadowAI.Intent.ATAQUE_FUERTE, 8) <= 8 \
			or ShadowAI.intent_value(ShadowAI.Intent.DRENAR, 8) <= 0 \
			or ShadowAI.describe(ShadowAI.Intent.ACECHAR, 0).is_empty():
		print("FALLO: valores o descripciones de intención incoherentes")
		failures += 1
		ai_failures += 1
	if ai_failures == 0:
		print("OK: IA de intenciones — 3 arquetipos, ciclado determinista, valores coherentes")

	# 9. Animaciones de personajes: carpetas de frames idle/attack (sur).
	var missing_strips := 0
	for character in ["viajero", "sombra_menor", "sombra_elite", "jefe_sombra"]:
		for anim in ["idle_south", "attack_south"]:
			var first_frame := "res://assets/personajes/%s/%s/0.png" % [character, anim]
			if not FileAccess.file_exists(first_frame):
				print("FALLO: falta la animación ", first_frame)
				failures += 1
				missing_strips += 1
	if missing_strips == 0:
		print("OK: 8 animaciones de personaje presentes en assets/personajes/")

	# 10. Los 12 iconos zodiacales existen (assets/zodiaco/<signo>.png).
	var missing_zodiac := 0
	const ZODIAC_SIGNS := [
		"Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo", "Libra",
		"Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis",
	]
	for sign_name in ZODIAC_SIGNS:
		var key := Zodiac.sign_key(sign_name)
		if key.is_empty():
			print("FALLO: Zodiac.sign_key() no reconoce ", sign_name)
			failures += 1
			missing_zodiac += 1
			continue
		var icon_path := "res://assets/zodiaco/%s.png" % key
		if not FileAccess.file_exists(icon_path):
			print("FALLO: falta el icono zodiacal ", icon_path)
			failures += 1
			missing_zodiac += 1
	if missing_zodiac == 0:
		print("OK: 12 iconos zodiacales presentes en assets/zodiaco/")

	# 11. Zodiac.sign_for() cubre las 26 fechas límite sin off-by-one.
	var zodiac_failures := 0
	const BOUNDARY_CASES := [
		[1, 1, "Capricornio"], [1, 19, "Capricornio"], [1, 20, "Acuario"],
		[2, 18, "Acuario"], [2, 19, "Piscis"],
		[3, 20, "Piscis"], [3, 21, "Aries"],
		[4, 19, "Aries"], [4, 20, "Tauro"],
		[5, 20, "Tauro"], [5, 21, "Géminis"],
		[6, 20, "Géminis"], [6, 21, "Cáncer"],
		[7, 22, "Cáncer"], [7, 23, "Leo"],
		[8, 22, "Leo"], [8, 23, "Virgo"],
		[9, 22, "Virgo"], [9, 23, "Libra"],
		[10, 22, "Libra"], [10, 23, "Escorpio"],
		[11, 21, "Escorpio"], [11, 22, "Sagitario"],
		[12, 21, "Sagitario"], [12, 22, "Capricornio"], [12, 31, "Capricornio"],
	]
	for case in BOUNDARY_CASES:
		var got := Zodiac.sign_for(case[0], case[1])
		if got != case[2]:
			print("FALLO: Zodiac.sign_for(%d,%d) = %s, esperado %s" % [
				case[0], case[1], got, case[2]])
			failures += 1
			zodiac_failures += 1
	if zodiac_failures == 0:
		print("OK: Zodiac.sign_for() correcto en las 26 fechas límite")

	# 12. Fondos ambientales del mapa y el combate existen.
	var missing_bg := 0
	for bg_file in ["mapa_bosque.png", "combate_santuario.png"]:
		var bg_path: String = "res://assets/backgrounds/" + bg_file
		if not FileAccess.file_exists(bg_path):
			print("FALLO: falta ", bg_path)
			failures += 1
			missing_bg += 1
	if missing_bg == 0:
		print("OK: fondos ambientales presentes en assets/backgrounds/")

	print("RESULTADO: %s (%d fallos)" % ["PASA" if failures == 0 else "FALLA", failures])
	quit(1 if failures > 0 else 0)


func _load_all_card_data() -> Array:
	var cards: Array = []
	var dir := DirAccess.open("res://resources/cards")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card: CardData = load("res://resources/cards/" + file_name)
			if card:
				cards.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()
	return cards
