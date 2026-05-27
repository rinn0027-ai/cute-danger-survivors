extends Node

## One-shot NES-style sound effects synthesized from raw PCM.
## Pre-generate AudioStreamWAV objects once on startup, then
## spawn a temporary AudioStreamPlayer for each playback.

const SAMPLE_RATE := 22050  # sufficient quality for short SFX

var _shoot_wav: AudioStreamWAV
var _hit_wav: AudioStreamWAV

# Cooldown prevents the same sound piling up when many events fire at once
var _hit_cooldown := 0.0

func _ready() -> void:
	_shoot_wav = _gen_shoot()
	_hit_wav   = _gen_hit()

func _process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)

# ── Public API ────────────────────────────────────────────────────────────────

## Call once per salvo (not once per bullet in a burst).
func play_shoot() -> void:
	_play(_shoot_wav, -8.0)

## Call when a player bullet damages an enemy.
func play_hit() -> void:
	if _hit_cooldown > 0.0:
		return
	_hit_cooldown = 0.04   # max ~25 hit-sounds per second
	_play(_hit_wav, -4.0)

# ── Internal playback ─────────────────────────────────────────────────────────

func _play(wav: AudioStreamWAV, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream    = wav
	p.volume_db = db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

# ── PCM generation ────────────────────────────────────────────────────────────

## Shoot: 25% square wave sweeping 880 Hz → 170 Hz in 70 ms.
## Sounds like a classic NES "pew".
func _gen_shoot() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.07)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in range(n):
		var t   := float(i) / float(n)
		var freq := lerpf(880.0, 170.0, t)
		var env  := 1.0 - t                     # linear decay
		var sq   := 1.0 if phase < 0.25 else -1.0
		var s    := clampi(int(sq * env * 28000.0), -32768, 32767)
		bytes[i * 2]     = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
		phase = fmod(phase + freq / SAMPLE_RATE, 1.0)
	return _make_wav(bytes)

## Hit: noise burst mixed with a sharp descending tone, 55 ms.
## Sounds like a NES impact / "bop".
func _gen_hit() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.055)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var nstate := 54321
	for i in range(n):
		var t    := float(i) / float(n)
		var env  := pow(1.0 - t, 1.6)           # sharper-than-linear decay
		var freq := lerpf(560.0, 55.0, t)
		# Noise component
		nstate = (nstate * 1664525 + 1013904223) & 0x7FFFFFFF
		var noise := float(nstate) / 1073741823.0 - 1.0
		# Square tone component
		var sq   := 1.0 if phase < 0.25 else -1.0
		phase = fmod(phase + freq / SAMPLE_RATE, 1.0)
		var mix  := noise * 0.5 + sq * 0.5
		var s    := clampi(int(mix * env * 25000.0), -32768, 32767)
		bytes[i * 2]     = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	return _make_wav(bytes)

func _make_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo   = false
	wav.data     = bytes
	return wav
