class_name MosswakeMap
extends TileMap

const TILE_SIZE := 32
const ZONE_UNITS_PER_TILE := 2.0
const TILE_SOURCE_ID := 0
const GRASS := Vector2i(0, 0)
const PATH := Vector2i(1, 0)
const WATER := Vector2i(2, 0)
const ROCK := Vector2i(3, 0)
const TREE := Vector2i(4, 0)
const WALL := Vector2i(5, 0)
const TILE_TEXTURE: Texture2D = preload("res://assets/vale_tiles.svg")

var zone_size := Vector2i(100, 100)


func _ready() -> void:
	tile_set = _create_tile_set()
	_paint_zone()


func set_zone_size(width: int, height: int) -> void:
	zone_size = Vector2i(maxi(1, width), maxi(1, height))
	if tile_set != null:
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
	clear()
	var columns := ceili(float(zone_size.x) / ZONE_UNITS_PER_TILE)
	var rows := ceili(float(zone_size.y) / ZONE_UNITS_PER_TILE)
	for y in range(rows):
		for x in range(columns):
			set_cell(0, Vector2i(x, y), TILE_SOURCE_ID, GRASS)

	for x in range(columns):
		var center_y := _road_y(x, rows)
		_paint_cell(Vector2i(x, center_y), PATH)
		_paint_cell(Vector2i(x, center_y + 1), PATH)

	for y in range(rows):
		var trail_x := _trail_x(y, columns)
		_paint_cell(Vector2i(trail_x, y), PATH)
		_paint_cell(Vector2i(trail_x + 1, y), PATH)

	_paint_pond(columns, rows)
	_paint_ruins(columns, rows)
	_paint_scattered_trees(columns, rows)


func _paint_pond(columns: int, rows: int) -> void:
	var center_x := float(columns) * 0.23
	var center_y := float(rows) * 0.2
	for y in range(maxi(2, int(center_y) - 5), mini(rows - 2, int(center_y) + 6)):
		for x in range(maxi(2, int(center_x) - 6), mini(columns - 2, int(center_x) + 7)):
			var dx := (float(x) - center_x) / 5.0
			var dy := (float(y) - center_y) / 4.0
			if dx * dx + dy * dy <= 1.0:
				_paint_cell(Vector2i(x, y), WATER)


func _paint_ruins(columns: int, rows: int) -> void:
	var left := int(float(columns) * 0.76)
	var top := int(float(rows) * 0.16)
	var right := mini(columns - 2, left + 6)
	var bottom := mini(rows - 2, top + 6)
	for x in range(left, right + 1):
		if x != left + 3:
			_paint_cell(Vector2i(x, top), WALL)
			_paint_cell(Vector2i(x, bottom), WALL)
	for y in range(top + 1, bottom):
		_paint_cell(Vector2i(left, y), WALL)
		_paint_cell(Vector2i(right, y), WALL)
	for cell in [
		Vector2i(int(float(columns) * 0.38), int(float(rows) * 0.26)),
		Vector2i(int(float(columns) * 0.40), int(float(rows) * 0.26)),
		Vector2i(int(float(columns) * 0.40), int(float(rows) * 0.28)),
		Vector2i(int(float(columns) * 0.64), int(float(rows) * 0.72)),
	]:
		_paint_cell(cell, ROCK)


func _paint_scattered_trees(columns: int, rows: int) -> void:
	for y in range(3, rows - 2, 3):
		for x in range(3, columns - 2, 4):
			if (x * 17 + y * 31) % 7 > 2:
				continue
			if abs(y - _road_y(x, rows)) <= 2 or abs(x - _trail_x(y, columns)) <= 2:
				continue
			if (
				x >= int(float(columns) * 0.12)
				and x <= int(float(columns) * 0.36)
				and y >= int(float(rows) * 0.1)
				and y <= int(float(rows) * 0.3)
			):
				continue
			if (
				x >= int(float(columns) * 0.74)
				and x <= int(float(columns) * 0.9)
				and y >= int(float(rows) * 0.14)
				and y <= int(float(rows) * 0.32)
			):
				continue
			_paint_cell(Vector2i(x, y), TREE)


func _paint_cell(cell: Vector2i, atlas_coordinates: Vector2i) -> void:
	set_cell(0, cell, TILE_SOURCE_ID, atlas_coordinates)


func _road_y(x: int, rows: int) -> int:
	return int(float(rows) * 0.48) + roundi(sin(float(x) * 0.23) * float(rows) * 0.06)


func _trail_x(y: int, columns: int) -> int:
	return int(float(columns) * 0.75) + roundi(cos(float(y) * 0.2) * 2.0)
