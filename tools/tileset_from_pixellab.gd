extends SceneTree
## Convierte un tileset Wang de PixelLab (metadata JSON + imagen PNG) a un
## TileSet de Godot 4.5 con terreno por esquinas (corner peering bits), listo
## para pintarse con set_cells_terrain_connect(). Uso:
##   godot --headless -s tools/tileset_from_pixellab.gd -- \
##       assets/tiles/grass_world_metadata.json assets/tiles/grass_world_image.png \
##       assets/tiles/grass_world.tres "Camino" "Césped"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5:
		print("Uso: tileset_from_pixellab.gd metadata.json image.png salida.tres lower_name upper_name")
		quit(1)
		return

	var metadata_path: String = args[0]
	var image_path: String = args[1]
	var output_path: String = args[2]
	var lower_name: String = args[3]
	var upper_name: String = args[4]

	var file := FileAccess.open(metadata_path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("FALLO: metadata JSON inválido")
		quit(1)
		return
	var data: Dictionary = json.data
	var tiles_meta: Array = data["tileset_data"]["tiles"]
	var tile_size: int = int(data["tileset_data"]["tile_size"]["width"])

	var sheet := Image.load_from_file(image_path)

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0, 0)
	tile_set.set_terrain_name(0, 0, lower_name)
	tile_set.add_terrain(0, 1)
	tile_set.set_terrain_name(0, 1, upper_name)

	# Un atlas propio con una celda por tile del Wang set (recortado del
	# spritesheet original por su bounding_box), en fila única.
	var atlas_image := Image.create(tile_size * tiles_meta.size(), tile_size, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture_region_size = Vector2i(tile_size, tile_size)

	for i in range(tiles_meta.size()):
		var tile_data: Dictionary = tiles_meta[i]
		var bbox: Dictionary = tile_data["bounding_box"]
		var region := Rect2i(int(bbox["x"]), int(bbox["y"]), int(bbox["width"]), int(bbox["height"]))
		atlas_image.blit_rect(sheet, region, Vector2i(i * tile_size, 0))

	var atlas_texture := ImageTexture.create_from_image(atlas_image)
	source.texture = atlas_texture

	for i in range(tiles_meta.size()):
		var tile_data: Dictionary = tiles_meta[i]
		var coord := Vector2i(i, 0)
		source.create_tile(coord)
		var tile := source.get_tile_data(coord, 0)
		tile.terrain_set = 0
		var corners: Dictionary = tile_data["corners"]
		tile.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, _terrain_id(corners["NW"]))
		tile.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, _terrain_id(corners["NE"]))
		tile.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, _terrain_id(corners["SW"]))
		tile.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, _terrain_id(corners["SE"]))

	tile_set.add_source(source, 0)

	var err := ResourceSaver.save(tile_set, output_path)
	if err != OK:
		print("FALLO: no se pudo guardar ", output_path, " (", err, ")")
		quit(1)
		return
	print("OK: ", output_path, " (", tiles_meta.size(), " tiles, terreno '", lower_name, "'/'", upper_name, "')")
	quit(0)


func _terrain_id(corner_terrain: String) -> int:
	return 1 if corner_terrain == "upper" else 0
