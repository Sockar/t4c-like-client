class_name DialoguePanel
extends PanelContainer

signal quest_accept_requested(quest_id: String, npc_id: String)

var _speaker_label: Label
var _dialogue_label: Label
var _quest_list: VBoxContainer


func _ready() -> void:
	visible = false

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(_speaker_label)

	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_dialogue_label)

	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 4)
	layout.add_child(_quest_list)

	var continue_button := Button.new()
	continue_button.text = "Close"
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(hide_dialogue)
	layout.add_child(continue_button)


func show_dialogue(
	speaker: String, message: String, npc_id: String = "", available_quests: Variant = []
) -> void:
	_speaker_label.text = speaker
	_dialogue_label.text = message
	for child in _quest_list.get_children():
		child.queue_free()
	var quests: Array = []
	if available_quests is Array:
		quests = available_quests
	elif available_quests is Dictionary:
		for quest_id in available_quests:
			var quest: Variant = available_quests[quest_id]
			if quest is Dictionary:
				var quest_data: Dictionary = quest.duplicate(true)
				quest_data["quest_id"] = quest_data.get("quest_id", quest_id)
				quests.append(quest_data)
			else:
				quests.append({"quest_id": quest_id, "title": str(quest)})

	for quest in quests:
		var quest_id := ""
		var title := ""
		if quest is Dictionary:
			quest_id = str(quest.get("quest_id", quest.get("id", "")))
			title = str(quest.get("title", quest_id))
		elif quest is String:
			quest_id = quest
			title = quest
		if quest_id.is_empty():
			continue
		var accept_button := Button.new()
		accept_button.text = "Accept: %s" % title
		accept_button.pressed.connect(_on_accept_quest_pressed.bind(quest_id, npc_id))
		_quest_list.add_child(accept_button)
	visible = true


func hide_dialogue() -> void:
	visible = false


func _on_accept_quest_pressed(quest_id: String, npc_id: String) -> void:
	quest_accept_requested.emit(quest_id, npc_id)
