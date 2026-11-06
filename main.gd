extends Node2D

const MazeGenerator := preload("res://maze_generator.gd")

const FLOOR_SOURCE_ID := 1
const FLOOR_ATLAS_COORDS := Vector2i(0, 0)
const WALL_SOURCE_ID := 1
const WALL_ATLAS_COORDS := Vector2i(1, 0)

## Full board size including the 1-tile border ring; the maze itself fills
## bounds.grow(-1). Change this to try e.g. Vector2i(16, 16) or Vector2i(32, 32).
@export var level_size := Vector2i(18, 10)

@onready var floor_layer: TileMapLayer = $Board/Floor
@onready var wall_layer: TileMapLayer = $Board/Walls
@onready var painted_layer: TileMapLayer = $Board/Painted
@onready var player = $Board/Player
@onready var camera: Camera2D = $Board/Camera2D

const LEVELS_PATH := "res://levels/levels.json"

var rng := RandomNumberGenerator.new()
var _levels_data: Array = []
var _levels_loaded := false
var _test_level := 1

func _ready() -> void:
	rng.randomize()
	_build_board()
	camera.center_on_bounds(Rect2i(Vector2i.ZERO, level_size))
	generate_procedural_maze()

func _build_board() -> void:
	floor_layer.clear()
	wall_layer.clear()
	for y in range(level_size.y):
		for x in range(level_size.x):
			var tile := Vector2i(x, y)
			floor_layer.set_cell(tile, FLOOR_SOURCE_ID, FLOOR_ATLAS_COORDS)
			if x == 0 or y == 0 or x == level_size.x - 1 or y == level_size.y - 1:
				wall_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_M:
			generate_procedural_maze()
		KEY_1:
			generate_procedural_maze("easy")
		KEY_2:
			generate_procedural_maze("medium")
		KEY_3:
			generate_procedural_maze("hard")
		KEY_L:
			load_level(_test_level)
			_test_level = _test_level % _load_levels_data().size() + 1

func generate_procedural_maze(target_difficulty: String = "") -> void:
	# Border ring stays fixed; only the interior is regenerated.
	var bounds := Rect2i(Vector2i.ZERO, level_size).grow(-1)
	var start := bounds.position
	var maze := MazeGenerator.generate(bounds, start, rng, target_difficulty)
	var bfs: Dictionary = maze.bfs
	var goal: Vector2i = bfs.farthest
	var difficulty: int = bfs.distances[goal]

	_paint_walls(bounds, maze.walls)
	painted_layer.clear()

	player.grid_pos = start
	player.position = floor_layer.map_to_local(start)
	player.last_painted_cell = start
	player.paint_cell(start)

	print("Procedural maze: goal %s, %d slides to reach it (%s)" % [
		goal, difficulty, MazeGenerator.difficulty_label(difficulty)
	])

func _load_levels_data() -> Array:
	if _levels_loaded:
		return _levels_data
	_levels_loaded = true
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_error("load_level: %s not found — run tools/generate_levels.gd first" % LEVELS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("load_level: %s is not a valid levels array" % LEVELS_PATH)
		return []
	_levels_data = parsed
	return _levels_data

func load_level(level_number: int) -> void:
	var levels := _load_levels_data()
	if level_number < 1 or level_number > levels.size():
		push_error("load_level: %d out of range (1..%d)" % [level_number, levels.size()])
		return

	var entry: Dictionary = levels[level_number - 1]
	level_size = Vector2i(int(entry.size[0]), int(entry.size[1]))
	_build_board()
	camera.center_on_bounds(Rect2i(Vector2i.ZERO, level_size))

	var bounds := Rect2i(Vector2i.ZERO, level_size).grow(-1)
	var walls := {}
	for pair in entry.walls:
		walls[Vector2i(int(pair[0]), int(pair[1]))] = true
	_paint_walls(bounds, walls)
	painted_layer.clear()

	var start := Vector2i(int(entry.start[0]), int(entry.start[1]))
	player.grid_pos = start
	player.position = floor_layer.map_to_local(start)
	player.last_painted_cell = start
	player.paint_cell(start)

	print("Loaded level %d: size %s, score %d (%s)" % [
		level_number, level_size, entry.difficulty_score, entry.difficulty_label
	])

func _paint_walls(bounds: Rect2i, walls: Dictionary) -> void:
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var tile := Vector2i(x, y)
			if walls.get(tile, false):
				wall_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)
			else:
				wall_layer.erase_cell(tile)
