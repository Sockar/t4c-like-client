extends Control

var _address_input: LineEdit
var _name_input: LineEdit
var _error_label: Label


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("#18251f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 360)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "ASHEN VALE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A new frontier awaits"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)

	_address_input = _add_field(layout, "Server address", "ws://127.0.0.1:8080")
	_name_input = _add_field(layout, "Character name", "Wayfarer")
	_name_input.max_length = 24

	var connect_button := Button.new()
	connect_button.text = "Connect"
	connect_button.custom_minimum_size.y = 42
	connect_button.pressed.connect(_on_connect_pressed)
	layout.add_child(connect_button)

	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_error_label)


func _add_field(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	parent.add_child(group)

	var label := Label.new()
	label.text = label_text
	group.add_child(label)

	var input := LineEdit.new()
	input.placeholder_text = placeholder
	group.add_child(input)
	return input


func _on_connect_pressed() -> void:
	var address := _address_input.text.strip_edges()
	var character_name := _name_input.text.strip_edges()
	if address.is_empty() or character_name.is_empty():
		_error_label.text = "Enter a server address and character name."
		return
	if not address.begins_with("ws://") and not address.begins_with("wss://"):
		_error_label.text = "Server address must begin with ws:// or wss://."
		return

	GameSession.server_address = address
	GameSession.character_name = character_name
	get_tree().change_scene_to_file("res://scenes/character_creation.tscn")
