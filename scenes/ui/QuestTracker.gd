extends Control
class_name QuestTracker
## 屏幕左侧的【任务目标】。监听 GameState.set_quest()，任务变化时滑入；对话期间隐藏（避免与立绘重叠）。

const SLIDE_DISTANCE := 40.0
const SLIDE_TIME := 0.4

@onready var title_label: Label = $Box/Header/Title
@onready var description_label: Label = $Box/Description

var _in_dialogue := false
var _home_x := 0.0

func _ready() -> void:
	_home_x = position.x
	title_label.text = tr("UI_QUEST_TITLE")
	# 连接 autoload 信号时用方法而不是 lambda：节点释放时方法连接会自动断开，lambda 不会。
	EventBus.quest_changed.connect(_on_quest_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	_on_quest_changed(GameState.quest_key)

func _on_dialogue_started(_id: String) -> void:
	_in_dialogue = true
	refresh()

func _on_dialogue_finished(_id: String) -> void:
	_in_dialogue = false
	refresh()

func _on_quest_changed(key: String) -> void:
	description_label.text = "• " + tr(key) if not key.is_empty() else ""
	refresh()
	if visible: slide_in()

func refresh() -> void:
	visible = not GameState.quest_key.is_empty() and not _in_dialogue

func slide_in() -> void:
	position.x = _home_x - SLIDE_DISTANCE
	modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", _home_x, SLIDE_TIME)
	tween.tween_property(self, "modulate:a", 1.0, SLIDE_TIME)
