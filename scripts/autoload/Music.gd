extends Node
## Autoload：背景音乐。两个播放器交替使用，实现交叉淡入淡出。
## 曲目 id → 文件路径定义在 data/audio.json 的 "music" 中（以 "_" 开头的 key 是备注，会被忽略）。
## 用法：Music.play("forest") / Music.stop(2.0)

const AUDIO_PATH := "res://data/audio.json"
const MUSIC_VOLUME := 0.8

var tracks: Dictionary = {}
var current_id := ""
var _players: Array[AudioStreamPlayer] = []
var _tweens: Dictionary = {}
var _active := 0

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_PATH))
	for id: String in data.get("music", {}):
		if not id.begins_with("_"): tracks[id] = data.music[id]
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % i
		add_child(player)
		_players.append(player)

func play(id: String, fade := 1.0) -> void:
	if id == current_id: return
	if not tracks.has(id):
		push_error("找不到曲目：%s（请在 %s 中添加）" % [id, AUDIO_PATH])
		return
	var path := String(tracks[id])
	var old := _players[_active]
	current_id = id
	# 占位阶段多个 id 可能指向同一文件：同一首歌继续播放，不重新开始。
	if old.playing and old.stream != null and old.stream.resource_path == path:
		return
	_active = 1 - _active
	var player := _players[_active]
	player.stream = load(path)
	player.volume_linear = 0.0 if fade > 0.0 else MUSIC_VOLUME
	player.play()
	_fade(player, MUSIC_VOLUME, fade, false)
	_fade(old, 0.0, fade, true)

func stop(fade := 1.0) -> void:
	current_id = ""
	_fade(_players[_active], 0.0, fade, true)

func is_playing() -> bool:
	return _players[_active].playing

func _fade(player: AudioStreamPlayer, target: float, duration: float, stop_after: bool) -> void:
	if _tweens.has(player): _tweens[player].kill()
	if not player.playing: return
	if duration <= 0.0:
		player.volume_linear = target
		if stop_after: player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_linear", target, duration)
	if stop_after: tween.tween_callback(player.stop)
	_tweens[player] = tween
