extends Node2D

const TILE_SIZE := 48
const MAP_COLUMNS := 20
const MAP_ROWS := 12


func _draw() -> void:
	for y in range(MAP_ROWS):
		for x in range(MAP_COLUMNS):
			var color := Color("#566b45") if (x + y) % 2 == 0 else Color("#5d714a")
			if _is_path_tile(x, y):
				color = Color("#9a8058") if (x + y) % 2 == 0 else Color("#a48a61")
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, color)
			draw_rect(rect, Color("#1e2c20"), false, 1.0)
			if not _is_path_tile(x, y) and (x * 7 + y * 11) % 19 == 0:
				draw_circle(rect.position + Vector2(14, 14), 3, Color("#718258"))


func _is_path_tile(x: int, y: int) -> bool:
	return (y >= 5 and y <= 6) or (x >= 9 and x <= 10 and y >= 2 and y <= 9)
