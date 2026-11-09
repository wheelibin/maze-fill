extends Node

const LEVELS_PATH := "res://levels/levels.json"
const SAVE_PATH := "user://save.json"
const LEVELS_PER_TIER := 250
const TIER_COUNT := 4

var selected_size_index := 0 # 0=Small(14x6) 1=Medium(16x8) 2=Large(18x10) 3=Huge(20x12)
var selected_level := 1 # global level number, 1..1000

## Flat paint colors, picked to read well against the lavender floor/navy
## walls while staying clear of the player's orange and the gold stars.
const PAINT_COLORS: Array[Color] = [
	Color(0.31, 0.851, 0.69, 1), # teal
	Color(0.31, 0.72, 0.91, 1),  # sky blue
	Color(0.49, 0.51, 0.95, 1),  # periwinkle
	Color(0.68, 0.49, 0.95, 1),  # orchid
	Color(0.95, 0.42, 0.65, 1),  # rose
	Color(0.95, 0.48, 0.45, 1),  # coral
	Color(0.56, 0.85, 0.42, 1),  # lime
	Color(0.35, 0.87, 0.87, 1),  # aqua
]

func paint_color_for_level(global_level: int) -> Color:
	return PAINT_COLORS[(global_level - 1) % PAINT_COLORS.size()]

## Rotations of the same anhemitonic pentatonic scale -- different mood per
## level, but never a half-step or tritone between adjacent degrees, so the
## wall-hit note sequence always sounds musical regardless of play order.
const SCALE_SETS: Array[Array] = [
	[0, 2, 4, 7, 9, 12, 14, 16],   # major pentatonic
	[0, 2, 5, 7, 10, 12, 14, 17],  # suspended / Egyptian
	[0, 3, 5, 8, 10, 12, 15, 17],  # blues minor / man gong
	[0, 2, 5, 7, 9, 12, 14, 17],   # yo / ritsu
	[0, 3, 5, 7, 10, 12, 15, 17],  # minor pentatonic
]

func scale_for_level(global_level: int) -> Array:
	return SCALE_SETS[(global_level - 1) % SCALE_SETS.size()]

var _levels_data: Array = []
var _levels_loaded := false
var _save_data: Dictionary = {}
var _save_loaded := false

func get_levels() -> Array:
	if _levels_loaded:
		return _levels_data
	_levels_loaded = true
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: %s not found" % LEVELS_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("GameState: %s is not a valid levels array" % LEVELS_PATH)
		return []
	_levels_data = parsed
	return _levels_data

func get_level_entry(global_level: int) -> Dictionary:
	var levels := get_levels()
	if global_level < 1 or global_level > levels.size():
		return {}
	return levels[global_level - 1]

func tier_index_for_level(global_level: int) -> int:
	return (global_level - 1) / LEVELS_PER_TIER

func tier_bounds(tier_index: int) -> Vector2i:
	var first := tier_index * LEVELS_PER_TIER + 1
	return Vector2i(first, first + LEVELS_PER_TIER - 1)

func local_level(global_level: int) -> int:
	return (global_level - 1) % LEVELS_PER_TIER + 1

func global_level(tier_index: int, local: int) -> int:
	return tier_index * LEVELS_PER_TIER + local

func _load_save() -> void:
	if _save_loaded:
		return
	_save_loaded = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_save_data = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_save_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_save_data))

## Stored in the same save file under a non-numeric key, so it can't collide
## with the per-level progress entries (keyed by str(global_level)).
func get_music_enabled() -> bool:
	_load_save()
	return _save_data.get("music_enabled", false)

func set_music_enabled(enabled: bool) -> void:
	_load_save()
	_save_data["music_enabled"] = enabled
	_write_save()

func get_progress(global_level: int) -> Dictionary:
	_load_save()
	var entry: Dictionary = _save_data.get(str(global_level), {})
	return {
		"completed": entry.get("completed", false),
		"best_moves": entry.get("best_moves", -1),
	}

func is_unlocked(global_level: int) -> bool:
	if local_level(global_level) == 1:
		return true
	return get_progress(global_level - 1).completed

## Only call for a level that actually finished (never for a procedural maze).
## Returns this attempt's stars; best_moves only improves, never regresses.
func record_completion(global_level: int, moves: int) -> Dictionary:
	_load_save()
	var key := str(global_level)
	var entry: Dictionary = _save_data.get(key, {"completed": false, "best_moves": -1})
	if entry.best_moves < 0 or moves < entry.best_moves:
		entry.best_moves = moves
	entry.completed = true
	_save_data[key] = entry
	_write_save()
	return {"stars": compute_stars(global_level, moves)}

## Single shared formula -- used both right after a completion (live `moves`)
## and when rendering the level-select menu's saved best. Golf-par tolerance:
## 3 stars at +15% over the true minimum, 2 stars at +50%, 1 star for finishing
## at all. Scales naturally since min_moves already grows with board size.
func compute_stars(global_level: int, moves: int) -> int:
	if moves < 0:
		return 0
	var min_moves := int(get_level_entry(global_level).get("min_moves", -1))
	if min_moves <= 0:
		return 1
	if moves <= ceili(min_moves * 1.15):
		return 3
	if moves <= ceili(min_moves * 1.5):
		return 2
	return 1
