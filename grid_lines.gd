extends Control

const UIColors := preload("res://ui_colors.gd")

## Subtle graph-paper grid over the menu background, echoing the game board.
@export var cell_size: float = 64.0
@export var line_color: Color = Color(UIColors.NAVY, 0.08)
@export var line_width: float = 1.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), line_color, line_width)
		x += cell_size

	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line_color, line_width)
		y += cell_size
