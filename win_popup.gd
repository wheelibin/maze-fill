extends Panel

@onready var main = $"../.."
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var moves_label: Label = $MarginContainer/VBoxContainer/MovesLabel
@onready var stars_label: Label = $MarginContainer/VBoxContainer/StarsLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton
@onready var retry_button: Button = $MarginContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MenuButton

const NAVY := Color(0.235, 0.247, 0.31, 1)
const TEAL := Color(0.31, 0.851, 0.69, 1)
const TEAL_HOVER := Color(0.22, 0.74, 0.6, 1)
const TEAL_PRESSED := Color(0.17, 0.6, 0.49, 1)

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	retry_button.pressed.connect(func(): main.retry_level())
	menu_button.pressed.connect(func(): main.go_to_level_select())

	_recolor_button(retry_button, TEAL, TEAL_HOVER, TEAL_PRESSED, NAVY)
	_make_ghost_button(menu_button)

## Secondary action: same rounded shape as the theme's primary button, just
## a different fill color -- keeps the family look without a second theme.
func _recolor_button(button: Button, normal: Color, hover: Color, pressed: Color, font_color: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var base: StyleBox = button.get_theme_stylebox("normal")
		var box: StyleBoxFlat = base.duplicate()
		box.bg_color = {"normal": normal, "hover": hover, "pressed": pressed}[state]
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)

## Tertiary action: no fill, just text -- visually the least prominent of
## the three buttons so it doesn't compete with Next/Retry.
func _make_ghost_button(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_color_override("font_color", NAVY.lerp(Color.WHITE, 0.3))
	button.add_theme_color_override("font_hover_color", NAVY)

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
