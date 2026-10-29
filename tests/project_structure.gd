extends SceneTree
## 第 1 步验证：autoload、输入映射、多语言、GameState 与序章森林场景。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func run() -> void:
	var bus: Node = root.get_node_or_null("EventBus")
	var state: Node = root.get_node_or_null("GameState")
	check(bus != null, "EventBus autoload 存在")
	check(state != null, "GameState autoload 存在")
	check(root.get_node_or_null("MelodyProgress") != null, "旧 MelodyProgress autoload 保留")

	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "interact", "talk", "inventory", "dialogue_next", "pause"]:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "输入动作 %s 已定义" % action)
	var e_key := InputEventKey.new()
	e_key.physical_keycode = KEY_E
	check(e_key.is_action("interact") and e_key.is_action("dialogue_next"), "E 同时用于拾取和推进对话")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	check(click.is_action("dialogue_next"), "鼠标左键推进对话")

	check(TranslationServer.get_locale().begins_with("zh"), "默认语言为中文")
	check(tr("NAME_RABBIT") == "白兔", "中文字符串可读取")
	TranslationServer.set_locale("en")
	check(tr("NAME_RABBIT") == "White Rabbit", "英文字符串可读取")
	TranslationServer.set_locale("zh")

	# GameState：背包顺序、操作锁、信号
	state.reset()
	var added: Array[String] = []
	bus.item_added.connect(func(id: String): added.append(id))
	check(state.add_item("watch") and state.add_item("note_a"), "可添加道具")
	check(not state.add_item("watch"), "同一道具不会重复添加")
	check(state.inventory == ["watch", "note_a"] and added == ["watch", "note_a"], "背包按获得顺序排列并发出信号")
	check(state.remove_item("watch") and state.inventory == ["note_a"], "可移除道具")
	state.lock_control("dialogue")
	state.lock_control("camera")
	state.unlock_control("dialogue")
	check(not state.can_control(), "仍有锁时不能操作")
	state.unlock_control("camera")
	check(state.can_control(), "全部解锁后恢复操作")
	check(not state.is_character_known("rabbit"), "白兔初始未知")
	state.know_character("rabbit")
	check(state.is_character_known("rabbit"), "可记录已知角色")
	state.reset()

	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var level: Node = scene.get_node("ForestLevel")
	check(level.get_node("ForestModel").find_children("*", "MeshInstance3D", true, false).size() > 0, "森林模型已按 data/forest.json 实例化")
	check(level.route.size() > 10, "路线已从 layout.json 读取")
	check(level.get_node_or_null("OuterPathWalls") != null, "路径墙已生成")
	check(level.layout.has("jump_obstacle") == (level.get_node_or_null("LowJumpLogCollision") != null), "有横木数据时才生成横木碰撞")
	var mid: Vector3 = level.point_on_route(level.route_length() * 0.5)
	check(absf(level.route_progress(mid) - level.route_length() * 0.5) < 0.05, "路线进度换算一致")
	print("Project structure: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
