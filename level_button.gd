extends Button

const UIColors := preload("res://ui_colors.gd")

@onready var stars_label := $StarsLabel

func configure(local: int, unlocked: bool, completed: bool, stars: int, best_moves: int) -> void:
	disabled = not unlocked
	custom_minimum_size = Vector2(72, 64)
	text = str(local)
	stars_label.visible = completed

	if not unlocked:
		_style(UIColors.DISABLED_BG, UIColors.DISABLED_BG, UIColors.DISABLED_TEXT)
	elif completed:
		stars_label.stars = stars
		tooltip_text = "Best: %d moves" % best_moves
		_style(UIColors.TEAL, UIColors.TEAL_DARK, UIColors.NAVY)
	else:
		_style(Color.WHITE, UIColors.NAVY, UIColors.NAVY)

func _style(bg: Color, border: Color, font_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		# Matches game_theme.tres's own hover/pressed shading so these tiles
		# give the same press feedback as every other button in the game.
		var state_bg := bg
		if state == "hover":
			state_bg = bg.lightened(0.12)
		elif state == "pressed":
			state_bg = bg.darkened(0.15)
		box.bg_color = state_bg
		# Matches the global theme's button radius (game_theme.tres) --
		# these tiles used to be 10px, visibly less rounded than every
		# other button in the game.
		box.corner_radius_top_left = 16
		box.corner_radius_top_right = 16
		box.corner_radius_bottom_left = 16
		box.corner_radius_bottom_right = 16
		box.border_width_bottom = 4
		box.border_color = border
		box.content_margin_bottom = 16
		add_theme_stylebox_override(state, box)
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_disabled_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	add_theme_color_override("font_pressed_color", font_color)
