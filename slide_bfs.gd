extends RefCounted

## Slide-move BFS solver, used at runtime for every level (stored or
## procedural) to compute total paintable tiles for the win condition.
## The level-*generation* logic that used to live in this file (random wall
## scatter, difficulty banding, retry-until-valid) has been removed now that
## generator/ (Go) is the only source of levels -- keeping a second,
## hand-synced GDScript port of that generation logic around was exactly the
## kind of duplication that drifts out of sync; this file now only keeps the
## solver half, which every level actually depends on at runtime.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

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
