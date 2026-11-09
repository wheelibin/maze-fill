extends Node

## Ambient background pad: a slow attack/release tone, retriggered every 2-3s
## on a random note from the level's scale. Envelope is baked into a
## precomputed AudioStreamWAV rather than driven live -- same reason as
## player.gd's wall-hit notes: a live ring buffer doesn't recover cleanly
## from Web Audio context suspension when a mobile tab is backgrounded.

const MIX_RATE := 44100.0
const DURATION := 4.0
const ATTACK := 0.35 # fraction of DURATION
const RELEASE := 0.45 # fraction of DURATION
const ROOT_FREQ := 110.0 # one octave below player.gd's wall-hit root
const MIN_INTERVAL := 4.0
const MAX_INTERVAL := 5.0
const VOICE_COUNT := 3
const VOLUME_DB := -18.0
const FADE_OUT_TIME := 1.5

var _scale_semitones: Array = GameState.SCALE_SETS[0]
var _note_streams: Array[AudioStreamWAV] = []
var _voices: Array[AudioStreamPlayer] = []
var _fade_tweens: Array[Tween] = []
var _next_voice := 0
var _timer: Timer

func _ready() -> void:
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = VOLUME_DB
		add_child(voice)
		_voices.append(voice)
		_fade_tweens.append(null)

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

	_rebuild_note_streams()
	_schedule_next()

## Called on level complete: stops scheduling new notes and fades out
## whatever's currently sounding, rather than leaving it to ring out on its
## own envelope (which could still be mid-sustain, nowhere near its release).
func stop() -> void:
	_timer.stop()
	for i in _voices.size():
		var voice := _voices[i]
		if not voice.playing:
			continue
		if _fade_tweens[i]:
			_fade_tweens[i].kill()
		var tween := create_tween()
		_fade_tweens[i] = tween
		tween.tween_property(voice, "volume_db", VOLUME_DB - 40.0, FADE_OUT_TIME)
		tween.finished.connect(voice.stop)

## Called on level load/retry to undo a previous stop()'s fade-out. Plays a
## note right away -- otherwise every level start has a silent 3-5s wait
## for the first scheduled note.
func resume() -> void:
	for i in _voices.size():
		if _fade_tweens[i]:
			_fade_tweens[i].kill()
			_fade_tweens[i] = null
		_voices[i].stop()
		_voices[i].volume_db = VOLUME_DB
	_play_random_note()
	_schedule_next()

## Called by main.gd when a level loads, so the pad always harmonizes with
## that level's wall-hit notes (see GameState.SCALE_SETS).
func set_level_scale(semitones: Array) -> void:
	_scale_semitones = semitones
	_rebuild_note_streams()

func _rebuild_note_streams() -> void:
	_note_streams.resize(_scale_semitones.size())
	for i in _scale_semitones.size():
		var freq := ROOT_FREQ * pow(2.0, _scale_semitones[i] / 12.0)
		_note_streams[i] = _build_pad_stream(freq)

func _schedule_next() -> void:
	_timer.start(randf_range(MIN_INTERVAL, MAX_INTERVAL))

func _on_timeout() -> void:
	_play_random_note()
	_schedule_next()

## Round-robins across a small voice pool (rather than one retriggered
## player) so a slow release tail isn't cut off by the next note.
func _play_random_note() -> void:
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _note_streams[randi() % _note_streams.size()]
	voice.play()

func _build_pad_stream(freq: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2) # 16-bit mono
	for i in sample_count:
		var t := i / MIX_RATE
		var progress := float(i) / sample_count
		var envelope := 1.0
		if progress < ATTACK:
			envelope = progress / ATTACK
		elif progress > 1.0 - RELEASE:
			envelope = (1.0 - progress) / RELEASE
		var sample := sin(TAU * freq * t) * envelope
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(MIX_RATE)
	stream.stereo = false
	stream.data = data
	return stream
