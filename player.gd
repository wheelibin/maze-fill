extends Node2D

@export var color: Color = Color.ORANGE
@export var slide_speed: float = 4000.0

@onready var floor_layer: TileMapLayer = $"../Floor"
@onready var wall_layer: TileMapLayer = $"../Walls"
@onready var camera: Camera2D = $"../Camera2D"
@onready var painted_layer: TileMapLayer = $"../Painted"

var grid_pos := Vector2i(2, 2)
var moving := false
const PAINT_SOURCE_ID := 2
const PAINT_ATLAS_COORDS := Vector2i(2, 0)
var last_painted_cell := Vector2i(-999, -999)
var touch_start := Vector2.ZERO
const MIN_SWIPE := 30.0

func _ready() -> void:
	position = floor_layer.map_to_local(grid_pos)
	paint_cell(grid_pos)
	last_painted_cell = grid_pos

func _draw() -> void:
	draw_rect(Rect2(-24, -24, 48, 48), color)

func _process(_delta: float) -> void:
	if moving:
		update_painting()

func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return

	if event.is_action_pressed("ui_right"):
		slide(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_left"):
		slide(Vector2i.LEFT)
	elif event.is_action_pressed("ui_up"):
		slide(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		slide(Vector2i.DOWN)


func slide(direction: Vector2i) -> void:
	var target := grid_pos

	while true:
		var next := target + direction

		# Stop at walls or outside the floor.
		if floor_layer.get_cell_source_id(next) == -1:
			break

		if wall_layer.get_cell_source_id(next) != -1:
			break

		target = next

	if target == grid_pos:
		return

	grid_pos = target
	moving = true

	var destination := floor_layer.map_to_local(grid_pos)
	var duration := maxf(
		position.distance_to(destination) / slide_speed,
		0.08
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", destination, duration)

	tween.finished.connect(func():
		update_painting()
		moving = false
		#shake_camera()
	)

func shake_camera() -> void:
	var tween := create_tween()

	tween.tween_property(camera, "offset", Vector2(5, -3), 0.025)
	tween.tween_property(camera, "offset", Vector2(-4, 2), 0.025)
	tween.tween_property(camera, "offset", Vector2(2, -1), 0.025)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)
	
func paint_cell(cell: Vector2i) -> void:
	if floor_layer.get_cell_source_id(cell) == -1:
		return

	if wall_layer.get_cell_source_id(cell) != -1:
		return

	painted_layer.set_cell(
		cell,
		PAINT_SOURCE_ID,
		PAINT_ATLAS_COORDS
	)

func update_painting() -> void:
	var current_cell := floor_layer.local_to_map(position)

	if current_cell == last_painted_cell:
		return

	var direction := Vector2i(
		signi(current_cell.x - last_painted_cell.x),
		signi(current_cell.y - last_painted_cell.y)
	)

	var cell := last_painted_cell

	while cell != current_cell:
		cell += direction
		paint_cell(cell)

	last_painted_cell = current_cell

func _input(event: InputEvent) -> void:
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			var swipe: Vector2 = event.position - touch_start

			if swipe.length() < MIN_SWIPE or moving:
				return

			if absf(swipe.x) > absf(swipe.y):
				slide(Vector2i.RIGHT if swipe.x > 0 else Vector2i.LEFT)
			else:
				slide(Vector2i.DOWN if swipe.y > 0 else Vector2i.UP)
