package main

import (
	"math/bits"
	"time"
)

// Port of maze_solver.gd. A* over (position, painted-set) states with an
// admissible/consistent heuristic (remaining tiles / longest open run).
// Each state is visited at most once (closed set), expanded in order of
// f = g + h instead of pure breadth.
//
// Budgeted: a small number of layouts turn out to need tens of millions
// of states and run for hours even running alone (not just from
// concurrent contention) -- rather than chase that per-instance cost
// further, the caller (main.go) treats a timeout as "try a different
// candidate from the same difficulty band" instead of waiting it out.
//
// Performance notes (this file was rewritten once the no-budget version
// turned out to need 15-25+ minutes on the hardest 180-tile levels):
//   - slide() only depends on walls, never on paint state, so every
//     (position, direction) transition -- destination and which tiles
//     get newly painted -- is precomputed once per board instead of
//     being re-walked tile-by-tile on every single state expansion.
//   - Lanes is a fixed-size array (value type), not a slice: copying a
//     state is a stack copy, not a heap allocation + GC pressure, and it
//     can be used directly as a map key with no separate conversion step.
//   - The priority queue is a plain slice indexed by f-value, not a map
//     -- f is a small bounded int, so direct indexing beats hashing into
//     a map on every push/pop.

// maxLanes covers up to maxLanes*64 tiles. Current largest board (20x12,
// 180 touched tiles) needs exactly 3 -- bump this if a future size grows
// past 192 tiles.
const maxLanes = 3

type Lanes [maxLanes]uint64

func markLane(l *Lanes, bit int) {
	l[bit/64] |= 1 << uint(bit%64)
}

type StateKey struct {
	PosIndex int
	Lanes    Lanes
}

type SolveResult struct {
	Moves          int
	Path           []int8
	StatesExplored int
}

func heuristic(remaining, maxRun int) int {
	return (remaining + maxRun - 1) / maxRun // ceil division
}

func maxRunLength(walls map[Point]bool, bounds Bounds) int {
	maxRun := 1
	for y := bounds.MinY; y < bounds.MaxY; y++ {
		run := 0
		for x := bounds.MinX; x < bounds.MaxX; x++ {
			if walls[Point{x, y}] {
				run = 0
			} else {
				run++
				if run > maxRun {
					maxRun = run
				}
			}
		}
	}
	for x := bounds.MinX; x < bounds.MaxX; x++ {
		run := 0
		for y := bounds.MinY; y < bounds.MaxY; y++ {
			if walls[Point{x, y}] {
				run = 0
			} else {
				run++
				if run > maxRun {
					maxRun = run
				}
			}
		}
	}
	return maxRun
}

// transition is the precomputed result of sliding from some tile in a
// given direction: where you land, and which tiles (as a bitmask) get
// painted along the way. Independent of paint state, so computed once
// per (tile, direction) pair up front rather than per search node.
type transition struct {
	valid     bool
	destIndex int
	delta     Lanes
}

func precomputeTransitions(walls map[Point]bool, bounds Bounds, tiles []Point, tileIndex map[Point]int) [][4]transition {
	table := make([][4]transition, len(tiles))
	for i, p := range tiles {
		for di, d := range DIRS {
			dest := slide(walls, bounds, p, d)
			if dest == p {
				continue
			}
			var delta Lanes
			step := p
			for step != dest {
				step = step.Add(d)
				if bit, ok := tileIndex[step]; ok {
					markLane(&delta, bit)
				}
			}
			table[i][di] = transition{valid: true, destIndex: tileIndex[dest], delta: delta}
		}
	}
	return table
}

type searchNode struct {
	posIndex  int
	lanes     Lanes
	g         int
	remaining int
	parentKey StateKey
	dir       int8
}

type cameFromEntry struct {
	parent StateKey
	dir    int8
}

// MinMovesToCover returns SolveResult{-1, statesExplored} if `budget`
// elapses before a solution is found -- the caller should treat that as
// "give up on this candidate," not "no solution exists."
func MinMovesToCover(walls map[Point]bool, bounds Bounds, start Point, touched map[Point]bool, budget time.Duration) SolveResult {
	tiles := make([]Point, 0, len(touched))
	for p := range touched {
		tiles = append(tiles, p)
	}
	tileIndex := make(map[Point]int, len(tiles))
	for i, p := range tiles {
		tileIndex[p] = i
	}

	table := precomputeTransitions(walls, bounds, tiles, tileIndex)

	startIndex := tileIndex[start]
	var startLanes Lanes
	markLane(&startLanes, startIndex)

	maxRun := max(maxRunLength(walls, bounds), 1)
	startRemaining := len(tiles) - 1

	closed := map[StateKey]bool{}
	// Predecessor of each closed state, recorded only at close time (see
	// below) -- that's the only point the algorithm's A* ordering
	// guarantees the recorded parent is the optimal one, despite the
	// queue allowing multiple, differently-g'd pushes for the same key.
	cameFrom := map[StateKey]cameFromEntry{}

	// Priority queue bucketed by f-value, indexed directly (f is a
	// small bounded int) -- grown on demand if a push exceeds capacity.
	buckets := make([][]searchNode, len(tiles)+1)
	minF := heuristic(startRemaining, maxRun)
	startKey := StateKey{startIndex, startLanes}
	buckets[minF] = append(buckets[minF], searchNode{
		posIndex: startIndex, lanes: startLanes, g: 0, remaining: startRemaining,
		parentKey: startKey, dir: -1,
	})

	statesExplored := 0
	deadline := time.Now().Add(budget)

	for {
		for minF < len(buckets) && len(buckets[minF]) == 0 {
			minF++
		}
		if minF >= len(buckets) {
			return SolveResult{Moves: -1, StatesExplored: statesExplored}
		}
		if time.Now().After(deadline) {
			return SolveResult{Moves: -1, StatesExplored: statesExplored}
		}

		bucket := buckets[minF]
		cur := bucket[len(bucket)-1]
		buckets[minF] = bucket[:len(bucket)-1]

		key := StateKey{cur.posIndex, cur.lanes}
		if closed[key] {
			continue
		}
		closed[key] = true
		statesExplored++
		if cur.dir >= 0 {
			cameFrom[key] = cameFromEntry{parent: cur.parentKey, dir: cur.dir}
		}

		if cur.remaining == 0 {
			path := make([]int8, cur.g)
			for i, k := cur.g-1, key; k != startKey; i-- {
				entry := cameFrom[k]
				path[i] = entry.dir
				k = entry.parent
			}
			return SolveResult{Moves: cur.g, Path: path, StatesExplored: statesExplored}
		}

		for di, tr := range table[cur.posIndex] {
			if !tr.valid {
				continue
			}

			newLanes := cur.lanes // array value copy -- stack, not heap
			newRemaining := cur.remaining
			for lane := 0; lane < maxLanes; lane++ {
				newBits := tr.delta[lane] &^ newLanes[lane]
				newRemaining -= bits.OnesCount64(newBits)
				newLanes[lane] |= tr.delta[lane]
			}

			newKey := StateKey{tr.destIndex, newLanes}
			if closed[newKey] {
				continue
			}

			newG := cur.g + 1
			newF := newG + heuristic(newRemaining, maxRun)

			if newF >= len(buckets) {
				grown := make([][]searchNode, newF+1)
				copy(grown, buckets)
				buckets = grown
			}
			buckets[newF] = append(buckets[newF], searchNode{
				posIndex: tr.destIndex, lanes: newLanes, g: newG, remaining: newRemaining,
				parentKey: key, dir: int8(di),
			})
			if newF < minF {
				minF = newF
			}
		}
	}
}
