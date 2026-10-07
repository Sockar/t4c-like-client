extends Node2D

const TILE_MAP_SCRIPT := preload("res://scripts/tile_map.gd")
const ATTACK_ICON: Texture2D = preload("res://assets/icon_attack.svg")
const FIRE_BOLT_ICON: Texture2D = preload("res://assets/icon_fire_bolt.svg")
const HEAL_ICON: Texture2D = preload("res://assets/icon_heal.svg")
const EMPTY_SLOT_ICON: Texture2D = preload("res://assets/inventory_empty.svg")

var _health_bar: ProgressBar
var _mana_bar: ProgressBar
var _dialogue_panel: DialoguePanel


func _ready() -> void:
	var terrain := TileMap.new()
	terrain.set_script(TILE_MAP_SCRIPT)
	add_child(terrain)

	var player := WayfarerCharacter.new()
	player.position = Vector2(1024, 768)
	add_child(player)

	_build_hud(player)


func _build_hud(player: WayfarerCharacter) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var status := PanelContainer.new()
	status.position = Vector2(16, 16)
	status.custom_minimum_size = Vector2(300, 116)
	overlay.add_child(status)

	var status_layout := VBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 6)
	status.add_child(status_layout)

	var identity := Label.new()
	identity.text = "%s  |  Ashen Vale" % GameSession.character_name
	status_layout.add_child(identity)
	_health_bar = _make_stat_bar(status_layout, "HP", Color("#a9473e"))
	_mana_bar = _make_stat_bar(status_layout, "MP", Color("#4779a8"))
	player.stats_changed.connect(_on_player_stats_changed)
	_on_player_stats_changed(
		player.current_health, player.maximum_health, player.current_mana, player.maximum_mana
	)

	var inventory := PanelContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	inventory.offset_left = -296
	inventory.offset_top = 16
	inventory.offset_right = -16
	inventory.offset_bottom = 330
	overlay.add_child(inventory)

	var inventory_layout := VBoxContainer.new()
	inventory_layout.add_theme_constant_override("separation", 8)
	inventory.add_child(inventory_layout)

	var inventory_title := Label.new()
	inventory_title.text = "Satchel"
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_layout.add_child(inventory_title)

	var inventory_grid := GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.add_theme_constant_override("h_separation", 6)
	inventory_grid.add_theme_constant_override("v_separation", 6)
	inventory_layout.add_child(inventory_grid)
	for slot_index in range(12):
		var item_slot := Button.new()
		item_slot.custom_minimum_size = Vector2(54, 54)
		item_slot.icon = EMPTY_SLOT_ICON
		item_slot.expand_icon = true
		item_slot.tooltip_text = "Empty slot %d" % (slot_index + 1)
		inventory_grid.add_child(item_slot)

	var talk_button := Button.new()
	talk_button.text = "Talk · Preview"
	talk_button.pressed.connect(_on_talk_pressed)
	inventory_layout.add_child(talk_button)

	_dialogue_panel = DialoguePanel.new()
	_dialogue_panel.anchor_left = 0.5
	_dialogue_panel.anchor_right = 0.5
	_dialogue_panel.anchor_top = 0.58
	_dialogue_panel.anchor_bottom = 0.58
	_dialogue_panel.offset_left = -250
	_dialogue_panel.offset_right = 250
	_dialogue_panel.offset_top = -54
	_dialogue_panel.offset_bottom = 68
	overlay.add_child(_dialogue_panel)

	var chat := PanelContainer.new()
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat.offset_left = 16
	chat.offset_top = -194
	chat.offset_right = 354
	chat.offset_bottom = -98
	overlay.add_child(chat)

	var chat_layout := VBoxContainer.new()
	chat.add_child(chat_layout)
	var chat_title := Label.new()
	chat_title.text = "Local chat"
	chat_layout.add_child(chat_title)

	var chat_log := RichTextLabel.new()
	chat_log.bbcode_enabled = false
	chat_log.custom_minimum_size = Vector2(310, 42)
	chat_log.text = "Welcome to the Vale, %s." % GameSession.character_name
	chat_layout.add_child(chat_log)

	var chat_input := LineEdit.new()
	chat_input.placeholder_text = "Enter to send"
	chat_input.text_submitted.connect(_on_chat_submitted.bind(chat_input, chat_log))
	chat_layout.add_child(chat_input)

	_add_action_bar(overlay)


func _make_stat_bar(parent: VBoxContainer, label_text: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 30
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.x = 240
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _make_fill_style(fill_color))
	row.add_child(bar)
	parent.add_child(row)
	return bar


func _make_fill_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(3)
	return style


func _add_action_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -82
	panel.offset_bottom = -12
	parent.add_child(panel)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)

	_add_action_button(actions, "Attack", ATTACK_ICON)
	_add_action_button(actions, "Fire Bolt", FIRE_BOLT_ICON)
	_add_action_button(actions, "Heal", HEAL_ICON)


func _add_action_button(parent: HBoxContainer, action_name: String, icon: Texture2D) -> void:
	var button := Button.new()
	button.text = action_name
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(128, 52)
	button.tooltip_text = "%s (local UI placeholder)" % action_name
	button.pressed.connect(_on_action_pressed.bind(action_name))
	parent.add_child(button)


func _on_player_stats_changed(
	current_health: float, maximum_health: float, current_mana: float, maximum_mana: float
) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
	_mana_bar.max_value = maximum_mana
	_mana_bar.value = current_mana


func _on_talk_pressed() -> void:
	_dialogue_panel.show_dialogue(
		"Mara, the waykeeper", "Keep to the old stone road. The woods are calm this evening."
	)


func _on_action_pressed(action_name: String) -> void:
	print("Local action pressed: ", action_name)


func _on_chat_submitted(message: String, input: LineEdit, chat_log: RichTextLabel) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		return
	chat_log.append_text("\n%s: %s" % [GameSession.character_name, text])
	var error: Error = NetworkClient.send_message("chat_message", {"text": text})
	if error != OK:
		push_warning("Chat message was not sent: %s" % error_string(error))
	input.clear()
