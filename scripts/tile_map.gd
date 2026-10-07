extends TileMap

const TILE_SIZE := 32
const MAP_COLUMNS := 64
const MAP_ROWS := 48
const TILE_SOURCE_ID := 0
const GRASS := Vector2i(0, 0)
const PATH := Vector2i(1, 0)
const WATER := Vector2i(2, 0)
const ROCK := Vector2i(3, 0)
const TREE := Vector2i(4, 0)
const WALL := Vector2i(5, 0)
const TILE_TEXTURE: Texture2D = preload("res://assets/vale_tiles.svg")


func _ready() -> void:
	tile_set = _create_tile_set()
	_paint_zone()


func _create_tile_set() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 1)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILE_TEXTURE
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in range(6):
		atlas.create_tile(Vector2i(x, 0))
	tiles.add_source(atlas, TILE_SOURCE_ID)

	_set_collision(
		atlas,
		WATER,
		PackedVector2Array(
			[
				Vector2(0, 0),
				Vector2(32, 0),
				Vector2(32, 32),
				Vector2(0, 32),
			]
		)
	)
	_set_collision(
		atlas,
		ROCK,
		PackedVector2Array(
			[
				Vector2(4, 19),
				Vector2(8, 8),
				Vector2(18, 4),
				Vector2(28, 11),
				Vector2(29, 25),
				Vector2(18, 30),
				Vector2(5, 27),
			]
		)
	)
	_set_collision(
		atlas,
		TREE,
		PackedVector2Array(
			[
				Vector2(11, 21),
				Vector2(21, 21),
				Vector2(21, 32),
				Vector2(11, 32),
			]
		)
	)
	_set_collision(
		atlas,
		WALL,
		PackedVector2Array(
			[
				Vector2(0, 0),
				Vector2(32, 0),
				Vector2(32, 32),
				Vector2(0, 32),
			]
		)
	)
	return tiles


func _set_collision(
	atlas: TileSetAtlasSource, coordinates: Vector2i, points: PackedVector2Array
) -> void:
	var data := atlas.get_tile_data(coordinates, 0)
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, points)


func _paint_zone() -> void:
	for y in range(MAP_ROWS):
		for x in range(MAP_COLUMNS):
			set_cell(0, Vector2i(x, y), TILE_SOURCE_ID, GRASS)

	for x in range(MAP_COLUMNS):
		var center_y := _road_y(x)
		_paint_cell(Vector2i(x, center_y), PATH)
		_paint_cell(Vector2i(x, center_y + 1), PATH)

	for y in range(MAP_ROWS):
		var trail_x := _trail_x(y)
		_paint_cell(Vector2i(trail_x, y), PATH)
		_paint_cell(Vector2i(trail_x + 1, y), PATH)

	_paint_pond()
	_paint_ruins()
	_paint_scattered_trees()


func _paint_pond() -> void:
	for y in range(5, 15):
		for x in range(7, 18):
			var dx := (float(x) - 12.0) / 5.0
			var dy := (float(y) - 10.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				_paint_cell(Vector2i(x, y), WATER)


func _paint_ruins() -> void:
	for x in range(48, 55):
		if x != 51:
			_paint_cell(Vector2i(x, 9), WALL)
			_paint_cell(Vector2i(x, 15), WALL)
	for y in range(10, 15):
		_paint_cell(Vector2i(48, y), WALL)
		_paint_cell(Vector2i(54, y), WALL)
	for cell in [Vector2i(24, 12), Vector2i(25, 12), Vector2i(25, 13), Vector2i(35, 34)]:
		_paint_cell(cell, ROCK)


func _paint_scattered_trees() -> void:
	for y in range(3, MAP_ROWS - 2, 3):
		for x in range(3, MAP_COLUMNS - 2, 4):
			if (x * 17 + y * 31) % 7 > 2:
				continue
			if abs(y - _road_y(x)) <= 2 or abs(x - _trail_x(y)) <= 2:
				continue
			if x >= 6 and x <= 18 and y >= 4 and y <= 15:
				continue
			if x >= 47 and x <= 55 and y >= 8 and y <= 16:
				continue
			_paint_cell(Vector2i(x, y), TREE)


func _paint_cell(cell: Vector2i, atlas_coordinates: Vector2i) -> void:
	set_cell(0, cell, TILE_SOURCE_ID, atlas_coordinates)


func _road_y(x: int) -> int:
	return 23 + roundi(sin(float(x) * 0.11) * 3.0)


func _trail_x(y: int) -> int:
	return 40 + roundi(cos(float(y) * 0.13) * 2.0)
