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

	print("RESULTADO: %s (%d fallos)" % ["PASA" if failures == 0 else "FALLA", failures])
	quit(1 if failures > 0 else 0)
