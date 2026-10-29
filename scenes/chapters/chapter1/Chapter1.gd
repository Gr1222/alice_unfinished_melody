extends Control
## 第一章占位场景：序章结束后进入，显示章节标题。
## 背包与解谜结果保存在 GameState 中，跨场景保留（不要在这里 reset）。

@export var fade_in_time := 1.5

@onready var title_label: Label = $Center/Box/Title
@onready var subtitle_label: Label = $Center/Box/Subtitle

func _ready() -> void:
	title_label.text = tr("CHAPTER1_TITLE")
	subtitle_label.text = tr("CHAPTER1_PLACEHOLDER")
	print("CHAPTER1_READY: items=", GameState.inventory, " puzzles=", GameState.puzzle_results)
	await Fader.fade_in(fade_in_time)
