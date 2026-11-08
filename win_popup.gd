extends Panel

@onready var main = $"../.."
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var moves_label: Label = $MarginContainer/VBoxContainer/MovesLabel
@onready var stars_label: Label = $MarginContainer/VBoxContainer/StarsLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton
@onready var retry_button: Button = $MarginContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MenuButton

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	retry_button.pressed.connect(func(): main.retry_level())
	menu_button.pressed.connect(func(): main.go_to_level_select())

func show_result(moves: int, par: int = -1, stars: int = -1) -> void:
	title_label.text = "Level Complete!"
	moves_label.text = (
		"Moves: %d" % moves if par <= 0
		else "Moves: %d   (par %d)" % [moves, par]
	)
	stars_label.visible = stars >= 0
	if stars >= 0:
		stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	visible = true

func hide_popup() -> void:
	visible = false

func _on_next_pressed() -> void:
	main.go_to_next_level()
