extends SceneTree
## 第 7 步验证：没拿怀表时的提醒、兔子自言自语、F 对话教程、兔子对话、跳进洞、研究怀表任务与调律教程。
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

func wait_until(condition: Callable, max_frames := 600) -> bool:
	for i in range(max_frames):
		if condition.call(): return true
		await process_frame
	return false

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

func finish_dialogue(manager: Node) -> void:
	while manager.is_active():
		manager.box.finish_typing()
		manager.advance()

func place_alice(level: Node, alice: Node, distance: float) -> void:
	alice.global_position = level.point_on_route(distance) + Vector3(0, 0.06, 0)
	alice.velocity = Vector3.ZERO
	await frames(5)

func run() -> void:
	var state: Node = root.get_node("GameState")
	var manager: Node = root.get_node("DialogueManager")
	var bus: Node = root.get_node("EventBus")
	state.reset()
	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	director.skip_opening = true
	director.rabbit_notice_pan_time = 0.05
	director.rabbit_jump_time = 0.1
	root.add_child(scene)
	await frames(10)
	var level: Node = director.level
	var alice: Node = director.alice
	var rabbit: Node = director.rabbit
	var talk: Node = rabbit.get_node("Interactable")
	var tutorial: Node = director.tutorial
	var inventory: Node = scene.get_node("HUD/Inventory")
	var rabbit_at: float = director.rabbit_roots_progress()
	var notice_at: float = rabbit_at - director.rabbit_notice_distance

	check(rabbit.visible and rabbit.position.distance_to(level.point_on_route(rabbit_at)) < 0.01, "兔子在树根处等待")
	check(not talk.enabled, "自言自语之前不能与兔子对话")

	# 没拿怀表走到兔子附近：爱丽丝提醒自己回去
	await place_alice(level, alice, notice_at + 0.5)
	check(await wait_until(func(): return manager._current_id == "prologue_no_watch"), "没拿怀表时提醒回去看看")
	finish_dialogue(manager)
	await frames(30)
	check(not manager.is_active() and not talk.enabled, "没拿怀表不会触发兔子剧情")

	# 拾取怀表（走正常流程，但不打开背包，背包教程保持未完成）
	await place_alice(level, alice, director.watch_route_distance)
	director.watch.interactable.interacted.emit()
	await process_frame
	scene.get_node("HUD/ItemPopup")._confirm()
	check(state.has_item("watch") and tutorial.hint_key == "TUTORIAL_INVENTORY", "拾取怀表后显示背包教程")

	# 带着怀表再走过去：兔子自言自语，镜头移到两人中间
	await place_alice(level, alice, notice_at + 0.5)
	check(await wait_until(func(): return manager._current_id == "prologue_rabbit_roots"), "靠近后兔子自言自语")
	check(not director.camera.following, "自言自语时镜头移到两人中间")
	check(manager.box.name_label.text == "？？？" and manager.box.left_portrait.visible, "兔子独白：立绘在左，名字 ？？？")
	finish_dialogue(manager)
	check(await wait_until(func(): return director.camera.following and state.can_control()), "独白后镜头回到爱丽丝并恢复操作")
	check(talk.enabled, "独白后可以与兔子对话")

	# 走到兔子旁：F 对话教程与提示
	await place_alice(level, alice, rabbit_at - 0.8)
	check(await wait_until(func(): return tutorial.hint_key == "TUTORIAL_TALK"), "靠近兔子时显示 F 对话教程")
	check(talk.get_node("Prompt").visible and talk.get_node("Prompt").text == "[F] 对话", "兔子头上显示 [F] 对话")
	await press("interact")
	check(not manager.is_active(), "E 不能与 NPC 对话")
	await press("talk")
	check(manager._current_id == "prologue_rabbit_talk", "按 F 开始与兔子对话")
	check(manager.box.right_portrait.visible and manager.box.left_portrait.texture == manager.characters.alice.texture, "对话：爱丽丝在左，兔子在右")
	check(not tutorial.visible, "对话期间教程隐藏")
	check(tutorial.hint_key != "TUTORIAL_TALK", "开始对话后 F 教程结束")
	finish_dialogue(manager)

	# 兔子跳进洞消失 → 爱丽丝想研究怀表
	check(await wait_until(func(): return not rabbit.visible), "兔子跳进洞后消失")
	check(state.has_flag("prologue_rabbit_talked") and state.is_character_known("rabbit"), "记录已与兔子对话，并知道了兔子的名字")
	check(await wait_until(func(): return manager._current_id == "prologue_alice_study"), "爱丽丝想研究怀表")
	finish_dialogue(manager)
	check(await wait_until(func(): return state.can_control()), "独白后恢复操作")
	check(state.quest_key == "QUEST_PRO_STUDY_WATCH", "任务变为【研究一下怀表】")
	check(tutorial.hint_key == "TUTORIAL_TUNE", "显示调律教程")

	# 打开背包：旧的背包教程结束时不能关掉调律教程；怀表出现【调律】
	await press("inventory")
	await frames(2)
	check(state.has_flag("tutorial_inventory_done"), "背包教程完成")
	check(tutorial.hint_key == "TUTORIAL_TUNE", "背包教程结束不会关掉调律教程")
	check(inventory.selected_item == "watch" and inventory.tune_button.visible, "怀表详情页出现【调律】")
	# 只验证调律教程：断开导演对【调律】的响应，避免真的进入解谜（解谜在 tests/tuning_puzzle.gd 中测试）。
	bus.tune_requested.disconnect(director._on_tune_requested)
	var tuned: Array[String] = []
	bus.tune_requested.connect(func(id: String): tuned.append(id))
	inventory.tune_button.pressed.emit()
	await frames(2)
	check(tuned == ["watch"] and tutorial.hint_key == "", "点击【调律】后调律教程结束")

	state.reset()
	scene.queue_free()
	await process_frame
	print("Rabbit roots: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
