extends RefCounted

## Shared "3D edge" button-stylebox primitive: every themed button variant in
## this game (the global theme, level-select tiles, win-popup buttons) wants
## the same convention -- a darker bottom border on normal/hover, flattened
## to no border when pressed. Centralizing it here is what should have caught
## the Next Level button's stale orange border after the global theme grew
## this border: previously each caller built its own StyleBoxFlat from
## scratch and only one got updated.

const CORNER_RADIUS := 16
const BORDER_WIDTH := 4

## base: an existing StyleBox to duplicate (keeps its margins/shadow/corner
## radius) -- omit to build a bare box using CORNER_RADIUS/BORDER_WIDTH.
static func build_state(state: String, bg: Color, border: Color, base: StyleBox = null) -> StyleBoxFlat:
	var box: StyleBoxFlat = (base.duplicate() as StyleBoxFlat) if base else StyleBoxFlat.new()
	box.bg_color = bg
	if state == "pressed":
		box.border_width_bottom = 0
	else:
		box.border_color = border
		if not base:
			box.border_width_bottom = BORDER_WIDTH
	if not base:
		box.corner_radius_top_left = CORNER_RADIUS
		box.corner_radius_top_right = CORNER_RADIUS
		box.corner_radius_bottom_right = CORNER_RADIUS
		box.corner_radius_bottom_left = CORNER_RADIUS
	return box

static func apply_font_color(button: Button, color: Color, include_disabled: bool = true) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	if include_disabled:
		button.add_theme_color_override("font_disabled_color", color)
