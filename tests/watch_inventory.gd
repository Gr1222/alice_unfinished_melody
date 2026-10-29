extends SceneTree
## 第 6 步验证：交互提示、拾取怀表、获得道具弹窗、背包解锁/打开/详情/调律按钮、背包教程。
## 注意：引用了 autoload 的 class_name 脚本不能在测试里作为类型使用，这里一律用 Node。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

## 通过输入系统发送一次动作按下（走完整的 _input / _unhandled_input 流程）。
func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await process_frame

func run() -> void:
	var state: Node = root.get_node("GameState")
	var bus: Node = root.get_node("EventBus")
	var manager: Node = root.get_node("DialogueManager")
	state.reset()

	# 道具数据：每个道具的文本都有中英文
	var items: Dictionary = ItemDatabase.all()
	check(items.has("watch") and items.has("note_a"), "道具数据已加载")
	for id: String in items:
		for field in ["name", "category", "description"]:
			var key := String(items[id][field])
			for locale in ["zh", "en"]:
				TranslationServer.set_locale(locale)
				check(tr(key) != key, "%s.%s 缺少 %s 文本" % [id, field, locale])
	TranslationServer.set_locale("zh")

	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	director.skip_opening = true
	root.add_child(scene)
	await frames(20)
	var alice: Node = director.alice
	var watch: Node = director.watch
	var prompt: Node = watch.interactable.get_node("Prompt")
	var popup: Node = scene.get_node("HUD/ItemPopup")
	var inventory: Node = scene.get_node("HUD/Inventory")
	var tutorial: Node = director.tutorial

	check(not prompt.visible, "离怀表远时不显示提示")
	check(not inventory.bag_button.visible, "拾取前背包图标隐藏")
	await press("inventory")
	check(not inventory.is_open(), "背包未解锁时 B 无效")

	# 走到怀表旁：显示 [E] 拾取 与 E 教程
	alice.global_position = watch.global_position + Vector3(0.4, 0.06, 0)
	await frames(10)
	check(watch.interactable.player_in_range and prompt.visible, "靠近怀表时显示交互提示")
	check(prompt.text == "[E] 拾取", "提示文字来自字符串表")
	check(tutorial.visible and tutorial.hint_key == "TUTORIAL_INTERACT", "第一次靠近时显示 E 拾取教程")

	# F 不能拾取（拾取用 E）
	await press("talk")
	check(watch.visible and not state.has_item("watch"), "F 不能拾取物品")

	# E 拾取 → 弹窗
	await press("interact")
	check(not watch.visible and state.has_item("watch"), "按 E 拾取怀表")
	check(popup.visible and popup.title_label.text == "获得道具" and popup.item_label.text == "怀表", "弹窗【获得道具 怀表】")
	check(not state.can_control(), "弹窗期间锁定操作")
	check(not prompt.visible, "拾取后提示消失")
	check(not inventory.bag_button.visible, "确认弹窗前背包尚未解锁")

	# 确认弹窗 → 解锁背包 + 背包教程
	await press("dialogue_next")
	check(not popup.visible and state.can_control(), "确认后关闭弹窗并恢复操作")
	check(state.inventory_unlocked and inventory.bag_button.visible, "背包图标出现")
	check(tutorial.hint_key == "TUTORIAL_INVENTORY", "显示打开背包教程")

	# B 打开背包：默认选中第一个道具
	await press("inventory")
	check(inventory.is_open() and not state.can_control(), "按 B 打开背包并锁定操作")
	check(inventory.selected_item == "watch" and inventory.detail_name.text == "怀表", "默认显示第一个道具详情")
	check(inventory.detail_category.text == "仙境道具" and not inventory.detail_description.text.is_empty(), "显示类别与描述")
	check(not inventory.tune_button.visible, "与兔子对话前不显示【调律】")
	await frames(2)
	check(state.has_flag("tutorial_inventory_done") and tutorial.hint_key == "", "打开背包后教程结束")
	await press("inventory")
	check(not inventory.is_open() and state.can_control(), "再按 B 关闭背包")

	# 多个道具：顺序固定，调律按钮按道具与剧情标记显示
	state.set_flag("prologue_rabbit_talked")
	state.add_item("note_a")
	inventory.bag_button.pressed.emit()
	check(inventory.is_open(), "点击背包图标打开背包")
	check(inventory.selected_item == "watch", "每次打开都默认选中第一个道具")
	check(inventory.grid.get_child(0).name == "Slot_watch" and inventory.grid.get_child(1).name == "Slot_note_a", "道具按获得顺序排列")
	check(inventory.grid.get_child_count() == inventory.SLOT_COUNT and inventory.grid.get_child(2).disabled, "空格子不可选")
	check(inventory.tune_button.visible, "与兔子对话后怀表显示【调律】")
	inventory.grid.get_child(1).pressed.emit()
	check(inventory.selected_item == "note_a" and not inventory.tune_button.visible, "选中音符：没有【调律】")
	inventory.grid.get_child(0).pressed.emit()
	# 本测试只测背包：断开导演对【调律】的响应，避免真的进入解谜（解谜在 tests/tuning_puzzle.gd 中测试）。
	bus.tune_requested.disconnect(director._on_tune_requested)
	var tuned: Array[String] = []
	bus.tune_requested.connect(func(id: String): tuned.append(id))
	inventory.tune_button.pressed.emit()
	check(tuned == ["watch"] and not inventory.is_open(), "点击【调律】发出 tune_requested 并关闭背包")

	# Esc 关闭；对话期间不能打开
	await press("inventory")
	await press("pause")
	check(not inventory.is_open(), "Esc 关闭背包")
	manager.play("prologue_wake")
	await press("inventory")
	check(not inventory.is_open(), "对话期间不能打开背包")
	while manager.is_active():
		manager.box.finish_typing()
		manager.advance()

	# 失去道具弹窗
	popup.show_item("watch", true)
	check(popup.visible and popup.title_label.text == "失去道具", "弹窗【失去道具】")
	popup.confirm_button.pressed.emit()
	check(not popup.visible and state.can_control(), "点击【确定】关闭弹窗")

	state.reset()
	scene.queue_free()
	await process_frame
	print("Watch & inventory: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
