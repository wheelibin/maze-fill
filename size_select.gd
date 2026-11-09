extends Control

@onready var buttons: Array[Button] = [
	$CenterContainer/VBoxContainer/SmallButton,
	$CenterContainer/VBoxContainer/MediumButton,
	$CenterContainer/VBoxContainer/LargeButton,
	$CenterContainer/VBoxContainer/HugeButton,
]
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton

func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(_on_pressed.bind(i))
	options_button.pressed.connect(func(): get_tree().change_scene_to_file("res://options.tscn"))

func _on_pressed(tier_index: int) -> void:
	GameState.selected_size_index = tier_index
	get_tree().change_scene_to_file("res://level_select.tscn")
