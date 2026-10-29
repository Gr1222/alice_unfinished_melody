extends Node
## Autoload：全局游戏状态（剧情标记、已知角色、背包、任务、解谜结果、操作锁）。
## 目前只保存在内存中，尚未实现存档。

## 测试期使用中文；最终提交改为 "en"。
const DEFAULT_LOCALE := "zh"

var flags: Dictionary = {}
## 已知名字的角色 id；未知角色在对话框中显示为 UI_UNKNOWN_NAME（？？？）。
var known_characters: Array[String] = ["alice"]
## 背包按获得顺序排列，玩家不能调整顺序。
var inventory: Array[String] = []
var inventory_unlocked := false
var quest_key := ""
## 解谜 id → 玩家排列的片段 id 数组，游戏后期回放玩家创作的音乐。
var puzzle_results: Dictionary = {}
## 多个系统可同时锁定操作（对话、镜头演出、解谜），全部解锁后才恢复。
var _control_locks: Dictionary = {}

func _ready() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)

func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	EventBus.flag_changed.emit(flag, value)

func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))

func know_character(character_id: String) -> void:
	if character_id not in known_characters:
		known_characters.append(character_id)

func is_character_known(character_id: String) -> bool:
	return character_id in known_characters

func unlock_inventory() -> void:
	if inventory_unlocked: return
	inventory_unlocked = true
	EventBus.inventory_unlocked.emit()

func add_item(item_id: String) -> bool:
	if item_id in inventory: return false
	inventory.append(item_id)
	EventBus.item_added.emit(item_id)
	return true

func remove_item(item_id: String) -> bool:
	if item_id not in inventory: return false
	inventory.erase(item_id)
	EventBus.item_removed.emit(item_id)
	return true

func has_item(item_id: String) -> bool:
	return item_id in inventory

func set_quest(key: String) -> void:
	quest_key = key
	EventBus.quest_changed.emit(key)

func save_puzzle_result(puzzle_id: String, arrangement: Array) -> void:
	puzzle_results[puzzle_id] = arrangement.duplicate()

func lock_control(reason: String) -> void:
	var was_free := can_control()
	_control_locks[reason] = true
	if was_free: EventBus.player_control_changed.emit(false)

func unlock_control(reason: String) -> void:
	if not _control_locks.erase(reason): return
	if can_control(): EventBus.player_control_changed.emit(true)

func can_control() -> bool:
	return _control_locks.is_empty()

func reset() -> void:
	flags.clear()
	known_characters.assign(["alice"])
	inventory.clear()
	inventory_unlocked = false
	quest_key = ""
	puzzle_results.clear()
	_control_locks.clear()
