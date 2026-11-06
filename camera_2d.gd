extends Camera2D

@export_range(0.0, 0.4) var margin: float = 0.05

@onready var floor_layer: TileMapLayer = $"../Floor"


func _ready() -> void:
	get_viewport().size_changed.connect(fit_board)
	fit_board()


func fit_board() -> void:
	var bounds := floor_layer.get_used_rect()

	if bounds.size == Vector2i.ZERO:
		return

	var tile_size := Vector2(floor_layer.tile_set.tile_size)

	var board_size := Vector2(bounds.size) * tile_size

	var first_cell := floor_layer.map_to_local(bounds.position)
	var last_cell := floor_layer.map_to_local(
		bounds.position + bounds.size - Vector2i.ONE
	)

	# Camera and Floor are siblings under Board.
	position = floor_layer.position + (first_cell + last_cell) / 2.0

	var viewport_size := get_viewport_rect().size
	var available := viewport_size * (1.0 - margin * 2.0)

	var factor := minf(
		available.x / board_size.x,
		available.y / board_size.y
	)

	zoom = Vector2.ONE * factor
