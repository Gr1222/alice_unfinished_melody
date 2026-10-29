extends Node
## Autoload：读取 data/dialogue/*.json 与 data/characters.json，逐行驱动对话框。
## 用法：await DialogueManager.play("prologue_sister")
##
## 对话数据格式：
##   "对话id": { "mode": "talk" | "monologue", "with": "角色id（talk 时右侧角色）",
##               "lines": [ {"speaker": "角色id 或空（旁白）", "text": "字符串 key"},
##                          {"know": "角色id"}  ← 从此处起该角色显示真名 ] }
## 显示规则（见序章玩法文档）：
##   monologue：说话者的立绘与名字在左侧；
##   talk：爱丽丝永远在左，对方在右；名字显示在说话一方；未知角色名显示为 UI_UNKNOWN_NAME。

signal finished(dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogue/"
const CHARACTERS_PATH := "res://data/characters.json"
const PLAYER_ID := "alice"
const LOCK_REASON := "dialogue"

var dialogues: Dictionary = {}
var characters: Dictionary = {}
var _current_id := ""
var _lines: Array = []
var _index := -1
var _mode := ""
var _partner := ""

@onready var box: DialogueBox = $DialogueBox

func _ready() -> void:
	load_data()

func load_data() -> void:
	characters = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	for id: String in characters:
		var path := String(characters[id].get("portrait", ""))
		characters[id]["texture"] = load(path) if not path.is_empty() else null
	dialogues.clear()
	for file in DirAccess.get_files_at(DIALOGUE_DIR):
		if not file.ends_with(".json"): continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + file))
		for id: String in data:
			if dialogues.has(id): push_error("对话 id 重复：%s（%s）" % [id, file])
			dialogues[id] = data[id]

func is_active() -> bool:
	return not _current_id.is_empty()

func play(dialogue_id: String) -> void:
	if is_active():
		push_error("已有对话进行中，忽略：%s" % dialogue_id)
		return
	if not dialogues.has(dialogue_id):
		push_error("找不到对话：%s" % dialogue_id)
		return
	var data: Dictionary = dialogues[dialogue_id]
	_current_id = dialogue_id
	_lines = data.get("lines", [])
	_mode = String(data.get("mode", "monologue"))
	_partner = String(data.get("with", ""))
	_index = -1
	GameState.lock_control(LOCK_REASON)
	EventBus.dialogue_started.emit(dialogue_id)
	box.open()
	_show_next()
	await finished

## 推进：正在逐字显示时先补全本句，否则进入下一句。
func advance() -> void:
	if not is_active(): return
	if box.is_typing():
		box.finish_typing()
	else:
		_show_next()

func _show_next() -> void:
	_index += 1
	while _index < _lines.size() and _lines[_index].has("know"):
		GameState.know_character(String(_lines[_index]["know"]))
		_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	var speaker := String(line.get("speaker", ""))
	var text := tr(String(line.get("text", "")))
	if String(line.get("mode", _mode)) == "monologue":
		box.show_line(display_name(speaker), text, character(speaker), {}, "left" if not speaker.is_empty() else "")
		return
	var active := ""
	if speaker == PLAYER_ID: active = "left"
	elif not speaker.is_empty(): active = "right"
	# 对话中出现非 with 的第三方时，临时占用右侧。
	var right_id := speaker if active == "right" and speaker != _partner else _partner
	box.show_line(display_name(speaker), text, character(PLAYER_ID), character(right_id), active)

func _finish() -> void:
	var id := _current_id
	_current_id = ""
	_lines = []
	box.close()
	GameState.unlock_control(LOCK_REASON)
	EventBus.dialogue_finished.emit(id)
	finished.emit(id)

func character(id: String) -> Dictionary:
	return characters.get(id, {})

func display_name(id: String) -> String:
	if id.is_empty(): return ""
	var data := character(id)
	if data.is_empty(): return id
	if bool(data.get("always_known", false)) or GameState.is_character_known(id):
		return tr(String(data.name))
	return tr("UI_UNKNOWN_NAME")

func _input(event: InputEvent) -> void:
	if not is_active() or event.is_echo(): return
	if event.is_action_pressed("dialogue_next"):
		# 吞掉这次按键，避免 E 在关闭对话的同时触发拾取。
		get_viewport().set_input_as_handled()
		advance()
