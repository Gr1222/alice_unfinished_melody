extends SceneTree
## 第 5 步验证：爱丽丝移动/跳跃/路径墙/操作锁、行走动画、任务栏、移动教程。
## 注意：引用了 autoload 的 class_name 脚本（Alice3D、QuestTracker 等）不能在测试里作为类型使用，会编译失败。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func physics_frames(count: int) -> void:
	for i in range(count): await physics_frame

## 按住某个动作 frames 个物理帧后松开。
func hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await physics_frames(frames)
	Input.action_release(action)
	await physics_frames(2)

func run() -> void:
	var state: Node = root.get_node("GameState")
	var manager: Node = root.get_node("DialogueManager")
	state.reset()
	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	director.skip_opening = true
	# 本测试只测移动：让树根兔子的剧情永远不触发（触发点设在路线终点之外），
	# 否则走到路线末端会弹出“回去看看”的对话并锁定移动，使末端封口的检查失效。
	director.rabbit_notice_distance = -100.0
	root.add_child(scene)
	var alice: Node = director.alice
	var level: Node = director.level
	var quest: Node = scene.get_node("HUD/QuestTracker")
	var tutorial: Node = scene.get_node("HUD/TutorialHint")
	await physics_frames(30)
	check(alice.is_on_floor(), "爱丽丝落在地面上")

	# 任务栏与教程
	check(state.quest_key == "QUEST_PRO_FOLLOW_RABBIT", "探索开始时设置任务")
	check(quest.visible and quest.description_label.text.contains("兔子"), "任务栏显示任务描述")
	check(quest.title_label.text == "任务目标", "任务栏标题来自字符串表")
	check(tutorial.visible and tutorial.label.text.contains("W A S D"), "显示移动教程")

	# 移动：D 向屏幕右侧
	var start: Vector3 = alice.global_position
	await hold("move_right", 30)
	var moved: Vector3 = alice.global_position - start
	check(moved.dot(director.camera.screen_right()) > 0.5, "按 D 向屏幕右侧移动（%.2f 米）" % moved.length())
	check(alice.model.placeholder.animation == "idle_right" and not alice.model.placeholder.flip_h, "停下后保持侧面朝右")
	Input.action_press("move_left")
	await physics_frames(10)
	check(alice.model.placeholder.animation == "walk_right" and alice.model.placeholder.flip_h, "向左走时播放行走动画并翻转")
	Input.action_release("move_left")
	await physics_frames(2)
	Input.action_press("move_up")
	await physics_frames(10)
	check(alice.model.placeholder.animation == "walk_up", "向上走播放背面行走动画")
	Input.action_release("move_up")
	await physics_frames(2)

	# 教程：走够距离后消失
	for i in range(3): await hold("move_right", 20)
	await physics_frames(30)
	check(state.has_flag("tutorial_move_done") and not tutorial.visible, "走够距离后移动教程消失")

	# 跳跃
	await physics_frames(10)
	var ground_y: float = alice.global_position.y
	Input.action_press("jump")
	await physics_frames(8)
	Input.action_release("jump")
	check(alice.global_position.y > ground_y + 0.3, "空格跳跃（高度 %.2f）" % (alice.global_position.y - ground_y))
	await physics_frames(60)
	check(alice.is_on_floor(), "跳跃后落地")

	# 路径墙：一直往下走不能离开路线
	await hold("move_down", 240)
	var off: Vector3 = alice.global_position
	off.y = 0
	var nearest: Vector3 = level.point_on_route(level.route_progress(off))
	check(off.distance_to(nearest) < level.PATH_HALF_WIDTH + 0.1, "隐形墙阻止离开路线（偏离 %.2f 米）" % off.distance_to(nearest))

	# 全路线扫描：5 个位置 × 4 个方向，都不能走出路线（含起点/终点封口、弯道）。
	var worst := 0.0
	var worst_where := ""
	for distance in [0.3, 7.0, 14.0, 21.0, level.route_length() - 0.3]:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			alice.global_position = level.point_on_route(distance) + Vector3(0, 0.06, 0)
			alice.velocity = Vector3.ZERO
			await physics_frames(3)
			await hold(action, 90)
			var p: Vector3 = alice.global_position
			p.y = 0
			var error: float = p.distance_to(level.point_on_route(level.route_progress(p)))
			if error > worst:
				worst = error
				worst_where = "%.1f 米处 %s" % [distance, action]
	check(worst < level.PATH_HALF_WIDTH + 0.1, "全路线扫描不会走出路线（最大偏离 %.2f 米，%s）" % [worst, worst_where])

	# 操作锁：对话期间不能移动，任务栏隐藏
	manager.play("prologue_wake")
	check(not quest.visible, "对话期间任务栏隐藏")
	var locked_start: Vector3 = alice.global_position
	await hold("move_right", 30)
	check(alice.global_position.distance_to(locked_start) < 0.01, "对话期间不能移动")
	while manager.is_active():
		manager.box.finish_typing()
		manager.advance()
	check(quest.visible, "对话结束后任务栏恢复")
	await hold("move_right", 20)
	check(alice.global_position.distance_to(locked_start) > 0.3, "对话结束后恢复移动")

	state.reset()
	scene.queue_free()
	await process_frame
	print("Player movement: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
