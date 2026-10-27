extends Node

## Autoload：在章节切换之间保留同一首大旋律的修复进度。
## 目前为本次游玩的内存进度，尚未实现退出游戏后的存档。
signal phrase_restored(phrase_id: String)

var restored: Array[Resource] = []
var collected: Dictionary = {}

func collect(phrase_id: String, fragment_id: String) -> bool:
	var ids: Array = collected.get(phrase_id, [])
	if fragment_id in ids: return false
	ids.append(fragment_id)
	collected[phrase_id] = ids
	return true

func has_fragment(phrase_id: String, fragment_id: String) -> bool:
	return fragment_id in collected.get(phrase_id, [])

func has_all(phrase: Resource) -> bool:
	for id in phrase.fragment_ids:
		if not has_fragment(phrase.phrase_id, id): return false
	return true

func is_restored(phrase_id: String) -> bool:
	for phrase in restored:
		if phrase.phrase_id == phrase_id: return true
	return false

func restore_phrase(phrase: Resource, arrangement: Array[String]) -> bool:
	if not phrase.is_valid_definition() or not has_all(phrase): return false
	if arrangement != phrase.solution: return false
	if not is_restored(phrase.phrase_id):
		restored.append(phrase)
		restored.sort_custom(func(a: Resource, b: Resource): return a.sequence_index < b.sequence_index)
		phrase_restored.emit(phrase.phrase_id)
	return true

func summary() -> String:
	var names: PackedStringArray = []
	for phrase in restored: names.append(phrase.display_name)
	return ("尚未修复" if names.is_empty() else " → ".join(names)) + " → ……（后续章节待修复）"

func reset() -> void:
	restored.clear()
	collected.clear()
