extends Control

@onready var sfx_button: Button = $CenterContainer/VBoxContainer/SfxButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	_update_sfx_button_text()
	sfx_button.pressed.connect(_on_sfx_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://size_select.tscn"))

func _on_sfx_pressed() -> void:
	GameState.set_sound_effects_enabled(not GameState.get_sound_effects_enabled())
	_update_sfx_button_text()

func _update_sfx_button_text() -> void:
	sfx_button.text = "SOUND EFFECTS: ON" if GameState.get_sound_effects_enabled() else "SOUND EFFECTS: OFF"
