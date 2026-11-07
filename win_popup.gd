extends Panel

@onready var main = $"../.."
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var moves_label: Label = $MarginContainer/VBoxContainer/MovesLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)

func show_result(moves: int, par: int = -1) -> void:
	title_label.text = "Level Complete!"
	moves_label.text = (
		"Moves: %d" % moves if par <= 0
		else "Moves: %d   (par %d)" % [moves, par]
	)
	visible = true

func hide_popup() -> void:
	visible = false

func _on_next_pressed() -> void:
	main.go_to_next_level()
