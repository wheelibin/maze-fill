extends RefCounted

const MazeGenerator := preload("res://maze_generator.gd")

const LANE_BITS := 32

## Exact minimum number of slide-moves to paint every tile in `touched`,
## starting from `start` (already painted). BFS over (position, painted-set)
## states is optimal since every move costs 1.
##
## shortcut: budget_seconds caps runtime instead of falling back to a
## heuristic estimate — fine while boards stay under ~100-120 touched tiles
## (exact solve is sub-second there, measured). Past that, states explode
## and this returns exact=false rather than guessing; upgrade to IDA* with
## an admissible heuristic if a future tier needs it.
static func min_moves_to_cover(walls: Dictionary, bounds: Rect2i, start: Vector2i, touched: Dictionary, budget_seconds: float = 15.0) -> Dictionary:
	var tiles: Array = touched.keys()
	var tile_index := {}
	for i in tiles.size():
		tile_index[tiles[i]] = i

	var lane_count: int = ceili(tiles.size() / float(LANE_BITS))
	var full_lanes: Array[int] = []
	full_lanes.resize(lane_count)
	full_lanes.fill(0)
	for i in tiles.size():
		full_lanes[i / LANE_BITS] |= 1 << (i % LANE_BITS)

	var start_lanes: Array[int] = []
	start_lanes.resize(lane_count)
	start_lanes.fill(0)
	_mark(start_lanes, tile_index[start])

	var start_key := _state_key(tile_index[start], start_lanes)
	var visited := {start_key: true}
	var queue: Array = [[start, start_lanes, 0]]
	var states_explored := 0
	var deadline := Time.get_ticks_msec() + int(budget_seconds * 1000.0)

	while not queue.is_empty():
		if Time.get_ticks_msec() > deadline:
			return {"moves": -1, "exact": false, "states_explored": states_explored}

		var state: Array = queue.pop_front()
		var pos: Vector2i = state[0]
		var lanes: Array[int] = state[1]
		var depth: int = state[2]
		states_explored += 1

		if lanes == full_lanes:
			return {"moves": depth, "exact": true, "states_explored": states_explored}

		for d in MazeGenerator.DIRS:
			var dest := MazeGenerator._slide(walls, bounds, pos, d)
			if dest == pos:
				continue

			var new_lanes := lanes.duplicate()
			var step := pos
			while step != dest:
				step += d
				if tile_index.has(step):
					_mark(new_lanes, tile_index[step])

			var key := _state_key(tile_index[dest], new_lanes)
			if not visited.has(key):
				visited[key] = true
				queue.append([dest, new_lanes, depth + 1])

	return {"moves": -1, "exact": true, "states_explored": states_explored}

static func _mark(lanes: Array[int], bit_index: int) -> void:
	lanes[bit_index / LANE_BITS] |= 1 << (bit_index % LANE_BITS)

static func _state_key(pos_index: int, lanes: Array[int]) -> String:
	return "%d:%s" % [pos_index, ",".join(lanes.map(func(l): return str(l)))]
