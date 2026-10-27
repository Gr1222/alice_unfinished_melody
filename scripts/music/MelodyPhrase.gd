extends Resource
class_name MelodyPhrase

## 一个章节贡献的乐句，而非整首游戏主题曲。音频稍后在 Inspector 中填写。
@export var phrase_id: String = "prologue"
@export var display_name: String = "序章 · 初醒"
@export var sequence_index: int = 0
@export var fragment_ids: Array[String] = ["glimmer", "echo", "rest"]
@export var fragment_names: Array[String] = ["微光", "回声", "余韵"]
@export var visual_clues: Array[String] = ["静默 → 微光", "微光 → 回声", "回声 → 静默"]
@export var solution: Array[String] = ["glimmer", "echo", "rest"]
@export var fragment_audio: Array[AudioStream] = []

func is_valid_definition() -> bool:
	if phrase_id.is_empty() or fragment_ids.is_empty(): return false
	if fragment_names.size() != fragment_ids.size() or visual_clues.size() != fragment_ids.size(): return false
	if solution.size() != fragment_ids.size(): return false
	var unique := {}
	for id in fragment_ids:
		if id.is_empty() or unique.has(id) or solution.count(id) != 1: return false
		unique[id] = true
	return true

func audio_for(id: String) -> AudioStream:
	var index := fragment_ids.find(id)
	if index < 0 or index >= fragment_audio.size(): return null
	return fragment_audio[index]
