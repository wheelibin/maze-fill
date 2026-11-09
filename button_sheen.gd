extends Control

## Procedural gloss overlay for buttons -- draws a rounded-rect gradient
## (light top, dark bottom) directly rather than stretching a baked PNG via
## NinePatchRect. NinePatchRect's 9-slice stretching didn't survive export
## (buttons shipped with an unstretched blob in the corner instead of a
## full-width gradient), so this avoids the texture/import pipeline entirely.
@export var corner_radius: float = 16.0
@export var top_color: Color = Color(1, 1, 1, 0.3)
@export var bottom_color: Color = Color(0, 0, 0, 0.18)
@export var corner_segments: int = 6

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var r := minf(corner_radius, minf(size.x, size.y) * 0.5)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for corner in 4:
		var center: Vector2
		var start_angle: float
		match corner:
			0: center = Vector2(size.x - r, r); start_angle = -PI / 2
			1: center = Vector2(size.x - r, size.y - r); start_angle = 0.0
			2: center = Vector2(r, size.y - r); start_angle = PI / 2
			_: center = Vector2(r, r); start_angle = PI
		for i in range(corner_segments + 1):
			var angle := start_angle + (PI / 2) * (i / float(corner_segments))
			var p := center + Vector2(cos(angle), sin(angle)) * r
			points.append(p)
			colors.append(top_color.lerp(bottom_color, clampf(p.y / size.y, 0.0, 1.0)))
	draw_polygon(points, colors)
