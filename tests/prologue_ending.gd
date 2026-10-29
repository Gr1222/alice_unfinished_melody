extends SceneTree
## 第 9 步验证：兔子洞交互（解谜前不可用）、结尾演出（音符飞出变大 → 爱丽丝跳上 → 下沉 → 淡出）、
## 进入第一章后状态保留（背包、解谜结果）且没有残留的操作锁。
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

func wait_until(condition: Callable, max_frames := 900) -> bool:
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

func run() -> void:
	var state: Node = root.get_node("GameState")
	var manager: Node = root.get_node("DialogueManager")
	var fader: Node = root.get_node("Fader")
	var music: Node = root.get_node("Music")
	state.reset()

	# 音符符号用网格拼成，不依赖字体（UI 字体没有 ♪）
	var note_scene: Node = load("res://scenes/props/MusicNote.tscn").instantiate()
	check(note_scene.get_node("Symbol").get_child_count() == 3 and note_scene.find_children("*", "Label3D").is_empty(), "音符符号由 3D 网格组成，不使用字体")
	note_scene.free()

	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	director.skip_opening = true
	# 本测试不测兔子剧情：让树根兔子的剧情不触发
	director.rabbit_notice_distance = -100.0
	for property in ["note_fly_time", "alice_step_time"]: director.set(property, 0.2)
	director.sink_time = 0.6
	director.ending_fade_out = 0.3
	root.add_child(scene)
	current_scene = scene
	# 用 id 判断是否换了场景（lambda 直接捕获 scene 的话，场景释放后会报错）
	var prologue_id := scene.get_instance_id()
	await frames(10)
	var level: Node = director.level
	var alice: Node = director.alice
	var hole_talk: Node = director.hole.get_node("Interactable")
	var note: Node3D = director.note

	check(director.hole.position.distance_to(level.route[-1]) < 0.01, "兔子洞交互点在路线终点")
	check(not note.visible, "开始时音符隐藏")

	# 解谜之前：走到洞口按 F 无效
	alice.global_position = level.route[-1] + Vector3(0, 0.06, 0.6)
	await frames(10)
	check(hole_talk.player_in_range and not hole_talk.enabled and not hole_talk.get_node("Prompt").visible, "解谜之前洞口没有交互提示")
	await press("talk")
	check(not manager.is_active() and state.can_control(), "解谜之前按 F 无效")

	# 模拟解谜完成后的状态
	state.add_item("note_a")
	state.save_puzzle_result("watch", [3, 1, 0, 2])
	state.set_flag("puzzle_watch_done")
	state.set_quest("QUEST_PRO_APPROACH_HOLE")
	director.enable_hole()
	await frames(2)
	check(hole_talk.get_node("Prompt").visible and hole_talk.get_node("Prompt").text == "[F] 调查兔子洞", "解谜后洞口显示 [F] 调查兔子洞")

	# F → 独白
	await press("talk")
	check(manager._current_id == "prologue_note_hole", "按 F 后爱丽丝独白")
	check(not state.can_control(), "结尾演出锁定操作")
	while manager.is_active():
		manager.box.finish_typing()
		manager.advance()

	# 音符飞出并变大，落在洞口
	check(await wait_until(func(): return note.visible), "音符从爱丽丝身上飞出")
	check(note.scale.x < 0.6, "音符刚飞出时很小")
	var landing: Vector3 = level.route[-1] + director.note_landing_offset
	check(await wait_until(func(): return note.position.distance_to(landing) < 0.01), "音符落在洞口")
	check(await wait_until(func(): return is_equal_approx(note.scale.x, 1.0)), "音符落地时变成正常大小")

	# 爱丽丝跳上音符，然后一起下沉
	check(await wait_until(func(): return Vector2(alice.position.x, alice.position.z).distance_to(Vector2(landing.x, landing.z)) < 0.01), "爱丽丝跳上音符")
	check(await wait_until(func(): return state.has_flag("prologue_finished")), "记录序章完成")
	var top_y: float = alice.position.y
	await frames(15)
	check(alice.position.y < top_y - 0.05 and note.position.y < landing.y - 0.05, "音符带着爱丽丝下沉")
	check(not state.can_control(), "下沉期间仍不能操作")

	# 淡出并进入第一章
	check(await wait_until(func(): return current_scene != null and current_scene.get_instance_id() != prologue_id), "进入下一章")
	await frames(10)
	check(not manager.is_active(), "换场景后没有残留的对话（序章导演的协程已停止）")
	check(current_scene.scene_file_path == "res://scenes/chapters/chapter1/Chapter1.tscn", "进入第一章场景")
	check(music.current_id == "", "背景音乐已停止")
	check(state.can_control(), "进入第一章后没有残留的操作锁（残留：%s）" % str(state._control_locks.keys()))
	check(state.has_item("note_a") and state.puzzle_results.get("watch") == [3, 1, 0, 2], "背包与解谜结果跨场景保留")
	check(current_scene.get_node("Center/Box/Title").text == "第一章　音律大厅", "第一章标题来自字符串表")
	check(await wait_until(func(): return fader.is_clear()), "第一章淡入")

	state.reset()
	print("Prologue ending: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
