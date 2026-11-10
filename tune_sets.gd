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
	# Ode to Joy
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
	# Can-Can
	# [
	#   "G4",
	#   "A4", "C5", "B4", "A4",
	#   "D5", "D5",
	#   "D5", "E5", "B4", "C5",
	#   "A4", "A4",
	#
	#   "A4", "C5", "B4", "A4",
	#   "G4", "G5", "F#5", "E5",
	#   "D5", "C5", "B4", "A4",
	#   "G4",
	#   "A4", "C5", "B4", "A4",
	#   "D5", "D5",
	#   "D5", "E5", "B4", "C5",
	#   "A4", "A4",
	#   "A4", "C5", "B4", "A4",
	#   "B4", "G4", "A4", "B4",
	#
	#   "G4", "B4"
	# ],
	# fur-elise
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
	# the swan
	[
		"G4", "F#4", "B3", 
		"E4", "D4", "G3", 
		"A3", "B3", "C4",
		"E3", "F#3", "G3",
		"A3", "B3", "C4",
		"D4", "E4", "F#4", "B4"
	]
]
