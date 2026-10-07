extends Node2D

const TILE_MAP_SCRIPT := preload("res://scripts/tile_map.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")


func _ready() -> void:
	var terrain := Node2D.new()
	terrain.set_script(TILE_MAP_SCRIPT)
	add_child(terrain)

	var player := CharacterBody2D.new()
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector2(480, 288)
	add_child(player)

	_build_hud()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var status := PanelContainer.new()
	status.position = Vector2(16, 16)
	status.custom_minimum_size = Vector2(300, 108)
	overlay.add_child(status)

	var status_layout := VBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 6)
	status.add_child(status_layout)

	var identity := Label.new()
	identity.text = "%s  |  Ashen Vale" % GameSession.character_name
	status_layout.add_child(identity)
	status_layout.add_child(_make_stat_bar("HP", 78.0, Color("#a9473e")))
	status_layout.add_child(_make_stat_bar("MP", 54.0, Color("#4779a8")))

	var inventory := PanelContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	inventory.offset_left = -216
	inventory.offset_top = 16
	inventory.offset_right = -16
	inventory.offset_bottom = 276
	overlay.add_child(inventory)

	var inventory_layout := VBoxContainer.new()
	inventory_layout.add_theme_constant_override("separation", 8)
	inventory.add_child(inventory_layout)

	var inventory_title := Label.new()
	inventory_title.text = "Satchel"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_layout.add_child(inventory_title)
	for slot in range(8):
		var item_slot := Label.new()
		item_slot.text = "[ %02d ]   Empty" % (slot + 1)
		inventory_layout.add_child(item_slot)

	var chat := PanelContainer.new()
	chat.position = Vector2(16, 420)
	chat.custom_minimum_size = Vector2(680, 164)
	overlay.add_child(chat)

	var chat_layout := VBoxContainer.new()
	chat.add_child(chat_layout)
	var chat_title := Label.new()
	chat_title.text = "Local chat"
	chat_layout.add_child(chat_title)

	var chat_log := RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.custom_minimum_size = Vector2(640, 82)
	chat_log.text = "Welcome to the Vale, %s." % GameSession.character_name
	chat_layout.add_child(chat_log)

	var chat_input := LineEdit.new()
	chat_input.placeholder_text = "Press Enter to send a chat message"
	chat_input.text_submitted.connect(_on_chat_submitted.bind(chat_input, chat_log))
	chat_layout.add_child(chat_input)


func _make_stat_bar(label_text: String, amount: float, fill_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 30
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.x = 240
	bar.max_value = 100
	bar.value = amount
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _make_fill_style(fill_color))
	row.add_child(bar)
	return row


func _make_fill_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(3)
	return style


func _on_chat_submitted(message: String, input: LineEdit, chat_log: RichTextLabel) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		return
	chat_log.append_text("\n%s: %s" % [GameSession.character_name, text])
	var error: Error = NetworkClient.send_message("chat_message", {"text": text})
	if error != OK:
		push_warning("Chat message was not sent: %s" % error_string(error))
	input.clear()
