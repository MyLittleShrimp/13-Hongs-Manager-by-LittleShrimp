extends AudioStreamPlayer
## One persistent player, independent of scene redraws and trade randomness.
signal track_changed(title: String)
const PATHS := ["res://assets/audio/main_theme.mp3", "res://assets/audio/13_hongs.mp3"]
const TITLES := ["茶船将发 · Main Theme", "茶船将发 · 13 Hongs"]
var tracks: Array[AudioStreamMP3] = []
var track_index := 0
var enabled := true
var volume_percent := 35.0
var output_suppressed := false

func _ready() -> void:
	for path in PATHS:
		var song := load(path) as AudioStreamMP3
		assert(song != null, "Missing background music: " + path)
		if song == null: return
		song.loop = false
		tracks.append(song)
	finished.connect(_next_track)
	set_volume_percent(volume_percent)
	_play_track(0)

func current_title() -> String:
	return TITLES[track_index]

func _exit_tree() -> void:
	stop()
	stream = null
	tracks.clear()

func _play_track(index: int) -> void:
	if tracks.is_empty(): return
	track_index = index % tracks.size()
	stream = tracks[track_index]
	play()
	stream_paused = not enabled
	track_changed.emit(current_title())

func _next_track() -> void:
	_play_track(track_index + 1)

func set_enabled(value: bool) -> void:
	enabled = value
	stream_paused = not enabled

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0, 100)
	volume_linear = 0.0 if output_suppressed else volume_percent / 100.0
