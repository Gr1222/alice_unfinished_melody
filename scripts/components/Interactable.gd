extends Area3D
class_name Interactable
## 可交互组件：爱丽丝（group "player"）进入范围时，在物体上方显示按键提示（如“[E] 拾取”），
## 按下对应动作时发出 interacted。需要一个 CollisionShape3D 子节点决定范围。
## 拾取物品用 interact（E），与 NPC 对话用 talk（F）。

signal interacted
## 爱丽丝第一次及每次进入范围时发出（用于触发新手教程）。
signal player_entered

@export_enum("interact", "talk") var action := "interact"
@export var prompt_key := "UI_PROMPT_INTERACT"
## 提示文字距离本节点的高度（米）。
@export var prompt_height := 0.8
@export var enabled := true

var player_in_range := false
var _label: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_label = Label3D.new()
	_label.name = "Prompt"
	_label.text = tr(prompt_key)
	_label.font = load("res://assets/fonts/ui_font.tres")
	_label.font_size = 40
	_label.outline_size = 12
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = prompt_height
	_label.hide()
	add_child(_label)

func can_interact() -> bool:
	return enabled and player_in_range and GameState.can_control()

func _process(_delta: float) -> void:
	_label.visible = can_interact()

func _unhandled_input(event: InputEvent) -> void:
	if can_interact() and event.is_action_pressed(action) and not event.is_echo():
		get_viewport().set_input_as_handled()
		interacted.emit()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	player_in_range = true
	player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"): player_in_range = false
