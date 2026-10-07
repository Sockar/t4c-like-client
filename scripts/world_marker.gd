class_name WorldMarker
extends Node2D

signal selected(marker: WorldMarker)

const ZONE_PIXELS_PER_UNIT := GameSession.PIXELS_PER_ZONE_UNIT

var entity_id := ""
var entity_kind := ""
var entity_data: Dictionary = {}
var _selected := false
var _name_label: Label
var _health := -1.0
var _maximum_health := -1.0
var _hit_area: Area2D


func _ready() -> void:
	_hit_area = Area2D.new()
	_hit_area.collision_layer = 2
	_hit_area.collision_mask = 0
	_hit_area.input_pickable = true
	_hit_area.input_event.connect(_on_input_event)
	add_child(_hit_area)

	var hit_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 19.0
	hit_shape.shape = circle
	_hit_area.add_child(hit_shape)

	_name_label = Label.new()
	_name_label.position = Vector2(-70, -46)
	_name_label.size = Vector2(140, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_refresh_label()


func update_entity(data: Dictionary) -> void:
	entity_data = data.duplicate(true)
	var entity_name := str(data.get("name", entity_id))
	if _name_label != null:
		_name_label.text = entity_name
	if data.has("x") and data.has("y"):
		global_position = Vector2(float(data["x"]), float(data["y"])) * ZONE_PIXELS_PER_UNIT
	if data.has("hp"):
		_health = float(data["hp"])
	if data.has("max_hp"):
		_maximum_health = float(data["max_hp"])
	queue_redraw()


func set_selected(value: bool) -> void:
	_selected = value
	_refresh_label()
	queue_redraw()


func set_health(value: float) -> void:
	_health = value
	if _maximum_health < 0.0:
		_maximum_health = maxf(value, 1.0)
	queue_redraw()


func get_health() -> float:
	return _health


func show_number(amount: float, is_healing: bool = false) -> void:
	var number := Label.new()
	number.text = "%s%d" % ["+" if is_healing else "-", roundi(absf(amount))]
	number.add_theme_color_override(
		"font_color", Color("#a9d27e") if is_healing else Color("#f2a079")
	)
	number.position = Vector2(-20, -20)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)

	var tween := create_tween()
	tween.tween_property(number, "position", number.position - Vector2(0, 28), 0.8)
	tween.parallel().tween_property(number, "modulate:a", 0.0, 0.8)
	tween.tween_callback(number.queue_free)


func _draw() -> void:
	var tint := _marker_color()
	if entity_kind == "monster":
		draw_colored_polygon(_ellipse_points(Vector2.ZERO, Vector2(13, 9)), tint)
		draw_circle(Vector2(-8, -5), 3, tint.lightened(0.2))
		draw_circle(Vector2(8, -5), 3, tint.lightened(0.2))
		draw_circle(Vector2(-4, -1), 1.5, Color("#2c2922"))
		draw_circle(Vector2(4, -1), 1.5, Color("#2c2922"))
	elif entity_kind == "player":
		draw_circle(Vector2.ZERO, 10, Color("#2d392f"))
		draw_rect(Rect2(-7, -5, 14, 13), tint)
		draw_circle(Vector2(0, -7), 5, Color("#ddbd91"))
	else:
		draw_circle(Vector2.ZERO, 11, Color("#2d392f"))
		draw_rect(Rect2(-7, -5, 14, 15), tint)
		draw_circle(Vector2(0, -8), 5, Color("#e0c296"))

	if _selected:
		draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color("#f0d18b"), 2.0)
	if _maximum_health > 0:
		draw_rect(Rect2(-18, 16, 36, 4), Color("#2d2923"))
		var width := 36.0 * clampf(_health / _maximum_health, 0.0, 1.0)
		draw_rect(Rect2(-18, 16, width, 4), Color("#9c4b3e"))


func _marker_color() -> Color:
	match entity_kind:
		"monster":
			return Color("#a96d49")
		"player":
			return Color("#6e91a3")
		_:
			return Color("#79915a")


func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	return points


func _refresh_label() -> void:
	if _name_label != null and not entity_id.is_empty():
		_name_label.text = "%s%s" % ["▶ " if _selected else "", entity_data.get("name", entity_id)]


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)
