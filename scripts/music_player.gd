extends Node

## FC / NES-style 4-channel chiptune synthesizer
## Square 25% (lead melody) · Square 12.5% (harmony arpeggio)
## Triangle (bass) · Noise (drums)
## Key: D minor  BPM: 165  Length: 8 bars (128 sixteenth-note steps)

const SAMPLE_RATE := 44100.0
const BPM         := 165.0
const STEP_SEC    := 60.0 / BPM / 4.0   # one 1/16th note ≈ 0.09091 s
const FADE_SEC    := 0.4                  # fade-in to avoid startup click
const INV_SR      := 1.0 / SAMPLE_RATE
const PLAYBACK_TYPE_STREAM := 1

# ── Frequency table (Hz) ──────────────────────────────────────────────────────
const F := {
	"R":  0.0,
	"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61,
	"G3": 196.00, "A3": 220.00, "Bb3":233.08, "B3": 246.94,
	"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
	"G4": 392.00, "A4": 440.00, "Bb4":466.16, "B4": 493.88,
	"C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46,
	"G5": 784.00, "A5": 880.00, "Bb5":932.33, "B5": 987.77,
	"C6":1046.50, "D6":1174.66, "E6":1318.51
}

# ── 128-step sequences (one entry = one 1/16th note) ─────────────────────────

## Lead: Square 25% — D-minor Touhou-style melody
const TRACK_LEAD := [
	# — Bar 1 —
	"D4","E4","F4","G4","A4","G4","F4","E4",
	"D4","F4","A4","D5","C5","A4","G4","F4",
	# — Bar 2 —
	"E4","G4","A4","Bb4","A4","G4","E4","D4",
	"F4","A4","C5","F5","E5","D5","C5","Bb4",
	# — Bar 3 —
	"A4","Bb4","C5","D5","E5","D5","C5","Bb4",
	"A4","G4","A4","Bb4","C5","Bb4","A4","G4",
	# — Bar 4 —
	"F4","G4","A4","C5","D5","C5","A4","G4",
	"A4","R","D5","R","E5","D5","C5","A4",
	# — Bar 5 —
	"D5","E5","F5","G5","A5","G5","F5","E5",
	"D5","C5","Bb4","A4","G4","A4","Bb4","C5",
	# — Bar 6 —
	"D5","E5","F5","E5","D5","C5","Bb4","A4",
	"G4","A4","Bb4","C5","D5","E5","F5","E5",
	# — Bar 7 —
	"D5","E5","F5","G5","A5","Bb5","A5","G5",
	"F5","E5","D5","C5","Bb4","A4","G4","F4",
	# — Bar 8 —
	"E4","F4","G4","A4","Bb4","A4","G4","F4",
	"E4","D4","E4","F4","G4","A4","D5","R"
]

## Harmony: Square 12.5% — rapid chord arpeggios
## Progression: Dm|Gm  Am|Bb C  Dm|Am  Bb|Am  (repeated with variation)
const TRACK_HARM := [
	# — Bar 1: Dm | Gm —
	"D4","F4","A4","D5","D4","F4","A4","D5",
	"G3","Bb3","D4","G4","G3","Bb3","D4","G4",
	# — Bar 2: Am | Bb  C —
	"A3","C4","E4","A4","A3","C4","E4","A4",
	"Bb3","D4","F4","Bb4","C4","E4","G4","C5",
	# — Bar 3: Dm | Am —
	"D4","F4","A4","D5","D4","F4","A4","D5",
	"A3","C4","E4","A4","A3","C4","E4","A4",
	# — Bar 4: Bb | Am —
	"Bb3","D4","F4","Bb4","Bb3","D4","F4","Bb4",
	"A3","C4","E4","A4","A3","C4","E4","A4",
	# — Bar 5: Dm | Gm —
	"D4","F4","A4","D5","D4","F4","A4","D5",
	"G3","Bb3","D4","G4","G3","Bb3","D4","G4",
	# — Bar 6: Am | Bb  C —
	"A3","C4","E4","A4","A3","C4","E4","A4",
	"Bb3","D4","F4","Bb4","C4","E4","G4","C5",
	# — Bar 7: Dm  Gm | Am  Dm —
	"D4","F4","A4","D5","G3","Bb3","D4","G4",
	"A3","C4","E4","A4","D4","F4","A4","D5",
	# — Bar 8: Bb  C | Dm —
	"Bb3","D4","F4","Bb4","C4","E4","G4","C5",
	"D4","F4","A4","D5","D4","F4","A4","D5"
]

## Bass: Triangle wave — root notes
const TRACK_BASS := [
	# — Bar 1: Dm | Gm —
	"D3","D3","D3","D3","D3","D3","D3","D3",
	"G3","G3","G3","G3","G3","G3","G3","G3",
	# — Bar 2: Am | Bb  C —
	"A3","A3","A3","A3","A3","A3","A3","A3",
	"Bb3","Bb3","Bb3","Bb3","C3","C3","C3","C3",
	# — Bar 3: Dm | Am —
	"D3","D3","D3","D3","D3","D3","D3","D3",
	"A3","A3","A3","A3","A3","A3","A3","A3",
	# — Bar 4: Bb | Am —
	"Bb3","Bb3","Bb3","Bb3","Bb3","Bb3","Bb3","Bb3",
	"A3","A3","A3","A3","A3","A3","A3","A3",
	# — Bar 5: Dm | Gm —
	"D3","D3","D3","D3","D3","D3","D3","D3",
	"G3","G3","G3","G3","G3","G3","G3","G3",
	# — Bar 6: Am | Bb  C —
	"A3","A3","A3","A3","A3","A3","A3","A3",
	"Bb3","Bb3","Bb3","Bb3","C3","C3","C3","C3",
	# — Bar 7: Dm  Gm | Am  Dm —
	"D3","D3","D3","D3","G3","G3","G3","G3",
	"A3","A3","A3","A3","D3","D3","D3","D3",
	# — Bar 8: Bb  C | Dm —
	"Bb3","Bb3","Bb3","Bb3","C3","C3","C3","C3",
	"D3","D3","D3","D3","D3","D3","D3","D3"
]

## Drums: 0=rest  1=hi-hat  2=snare  3=kick
const DRUM_PATTERN := [
	3,1,0,1, 2,1,0,1, 3,1,0,1, 2,1,0,1,   # bar 1
	3,1,0,1, 2,1,0,1, 3,1,0,1, 2,1,0,1,   # bar 2
	3,1,0,1, 2,1,0,1, 3,0,1,0, 2,1,0,1,   # bar 3
	3,1,0,1, 2,1,0,1, 3,1,0,1, 2,1,3,1,   # bar 4
	3,1,0,1, 2,1,0,1, 3,1,0,1, 2,1,0,1,   # bar 5
	3,1,0,1, 2,1,0,1, 3,1,0,1, 2,1,0,1,   # bar 6
	3,1,3,1, 2,1,0,1, 3,1,3,1, 2,1,0,1,   # bar 7
	3,1,0,1, 2,1,0,1, 3,1,3,1, 2,1,2,3    # bar 8
]

# ── Runtime state ─────────────────────────────────────────────────────────────
var _playback: AudioStreamGeneratorPlayback

# Tone channels — each is a dict: {phase, freq, type, vol}
var _ch := [
	{"phase": 0.0, "freq": 0.0, "type": "sq25", "vol": 0.26},  # lead
	{"phase": 0.0, "freq": 0.0, "type": "sq12", "vol": 0.18},  # harmony
	{"phase": 0.0, "freq": 0.0, "type": "tri",  "vol": 0.30},  # bass
]

var _step := 0        # sequencer position (wraps at 128)
var _tick := 0.0      # sample counter within current step

var _drum_type  := 0  # active drum: 0=none 1=hat 2=snare 3=kick
var _drum_env   := 0.0
var _drum_kick_t := 0.0  # time since trigger (pitch sweep + buzz)
var _noise_state: int = 12345

var _fade := 0.0      # fade-in envelope [0, 1]

# ── Setup ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.12
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.playback_type = PLAYBACK_TYPE_STREAM
	player.volume_db = -6.0
	add_child(player)
	player.play()
	_playback = player.get_stream_playback()
	# Pre-load step 0 so music starts immediately (no silent first step)
	_apply_step(0)
	_step = 1

# ── Buffer fill ───────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for _i in range(frames):
		_tick += 1.0
		if _tick >= STEP_SEC * SAMPLE_RATE:
			_tick -= STEP_SEC * SAMPLE_RATE
			_advance_step()
		_fade = minf(_fade + INV_SR / FADE_SEC, 1.0)
		var s := clampf(_mix() * _fade, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))

# ── Sequencer ─────────────────────────────────────────────────────────────────
func _advance_step() -> void:
	_apply_step(_step % 128)
	_step += 1

func _apply_step(step: int) -> void:
	_ch[0].freq = F.get(TRACK_LEAD[step], 0.0)
	_ch[1].freq = F.get(TRACK_HARM[step], 0.0)
	_ch[2].freq = F.get(TRACK_BASS[step], 0.0)
	var d: int = DRUM_PATTERN[step]
	if d > 0:
		_drum_type   = d
		_drum_env    = 1.0
		_drum_kick_t = 0.0

# ── Audio synthesis ───────────────────────────────────────────────────────────
func _mix() -> float:
	var s := 0.0
	for ch in _ch:
		if ch.freq > 0.0:
			s += _wave(ch) * ch.vol
		ch.phase = fmod(ch.phase + ch.freq * INV_SR, 1.0)
	s += _drum()
	return s

func _wave(ch: Dictionary) -> float:
	var t: float = ch.phase
	match ch.type:
		"sq25":
			return 1.0 if t < 0.25 else -1.0
		"sq12":
			return 1.0 if t < 0.125 else -1.0
		"tri":
			return 4.0 * t - 1.0 if t < 0.5 else 3.0 - 4.0 * t
	return 0.0

func _drum() -> float:
	if _drum_env <= 0.0:
		return 0.0
	# Amplitude decay per second for each drum type
	var decay: float = [0.0, 28.0, 14.0, 8.5][_drum_type]
	_drum_env = maxf(0.0, _drum_env - decay * INV_SR)
	match _drum_type:
		1:  # hi-hat: high-frequency noise burst
			_noise_state = (_noise_state * 1664525 + 1013904223) & 0x7FFFFFFF
			return (float(_noise_state) / 1073741823.0 - 1.0) * _drum_env * 0.15
		2:  # snare: noise + tone buzz
			_noise_state = (_noise_state * 1664525 + 1013904223) & 0x7FFFFFFF
			var n := float(_noise_state) / 1073741823.0 - 1.0
			var buzz := sin(TAU * 185.0 * _drum_kick_t)
			_drum_kick_t += INV_SR
			return (n * 0.65 + buzz * 0.35) * _drum_env * 0.20
		3:  # kick: descending pitch sweep (155 Hz → 42 Hz)
			var freq := lerpf(155.0, 42.0, minf(1.0, _drum_kick_t * 9.0))
			var s := sin(TAU * freq * _drum_kick_t) * _drum_env * 0.40
			_drum_kick_t += INV_SR
			return s
	return 0.0
