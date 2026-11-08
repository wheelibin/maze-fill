extends Button

const NAVY := Color(0.235, 0.247, 0.31, 1)
const TEAL := Color(0.31, 0.851, 0.69, 1)
const TEAL_DARK := Color(0.2, 0.68, 0.54, 1)
const LOCKED_GREY := Color(0.82, 0.84, 0.88, 1)
const LOCKED_GREY_TEXT := Color(0.6, 0.63, 0.7, 1)
const WHITE := Color(1, 1, 1, 1)

@onready var stars_label: Label = $StarsLabel

func configure(local: int, unlocked: bool, completed: bool, stars: int, best_moves: int) -> void:
	disabled = not unlocked
	custom_minimum_size = Vector2(72, 64)
	text = str(local)
	stars_label.visible = completed

	if not unlocked:
		_style(LOCKED_GREY, LOCKED_GREY, LOCKED_GREY_TEXT)
	elif completed:
		stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
		tooltip_text = "Best: %d moves" % best_moves
		_style(TEAL, TEAL_DARK, NAVY)
	else:
		_style(WHITE, NAVY, NAVY)

func _style(bg: Color, border: Color, font_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.corner_radius_top_left = 10
		box.corner_radius_top_right = 10
		box.corner_radius_bottom_left = 10
		box.corner_radius_bottom_right = 10
		box.border_width_bottom = 3
		box.border_color = border
		box.content_margin_bottom = 16
		add_theme_stylebox_override(state, box)
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_disabled_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	add_theme_color_override("font_pressed_color", font_color)
