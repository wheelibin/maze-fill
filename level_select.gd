extends Control

const LevelButtonScene := preload("res://level_button.tscn")
const TIER_LABELS := ["Small (14×6)", "Medium (16×8)", "Large (18×10)", "Huge (20×12)"]

@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/LevelGrid
@onready var header: Label = $VBoxContainer/TopBar/HeaderLabel
@onready var back_button: Button = $VBoxContainer/TopBar/BackButton

func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://size_select.tscn"))
	header.text = TIER_LABELS[GameState.selected_size_index]
	_populate()

func _populate() -> void:
	var tier := GameState.selected_size_index
	for local in range(1, GameState.LEVELS_PER_TIER + 1):
		var global: int = GameState.global_level(tier, local)
		var unlocked := GameState.is_unlocked(global)
		var progress := GameState.get_progress(global)
		var stars := GameState.compute_stars(global, progress.best_moves) if progress.completed else 0

		var btn := LevelButtonScene.instantiate()
		grid.add_child(btn)
		btn.configure(local, unlocked, progress.completed, stars, progress.best_moves)
		if unlocked:
			btn.pressed.connect(_on_level_pressed.bind(local))

func _on_level_pressed(local: int) -> void:
	GameState.selected_level = GameState.global_level(GameState.selected_size_index, local)
	get_tree().change_scene_to_file("res://game.tscn")
