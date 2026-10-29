extends Node
## Autoload：全局信号总线。各系统只通过这里通信，互不直接引用。

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_unlocked
signal inventory_opened
signal inventory_closed
## 背包详情页点击【调律】按钮。
signal tune_requested(item_id: String)
signal quest_changed(quest_key: String)
signal flag_changed(flag: String, value: Variant)
signal player_control_changed(enabled: bool)
