extends Button

const UIColors := preload("res://ui_colors.gd")
const ButtonStyle := preload("res://button_style.gd")

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
		tooltip_text = "BEST: %d MOVES" % best_moves
		_style(UIColors.TEAL, UIColors.TEAL_DARK, UIColors.NAVY)
	else:
		_style(Color.WHITE, UIColors.NAVY, UIColors.NAVY)

func _style(bg: Color, border: Color, font_color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		# Matches game_theme.tres's own hover/pressed shading so these tiles
		# give the same press feedback as every other button in the game.
		var state_bg := bg
		if state == "hover":
			state_bg = bg.lightened(0.12)
		elif state == "pressed":
			state_bg = bg.darkened(0.15)
		var box := ButtonStyle.build_state(state, state_bg, border)
		box.content_margin_bottom = 16
		add_theme_stylebox_override(state, box)
	ButtonStyle.apply_font_color(self, font_color)
