extends Node
## Plays positional one-shot sound effects from a small voice pool, the music (with
## crossfades) and the looping crowd bed whose level follows the match's heat.
## Buses: SFX, Music, Crowd (created by Settings).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 16

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _music: Array[AudioStreamPlayer] = []     # two players for crossfades
var _music_fades: Array = [null, null]        # in-flight volume tween per music player
var _music_on := 0
var _music_name := ""
var _music_db := 0.0
## Front-end music (menus, create-a-wrestler, career) plays this much quieter than the arena.
const MENU_DB := -9.0
var _murmur: AudioStreamPlayer
var _cheer: AudioStreamPlayer
var _crowd_target := 0.0
var _crowd_on := false


func _ready() -> void:
	# list_directory sees imported resources in exported builds too
	for f in ResourceLoader.list_directory(SFX_DIR):
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			_streams[f.get_basename()] = load(SFX_DIR + f)
	for i in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_db = 3.0
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_murmur = _loop_player("crowd_murmur_loop")
	_cheer = _loop_player("crowd_cheer_loop")


func _loop_player(sfx: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Crowd"
	p.volume_db = -80.0
	if _streams.has(sfx):
		p.stream = _looped(_streams[sfx])
	add_child(p)
	return p


static func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav:
		wav = wav.duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav
	return stream


## Start or cancel a volume fade on one music player. Any in-flight fade on that
## player is superseded: two tweens on one volume let the last one to finish win, so a
## stale fade-out could stomp a settled theme back to silence (issue #17).
func _fade_music(i: int, to_db: float, dur: float) -> void:
	var stale: Tween = _music_fades[i]
	if stale != null and stale.is_valid():
		stale.kill()
	var tw := create_tween()
	tw.tween_property(_music[i], "volume_db", to_db, maxf(dur, 0.05))
	_music_fades[i] = tw


## Crossfade to a music track from assets/audio/music ("" fades out), at `volume_db`.
## A fade of 0 starts it at full level at once (the loading screen: a fade would stall).
func play_music(track: String, fade: float = 1.0, loop: bool = true, volume_db: float = 0.0) -> void:
	if track == _music_name:
		if track != "" and not is_equal_approx(_music_db, volume_db):
			_music_db = volume_db
			_fade_music(_music_on, volume_db, fade)
		return
	_music_name = track
	_music_db = volume_db
	var old_i := _music_on
	_music_on = 1 - _music_on
	var cur_i := _music_on
	_fade_music(old_i, -80.0, fade)
	if track == "":
		# silence: the player being handed over goes quiet too, or a pending fade-in
		# of its own would lift it back up after this transition settles
		_fade_music(cur_i, -80.0, fade)
		return
	var path := MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("unknown music %s" % track)
		_fade_music(cur_i, -80.0, fade)
		return
	var stream: AudioStream = load(path)
	_music[cur_i].stream = _looped(stream) if loop else stream
	_music[cur_i].volume_db = volume_db if fade <= 0.0 else -30.0
	_music[cur_i].play()
	if fade > 0.0:
		_fade_music(cur_i, volume_db, fade * 0.6)


func music_playing() -> String:
	return _music_name


## Start/stop the crowd ambience (matches and the menu backdrop).
func crowd_ambience(on: bool) -> void:
	_crowd_on = on
	for p in [_murmur, _cheer]:
		if on and not p.playing and p.stream:
			p.play(_rng.randf() * 4.0)
	if not on:
		_crowd_target = 0.0


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


## Crowd ambience level (0..1): a murmur that swells into a roar.
func set_crowd(heat: float) -> void:
	_crowd_target = heat
	if not _crowd_on:
		crowd_ambience(true)


func _process(delta: float) -> void:
	var on := 1.0 if _crowd_on else 0.0
	var want_murmur := lerpf(-16.0, -9.0, _crowd_target) if on > 0.0 else -80.0
	var want_cheer := lerpf(-38.0, -3.0, pow(_crowd_target, 1.4)) if on > 0.0 else -80.0
	_murmur.volume_db = move_toward(_murmur.volume_db, want_murmur, delta * 30.0)
	_cheer.volume_db = move_toward(_cheer.volume_db, want_cheer, delta * 24.0)
	if not _crowd_on and _murmur.volume_db <= -79.0:
		_murmur.stop()
		_cheer.stop()


func has_sfx(sfx: String) -> bool:
	return _streams.has(sfx)
