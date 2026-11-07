package main

import "math/rand"

// Port of maze_generator.gd.

type Point struct{ X, Y int }

func (p Point) Add(d Point) Point { return Point{p.X + d.X, p.Y + d.Y} }

// Bounds is the interior playable rect: Min inclusive, Max exclusive
// (matches Godot's Rect2i.position / .end).
type Bounds struct{ MinX, MinY, MaxX, MaxY int }

func (b Bounds) Contains(p Point) bool {
	return p.X >= b.MinX && p.X < b.MaxX && p.Y >= b.MinY && p.Y < b.MaxY
}

func (b Bounds) Size() (int, int) { return b.MaxX - b.MinX, b.MaxY - b.MinY }

// BoundsForSize mirrors `Rect2i(Vector2i.ZERO, size).grow(-1)`: the full
// board shrunk by the 1-tile border on every side.
func BoundsForSize(size Point) Bounds {
	return Bounds{1, 1, size.X - 1, size.Y - 1}
}

// DIRS order matches maze_generator.gd: UP, DOWN, LEFT, RIGHT.
var DIRS = []Point{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

const (
	maxAttempts         = 30
	minReachable        = 6
	minCoverageFraction = 0.6
)

func slide(walls map[Point]bool, bounds Bounds, from Point, dir Point) Point {
	pos := from
	for {
		next := pos.Add(dir)
		if !bounds.Contains(next) || walls[next] {
			break
		}
		pos = next
	}
	return pos
}

type BFSResult struct {
	Distances map[Point]int
	Touched   map[Point]bool
	Farthest  Point
}

// slideBFS mirrors MazeGenerator.slide_bfs: BFS over slide-moves (not
// single tile steps). Touched includes tiles a slide only glides over.
func slideBFS(walls map[Point]bool, bounds Bounds, start Point) BFSResult {
	distances := map[Point]int{start: 0}
	touched := map[Point]bool{start: true}
	queue := []Point{start}
	farthest := start

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, d := range DIRS {
			dest := slide(walls, bounds, current, d)
			if dest == current {
				continue
			}
			step := current
			for step != dest {
				step = step.Add(d)
				touched[step] = true
			}
			if _, ok := distances[dest]; !ok {
				distances[dest] = distances[current] + 1
				if distances[dest] > distances[farthest] {
					farthest = dest
				}
				queue = append(queue, dest)
			}
		}
	}
	return BFSResult{distances, touched, farthest}
}

func scatterWalls(bounds Bounds, start Point, rng *rand.Rand) map[Point]bool {
	walls := map[Point]bool{}
	w, h := bounds.Size()
	segmentCount := 4
	if sc := w * h / 14; sc > segmentCount {
		segmentCount = sc
	}
	for i := 0; i < segmentCount; i++ {
		tile := Point{bounds.MinX + rng.Intn(w), bounds.MinY + rng.Intn(h)}
		dir := DIRS[rng.Intn(4)]
		steps := 1 + rng.Intn(3) // randi_range(1, 3) inclusive
		for s := 0; s < steps; s++ {
			if !bounds.Contains(tile) || tile == start {
				break
			}
			walls[tile] = true
			tile = tile.Add(dir)
		}
	}
	return walls
}

// canAlwaysReturn mirrors _can_always_return: BFS over the reversed
// slide-graph, checking every reachable tile can also slide back to start.
func canAlwaysReturn(walls map[Point]bool, bounds Bounds, start Point, reachable map[Point]int) bool {
	reverse := map[Point][]Point{}
	for tile := range reachable {
		for _, d := range DIRS {
			dest := slide(walls, bounds, tile, d)
			if dest != tile {
				reverse[dest] = append(reverse[dest], tile)
			}
		}
	}

	seen := map[Point]bool{start: true}
	queue := []Point{start}
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, prev := range reverse[current] {
			if !seen[prev] {
				seen[prev] = true
				queue = append(queue, prev)
			}
		}
	}
	return len(seen) == len(reachable)
}

func sealDeadSpace(walls map[Point]bool, bounds Bounds, touched map[Point]bool) {
	for y := bounds.MinY; y < bounds.MaxY; y++ {
		for x := bounds.MinX; x < bounds.MaxX; x++ {
			p := Point{x, y}
			if !touched[p] {
				walls[p] = true
			}
		}
	}
}

type GenerateResult struct {
	Walls map[Point]bool
	BFS   BFSResult
}

// difficultyLabel mirrors MazeGenerator.difficulty_label -- only used by
// generate()'s own target_difficulty retry logic, not by the tier-relative
// labeling the generator pipeline does itself.
func difficultyLabel(slides int) string {
	if slides <= 7 {
		return "easy"
	}
	if slides <= 10 {
		return "medium"
	}
	return "hard"
}

func generate(bounds Bounds, start Point, rng *rand.Rand, targetDifficulty string) GenerateResult {
	w, h := bounds.Size()
	minTouched := int(float64(w*h) * minCoverageFraction)
	var fallback GenerateResult
	haveFallback := false

	for attempt := 0; attempt < maxAttempts; attempt++ {
		walls := scatterWalls(bounds, start, rng)
		bfs := slideBFS(walls, bounds, start)
		if len(bfs.Distances) < minReachable || len(bfs.Touched) < minTouched || !canAlwaysReturn(walls, bounds, start, bfs.Distances) {
			continue
		}

		sealDeadSpace(walls, bounds, bfs.Touched)
		result := GenerateResult{walls, bfs}

		if targetDifficulty == "" || difficultyLabel(bfs.Distances[bfs.Farthest]) == targetDifficulty {
			return result
		}
		fallback = result
		haveFallback = true
	}

	if haveFallback {
		return fallback
	}

	emptyWalls := map[Point]bool{}
	return GenerateResult{emptyWalls, slideBFS(emptyWalls, bounds, start)}
}
