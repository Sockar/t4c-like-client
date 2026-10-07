extends Node

const CLIENT := preload("res://scripts/network_client.gd")
const ATTRIBUTES := ["power", "agility", "endurance", "insight"]

var _failure_count := 0


func _ready() -> void:
	_test_attribute_normalization()
	_test_protocol_message_codec()
	_test_world_snapshot_and_delta()
	_test_server_message_dispatch()
	if _failure_count == 0:
		print("Protocol unit checks passed.")
		get_tree().quit()
	else:
		push_error("%d protocol unit check(s) failed." % _failure_count)
		get_tree().quit(1)


func _test_attribute_normalization() -> void:
	var neutral_result: Dictionary = CLIENT.normalize_creation_attributes({})
	_check(
		neutral_result == {"power": 5, "agility": 5, "endurance": 5, "insight": 5},
		"all-neutral answers should normalize to five in each attribute"
	)
	var capped_result: Dictionary = CLIENT.normalize_creation_attributes(
		{"power": 5, "agility": 0, "endurance": 0, "insight": 0}
	)
	_check(
		capped_result == {"power": 10, "agility": 4, "endurance": 3, "insight": 3},
		"capped attributes should redistribute points using stable largest-remainder order"
	)
	var samples := [
		{"power": 5, "agility": 0, "endurance": 0, "insight": 0},
		{"power": 0, "agility": 3, "endurance": 1, "insight": 1},
		{"power": 999, "agility": 999, "endurance": 999, "insight": 999},
	]
	for sample in samples:
		var normalized: Dictionary = CLIENT.normalize_creation_attributes(sample)
		_check(normalized.size() == 4, "normalized attributes should include all four keys")
		var total := 0
		for attribute in ATTRIBUTES:
			var score := int(normalized[attribute])
			_check(score >= 1 and score <= 10, "%s should be within 1..10" % attribute)
			total += score
		_check(total == 20, "normalized attribute total should be exactly 20")


func _test_protocol_message_codec() -> void:
	_check(
		(
			CLIENT.OUTGOING_TYPES
			== [
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
		),
		"client message type allowlist should exactly match the server protocol"
	)
	var encoded := (
		CLIENT
		. encode_message(
			"character.create",
			{
				"name": "Aster",
				"attributes": {"power": 5, "agility": 5, "endurance": 5, "insight": 5},
			}
		)
	)
	var decoded: Dictionary = CLIENT.parse_message(encoded)
	_check(decoded.get("type") == "character.create", "message type should be preserved")
	_check(decoded.get("payload", {}).get("name") == "Aster", "message payload should be preserved")
	var total := 0
	for score in decoded["payload"]["attributes"].values():
		total += int(score)
	_check(total == 20, "encoded creation attributes should total 20")
	_check(
		CLIENT.encode_message("unsupported.type", {}) == "",
		"unknown client message types must not be encoded"
	)
	_check(
		CLIENT.parse_message('{"type":"chat.message","payload":[]}').is_empty(),
		"payload must be a JSON object"
	)


func _test_world_snapshot_and_delta() -> void:
	var client: Node = CLIENT.new()
	(
		client
		. call(
			"_handle_packet",
			(
				JSON
				. stringify(
					{
						"type": "world.snapshot",
						"payload":
						{
							"zone":
							{
								"id": "mosswake_fen",
								"name": "Mosswake Fen",
								"width": 100,
								"height": 100
							},
							"players": [{"id": "p-1", "name": "Aster", "x": 10.0, "y": 20.0}],
							"npcs": [{"id": "npc_elin", "name": "Elin"}],
							"monsters":
							[
								{"id": "reedling-01", "name": "Reedling", "x": 12.0, "hp": 8},
								{
									"id": "lantern-moth-01",
									"name": "Lantern Moth",
									"x": 14.0,
									"hp": 5
								},
							],
						},
					}
				)
			)
		)
	)
	(
		client
		. call(
			"_handle_packet",
			(
				JSON
				. stringify(
					{
						"type": "world.delta",
						"payload":
						{
							"players": [{"id": "p-1", "x": 11.0}],
							"monsters": [{"id": "reedling-01", "x": 13.0}],
							"removed_monsters": ["lantern-moth-01"],
						},
					}
				)
			)
		)
	)

	var world: Dictionary = client.call("get_current_world")
	_check(world["zone"]["width"] == 100, "snapshot zone metadata should be retained")
	_check(world["players"].size() == 1, "player collection should be retained")
	_check(world["players"][0]["name"] == "Aster", "delta should preserve omitted player fields")
	_check(world["players"][0]["x"] == 11.0, "delta should update player position")
	_check(world["npcs"].size() == 1, "NPCs should remain after a delta")
	_check(world["monsters"].size() == 1, "removed monsters should be removed")
	_check(world["monsters"][0]["x"] == 13.0, "delta should update monster state")
	client.free()


func _test_server_message_dispatch() -> void:
	var client: Node = CLIENT.new()
	var received: Dictionary = {}
	client.connect(
		"character_state_updated", Callable(self, "_capture_message").bind(received, "character")
	)
	client.connect(
		"chat_message_received", Callable(self, "_capture_message").bind(received, "chat")
	)
	client.connect(
		"combat_result_received", Callable(self, "_capture_message").bind(received, "combat")
	)
	client.connect(
		"magic_result_received", Callable(self, "_capture_message").bind(received, "magic")
	)
	client.connect(
		"npc_dialogue_received", Callable(self, "_capture_message").bind(received, "dialogue")
	)
	client.connect("quest_updated", Callable(self, "_capture_message").bind(received, "quest"))
	client.connect(
		"experience_updated", Callable(self, "_capture_message").bind(received, "experience")
	)
	client.connect(
		"server_error_received", Callable(self, "_capture_message").bind(received, "error")
	)

	var messages := {
		"character.created": {"hp": 50, "max_hp": 100},
		"chat.message": {"from": "Aster", "message": "Hello"},
		"combat.result": {"target_id": "reedling-01", "damage": 3},
		"magic.result": {"spell_id": "fire_ember_bolt", "damage": 4},
		"npc.dialogue": {"npc_id": "npc_elin", "dialogue": "Welcome."},
		"quest.updated": {"quest_id": "fen_patrol", "status": "active"},
		"character.xp": {"total": 12, "gained": 2},
		"error": {"code": "test", "message": "Expected test error"},
	}
	for message_type in messages:
		client.call(
			"_handle_packet",
			JSON.stringify({"type": message_type, "payload": messages[message_type]})
		)

	for key in ["character", "chat", "combat", "magic", "dialogue", "quest", "experience", "error"]:
		_check(received.has(key), "server event %s should be dispatched" % key)
	client.free()


func _capture_message(payload: Dictionary, target: Dictionary, key: String) -> void:
	target[key] = payload


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error(message)
