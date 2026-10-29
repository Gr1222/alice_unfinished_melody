extends Control
class_name ItemPopup
## 【获得道具】/【失去道具】弹窗。用法：await item_popup.show_item("watch") / show_item("watch", true)
## 点击【确定】或按 dialogue_next（Enter / E / 左键）关闭；显示期间锁定操作。

signal confirmed

const LOCK_REASON := "popup"
const POP_TIME := 0.25

@onready var window: Control = $Window
@onready var icon_panel: Panel = $Window/Content/IconFrame/Icon
@onready var icon_image: TextureRect = $Window/Content/IconFrame/Icon/Image
@onready var title_label: Label = $Window/Content/Text/Title
@onready var item_label: Label = $Window/Content/Text/ItemName
@onready var confirm_button: Button = $Window/Confirm

func _ready() -> void:
	hide()
	confirm_button.pressed.connect(_confirm)

func show_item(item_id: String, lost := false) -> void:
	var item := ItemDatabase.get_item(item_id)
	title_label.text = tr("UI_ITEM_LOST" if lost else "UI_ITEM_GET")
	item_label.text = tr(String(item.get("name", item_id)))
	confirm_button.text = tr("UI_CONFIRM")
	var texture := ItemDatabase.icon_texture(item_id)
	icon_image.texture = texture
	icon_panel.add_theme_stylebox_override("panel", ItemDatabase.icon_style(item_id) if texture == null else StyleBoxEmpty.new())
	# 失去道具时图标变灰
	icon_panel.modulate = Color(0.55, 0.55, 0.55) if lost else Color.WHITE
	show()
	GameState.lock_control(LOCK_REASON)
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.85, 0.85)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(window, "scale", Vector2.ONE, POP_TIME)
	await confirmed

func _confirm() -> void:
	if not visible: return
	hide()
	GameState.unlock_control(LOCK_REASON)
	confirmed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("dialogue_next") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_confirm()
