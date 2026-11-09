extends Node2D

const SlideBFS := preload("res://slide_bfs.gd")

const FLOOR_SOURCE_ID := 2
const FLOOR_ATLAS_COORDS := Vector2i(1, 0)
const WALL_SOURCE_ID := 2
const WALL_ATLAS_COORDS := Vector2i(0, 0)

## Full board size including the 1-tile border ring; the maze itself fills
## bounds.grow(-1). Change this to try e.g. Vector2i(16, 16) or Vector2i(32, 32).
@export var level_size := Vector2i(18, 10)

@onready var floor_layer: TileMapLayer = $Board/Floor
@onready var wall_layer: TileMapLayer = $Board/Walls
@onready var wall_shadow_layer: TileMapLayer = $Board/WallShadowGroup/WallShadow
@onready var painted_layer: TileMapLayer = $Board/Painted
@onready var player = $Board/Player
@onready var camera: Camera2D = $Board/Camera2D
@onready var background_pad = $BackgroundPad
@onready var win_popup = $WinPopup/Panel
@onready var hud_moves_label: Label = $HUD/Margin/Panel/MarginContainer/HBoxContainer/MovesLabel
@onready var hud_par_label: Label = $HUD/Margin/Panel/MarginContainer/HBoxContainer/ParLabel
@onready var menu_button: Button = $HUD/MenuButton
@onready var restart_button: Button = $HUD/RestartButton

var _test_level := 1
var current_level := 1
var _current_level_entry: Dictionary = {}

func _ready() -> void:
	menu_button.pressed.connect(go_to_level_select)
	restart_button.pressed.connect(retry_level)
	_build_board()
	camera.fit_board()
	load_level(GameState.selected_level)

func _build_board() -> void:
	floor_layer.clear()
	wall_layer.clear()
	wall_shadow_layer.clear()
	for y in range(level_size.y):
		for x in range(level_size.x):
			var tile := Vector2i(x, y)
			floor_layer.set_cell(tile, FLOOR_SOURCE_ID, FLOOR_ATLAS_COORDS)
			if x == 0 or y == 0 or x == level_size.x - 1 or y == level_size.y - 1:
				wall_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)
				wall_shadow_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_L:
			load_level(_test_level)
			_test_level = _test_level % GameState.get_levels().size() + 1

func load_level(level_number: int) -> void:
	var entry := GameState.get_level_entry(level_number)
	if entry.is_empty():
		push_error("load_level: %d out of range" % level_number)
		return

	level_size = Vector2i(int(entry.size[0]), int(entry.size[1]))
	_build_board()
	camera.fit_board()

	var bounds := Rect2i(Vector2i.ZERO, level_size).grow(-1)
	var walls := {}
	for pair in entry.walls:
		walls[Vector2i(int(pair[0]), int(pair[1]))] = true
	var start := Vector2i(int(entry.start[0]), int(entry.start[1]))

	current_level = level_number
	GameState.selected_level = level_number
	_current_level_entry = entry
	_start_level(bounds, walls, start)

	print("Loaded level %d: size %s, score %d (%s)" % [
		level_number, level_size, entry.difficulty_score, entry.difficulty_label
	])

func _start_level(bounds: Rect2i, walls: Dictionary, start: Vector2i) -> void:
	_paint_walls(bounds, walls)
	painted_layer.clear()
	painted_layer.modulate = GameState.paint_color_for_level(current_level)
	player.set_level_scale(GameState.scale_for_level(current_level))
	background_pad.set_level_scale(GameState.scale_for_level(current_level))
	background_pad.resume()

	player.grid_pos = start
	player.position = floor_layer.map_to_local(start)
	player.last_painted_cell = start
	player.move_count = 0
	player.level_complete = false
	win_popup.hide_popup()

	var touched: Dictionary = SlideBFS.slide_bfs(walls, bounds, start).touched
	player.total_paintable = touched.size()

	hud_moves_label.text = "Moves: 0"
	var min_moves := int(_current_level_entry.get("min_moves", -1))
	hud_par_label.visible = min_moves > 0
	if min_moves > 0:
		hud_par_label.text = "Par: %d" % min_moves

	player.paint_cell(start)

func update_move_count(moves: int) -> void:
	hud_moves_label.text = "Moves: %d" % moves

func show_win_popup(moves: int) -> void:
	background_pad.stop()
	var par := int(_current_level_entry.get("min_moves", -1))
	var stars := -1
	if not _current_level_entry.is_empty():
		var result := GameState.record_completion(current_level, moves)
		stars = result.stars
	win_popup.show_result(moves, par, stars)

func go_to_next_level() -> void:
	var bounds := GameState.tier_bounds(GameState.tier_index_for_level(current_level))
	var next := current_level + 1
	if next > bounds.y:
		go_to_level_select()
		return
	load_level(next)

func retry_level() -> void:
	load_level(current_level)

func go_to_level_select() -> void:
	get_tree().change_scene_to_file("res://level_select.tscn")

func _paint_walls(bounds: Rect2i, walls: Dictionary) -> void:
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var tile := Vector2i(x, y)
			if walls.get(tile, false):
				wall_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)
				wall_shadow_layer.set_cell(tile, WALL_SOURCE_ID, WALL_ATLAS_COORDS)
			else:
				wall_layer.erase_cell(tile)
				wall_shadow_layer.erase_cell(tile)
