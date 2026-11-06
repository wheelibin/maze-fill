extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

const MAX_ATTEMPTS := 30
## ponytail: arbitrary floor against a maze where start is boxed in or barely
## reachable at all — tune higher if tiny mazes still slip through.
const MIN_REACHABLE := 6
## Without this, generate() happily accepts the first layout that barely
## clears MIN_REACHABLE even if it seals off most of the board as dead space
## afterward — require most of the floor to stay in play. 0.6 clears in ~4
## attempts on average on a 16x8 board; tune down if bigger boards start
## chewing through MAX_ATTEMPTS.
const MIN_COVERAGE_FRACTION := 0.6

## Corridor mazes don't work with slide-until-wall movement: a branch off a
## straight corridor can never be stopped at, since the player always slides
## straight through the junction tile instead. So this scatters short wall
## segments across the open floor instead (Ricochet-Robots style).
##
## Slide moves aren't generally reversible (sliding back from where you
## stopped can overshoot past where you came from), so reachable-from-start
## isn't enough to call a layout safe — a tile can be reachable but still a
## one-way trap. Retry until every tile the player can reach can also slide
## back to start again.
## target_difficulty, if given ("easy"/"medium"/"hard"), keeps retrying for a
## layout matching that band. If none turns up within MAX_ATTEMPTS, the last
## valid (just wrong-difficulty) layout is used instead of nothing at all.
static func generate(bounds: Rect2i, start: Vector2i, rng: RandomNumberGenerator, target_difficulty: String = "") -> Dictionary:
	var min_touched := int(bounds.size.x * bounds.size.y * MIN_COVERAGE_FRACTION)
	var fallback := {}

	for attempt in MAX_ATTEMPTS:
		var walls := _scatter_walls(bounds, start, rng)
		var bfs := slide_bfs(walls, bounds, start)
		if bfs.distances.size() < MIN_REACHABLE or bfs.touched.size() < min_touched \
				or not _can_always_return(walls, bounds, start, bfs.distances):
			continue

		# Any open tile a slide never stops at or passes through is dead
		# space the player can see but never actually reach — wall it off
		# instead of leaving misleading unreachable floor on display.
		_seal_dead_space(walls, bounds, bfs.touched)
		var result := {"walls": walls, "bfs": bfs}

		if target_difficulty.is_empty() or difficulty_label(bfs.distances[bfs.farthest]) == target_difficulty:
			return result
		fallback = result

	if not fallback.is_empty():
		return fallback

	var walls := {}
	return {"walls": walls, "bfs": slide_bfs(walls, bounds, start)}

static func _seal_dead_space(walls: Dictionary, bounds: Rect2i, touched: Dictionary) -> void:
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var tile := Vector2i(x, y)
			if not touched.has(tile):
				walls[tile] = true

## BFS over the reversed slide-graph: a tile ends up "seen" here only if some
## path of real slide-moves leads from it back to start.
static func _can_always_return(walls: Dictionary, bounds: Rect2i, start: Vector2i, reachable: Dictionary) -> bool:
	var reverse := {}
	for tile in reachable:
		for d in DIRS:
			var dest := _slide(walls, bounds, tile, d)
			if dest != tile:
				reverse.get_or_add(dest, []).append(tile)

	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for prev in reverse.get(current, []):
			if not seen.has(prev):
				seen[prev] = true
				queue.append(prev)

	return seen.size() == reachable.size()

static func _scatter_walls(bounds: Rect2i, start: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var walls := {}
	var segment_count: int = maxi(4, bounds.size.x * bounds.size.y / 14)
	for i in segment_count:
		var tile := Vector2i(
			rng.randi_range(bounds.position.x, bounds.end.x - 1),
			rng.randi_range(bounds.position.y, bounds.end.y - 1)
		)
		var dir: Vector2i = DIRS[rng.randi() % 4]
		for step in rng.randi_range(1, 3):
			if not bounds.has_point(tile) or tile == start:
				break
			walls[tile] = true
			tile += dir

	return walls

## BFS over slide-moves (not single tile steps) since that's the actual
## move the player makes. distances are "number of slides", which doubles
## as the difficulty score; farthest is a good spot for the goal. touched
## includes tiles a slide only glides over (never stops at), since those are
## still legitimately reachable floor, just not valid stopping points.
static func slide_bfs(walls: Dictionary, bounds: Rect2i, start: Vector2i) -> Dictionary:
	var distances := {start: 0}
	var touched := {start: true}
	var queue: Array[Vector2i] = [start]
	var farthest := start

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d in DIRS:
			var dest := _slide(walls, bounds, current, d)
			if dest == current:
				continue

			var step := current
			while step != dest:
				step += d
				touched[step] = true

			if not distances.has(dest):
				distances[dest] = distances[current] + 1
				if distances[dest] > distances[farthest]:
					farthest = dest
				queue.append(dest)

	return {"distances": distances, "farthest": farthest, "touched": touched}

static func _slide(walls: Dictionary, bounds: Rect2i, from: Vector2i, dir: Vector2i) -> Vector2i:
	var pos := from
	while true:
		var next := pos + dir
		if not bounds.has_point(next) or walls.get(next, false):
			break
		pos = next
	return pos

## ponytail: thresholds calibrated against this one 16x8 board's actual
## distribution (min 5, p25 8, median 9, p75 10, max 17) — rescale if board
## size/coverage ever change, or make this relative to bounds area instead.
static func difficulty_label(slides: int) -> String:
	if slides <= 7:
		return "easy"
	if slides <= 10:
		return "medium"
	return "hard"
