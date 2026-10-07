extends Control

const QUESTIONS := [
	{
		"prompt": "A storm closes in as you travel. What do you do?",
		"choices":
		[
			{"text": "Shoulder through the wind and keep moving.", "attribute": "Power"},
			{"text": "Find a narrow trail sheltered by the trees.", "attribute": "Agility"},
			{"text": "Make camp and wait for the worst to pass.", "attribute": "Endurance"},
			{"text": "Read the clouds to predict how long it will last.", "attribute": "Insight"},
			{"text": "Follow the main road at an easy pace.", "attribute": ""},
		],
	},
	{
		"prompt": "You find a sealed chest in an abandoned waystation.",
		"choices":
		[
			{"text": "Force the old lock with a sturdy tool.", "attribute": "Power"},
			{"text": "Work the delicate mechanism carefully.", "attribute": "Agility"},
			{"text": "Carry it to town without opening it.", "attribute": "Endurance"},
			{"text": "Look for marks that reveal its maker.", "attribute": "Insight"},
			{"text": "Leave it where it is and continue onward.", "attribute": ""},
		],
	},
	{
		"prompt": "A traveler asks for help crossing a flooded stream.",
		"choices":
		[
			{"text": "Brace against the current and guide them across.", "attribute": "Power"},
			{"text": "Find a line of stepping stones upstream.", "attribute": "Agility"},
			{"text": "Build a simple bridge from fallen branches.", "attribute": "Endurance"},
			{"text": "Study the current and choose a safe crossing.", "attribute": "Insight"},
			{"text": "Point them toward the nearby ferry.", "attribute": ""},
		],
	},
	{
		"prompt": "At a quiet village gathering, where do you spend your time?",
		"choices":
		[
			{"text": "Help raise a new beam for the meeting hall.", "attribute": "Power"},
			{"text": "Join the nimble-footed dancers.", "attribute": "Agility"},
			{"text": "Share stories beside the evening fire.", "attribute": "Endurance"},
			{"text": "Listen to the elders' tales of the valley.", "attribute": "Insight"},
			{"text": "Enjoy the meal and the company.", "attribute": ""},
		],
	},
	{
		"prompt": "You discover an unfamiliar symbol carved in stone.",
		"choices":
		[
			{"text": "Trace its deep grooves with a firm hand.", "attribute": "Power"},
			{"text": "Sketch its precise lines in your journal.", "attribute": "Agility"},
			{"text": "Mark the location and return with supplies.", "attribute": "Endurance"},
			{"text": "Compare it with symbols you have studied.", "attribute": "Insight"},
			{"text": "Remember the place and carry on.", "attribute": ""},
		],
	},
]

var _question_index := 0
var _attributes := {}
var _question_label: Label
var _progress_label: Label
var _choices_box: VBoxContainer
var _summary_box: VBoxContainer


func _ready() -> void:
	_restart_questionnaire()
	_build_interface()
	_show_question()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("#18251f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Shape Your Wayfarer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	var identity := Label.new()
	identity.text = "Creating %s" % GameSession.character_name
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(identity)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_progress_label)

	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.custom_minimum_size.y = 48
	layout.add_child(_question_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	layout.add_child(_choices_box)

	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 8)
	layout.add_child(_summary_box)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	var reroll_button := Button.new()
	reroll_button.text = "Reroll Questionnaire"
	reroll_button.pressed.connect(_on_reroll_pressed)
	footer.add_child(reroll_button)

	var confirm_button := Button.new()
	confirm_button.text = "Confirm & Enter the Vale"
	confirm_button.pressed.connect(_on_confirm_pressed)
	footer.add_child(confirm_button)


func _restart_questionnaire() -> void:
	_question_index = 0
	_attributes = {
		"Power": 0,
		"Agility": 0,
		"Endurance": 0,
		"Insight": 0,
	}


func _show_question() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
	for child in _summary_box.get_children():
		child.queue_free()

	_progress_label.text = "Question %d of %d" % [_question_index + 1, QUESTIONS.size()]
	_question_label.text = QUESTIONS[_question_index].prompt
	_choices_box.visible = true
	_summary_box.visible = false

	for choice in QUESTIONS[_question_index].choices:
		var button := Button.new()
		button.text = choice.text
		button.custom_minimum_size.y = 42
		button.pressed.connect(_on_choice_selected.bind(choice.attribute))
		_choices_box.add_child(button)


func _on_choice_selected(attribute: String) -> void:
	if not attribute.is_empty():
		_attributes[attribute] += 1
	_question_index += 1
	if _question_index < QUESTIONS.size():
		_show_question()
	else:
		_show_summary()


func _show_summary() -> void:
	_progress_label.text = "Your starting attributes"
	_question_label.text = "Every path begins somewhere. These are the strengths you have found."
	_choices_box.visible = false
	_summary_box.visible = true
	for attribute in _attributes:
		var stat := Label.new()
		stat.text = "%s: %d" % [attribute, _attributes[attribute]]
		stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_summary_box.add_child(stat)


func _on_reroll_pressed() -> void:
	_restart_questionnaire()
	_show_question()


func _on_confirm_pressed() -> void:
	if _question_index < QUESTIONS.size():
		return
	GameSession.attributes = _attributes.duplicate()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
