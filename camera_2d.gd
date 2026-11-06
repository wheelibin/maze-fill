extends Camera2D

@onready var floor_layer: TileMapLayer = $"../Floor"

func center_on_bounds(bounds: Rect2i) -> void:
	var top_left := floor_layer.map_to_local(bounds.position)
	var bottom_right := floor_layer.map_to_local(
		bounds.position + bounds.size - Vector2i.ONE
	)

	position = (top_left + bottom_right) / 2.0

	var tile_size := Vector2(floor_layer.tile_set.tile_size)
	var board_px := bottom_right - top_left + tile_size
	var viewport_size := get_viewport_rect().size
	# Only zoom out to fit; never zoom in past native tile size.
	zoom = Vector2.ONE * minf(1.0, minf(
		viewport_size.x / board_px.x, viewport_size.y / board_px.y
	))
