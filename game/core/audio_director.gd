extends Node
## Plays positional one-shot sound effects from a small voice pool.

const SFX_DIR := "res://assets/audio/sfx/"
const VOICES := 16

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# list_directory sees imported resources in exported builds too
	for f in ResourceLoader.list_directory(SFX_DIR):
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			_streams[f.get_basename()] = load(SFX_DIR + f)
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_db = 3.0
		add_child(p)
		_players.append(p)


func play(sfx: String, at: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if not _streams.has(sfx):
		push_warning("unknown sfx %s" % sfx)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sfx]
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func has_sfx(sfx: String) -> bool:
	return _streams.has(sfx)
