extends SceneTree

const MazeGenerator := preload("res://maze_generator.gd")
const MazeSolver := preload("res://maze_solver.gd")

const LEVELS_PER_TIER := 10
const TIER_COUNT := 3
const BASE_LEVEL_SIZE := Vector2i(9, 5) # full board incl. 1-tile border
const TIER_GROWTH_STEP := Vector2i(2, 2)
const CANDIDATES_PER_TIER := 2000
const EASY_FRACTION := 1.0 / 3.0
const MEDIUM_FRACTION := 1.0 / 3.0 # hard fraction = remainder
const GENERATION_SEED := 1
const OUTPUT_PATH := "res://levels/levels.json"
const MIN_MOVES_BUDGET_SECONDS := 15.0

## v1: slide-distance alone. To add a second signal later (wall density,
## direction-change count, etc.), change only this function's body.
func _score_candidate(bfs: Dictionary) -> float:
	return float(bfs.distances[bfs.farthest])

func _label_for_score(score: float, t1: float, t2: float) -> String:
	if score <= t1:
		return "easy"
	if score <= t2:
		return "medium"
	return "hard"

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GENERATION_SEED

	var easy_count: int = floori(LEVELS_PER_TIER * EASY_FRACTION)
	var medium_count: int = floori(LEVELS_PER_TIER * MEDIUM_FRACTION)
	var hard_count: int = LEVELS_PER_TIER - easy_count - medium_count

	var levels := []

	for t in TIER_COUNT:
		var size: Vector2i = BASE_LEVEL_SIZE + TIER_GROWTH_STEP * t
		var bounds := Rect2i(Vector2i.ZERO, size).grow(-1)
		var start := bounds.position

		var pool := []
		for i in CANDIDATES_PER_TIER:
			var maze := MazeGenerator.generate(bounds, start, rng)
			pool.append({
				"walls": maze.walls,
				"goal": maze.bfs.farthest,
				"touched": maze.bfs.touched,
				"score": _score_candidate(maze.bfs),
			})
		pool.sort_custom(func(a, b): return a.score < b.score)

		var t1: float = pool[int(pool.size() / 3.0)].score
		var t2: float = pool[int(pool.size() * 2.0 / 3.0)].score

		var bands := {"easy": [], "medium": [], "hard": []}
		for c in pool:
			bands[_label_for_score(c.score, t1, t2)].append(c)

		print("Tier %d (size %s): pool=%d scores min=%d median=%d max=%d t1=%.1f t2=%.1f" % [
			t, size, pool.size(), pool[0].score, pool[int(pool.size() / 2.0)].score,
			pool[pool.size() - 1].score, t1, t2,
		])

		var warned := {}
		var fallback_order := {"hard": "medium", "medium": "easy", "easy": ""}
		var band_plan: Array[String] = []
		for i in easy_count:
			band_plan.append("easy")
		for i in medium_count:
			band_plan.append("medium")
		for i in hard_count:
			band_plan.append("hard")

		var band_rank := {"easy": 0, "medium": 0, "hard": 0}
		var band_total := {"easy": easy_count, "medium": medium_count, "hard": hard_count}

		for local_index in LEVELS_PER_TIER:
			var target_band: String = band_plan[local_index]
			var actual_band := target_band
			while bands[actual_band].is_empty() and fallback_order[actual_band] != "":
				if not warned.has(target_band):
					warned[target_band] = true
					print("Tier %d: band '%s' empty, falling back to '%s' — board too small for 3 distinct bands (expected for tiny tiers)" % [
						t, actual_band, fallback_order[actual_band],
					])
				actual_band = fallback_order[actual_band]

			var subpool: Array = bands[actual_band]
			var rank: int = band_rank[target_band]
			var total: int = band_total[target_band]
			band_rank[target_band] = rank + 1
			var p: float = 0.0 if total <= 1 else float(rank) / float(total - 1)
			var chosen: Dictionary = subpool[int(round(p * (subpool.size() - 1)))]

			var walls_arr := []
			for tile in chosen.walls:
				walls_arr.append([tile.x, tile.y])

			var level_number := t * LEVELS_PER_TIER + local_index + 1
			var label := _label_for_score(chosen.score, t1, t2)
			var solved := MazeSolver.min_moves_to_cover(chosen.walls, bounds, start, chosen.touched, MIN_MOVES_BUDGET_SECONDS)
			if not solved.exact:
				print("Level %d: min-moves solve exceeded %.0fs budget (%d states) — board too big for exact BFS" % [
					level_number, MIN_MOVES_BUDGET_SECONDS, solved.states_explored,
				])
			levels.append({
				"size": [size.x, size.y],
				"start": [start.x, start.y],
				"walls": walls_arr,
				"goal": [chosen.goal.x, chosen.goal.y],
				"difficulty_score": chosen.score,
				"difficulty_label": label,
				"min_moves": solved.moves,
				"min_moves_exact": solved.exact,
			})
			print("  level %d -> score=%d label=%s min_moves=%d%s" % [
				level_number, chosen.score, label, solved.moves, "" if solved.exact else " (not exact)",
			])

	assert(levels.size() == TIER_COUNT * LEVELS_PER_TIER)

	for entry in levels:
		var size: Vector2i = Vector2i(entry.size[0], entry.size[1])
		var bounds := Rect2i(Vector2i.ZERO, size).grow(-1)
		var start := Vector2i(entry.start[0], entry.start[1])
		var walls := {}
		for pair in entry.walls:
			walls[Vector2i(pair[0], pair[1])] = true
		var bfs := MazeGenerator.slide_bfs(walls, bounds, start)
		var goal := Vector2i(entry.goal[0], entry.goal[1])
		assert(bfs.distances[goal] == entry.difficulty_score)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels"))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(levels, "\t"))
	file.close()

	print("Wrote %d levels to %s" % [levels.size(), OUTPUT_PATH])
	quit()
