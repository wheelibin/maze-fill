extends RefCounted

## Scientific-pitch-notation (A4 = 440Hz) note-name -> frequency parser.
## Lets tune_sets.gd write melodies as plain note names ("C4", "F#3", "Bb5")
## instead of hand-computed Hz or semitone math.

const FALLBACK_FREQ := 440.0 # A4 -- used when a note name fails to parse

const SEMITONE_FROM_C := {
	"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
}

## name: e.g. "C4", "F#3", "Bb5", "a4" (letter case-insensitive, sharp/flat
## both accepted). Returns equal-temperament Hz, A4=440. On a malformed
## name, pushes an error and returns FALLBACK_FREQ -- this is hand-typed
## content, so one typo should drop a note, not crash the game.
static func note_to_freq(name: String) -> float:
	var err := "NotePitch: malformed note name '%s'" % name
	if name.length() < 2:
		push_error(err)
		return FALLBACK_FREQ
	var letter := name[0].to_upper()
	if not SEMITONE_FROM_C.has(letter):
		push_error(err)
		return FALLBACK_FREQ
	var semitone: int = SEMITONE_FROM_C[letter]
	var i := 1
	if i < name.length() and (name[i] == "#" or name[i] == "b"):
		semitone += 1 if name[i] == "#" else -1
		i += 1
	var octave_str := name.substr(i)
	if octave_str.is_empty() or not octave_str.is_valid_int():
		push_error(err)
		return FALLBACK_FREQ
	var midi := (int(octave_str) + 1) * 12 + semitone # MIDI note number
	return 440.0 * pow(2.0, (midi - 69) / 12.0) # A4 = MIDI 69
