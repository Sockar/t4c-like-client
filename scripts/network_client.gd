extends Node

signal connection_status_changed(status: String, detail: String)
signal character_state_updated(state: Dictionary)
signal world_updated(world: Dictionary)
signal chat_message_received(message: Dictionary)
signal combat_result_received(result: Dictionary)
signal magic_result_received(result: Dictionary)
signal npc_dialogue_received(dialogue: Dictionary)
signal quest_updated(quest: Dictionary)
signal experience_updated(experience: Dictionary)
signal server_error_received(error: Dictionary)

const ATTRIBUTE_KEYS := ["power", "agility", "endurance", "insight"]
const OUTGOING_TYPES := [
	"auth.login",
	"character.create",
	"position.update",
	"chat.send",
	"combat.attack",
	"magic.cast",
	"npc.talk",
	"quest.accept",
	"quest.turn_in",
]

var _socket := WebSocketPeer.new()
var _connecting := false
var _was_open := false
var _character_name := ""
var _creation_attributes: Dictionary = {}
var _awaiting_create_response := false
var _character_ready := false
var _zone: Dictionary = {}
var _entities := {
	"players": {},
	"npcs": {},
	"monsters": {},
}


func connect_to_server(address: String, character_name: String, attributes: Dictionary) -> Error:
	if not address.begins_with("ws://") and not address.begins_with("wss://"):
		return ERR_INVALID_PARAMETER
	if character_name.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER

	close_connection()
	_socket = WebSocketPeer.new()
	_character_name = character_name.strip_edges()
	_creation_attributes = normalize_creation_attributes(attributes)
	_awaiting_create_response = false
	_character_ready = false
	_was_open = false
	GameSession.character_id = ""
	GameSession.character_state.clear()
	GameSession.experience = 0.0
	_zone.clear()
	for category in _entities:
		_entities[category].clear()

	var error := _socket.connect_to_url(address)
	if error != OK:
		connection_status_changed.emit(
			"error", "Could not start connection: %s" % error_string(error)
		)
		return error

	_connecting = true
	connection_status_changed.emit("connecting", "Connecting to %s" % address)
	return OK


func send_message(message_type: String, payload: Dictionary) -> Error:
	if not OUTGOING_TYPES.has(message_type):
		return ERR_INVALID_PARAMETER
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	return _socket.send(
		encode_message(message_type, payload).to_utf8_buffer(), WebSocketPeer.WRITE_MODE_TEXT
	)


func is_connected_to_server() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_character_ready() -> bool:
	return _character_ready


func get_current_world() -> Dictionary:
	return _world_snapshot_copy()


func close_connection() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_connecting = false
	_was_open = false
	_awaiting_create_response = false
	_character_ready = false


func _process(_delta: float) -> void:
	if not _connecting:
		return

	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		connection_status_changed.emit("connected", "Connected to the game server.")
		_send_character_create()
	elif state == WebSocketPeer.STATE_CLOSED:
		_connecting = false
		var reason := _socket.get_close_reason()
		if reason.is_empty():
			reason = "Connection closed (code %d)." % _socket.get_close_code()
		connection_status_changed.emit("closed", reason)

	while state == WebSocketPeer.STATE_OPEN and _socket.get_available_packet_count() > 0:
		_handle_packet(_socket.get_packet().get_string_from_utf8())


func _send_character_create() -> void:
	var error := send_message(
		"character.create",
		{
			"name": _character_name,
			"attributes": _creation_attributes,
		}
	)
	if error != OK:
		connection_status_changed.emit(
			"error", "Could not create character: %s" % error_string(error)
		)
		return
	_awaiting_create_response = true


func _handle_packet(packet_text: String) -> void:
	var message := parse_message(packet_text)
	if message.is_empty():
		push_warning("Ignoring invalid server message: %s" % packet_text)
		return

	var message_type: String = message["type"]
	var payload: Dictionary = message["payload"]
	match message_type:
		"character.created", "auth.accepted":
			_awaiting_create_response = false
			_character_ready = true
			var state: Dictionary = payload.get("character", payload).duplicate(true)
			GameSession.character_state = state
			GameSession.character_id = str(state.get("id", state.get("character_id", "")))
			GameSession.experience = float(state.get("xp", 0))
			character_state_updated.emit(state)
		"world.snapshot":
			_apply_world_snapshot(payload)
		"world.delta":
			_apply_world_delta(payload)
		"chat.message":
			chat_message_received.emit(payload)
		"combat.result":
			combat_result_received.emit(payload)
		"magic.result":
			magic_result_received.emit(payload)
		"npc.dialogue":
			npc_dialogue_received.emit(payload)
		"quest.updated":
			quest_updated.emit(payload)
		"character.xp":
			GameSession.experience = float(payload.get("total", GameSession.experience))
			experience_updated.emit(payload)
		"error":
			_handle_server_error(payload)
		_:
			push_warning("Ignoring unknown server message type: %s" % message_type)


func _handle_server_error(payload: Dictionary) -> void:
	server_error_received.emit(payload)
	var message := str(payload.get("message", "The server reported an error."))
	connection_status_changed.emit("error", message)
	if not _awaiting_create_response:
		return

	_awaiting_create_response = false
	var error := send_message("auth.login", {"name": _character_name})
	if error != OK:
		connection_status_changed.emit(
			"error",
			(
				"Character creation failed and login fallback could not be sent: %s"
				% error_string(error)
			)
		)
		return
	connection_status_changed.emit(
		"authenticating", "Character creation was rejected; trying login."
	)


func _apply_world_snapshot(payload: Dictionary) -> void:
	_zone = payload.get("zone", {}).duplicate(true)
	for category in _entities:
		_entities[category].clear()
		_merge_entities(category, payload.get(category, []))
	world_updated.emit(_world_snapshot_copy())


func _apply_world_delta(payload: Dictionary) -> void:
	for category in ["players", "monsters"]:
		_merge_entities(category, payload.get(category, []))
	for removed in payload.get("removed_monsters", []):
		var entity_id := _entity_id(removed)
		if not entity_id.is_empty():
			_entities["monsters"].erase(entity_id)
	world_updated.emit(_world_snapshot_copy())


func _merge_entities(category: String, entries: Variant) -> void:
	if not entries is Array:
		push_warning("Ignoring invalid %s collection in world update." % category)
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entity_id := _entity_id(entry)
		if entity_id.is_empty():
			push_warning("Ignoring world entity without an id: %s" % JSON.stringify(entry))
			continue
		var merged: Dictionary = _entities[category].get(entity_id, {}).duplicate(true)
		for key in entry:
			merged[key] = entry[key]
		_entities[category][entity_id] = merged


func _entity_id(entity: Variant) -> String:
	if entity is Dictionary:
		for key in ["id", "player_id", "character_id", "npc_id", "monster_id"]:
			if entity.has(key):
				return str(entity[key])
		return ""
	if entity is String or entity is int:
		return str(entity)
	return ""


func _world_snapshot_copy() -> Dictionary:
	return {
		"zone": _zone.duplicate(true),
		"players": _entities["players"].values(),
		"npcs": _entities["npcs"].values(),
		"monsters": _entities["monsters"].values(),
	}


static func normalize_creation_attributes(attributes: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	var weight_total := 0
	for key in ATTRIBUTE_KEYS:
		weights[key] = maxi(0, int(attributes.get(key, 0)))
		weight_total += weights[key]
	if weight_total == 0:
		for key in ATTRIBUTE_KEYS:
			weights[key] = 1

	var result: Dictionary = {}
	for key in ATTRIBUTE_KEYS:
		result[key] = 1

	var remaining := 16
	while remaining > 0:
		var active_keys: Array[String] = []
		var active_weight := 0
		for key in ATTRIBUTE_KEYS:
			if result[key] < 10:
				active_keys.append(key)
				active_weight += weights[key]
		if active_keys.is_empty():
			break
		if active_weight == 0:
			for key in active_keys:
				weights[key] = 1
				active_weight += 1

		var distributed := 0
		var fractions: Array[Dictionary] = []
		for key in active_keys:
			var exact_share := float(remaining * weights[key]) / float(active_weight)
			var whole_share := floori(exact_share)
			var added := mini(whole_share, 10 - result[key])
			result[key] += added
			distributed += added
			(
				fractions
				. append(
					{
						"key": key,
						"fraction": exact_share - float(whole_share),
					}
				)
			)
		remaining -= distributed
		if remaining == 0:
			break

		fractions.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				if is_equal_approx(left["fraction"], right["fraction"]):
					return ATTRIBUTE_KEYS.find(left["key"]) < ATTRIBUTE_KEYS.find(right["key"])
				return left["fraction"] > right["fraction"]
		)
		var rounded_up := 0
		for fraction in fractions:
			var key: String = fraction["key"]
			if remaining == 0:
				break
			if result[key] >= 10:
				continue
			result[key] += 1
			remaining -= 1
			rounded_up += 1
		if distributed == 0 and rounded_up == 0:
			break
	return result


static func encode_message(message_type: String, payload: Dictionary) -> String:
	if not OUTGOING_TYPES.has(message_type):
		return ""
	return JSON.stringify({"type": message_type, "payload": payload})


static func parse_message(packet_text: String) -> Dictionary:
	var decoded: Variant = JSON.parse_string(packet_text)
	if not decoded is Dictionary:
		return {}
	if not decoded.get("type") is String or not decoded.get("payload") is Dictionary:
		return {}
	return decoded
