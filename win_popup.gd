extends Panel

const UIColors := preload("res://ui_colors.gd")
const ButtonStyle := preload("res://button_style.gd")

@onready var main = $"../.."
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var moves_label: RichTextLabel = $MarginContainer/VBoxContainer/MovesLabel
@onready var stars_label := $MarginContainer/VBoxContainer/StarsLabel
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton
@onready var retry_button: Button = $MarginContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MenuButton
@onready var hint_row: HBoxContainer = $MarginContainer/VBoxContainer/HintRow
@onready var hint_button: Button = $MarginContainer/VBoxContainer/HintRow/HintButton
@onready var solution_button: Button = $MarginContainer/VBoxContainer/HintRow/SolutionButton

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	retry_button.pressed.connect(func(): main.retry_level())
	menu_button.pressed.connect(func(): main.go_to_level_select())
	hint_button.pressed.connect(func(): main.play_hint())
	solution_button.pressed.connect(func(): main.play_solution())

	# Swapped from before: Next now gets the teal that used to be Retry's,
	# Retry keeps the theme's default orange that used to be Next's.
	_recolor_button(next_button, UIColors.TEAL, UIColors.TEAL_HOVER, UIColors.TEAL_DARK, UIColors.NAVY)
	_make_outline_button(menu_button)
	_recolor_button(hint_button, UIColors.GOLD, UIColors.GOLD.darkened(0.12), UIColors.GOLD.darkened(0.25), UIColors.NAVY)
	_make_text_link(solution_button, UIColors.GOLD.darkened(0.25))

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

## Quaternary action: no fill/border/shadow at all, just small colored text
## -- for Hint/Solution, which should read as "psst, need help?" rather
## than compete visually with Next/Retry/Menu. Each gets its own color so
## the two read as distinct actions, not a single blob of link text.
func _make_text_link(button: Button, color: Color) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.darkened(0.2))
	button.add_theme_color_override("font_pressed_color", color.darkened(0.35))

func show_result(moves: int, par: int = -1, stars: int = -1) -> void:
	title_label.text = "LEVEL COMPLETE!"
	moves_label.text = "[center]" + (
		"MOVES: [b]%d[/b]" % moves if par <= 0
		else "MOVES: [b]%d[/b]   (MIN [b]%d[/b])" % [moves, par]
	) + "[/center]"
	stars_label.visible = stars >= 0
	if stars >= 0:
		stars_label.stars = stars
	# "Didn't get the min moves" -- same condition that already denies 3
	# stars. Faded + disabled, not hidden: HintRow (and its spacers) stay
	# in the layout always, so the popup's size and every other button's
	# position never shift depending on whether hints are offered.
	var show_hints := par > 0 and moves > par
	hint_row.modulate.a = 1.0 if show_hints else 0.0
	hint_button.disabled = not show_hints
	solution_button.disabled = not show_hints
	visible = true

func hide_popup() -> void:
	visible = false

func _on_next_pressed() -> void:
	main.go_to_next_level()
