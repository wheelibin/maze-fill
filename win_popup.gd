extends Panel

const UIColors := preload("res://ui_colors.gd")
const ButtonStyle := preload("res://button_style.gd")

@onready var main = $"../.."
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var moves_label: Label = $MarginContainer/VBoxContainer/MovesLabel
@onready var stars_label := $MarginContainer/VBoxContainer/StarsLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton
@onready var retry_button: Button = $MarginContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MenuButton

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	retry_button.pressed.connect(func(): main.retry_level())
	menu_button.pressed.connect(func(): main.go_to_level_select())

	# Swapped from before: Next now gets the teal that used to be Retry's,
	# Retry keeps the theme's default orange that used to be Next's.
	_recolor_button(next_button, UIColors.TEAL, UIColors.TEAL_HOVER, UIColors.TEAL_DARK, UIColors.NAVY)
	_make_outline_button(menu_button)

## Secondary action: same rounded shape as the theme's primary button, just
## a different fill color -- keeps the family look without a second theme.
func _recolor_button(button: Button, normal: Color, hover: Color, pressed: Color, font_color: Color) -> void:
	var base: StyleBox = button.get_theme_stylebox("normal")
	var bg_by_state := {"normal": normal, "hover": hover, "pressed": pressed}
	for state in bg_by_state:
		button.add_theme_stylebox_override(state, ButtonStyle.build_state(state, bg_by_state[state], pressed, base))
	ButtonStyle.apply_font_color(button, font_color, false)

## Tertiary action: same rounded shape as the other buttons but outlined
## instead of filled, so it still reads as a button while staying visually
## quieter than Next/Retry.
func _make_outline_button(button: Button) -> void:
	var bg_by_state := {
		"normal": Color(1, 1, 1, 1),
		"hover": Color(0.95, 0.96, 0.98, 1),
		"pressed": Color(0.88, 0.89, 0.93, 1),
	}
	for state in bg_by_state:
		var base: StyleBox = button.get_theme_stylebox("normal")
		var box: StyleBoxFlat = base.duplicate()
		box.bg_color = bg_by_state[state]
		box.shadow_size = 0
		box.border_width_left = 1.5
		box.border_width_top = 1.5
		box.border_width_right = 1.5
		box.border_width_bottom = 1.5
		box.border_color = UIColors.NAVY.lerp(Color.WHITE, 0.45)
		button.add_theme_stylebox_override(state, box)
	var font_color := UIColors.NAVY.lerp(Color.WHITE, 0.15)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)

func show_result(moves: int, par: int = -1, stars: int = -1) -> void:
	title_label.text = "Level Complete!"
	moves_label.text = (
		"Moves: %d" % moves if par <= 0
		else "Moves: %d   (par %d)" % [moves, par]
	)
	stars_label.visible = stars >= 0
	if stars >= 0:
		stars_label.stars = stars
	visible = true

func hide_popup() -> void:
	visible = false

func _on_next_pressed() -> void:
	main.go_to_next_level()
