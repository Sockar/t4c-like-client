extends CharacterBody2D

const MOVE_SPEED := 210.0
const PLAYER_SIZE := Vector2(22, 30)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction += Vector2(
		float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	velocity = direction * MOVE_SPEED
	move_and_slide()

	var bounds := get_viewport_rect().size
	position.x = clampf(position.x, PLAYER_SIZE.x, bounds.x - PLAYER_SIZE.x)
	position.y = clampf(position.y, PLAYER_SIZE.y, bounds.y - PLAYER_SIZE.y)


func _draw() -> void:
	var body := Rect2(Vector2(-PLAYER_SIZE.x / 2.0, -PLAYER_SIZE.y / 2.0), PLAYER_SIZE)
	draw_rect(body, Color("#26322c"))
	draw_rect(Rect2(Vector2(-8, -13), Vector2(16, 15)), Color("#b78a54"))
	draw_circle(Vector2(0, -10), 7, Color("#e2c69a"))
	draw_rect(Rect2(Vector2(-4, -11), Vector2(2, 2)), Color("#28332c"))
	draw_rect(Rect2(Vector2(2, -11), Vector2(2, 2)), Color("#28332c"))
