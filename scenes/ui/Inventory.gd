extends Control
class_name Inventory
## 背包：屏幕上方的背包图标（解锁后出现）+ 背包界面（左侧格子、右侧道具详情）。
## B 或点击图标打开/关闭，Esc 或返回按钮关闭。每次打开默认选中第一个道具；道具顺序固定（按获得顺序）。
## 详情页的【调律】按钮：道具有 tune_puzzle 且满足 tune_requires_flag 时出现，点击发出 EventBus.tune_requested。

const LOCK_REASON := "inventory"
const SLOT_COUNT := 16
const SLOT_SIZE := Vector2(104, 104)
const SLOT_ICON_SIZE := Vector2(64, 64)

@onready var bag_button: Button = $BagButton
@onready var window: Control = $Window
@onready var back_button: Button = $Window/BackButton
@onready var title_label: Label = $Window/BagPanel/Box/Title
@onready var grid: GridContainer = $Window/BagPanel/Box/Grid
@onready var detail_header: Label = $Window/DetailPanel/Box/Header
@onready var detail_icon: Panel = $Window/DetailPanel/Box/Top/Icon
@onready var detail_image: TextureRect = $Window/DetailPanel/Box/Top/Icon/Image
@onready var detail_name: Label = $Window/DetailPanel/Box/Top/Info/Name
@onready var detail_category: Label = $Window/DetailPanel/Box/Top/Info/Category
@onready var detail_description: Label = $Window/DetailPanel/Box/Description
@onready var tune_button: Button = $Window/DetailPanel/Box/Actions/Tune

var selected_item := ""
var _slot_group := ButtonGroup.new()

func _ready() -> void:
	window.hide()
	bag_button.visible = GameState.inventory_unlocked
	bag_button.text = tr("UI_INVENTORY_TITLE") + "  [B]"
	title_label.text = tr("UI_INVENTORY_TITLE")
	detail_header.text = tr("UI_ITEM_DETAIL")
	back_button.text = "← " + tr("UI_BACK")
	tune_button.text = tr("UI_TUNE")
	bag_button.pressed.connect(toggle)
	back_button.pressed.connect(close)
	tune_button.pressed.connect(_on_tune_pressed)
	EventBus.inventory_unlocked.connect(_on_unlocked)

func is_open() -> bool:
	return window.visible

func toggle() -> void:
	if is_open(): close()
	else: open()

func open() -> void:
	if is_open() or not GameState.inventory_unlocked or not GameState.can_control(): return
	rebuild_slots()
	select(GameState.inventory[0] if not GameState.inventory.is_empty() else "")
	window.show()
	bag_button.hide()
	GameState.lock_control(LOCK_REASON)
	EventBus.inventory_opened.emit()

func close() -> void:
	if not is_open(): return
	window.hide()
	bag_button.show()
	GameState.unlock_control(LOCK_REASON)
	EventBus.inventory_closed.emit()

func rebuild_slots() -> void:
	for child in grid.get_children(): child.free()
	for i in range(SLOT_COUNT):
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.toggle_mode = true
		slot.button_group = _slot_group
		grid.add_child(slot)
		if i >= GameState.inventory.size():
			slot.disabled = true
			continue
		var item_id: String = GameState.inventory[i]
		slot.name = "Slot_" + item_id
		slot.tooltip_text = tr(String(ItemDatabase.get_item(item_id).get("name", item_id)))
		slot.add_child(make_icon(item_id, SLOT_ICON_SIZE, SLOT_SIZE))
		slot.pressed.connect(select.bind(item_id))

## 道具图标：有图片用图片，没有则用 icon_color 圆形占位。
func make_icon(item_id: String, icon_size: Vector2, parent_size: Vector2) -> Control:
	var texture := ItemDatabase.icon_texture(item_id)
	var icon: Control
	if texture:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = rect
	else:
		var panel := Panel.new()
		panel.add_theme_stylebox_override("panel", ItemDatabase.icon_style(item_id))
		icon = panel
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = icon_size
	icon.position = (parent_size - icon_size) * 0.5
	return icon

func select(item_id: String) -> void:
	selected_item = item_id
	var empty := item_id.is_empty()
	detail_icon.visible = not empty
	tune_button.visible = not empty and can_tune(item_id)
	if empty:
		detail_name.text = ""
		detail_category.text = ""
		detail_description.text = ""
		return
	var item := ItemDatabase.get_item(item_id)
	detail_name.text = tr(String(item.get("name", item_id)))
	detail_category.text = tr(String(item.get("category", "")))
	detail_description.text = tr(String(item.get("description", "")))
	var texture := ItemDatabase.icon_texture(item_id)
	detail_image.texture = texture
	detail_icon.add_theme_stylebox_override("panel", ItemDatabase.icon_style(item_id) if texture == null else StyleBoxEmpty.new())
	var slot := grid.get_node_or_null("Slot_" + item_id) as Button
	if slot: slot.set_pressed_no_signal(true)

func can_tune(item_id: String) -> bool:
	var item := ItemDatabase.get_item(item_id)
	if String(item.get("tune_puzzle", "")).is_empty(): return false
	var flag := String(item.get("tune_requires_flag", ""))
	return flag.is_empty() or GameState.has_flag(flag)

func _on_tune_pressed() -> void:
	var item_id := selected_item
	close()
	EventBus.tune_requested.emit(item_id)

func _on_unlocked() -> void:
	bag_button.show()
	# 图标出现时轻微放大提示
	bag_button.pivot_offset = bag_button.size * 0.5
	bag_button.scale = Vector2(1.3, 1.3)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(bag_button, "scale", Vector2.ONE, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		toggle()
	elif is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
