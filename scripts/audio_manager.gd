extends Node
## AudioManager autoload: simple music + SFX playback.
##   AudioManager.play_music("world1_theme")   # loops; no restart if already playing
##   AudioManager.stop_music()
##   AudioManager.play_sfx("jump")
## Files live in res://audio/music/<name>.ogg and res://audio/sfx/<name>.ogg (.wav fallback).

const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const SFX_VOICES := 8

var _music := AudioStreamPlayer.new()
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}
var current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.bus = _bus_or_master("Music")
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = _bus_or_master("SFX")
		add_child(p)
		_sfx_players.append(p)

func play_music(track_name: String, restart := false) -> void:
	if track_name == current_music and _music.playing and not restart:
		return
	var stream := _load(MUSIC_DIR, track_name)
	if stream == null:
		return
	# Belt and braces: import settings already loop, but force it for title/world music.
	if stream is AudioStreamOggVorbis:
		stream.loop = track_name != "title_theme"
	current_music = track_name
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_music.stop()
	current_music = ""

func play_sfx(sfx_name: String, pitch := 1.0) -> void:
	var stream := _load(SFX_DIR, sfx_name)
	if stream == null:
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.play()

func _load(dir: String, n: String) -> AudioStream:
	var key := dir + n
	if _cache.has(key):
		return _cache[key]
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(key + ext):
			var s: AudioStream = load(key + ext)
			_cache[key] = s
			return s
	push_warning("AudioManager: missing audio '%s'" % key)
	return null

func _bus_or_master(bus_name: String) -> StringName:
	return StringName(bus_name) if AudioServer.get_bus_index(bus_name) != -1 else &"Master"
