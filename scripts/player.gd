class_name WayfarerCharacter
extends CharacterBody2D

signal stats_changed(
	current_health: float, maximum_health: float, current_mana: float, maximum_mana: float
)

const MOVE_SPEED := 170.0
const ZONE_PIXELS_PER_UNIT := GameSession.PIXELS_PER_ZONE_UNIT
const PLAYER_PADDING := 8.0
const SPRITESHEET: Texture2D = preload("res://assets/wayfarer_spritesheet.svg")

var maximum_health := 0.0
var current_health := 0.0
var maximum_mana := 0.0
var current_mana := 0.0

var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _zone_size := Vector2(100.0, 100.0)
var _position_update_elapsed := 0.0
var _last_server_position := Vector2(-1.0, -1.0)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1

	var hitbox := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	hitbox.shape = shape
	hitbox.position = Vector2(0, 7)
	add_child(hitbox)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.animation = "idle"
	_sprite.play()
	add_child(_sprite)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.enabled = true
	add_child(_camera)
	set_zone_size(_zone_size)

	stats_changed.emit(current_health, maximum_health, current_mana, maximum_mana)


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 2.0)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", _atlas_frame(0))
	frames.add_frame("idle", _atlas_frame(1))

	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for frame_index in range(2, 6):
		frames.add_frame("walk", _atlas_frame(frame_index))
	return frames


func _atlas_frame(frame_index: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = SPRITESHEET
	frame.region = Rect2(frame_index * 32, 0, 32, 32)
	return frame


func set_vitals(health: float, mana: float) -> void:
	current_health = clampf(health, 0.0, maximum_health)
	current_mana = clampf(mana, 0.0, maximum_mana)
	stats_changed.emit(current_health, maximum_health, current_mana, maximum_mana)


func show_number(amount: float, is_healing: bool = false) -> void:
	var number := Label.new()
	number.text = "%s%d" % ["+" if is_healing else "-", roundi(absf(amount))]
	number.add_theme_color_override(
		"font_color", Color("#a9d27e") if is_healing else Color("#f2a079")
	)
	number.position = Vector2(-18, -28)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)

	var tween := create_tween()
	tween.tween_property(number, "position", number.position - Vector2(0, 28), 0.8)
	tween.parallel().tween_property(number, "modulate:a", 0.0, 0.8)
	tween.tween_callback(number.queue_free)


func apply_character_state(state: Dictionary) -> void:
	maximum_health = maxf(1.0, float(state.get("max_hp", maximum_health)))
	current_health = clampf(float(state.get("hp", current_health)), 0.0, maximum_health)
	maximum_mana = maxf(0.0, float(state.get("max_mp", maximum_mana)))
	current_mana = clampf(float(state.get("mp", current_mana)), 0.0, maximum_mana)
	stats_changed.emit(current_health, maximum_health, current_mana, maximum_mana)


func set_zone_size(size: Vector2) -> void:
	_zone_size = Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	if _camera == null:
		return
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = roundi(_zone_size.x * ZONE_PIXELS_PER_UNIT)
	_camera.limit_bottom = roundi(_zone_size.y * ZONE_PIXELS_PER_UNIT)


func set_server_position(zone_position: Vector2) -> void:
	global_position = zone_position * ZONE_PIXELS_PER_UNIT
	_last_server_position = zone_position


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

	var map_pixels := _zone_size * ZONE_PIXELS_PER_UNIT
	position.x = clampf(position.x, PLAYER_PADDING, map_pixels.x - PLAYER_PADDING)
	position.y = clampf(position.y, PLAYER_PADDING, map_pixels.y - PLAYER_PADDING)
	_update_animation(direction)
	_send_position_update(_delta, direction)


func _send_position_update(delta: float, direction: Vector2) -> void:
	if direction == Vector2.ZERO or not NetworkClient.is_character_ready():
		return
	_position_update_elapsed += delta
	if _position_update_elapsed < 0.1:
		return
	_position_update_elapsed = 0.0

	var zone_position := global_position / ZONE_PIXELS_PER_UNIT
	if zone_position.distance_to(_last_server_position) < 0.1:
		return
	var error: Error = NetworkClient.send_message(
		"position.update", {"x": zone_position.x, "y": zone_position.y}
	)
	if error == OK:
		_last_server_position = zone_position
	elif error != ERR_UNAVAILABLE:
		push_warning("Position update failed: %s" % error_string(error))


func _update_animation(direction: Vector2) -> void:
	if direction.length_squared() > 0.0:
		if direction.x != 0.0:
			_sprite.flip_h = direction.x < 0.0
		if _sprite.animation != "walk":
			_sprite.play("walk")
	elif _sprite.animation != "idle":
		_sprite.play("idle")
