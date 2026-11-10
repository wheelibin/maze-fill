extends RefCounted

## Preset melodies for the wall-hit sound in tune mode (player.gd's
## use_tune_mode). Each entry is a flat Array[String] of note names
## (parsed by note_pitch.gd), one step per wall hit, looping from the
## start when exhausted. Add a new tune by appending a new array -- no
## synthesis code changes.
##
## There is no independent rhythm/duration control: tempo is entirely
## player-paced by how fast wall-hits happen. A note that should sound
## rhythmically longer is written as repeated identical entries. This is
## a known characteristic of the system, not a bug -- don't expect
## metronomic accuracy out of it.
const TUNE_SETS: Array[Array] = [
	# 1. Ode to Joy
	[
	  "E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4",
	  "C4", "C4", "D4", "E4", "E4", "D4", "D4",

	  "E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4",
	  "C4", "C4", "D4", "E4", "D4", "C4", "C4",

	  "D4", "D4", "E4", "C4", "D4", "E4", "F4", "E4", "C4",
	  "D4", "E4", "F4", "E4", "D4", "C4", "D4", "G3",

	  "E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4",
	  "C4", "C4", "D4", "E4", "D4", "C4", "C4"
	],
	# 2. Can-Can
	[
	  "G3", "G3",
	  "A3", "C4", "B3", "A3",
	  "D4", "D4",
	  "D4", "E4", "B3", "C4",
	  "A3", "A3",

	  "A3", "C4", "B3", "A3",
	  "G3", "G4", "F#4", "E4",
	  "D4", "C4", "B3", "A3"
	],
	# 3. fur-elise
	[
	  "E4", "D#4", "E4", "D#4", "E4",
	  "B3", "D4", "C4", "A3",
	  "C3", "E3", "A3", "B3",
	  "E3", "G#3", "B3", "C4",
	  "E3", "E4", "D#4", "E4", "D#4", "E4",
	  "B3", "D4", "C4", "A3",
	  "C3", "E3", "A3", "B3",
	  "E3", "C4", "B3", "A3"
	],
	# 4. the swan
	[
		"G4", "F#4", "B3", 
		"E4", "D4", "G3", 
		"A3", "B3", "C4",
		"E3", "F#3", "G3",
		"A3", "B3", "C4",
		"D4", "E4", "F#4", "B4"
	],
	# 5. in the hall of the mountain king
	[
	  "B3", "C#4", "D4", "E4", "F#4",
	  "D4", "F#4",
	  "F4", "C#4", "F4",
	  "E4", "C4", "E4",

	  "B3", "C#4", "D4", "E4", "F#4",
	  "D4", "F#4",
	  "B4", "A4", "F#4", "D4", "F#4", "A4"
	],
	# 6. greensleeves
	[
	  "A3", "C4", "D4",
	  "E4", "F4", "E4",
	  "D4", "B3",
	  "G3", "A3", "B3",

	  "C4", "A3",
	  "A3", "G#3", "A3",
	  "B3", "G#3",
	  "E3", "A3",

	  "A3", "C4", "D4",
	  "E4", "F4", "E4",
	  "D4", "B3",
	  "G3", "A3", "B3",

	  "C4", "B3", "A3",
	  "G#3", "F#3", "G#3",
	  "A3"
	]
]
