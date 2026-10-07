class_name DialoguePanel
extends PanelContainer

var _speaker_label: Label
var _dialogue_label: Label


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

	var continue_button := Button.new()
	continue_button.text = "Close"
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(hide_dialogue)
	layout.add_child(continue_button)


func show_dialogue(speaker: String, message: String) -> void:
	_speaker_label.text = speaker
	_dialogue_label.text = message
	visible = true


func hide_dialogue() -> void:
	visible = false
