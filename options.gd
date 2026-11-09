extends Control

@onready var music_button: Button = $CenterContainer/VBoxContainer/MusicButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	_update_music_button_text()
	music_button.pressed.connect(_on_music_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://size_select.tscn"))

func _on_music_pressed() -> void:
	GameState.set_music_enabled(not GameState.get_music_enabled())
	_update_music_button_text()

func _update_music_button_text() -> void:
	music_button.text = "MUSIC: ON" if GameState.get_music_enabled() else "MUSIC: OFF"
