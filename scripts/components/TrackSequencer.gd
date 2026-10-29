extends Node
class_name TrackSequencer
## 多音轨播放器：每条音轨是一个音频流 + 若干时间段，时间段按顺序首尾相接播放。
## 用于：解谜开头完整试听、单个片段试听、确认后播放玩家的排列，以及游戏后期回放玩家创作的旋律。
##
## 用法：
##   sequencer.play([
##       {"id": "melody", "stream": 钢琴, "ranges": [Vector2(0, 8)]},
##       {"id": "item",   "stream": 怀表, "ranges": [Vector2(2, 3.5), Vector2(0, 2), ...], "volume": 0.8},
##   ])
##   await sequencer.finished
## 时间由自己的计时器驱动（不依赖音频驱动的播放位置），所以无头测试中也能正常推进。

signal finished

## 测试用：加快计时（音频本身不会变快）。
var time_scale := 1.0
var playing := false
var elapsed := 0.0
var duration := 0.0
var _layers: Array = []
var _players: Array[AudioStreamPlayer] = []

func play(layers: Array) -> void:
	stop()
	duration = 0.0
	for i in range(layers.size()):
		var layer: Dictionary = layers[i]
		var schedule: Array = []
		var at := 0.0
		for range_value: Vector2 in layer.get("ranges", []):
			schedule.append({"at": at, "from": range_value.x, "length": range_value.y - range_value.x})
			at += range_value.y - range_value.x
		duration = maxf(duration, at)
		var player := _player(i)
		player.stream = layer.get("stream")
		player.volume_linear = float(layer.get("volume", 1.0))
		_layers.append({"id": String(layer.get("id", "")), "player": player, "schedule": schedule, "next": 0, "stop_at": -1.0})
	elapsed = 0.0
	playing = true
	_step()

## 停止播放（不会发出 finished）。
func stop() -> void:
	playing = false
	for layer: Dictionary in _layers: layer.player.stop()
	_layers.clear()

## 实时调整某条音轨的音量（按 id）。
func set_volume(id: String, volume: float) -> void:
	for layer: Dictionary in _layers:
		if layer.id == id: layer.player.volume_linear = volume

func _player(index: int) -> AudioStreamPlayer:
	while _players.size() <= index:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	return _players[index]

func _process(delta: float) -> void:
	if not playing: return
	elapsed += delta * time_scale
	_step()
	if elapsed >= duration:
		stop()
		finished.emit()

func _step() -> void:
	for layer: Dictionary in _layers:
		if layer.stop_at >= 0.0 and elapsed >= layer.stop_at:
			layer.player.stop()
			layer.stop_at = -1.0
		var schedule: Array = layer.schedule
		while layer.next < schedule.size() and elapsed >= schedule[layer.next].at:
			var entry: Dictionary = schedule[layer.next]
			if layer.player.stream: layer.player.play(entry.from)
			layer.stop_at = entry.at + entry.length
			layer.next += 1
