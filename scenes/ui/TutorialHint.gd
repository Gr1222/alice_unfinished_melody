extends Control
class_name TutorialHint
## 屏幕下方的新手教程提示（如“WASD 移动”）。对话期间暂时隐藏，对话结束后恢复。
## 用法：tutorial.show_hint("TUTORIAL_MOVE") / tutorial.hide_hint("TUTORIAL_MOVE")
## hide_hint 传入 key 时，只有当前显示的正是这条提示才隐藏（避免旧教程关掉新教程）。

const FADE_TIME := 0.3

@onready var label: Label = $Panel/Label

var hint_key := ""
var _in_dialogue := false

func _ready() -> void:
	hide()
	# 用方法连接 autoload 信号（节点释放时自动断开）。
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_started(_id: String) -> void:
	_in_dialogue = true
	refresh()

func _on_dialogue_finished(_id: String) -> void:
	_in_dialogue = false
	refresh()

func show_hint(key: String) -> void:
	hint_key = key
	label.text = tr(key)
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)

func hide_hint(only_key := "") -> void:
	if not only_key.is_empty() and hint_key != only_key: return
	hint_key = ""
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(refresh)

func refresh() -> void:
	visible = not hint_key.is_empty() and not _in_dialogue
