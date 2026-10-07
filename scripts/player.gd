class_name WayfarerCharacter
extends CharacterBody2D

signal stats_changed(
	current_health: float, maximum_health: float, current_mana: float, maximum_mana: float
)

const MOVE_SPEED := 170.0
const MAP_SIZE := Vector2(2048, 1536)
const PLAYER_PADDING := 8.0
const SPRITESHEET: Texture2D = preload("res://assets/wayfarer_spritesheet.svg")

@export var maximum_health := 100.0
@export var current_health := 78.0
@export var maximum_mana := 100.0
@export var current_mana := 54.0

var _sprite: AnimatedSprite2D


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

	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	camera.enabled = true
	add_child(camera)

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

	position.x = clampf(position.x, PLAYER_PADDING, MAP_SIZE.x - PLAYER_PADDING)
	position.y = clampf(position.y, PLAYER_PADDING, MAP_SIZE.y - PLAYER_PADDING)
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	if direction.length_squared() > 0.0:
		if direction.x != 0.0:
			_sprite.flip_h = direction.x < 0.0
		if _sprite.animation != "walk":
			_sprite.play("walk")
	elif _sprite.animation != "idle":
		_sprite.play("idle")
