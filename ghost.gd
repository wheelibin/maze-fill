extends Node2D

## Solution-replay marker: purely visual, no state of its own beyond
## position -- main.gd tweens it directly and paints the trail layer.

const RADIUS := 18.0
const FILL := Color(1, 1, 1, 0.75)
const BORDER := Color(1, 1, 1, 0.95)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL, true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS - 1.0, BORDER, false, 2.0, true)
