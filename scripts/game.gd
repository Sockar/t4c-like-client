extends Node2D

const ATTACK_ICON: Texture2D = preload("res://assets/icon_attack.svg")
const FIRE_BOLT_ICON: Texture2D = preload("res://assets/icon_fire_bolt.svg")
const HEAL_ICON: Texture2D = preload("res://assets/icon_heal.svg")
const EMPTY_SLOT_ICON: Texture2D = preload("res://assets/inventory_empty.svg")
const QUEST_GIVER_FALLBACK := {"fen_patrol": "npc_maela"}
const ATTACK_RANGE := 8.0
const TALK_RANGE := 5.0

var _terrain: MosswakeMap
var _player: WayfarerCharacter
var _connection_label: Label
var _zone_label: Label
var _experience_label: Label
var _health_bar: ProgressBar
var _mana_bar: ProgressBar
var _health_text: Label
var _mana_text: Label
var _chat_log: RichTextLabel
var _dialogue_panel: DialoguePanel
var _quest_list: VBoxContainer
var _markers: Dictionary = {}
var _quests: Dictionary = {}
var _quest_givers: Dictionary = {}
var _selected_entity_id := ""
var _zone_size := Vector2i(100, 100)


func _ready() -> void:
	_terrain = MosswakeMap.new()
	_terrain.name = "Terrain"
	add_child(_terrain)

	_player = WayfarerCharacter.new()
	_player.name = "LocalPlayer"
	_player.position = Vector2(50, 50) * GameSession.PIXELS_PER_ZONE_UNIT
	add_child(_player)

	_build_hud()
	_player.stats_changed.connect(_on_player_stats_changed)
	_connect_network_signals()
	if not GameSession.character_state.is_empty():
		_on_character_state_updated(GameSession.character_state)
	_on_world_updated(NetworkClient.get_current_world())


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var status := PanelContainer.new()
	status.position = Vector2(16, 16)
	status.custom_minimum_size = Vector2(330, 136)
	overlay.add_child(status)

	var status_layout := VBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 5)
	status.add_child(status_layout)

	var identity := Label.new()
	identity.text = "%s  |  Ashen Vale" % GameSession.character_name
	status_layout.add_child(identity)
	_zone_label = Label.new()
	_zone_label.text = "Connecting to Mosswake Fen..."
	status_layout.add_child(_zone_label)
	var health_controls := _make_stat_bar(status_layout, "HP", Color("#a9473e"))
	_health_bar = health_controls["bar"]
	_health_text = health_controls["value"]
	var mana_controls := _make_stat_bar(status_layout, "MP", Color("#4779a8"))
	_mana_bar = mana_controls["bar"]
	_mana_text = mana_controls["value"]
	_experience_label = Label.new()
	_experience_label.text = "XP: %d" % roundi(GameSession.experience)
	status_layout.add_child(_experience_label)
	_connection_label = Label.new()
	_connection_label.text = "Connecting..."
	status_layout.add_child(_connection_label)

	_build_inventory(overlay)
	_build_quest_log(overlay)
	_build_dialogue_panel(overlay)
	_build_chat(overlay)
	_add_action_bar(overlay)


func _build_inventory(parent: Control) -> void:
	var inventory := PanelContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	inventory.offset_left = -296
	inventory.offset_top = 16
	inventory.offset_right = -16
	inventory.offset_bottom = 330
	parent.add_child(inventory)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	inventory.add_child(layout)

	var title := Label.new()
	title.text = "Satchel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(grid)
	for slot_index in range(12):
		var item_slot := Button.new()
		item_slot.custom_minimum_size = Vector2(54, 54)
		item_slot.icon = EMPTY_SLOT_ICON
		item_slot.expand_icon = true
		item_slot.tooltip_text = "Empty slot %d" % (slot_index + 1)
		grid.add_child(item_slot)


func _build_quest_log(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -296
	panel.offset_top = 342
	panel.offset_right = -16
	panel.offset_bottom = 584
	parent.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "Quest log"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var talk_button := Button.new()
	talk_button.text = "Talk to nearby NPC (E)"
	talk_button.pressed.connect(_on_talk_pressed)
	layout.add_child(talk_button)

	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 6)
	layout.add_child(_quest_list)
	_refresh_quest_log()


func _build_dialogue_panel(parent: Control) -> void:
	_dialogue_panel = DialoguePanel.new()
	_dialogue_panel.anchor_left = 0.5
	_dialogue_panel.anchor_right = 0.5
	_dialogue_panel.anchor_top = 0.34
	_dialogue_panel.anchor_bottom = 0.34
	_dialogue_panel.offset_left = -250
	_dialogue_panel.offset_right = 250
	_dialogue_panel.offset_top = -62
	_dialogue_panel.offset_bottom = 130
	_dialogue_panel.quest_accept_requested.connect(_on_quest_accept_requested)
	parent.add_child(_dialogue_panel)


func _build_chat(parent: Control) -> void:
	var chat := PanelContainer.new()
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat.offset_left = 16
	chat.offset_top = -194
	chat.offset_right = 354
	chat.offset_bottom = -98
	parent.add_child(chat)

	var layout := VBoxContainer.new()
	chat.add_child(layout)
	var title := Label.new()
	title.text = "Local chat"
	layout.add_child(title)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = false
	_chat_log.custom_minimum_size = Vector2(310, 42)
	_chat_log.text = "Connected chat messages will appear here."
	layout.add_child(_chat_log)

	var input := LineEdit.new()
	input.placeholder_text = "Enter to send"
	input.text_submitted.connect(_on_chat_submitted.bind(input))
	layout.add_child(input)


func _connect_network_signals() -> void:
	NetworkClient.connection_status_changed.connect(_on_connection_status_changed)
	NetworkClient.character_state_updated.connect(_on_character_state_updated)
	NetworkClient.world_updated.connect(_on_world_updated)
	NetworkClient.chat_message_received.connect(_on_chat_message_received)
	NetworkClient.combat_result_received.connect(_on_combat_result_received)
	NetworkClient.magic_result_received.connect(_on_magic_result_received)
	NetworkClient.npc_dialogue_received.connect(_on_npc_dialogue_received)
	NetworkClient.quest_updated.connect(_on_quest_updated)
	NetworkClient.experience_updated.connect(_on_experience_updated)
	NetworkClient.server_error_received.connect(_on_server_error_received)


func _make_stat_bar(parent: VBoxContainer, label_text: String, fill_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 30
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.x = 180
	bar.max_value = 1
	bar.value = 0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _make_fill_style(fill_color))
	row.add_child(bar)
	var value := Label.new()
	value.text = "-- / --"
	value.custom_minimum_size.x = 70
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)
	return {"bar": bar, "value": value}


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
	button.pressed.connect(_on_action_pressed.bind(action_name))
	parent.add_child(button)


func _on_player_stats_changed(
	current_health: float, maximum_health: float, current_mana: float, maximum_mana: float
) -> void:
	_health_bar.max_value = maxf(1.0, maximum_health)
	_health_bar.value = current_health
	_mana_bar.max_value = maxf(1.0, maximum_mana)
	_mana_bar.value = current_mana
	_health_text.text = "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	_mana_text.text = "%d / %d" % [roundi(current_mana), roundi(maximum_mana)]


func _on_connection_status_changed(status: String, detail: String) -> void:
	if _connection_label == null:
		return
	_connection_label.text = "%s: %s" % [status.capitalize(), detail]
	_connection_label.add_theme_color_override(
		"font_color",
		Color("#de9a73") if status == "error" or status == "closed" else Color("#d5c99f")
	)


func _on_character_state_updated(state: Dictionary) -> void:
	GameSession.character_state = state.duplicate(true)
	GameSession.character_id = str(state.get("id", state.get("character_id", "")))
	_player.apply_character_state(state)
	_on_experience_updated({"total": state.get("xp", 0), "gained": 0})
	var quests: Variant = state.get("quests", [])
	if quests is Dictionary:
		quests = quests.values()
	for quest in quests:
		if quest is Dictionary:
			_on_quest_updated(quest)


func _on_world_updated(world: Dictionary) -> void:
	var zone: Dictionary = world.get("zone", {})
	var width := int(zone.get("width", _zone_size.x))
	var height := int(zone.get("height", _zone_size.y))
	var new_zone_size := Vector2i(maxi(1, width), maxi(1, height))
	_zone_label.text = (
		"%s (%d × %d)"
		% [
			str(zone.get("name", "Mosswake Fen")),
			new_zone_size.x,
			new_zone_size.y,
		]
	)
	if new_zone_size != _zone_size:
		_zone_size = new_zone_size
		_terrain.set_zone_size(width, height)
		_player.set_zone_size(Vector2(width, height))

	var active_ids: Dictionary = {}
	for category in ["players", "npcs", "monsters"]:
		for entity in world.get(category, []):
			if not entity is Dictionary:
				continue
			var entity_id := _entity_id(entity)
			if entity_id.is_empty():
				continue
			if category == "players" and _is_local_player(entity, entity_id):
				if entity.has("x") and entity.has("y"):
					_player.set_server_position(Vector2(float(entity["x"]), float(entity["y"])))
				if (
					entity.has("hp")
					or entity.has("max_hp")
					or entity.has("mp")
					or entity.has("max_mp")
				):
					_player.apply_character_state(entity)
				continue

			var kind := (
				"npc" if category == "npcs" else ("monster" if category == "monsters" else "player")
			)
			var marker: WorldMarker = _markers.get(entity_id)
			if marker == null or not is_instance_valid(marker):
				marker = WorldMarker.new()
				marker.entity_id = entity_id
				marker.entity_kind = kind
				marker.selected.connect(_on_marker_selected)
				_markers[entity_id] = marker
				add_child(marker)
			marker.update_entity(entity)
			active_ids[entity_id] = true
			if category == "npcs":
				_remember_quest_givers(entity)

	for entity_id in _markers.keys():
		if active_ids.has(entity_id):
			continue
		_markers[entity_id].queue_free()
		_markers.erase(entity_id)
		if _selected_entity_id == entity_id:
			_selected_entity_id = ""
			_update_marker_selection()


func _on_chat_message_received(message: Dictionary) -> void:
	_chat_log.append_text(
		"\n%s: %s" % [str(message.get("from", "Someone")), str(message.get("message", ""))]
	)


func _on_combat_result_received(result: Dictionary) -> void:
	var target_id := str(result.get("target_id", ""))
	var marker: WorldMarker = _markers.get(target_id)
	if marker != null:
		marker.show_number(float(result.get("damage", 0)))
		marker.set_health(float(result.get("target_hp_remaining", marker.get_health())))
		if bool(result.get("target_defeated", false)):
			_remove_marker(target_id)
	elif target_id == "self" or _is_local_character(target_id):
		var damage := float(result.get("damage", 0))
		_player.show_number(damage)
		_player.set_vitals(
			float(result.get("target_hp_remaining", _player.current_health - damage)),
			_player.current_mana
		)
	_set_connection_detail(
		(
			"Combat: %s dealt %s damage."
			% [
				str(result.get("attacker", "You")),
				str(result.get("damage", 0)),
			]
		)
	)


func _on_magic_result_received(result: Dictionary) -> void:
	var target_id := str(result.get("target_id", ""))
	var healing := float(result.get("healing", 0))
	var damage := float(result.get("damage", 0))
	var marker: WorldMarker = _markers.get(target_id)
	if marker != null:
		marker.show_number(damage if damage > 0 else healing, damage <= 0 and healing > 0)
		marker.set_health(float(result.get("target_hp_remaining", marker.get_health())))
		if bool(result.get("target_defeated", false)):
			_remove_marker(target_id)

	var local_caster := _is_local_character(result.get("caster", ""))
	if local_caster and (target_id == "self" or _is_local_character(target_id)):
		var health := float(
			result.get("target_hp_remaining", _player.current_health + healing - damage)
		)
		_player.show_number(healing if healing > 0 else damage, healing > 0)
		_player.set_vitals(health, float(result.get("caster_mp_remaining", _player.current_mana)))
	elif local_caster:
		_player.set_vitals(
			_player.current_health, float(result.get("caster_mp_remaining", _player.current_mana))
		)
	_set_connection_detail("Magic: %s for %s, %s." % [result.get("spell_id", ""), damage, healing])


func _on_npc_dialogue_received(data: Dictionary) -> void:
	var npc_id := str(data.get("npc_id", ""))
	var marker: WorldMarker = _markers.get(npc_id)
	var speaker := npc_id
	if marker != null:
		speaker = str(marker.entity_data.get("name", npc_id))
		_remember_quest_givers(
			{
				"id": npc_id,
				"available_quests": data.get("available_quests", []),
			}
		)
	_dialogue_panel.show_dialogue(
		speaker, str(data.get("dialogue", "")), npc_id, data.get("available_quests", [])
	)


func _on_quest_updated(quest: Dictionary) -> void:
	var quest_id := str(quest.get("quest_id", quest.get("id", "")))
	if quest_id.is_empty():
		return
	_quests[quest_id] = quest.duplicate(true)
	_refresh_quest_log()


func _on_experience_updated(experience: Dictionary) -> void:
	GameSession.experience = float(experience.get("total", GameSession.experience))
	_experience_label.text = (
		"XP: %d  (+%d)"
		% [
			roundi(GameSession.experience),
			roundi(float(experience.get("gained", 0))),
		]
	)


func _on_server_error_received(error: Dictionary) -> void:
	_set_connection_detail(
		(
			"Server error %s: %s"
			% [
				str(error.get("code", "unknown")),
				str(error.get("message", "Request failed.")),
			]
		)
	)


func _on_action_pressed(action_name: String) -> void:
	match action_name:
		"Attack":
			var target := _nearest_marker("monster", ATTACK_RANGE)
			if target == null:
				_set_connection_detail("No monster in attack range.")
				return
			_send_protocol_message("combat.attack", {"target_id": target.entity_id})
		"Fire Bolt":
			var target := _nearest_marker("monster", ATTACK_RANGE)
			if target == null:
				_set_connection_detail("No monster in spell range.")
				return
			_send_protocol_message(
				"magic.cast", {"spell_id": "fire_ember_bolt", "target_id": target.entity_id}
			)
		"Heal":
			_send_protocol_message(
				"magic.cast", {"spell_id": "fire_cinder_mend", "target_id": "self"}
			)


func _on_talk_pressed() -> void:
	var npc := _nearest_marker("npc", TALK_RANGE)
	if npc == null:
		_set_connection_detail("Move closer to an NPC to talk.")
		return
	_send_protocol_message("npc.talk", {"npc_id": npc.entity_id})


func _on_interact_requested() -> void:
	_on_talk_pressed()


func _on_quest_accept_requested(quest_id: String, npc_id: String) -> void:
	if npc_id.is_empty():
		npc_id = str(_quest_givers.get(quest_id, ""))
	if npc_id.is_empty():
		_set_connection_detail("No quest giver is known for %s." % quest_id)
		return
	_send_protocol_message("quest.accept", {"quest_id": quest_id, "npc_id": npc_id})


func _on_turn_in_pressed(quest_id: String) -> void:
	var npc_id := str(_quest_givers.get(quest_id, QUEST_GIVER_FALLBACK.get(quest_id, "")))
	if npc_id.is_empty():
		_set_connection_detail("No quest giver is known for %s." % quest_id)
		return
	_send_protocol_message("quest.turn_in", {"quest_id": quest_id, "npc_id": npc_id})


func _on_marker_selected(marker: WorldMarker) -> void:
	_selected_entity_id = marker.entity_id
	_update_marker_selection()


func _update_marker_selection() -> void:
	for entity_id in _markers:
		_markers[entity_id].set_selected(entity_id == _selected_entity_id)


func _nearest_marker(kind: String, maximum_distance: float) -> WorldMarker:
	var selected: WorldMarker = _markers.get(_selected_entity_id)
	if selected != null and selected.entity_kind == kind:
		if _distance_to_marker(selected) <= maximum_distance:
			return selected

	var nearest: WorldMarker
	var nearest_distance := maximum_distance
	for marker in _markers.values():
		if marker.entity_kind != kind:
			continue
		var distance := _distance_to_marker(marker)
		if distance <= nearest_distance:
			nearest = marker
			nearest_distance = distance
	return nearest


func _distance_to_marker(marker: WorldMarker) -> float:
	return (
		(_player.global_position - marker.global_position).length()
		/ GameSession.PIXELS_PER_ZONE_UNIT
	)


func _send_protocol_message(message_type: String, payload: Dictionary) -> void:
	var error: Error = NetworkClient.send_message(message_type, payload)
	if error != OK:
		_set_connection_detail("Could not send %s: %s" % [message_type, error_string(error)])


func _remember_quest_givers(npc: Dictionary) -> void:
	var npc_id := _entity_id(npc)
	for quest in npc.get("available_quests", []):
		var quest_id := ""
		if quest is Dictionary:
			quest_id = str(quest.get("quest_id", quest.get("id", "")))
		elif quest is String:
			quest_id = quest
		if not quest_id.is_empty():
			_quest_givers[quest_id] = npc_id


func _refresh_quest_log() -> void:
	for child in _quest_list.get_children():
		child.queue_free()
	if _quests.is_empty():
		var empty := Label.new()
		empty.text = "No active quests."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quest_list.add_child(empty)
		return

	for quest_id in _quests:
		var quest: Dictionary = _quests[quest_id]
		var status := str(quest.get("status", "active"))
		var objective := str(quest.get("objective", ""))
		var progress := int(quest.get("progress", 0))
		var required := int(quest.get("required", 0))
		var description := Label.new()
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = (
			"%s — %s (%d/%d)\n%s"
			% [
				str(quest.get("title", quest_id)),
				status.capitalize(),
				progress,
				required,
				objective,
			]
		)
		_quest_list.add_child(description)
		if status.to_lower() == "ready":
			var turn_in := Button.new()
			turn_in.text = "Turn In"
			turn_in.pressed.connect(_on_turn_in_pressed.bind(quest_id))
			_quest_list.add_child(turn_in)


func _is_local_player(entity: Dictionary, entity_id: String) -> bool:
	if bool(entity.get("self", false)):
		return true
	return (
		_is_local_character(entity_id) or str(entity.get("name", "")) == GameSession.character_name
	)


func _is_local_character(identifier: Variant) -> bool:
	if identifier is Dictionary:
		identifier = identifier.get("id", identifier.get("character_id", ""))
	var character_reference := str(identifier)
	return (
		not character_reference.is_empty()
		and (
			character_reference == GameSession.character_id
			or character_reference == GameSession.character_name
		)
	)


func _entity_id(entity: Dictionary) -> String:
	for key in ["id", "player_id", "character_id", "npc_id", "monster_id"]:
		if entity.has(key):
			return str(entity[key])
	return ""


func _remove_marker(entity_id: String) -> void:
	var marker: WorldMarker = _markers.get(entity_id)
	if marker == null:
		return
	marker.queue_free()
	_markers.erase(entity_id)
	if _selected_entity_id == entity_id:
		_selected_entity_id = ""


func _set_connection_detail(detail: String) -> void:
	if _connection_label != null:
		_connection_label.text = detail


func _on_chat_submitted(message: String, input: LineEdit) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		return
	_send_protocol_message("chat.send", {"message": text})
	input.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_on_interact_requested()
