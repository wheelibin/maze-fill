extends Control

## Draws max_stars 5-point stars evenly across this control's own rect --
## filled for earned stars, outlined for the rest. No font/glyph involved,
## so it renders identically regardless of what fonts an export has access to.
@export var max_stars: int = 3
@export var stars: int = 0:
	set(value):
		stars = value
		queue_redraw()
@export var fill_color: Color = Color(1, 0.82, 0.1, 1)
@export var empty_outline_color: Color = Color(0.65, 0.65, 0.67, 1)
@export var outline_width: float = 1.2
@export var padding_fraction: float = 0.12

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var slot_w := size.x / max_stars
	var outer_r := minf(slot_w, size.y) * 0.5 * (1.0 - padding_fraction)
	var inner_r := outer_r * 0.382

	for i in max_stars:
		var center := Vector2(slot_w * (i + 0.5), size.y * 0.5)
		if i < stars:
			draw_colored_polygon(_star_points(center, outer_r, inner_r), fill_color)
		else:
			# draw_polyline centers its stroke on the path, so shrink the
			# points by half the stroke width -- otherwise the outline
			# bulges past outer_r and the empty star reads as bigger.
			var shrink := outline_width * 0.5
			var closed := _star_points(center, outer_r - shrink, inner_r - shrink)
			closed.append(closed[0])
			draw_polyline(closed, empty_outline_color, outline_width, true)

func _star_points(center: Vector2, outer_r: float, inner_r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := outer_r if i % 2 == 0 else inner_r
		var angle := -PI / 2 + i * PI / 5
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
