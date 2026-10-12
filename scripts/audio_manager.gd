extends Node
## AudioManager autoload: music (with crossfade) + pooled SFX + bus controls.
##   AudioManager.play_music("world1_theme")        # crossfades from the current track
##   AudioManager.play_music("title_theme", 0.0)    # hard cut
##   AudioManager.stop_music()                      # fades out
##   AudioManager.play_sfx("jump")
##   AudioManager.set_bus_volume("Music", 0.5)      # linear 0..1 (or set_bus_volume_db)
##   AudioManager.set_bus_mute("SFX", true)
## Files live in res://audio/music/<name>.ogg and res://audio/sfx/<name>.ogg.

const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const SFX_VOICES := 8
const DEFAULT_FADE := 0.6
const SILENT_DB := -60.0

var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _music: AudioStreamPlayer = _music_a   # the currently active music player
var _fade_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}
var current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in [_music_a, _music_b]:
		p.bus = _bus_or_master("Music")
		add_child(p)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = _bus_or_master("SFX")
		add_child(p)
		_sfx_players.append(p)

# --- Music ---------------------------------------------------------------------

func play_music(track_name: String, fade := DEFAULT_FADE, restart := false) -> void:
	if track_name == current_music and _music.playing and not restart:
		return
	var stream := _load(MUSIC_DIR, track_name)
	if stream == null:
		return
	# Looping comes from each track's .import settings (world1_theme loops; title_theme
	# plays once). The shared cached resource is never modified here.
	var old := _music
	var new := _music_b if old == _music_a else _music_a
	current_music = track_name
	_kill_tween()
	new.stream = stream
	new.volume_db = SILENT_DB if fade > 0.0 and old.playing else 0.0
	new.play()
	_music = new
	if fade > 0.0 and old.playing:
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(new, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
		_fade_tween.tween_property(old, "volume_db", SILENT_DB, fade).set_trans(Tween.TRANS_SINE)
		_fade_tween.chain().tween_callback(old.stop)
	else:
		old.stop()

func stop_music(fade := DEFAULT_FADE) -> void:
	current_music = ""
	_kill_tween()
	var p := _music
	if fade > 0.0 and p.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(p, "volume_db", SILENT_DB, fade)
		_fade_tween.tween_callback(p.stop)
	else:
		p.stop()
	var other := _music_b if p == _music_a else _music_a
	other.stop()

func _kill_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	# Stop any player left half-faded by an interrupted crossfade.
	for p in [_music_a, _music_b]:
		if p != _music:
			p.stop()

# --- SFX -----------------------------------------------------------------------

func play_sfx(sfx_name: String, pitch := 1.0) -> void:
	var stream := _load(SFX_DIR, sfx_name)
	if stream == null:
		return
	var p := _free_voice()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()

func _free_voice() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	var p := _sfx_players[_next_voice]   # all busy: steal round-robin
	_next_voice = (_next_voice + 1) % SFX_VOICES
	return p

# --- Buses -----------------------------------------------------------------------

## Linear volume, 0.0 (silent) .. 1.0 (unity).
func set_bus_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))

func set_bus_volume_db(bus_name: String, db: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i != -1:
		AudioServer.set_bus_volume_db(i, db)

func get_bus_volume(bus_name: String) -> float:
	var i := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i != -1 else 0.0

func set_bus_mute(bus_name: String, muted: bool) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i != -1:
		AudioServer.set_bus_mute(i, muted)

func is_bus_muted(bus_name: String) -> bool:
	var i := AudioServer.get_bus_index(bus_name)
	return AudioServer.is_bus_mute(i) if i != -1 else false

# --- Internals ---------------------------------------------------------------------

func _load(dir: String, n: String) -> AudioStream:
	var key := dir + n + ".ogg"
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(key):
		push_warning("AudioManager: missing audio '%s'" % key)
		return null
	var s: AudioStream = load(key)
	_cache[key] = s
	return s

func _bus_or_master(bus_name: String) -> StringName:
	return StringName(bus_name) if AudioServer.get_bus_index(bus_name) != -1 else &"Master"
