package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

// Port of tools/generate_levels.gd, parallelized across CPU cores for
// both candidate generation and min-moves solving (the two CPU-heavy,
// fully-independent-per-item steps).

var sizes = []Point{{14, 6}, {16, 8}, {18, 10}, {20, 12}}

const (
	levelsPerSize     = 250
	candidatesPerSize = 3000
	// Target easy/hard fraction at the start and end of a size's run;
	// medium fills whatever's left. Linear ramp.
	easyStart      = 0.6
	easyEnd        = 0.0
	hardStart      = 0.0
	hardEnd        = 0.85
	generationSeed = 1
	outputPath     = "../levels/levels.json"
	// Solving (not candidate generation) is capped well below NumCPU:
	// the hardest layouts build a `closed` map with tens of millions of
	// entries (multiple GB each). Too many of those in flight at once
	// can exceed available RAM and trigger swapping, which is orders of
	// magnitude slower than just running fewer at a time -- a real
	// 1000-level run hit layouts needing 60-90M states and multi-hour
	// solves once enough of them piled up concurrently.
	maxConcurrentSolves = 4
	// A candidate that doesn't solve within this gets abandoned in favor
	// of a different one from the same difficulty band, rather than
	// waited out -- rerolling costs nothing in level quality (any other
	// candidate from the same band is an equally valid level), so there's
	// no downside to erring short. With solving capped at
	// maxConcurrentSolves, legitimately-hard-but-normal levels should
	// clear this easily; true pathological outliers (tens of millions of
	// states) won't.
	probeBudget = 45 * time.Second
	// After this many distinct candidates have failed the probe for one
	// level slot (should be rare -- most succeed on attempt 1), stop
	// rerolling and just solve the last one unbounded instead of
	// potentially looping forever on an unlucky band.
	maxRerollAttempts = 10
)

type candidate struct {
	walls     map[Point]bool
	goal      Point
	touched   map[Point]bool
	score     float64
	poolIndex int
}

type levelEntry struct {
	Size            [2]int   `json:"size"`
	Start           [2]int   `json:"start"`
	Walls           [][2]int `json:"walls"`
	Goal            [2]int   `json:"goal"`
	DifficultyScore float64  `json:"difficulty_score"`
	DifficultyLabel string   `json:"difficulty_label"`
	MinMoves        int      `json:"min_moves"`
}

func scoreCandidate(bfs BFSResult) float64 {
	return float64(bfs.Distances[bfs.Farthest])
}

func labelForScore(score, t1, t2 float64) string {
	if score <= t1 {
		return "easy"
	}
	if score <= t2 {
		return "medium"
	}
	return "hard"
}

func lerp(a, b, t float64) float64 { return a + (b-a)*t }

// seedFor derives a distinct, deterministic seed per parallel task so
// the whole run stays reproducible under concurrency -- each goroutine
// gets its own *rand.Rand, never a shared one.
func seedFor(parts ...int) int64 {
	s := int64(generationSeed)
	for _, p := range parts {
		s = s*1_000_003 + int64(p)
	}
	return s
}

// parallelFor runs `n` tasks across available CPUs, calling fn(i) for
// each index. Blocks until all complete.
func parallelFor(n int, fn func(i int)) {
	parallelForCapped(n, runtime.NumCPU(), fn)
}

// parallelForCapped is parallelFor with an explicit worker ceiling,
// for phases where running too many at once is actively harmful rather
// than just "not maximally fast" (see maxConcurrentSolves).
func parallelForCapped(n int, maxWorkers int, fn func(i int)) {
	workers := max(min(maxWorkers, n), 1)

	var next int64 = -1
	var wg sync.WaitGroup
	wg.Add(workers)
	for w := 0; w < workers; w++ {
		go func() {
			defer wg.Done()
			for {
				i := int(atomic.AddInt64(&next, 1))
				if i >= n {
					return
				}
				fn(i)
			}
		}()
	}
	wg.Wait()
}

func main() {
	var levels []levelEntry

	for sizeIndex, size := range sizes {
		bounds := BoundsForSize(size)
		start := Point{bounds.MinX, bounds.MinY}

		pool := make([]candidate, candidatesPerSize)
		parallelFor(candidatesPerSize, func(i int) {
			rng := rand.New(rand.NewSource(seedFor(sizeIndex, i, 1)))
			result := generate(bounds, start, rng, "")
			pool[i] = candidate{
				walls:     result.Walls,
				goal:      result.BFS.Farthest,
				touched:   result.BFS.Touched,
				score:     scoreCandidate(result.BFS),
				poolIndex: i,
			}
		})
		// Stable, not just Slice: many candidates share the same integer
		// score, and sort.Slice's pivot selection isn't guaranteed to
		// break those ties the same way across runs -- SliceStable keeps
		// tie order equal to the (deterministic) input order instead.
		sort.SliceStable(pool, func(i, j int) bool { return pool[i].score < pool[j].score })

		t1 := pool[len(pool)/3].score
		t2 := pool[len(pool)*2/3].score

		bands := map[string][]candidate{}
		for _, c := range pool {
			label := labelForScore(c.score, t1, t2)
			bands[label] = append(bands[label], c)
		}

		fmt.Printf("Size %v: pool=%d scores min=%.0f median=%.0f max=%.0f t1=%.1f t2=%.1f\n",
			size, len(pool), pool[0].score, pool[len(pool)/2].score, pool[len(pool)-1].score, t1, t2)

		// Pick AND solve each level's candidate together, per slot, so a
		// candidate that proves too slow to solve can be rerolled for a
		// different one from the same band instead of waited out.
		// Shared across slots (mutex-protected): a cache of confirmed-
		// fast results (dedupes identical picks -- collisions across
		// ~150+ hard slots drawn from a ~1000-candidate pool are
		// near-certain, birthday-paradox style) and a cache of
		// confirmed-too-slow candidates (skip straight to rerolling
		// without re-probing them).
		fallbackOrder := map[string]string{"hard": "medium", "medium": "easy", "easy": ""}
		warned := map[string]bool{}
		resultByPoolIndex := map[int]SolveResult{}
		badPoolIndices := map[int]bool{}
		var cacheMu sync.Mutex
		var rerollCount atomic.Int64

		chosen := make([]candidate, levelsPerSize)
		chosenLabel := make([]string, levelsPerSize)
		solved := make([]SolveResult, levelsPerSize)

		var doneCount atomic.Int64
		progressDone := make(chan struct{})
		go func(size Point) {
			ticker := time.NewTicker(10 * time.Second)
			defer ticker.Stop()
			start := time.Now()
			for {
				select {
				case <-progressDone:
					return
				case <-ticker.C:
					fmt.Printf("Size %v: %d/%d levels solved (%s elapsed)\n",
						size, doneCount.Load(), levelsPerSize, time.Since(start).Round(time.Second))
				}
			}
		}(size)

		// Capped (not full NumCPU): these workers are the only place in
		// the program building maps large enough to risk swapping (see
		// maxConcurrentSolves).
		parallelForCapped(levelsPerSize, maxConcurrentSolves, func(i int) {
			rng := rand.New(rand.NewSource(seedFor(sizeIndex, i, 2)))

			t := float64(i) / float64(levelsPerSize-1)
			easyFrac := lerp(easyStart, easyEnd, t)
			hardFrac := lerp(hardStart, hardEnd, t)
			mediumFrac := max(1.0-easyFrac-hardFrac, 0)

			roll := rng.Float64() * (easyFrac + mediumFrac + hardFrac)
			var targetBand string
			switch {
			case roll < easyFrac:
				targetBand = "easy"
			case roll < easyFrac+mediumFrac:
				targetBand = "medium"
			default:
				targetBand = "hard"
			}

			actualBand := targetBand
			for len(bands[actualBand]) == 0 && fallbackOrder[actualBand] != "" {
				cacheMu.Lock()
				if !warned[targetBand] {
					warned[targetBand] = true
					fmt.Printf("Size %v: band '%s' empty, falling back to '%s' — board too small for 3 distinct bands (expected for small sizes)\n",
						size, actualBand, fallbackOrder[actualBand])
				}
				cacheMu.Unlock()
				actualBand = fallbackOrder[actualBand]
			}
			subpool := bands[actualBand]

			var c candidate
			var result SolveResult
			tried := map[int]bool{}
			for {
				c = subpool[rng.Intn(len(subpool))]

				cacheMu.Lock()
				cached, isCached := resultByPoolIndex[c.poolIndex]
				isBad := badPoolIndices[c.poolIndex]
				cacheMu.Unlock()

				if isCached {
					result = cached
					break
				}
				if isBad {
					continue // known too slow -- reroll without re-probing
				}

				// Past a reasonable number of distinct attempts (should
				// be rare -- most levels succeed on the first try), fall
				// back to an unbounded solve on whichever candidate we're
				// on rather than loop forever if a whole band is unlucky.
				tried[c.poolIndex] = true
				budget := probeBudget
				if len(tried) >= maxRerollAttempts {
					budget = time.Hour * 24
				}

				t0 := time.Now()
				result = MinMovesToCover(c.walls, bounds, start, c.touched, budget)
				elapsed := time.Since(t0)

				if result.Moves == -1 {
					cacheMu.Lock()
					badPoolIndices[c.poolIndex] = true
					cacheMu.Unlock()
					rerollCount.Add(1)
					fmt.Printf("Size %v candidate (score=%.0f): exceeded %s probe budget (%d states) -- rerolling\n",
						size, c.score, probeBudget, result.StatesExplored)
					continue
				}

				if elapsed > 2*time.Second {
					fmt.Printf(
						"Size %v candidate (score=%.0f): solved in %s (%d states)\n",
						size,
						c.score,
						elapsed.Round(time.Second),
						result.StatesExplored,
					)
				}
				cacheMu.Lock()
				resultByPoolIndex[c.poolIndex] = result
				cacheMu.Unlock()
				break
			}

			chosen[i] = c
			chosenLabel[i] = labelForScore(c.score, t1, t2)
			solved[i] = result
			doneCount.Add(1)
		})
		close(progressDone)

		if n := rerollCount.Load(); n > 0 {
			fmt.Printf("Size %v: %d candidates were too slow and got rerolled\n", size, n)
		}

		for i := 0; i < levelsPerSize; i++ {
			wallsArr := make([][2]int, 0, len(chosen[i].walls))
			for p := range chosen[i].walls {
				wallsArr = append(wallsArr, [2]int{p.X, p.Y})
			}
			sort.Slice(wallsArr, func(a, b int) bool {
				if wallsArr[a][1] != wallsArr[b][1] {
					return wallsArr[a][1] < wallsArr[b][1]
				}
				return wallsArr[a][0] < wallsArr[b][0]
			})

			levels = append(levels, levelEntry{
				Size:            [2]int{size.X, size.Y},
				Start:           [2]int{start.X, start.Y},
				Walls:           wallsArr,
				Goal:            [2]int{chosen[i].goal.X, chosen[i].goal.Y},
				DifficultyScore: chosen[i].score,
				DifficultyLabel: chosenLabel[i],
				MinMoves:        solved[i].Moves,
			})
		}

		fmt.Printf("  size %v done (%d levels)\n", size, levelsPerSize)
	}

	if len(levels) != len(sizes)*levelsPerSize {
		panic("level count mismatch")
	}

	// Self-check: recomputing difficulty from stored walls must match
	// what was recorded, same as the GDScript version's assert.
	for _, entry := range levels {
		b := Bounds{1, 1, entry.Size[0] - 1, entry.Size[1] - 1}
		s := Point{entry.Start[0], entry.Start[1]}
		walls := map[Point]bool{}
		for _, pair := range entry.Walls {
			walls[Point{pair[0], pair[1]}] = true
		}
		bfs := slideBFS(walls, b, s)
		goal := Point{entry.Goal[0], entry.Goal[1]}
		if float64(bfs.Distances[goal]) != entry.DifficultyScore {
			panic(fmt.Sprintf("self-check failed for level with goal %v", goal))
		}
	}

	out, err := filepath.Abs(outputPath)
	if err != nil {
		panic(err)
	}
	if err := os.MkdirAll(filepath.Dir(out), 0755); err != nil {
		panic(err)
	}
	data, err := json.MarshalIndent(levels, "", "\t")
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile(out, data, 0644); err != nil {
		panic(err)
	}

	fmt.Printf("Wrote %d levels to %s\n", len(levels), out)
}
