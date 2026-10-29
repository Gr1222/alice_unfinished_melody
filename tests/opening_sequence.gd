extends SceneTree
## 第 3 步验证：淡入淡出、音乐交叉淡入淡出、开场剧情顺序。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

## 等待条件成立，最多 max_frames 帧。
func wait_until(condition: Callable, max_frames := 600) -> bool:
	for i in range(max_frames):
		if condition.call(): return true
		await process_frame
	return false

func finish_dialogue(manager: Node) -> void:
	while manager.is_active():
		manager.box.finish_typing()
		manager.advance()

func run() -> void:
	var fader: Node = root.get_node("Fader")
	var music: Node = root.get_node("Music")
	var manager: Node = root.get_node("DialogueManager")
	var state: Node = root.get_node("GameState")
	state.reset()

	# Fader
	fader.set_black(true)
	check(fader.is_black(), "set_black 立即变黑")
	await fader.fade_in(0.1)
	check(fader.is_clear(), "fade_in 结束后完全透明")
	await fader.fade_out(0.1)
	check(fader.is_black(), "fade_out 结束后完全变黑")
	fader.set_black(false)

	# Music
	check(music.tracks.has("forest") and music.tracks.has("prologue_sleep"), "audio.json 曲目已加载")
	check(not music.tracks.has("_note"), "备注 key 被忽略")
	for id: String in music.tracks:
		check(ResourceLoader.exists(music.tracks[id]), "曲目文件存在：%s" % id)
	music.play("forest", 0.0)
	check(music.current_id == "forest", "播放森林音乐")
	var player: AudioStreamPlayer = music._players[music._active]
	music.play("prologue_sleep", 0.0)
	check(music._players[music._active] == player, "同一文件的不同 id 不会重新开始播放")
	music.stop(0.0)
	check(music.current_id == "", "停止音乐")

	# 开场剧情（缩短时间）
	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	for property in ["opening_fade_in", "sleep_fade_out", "sleep_hold", "wake_fade_in", "pan_time", "return_time"]:
		director.set(property, 0.05)
	director.rabbit_speed = 40.0
	var finished := [false]
	var intro_done := [false]
	director.opening_finished.connect(func(): finished[0] = true)
	director.intro_finished.connect(func(): intro_done[0] = true)
	root.add_child(scene)
	check(fader.is_black() and not state.can_control(), "开场从黑屏开始，且锁定操作")
	var sister: Node3D = director.sister
	check(sister.visible and sister.position.distance_to(director.alice.position) < 1.5, "姐姐在爱丽丝身边")
	check(await wait_until(func(): return manager._current_id == "prologue_sister"), "淡入后开始与姐姐对话")
	check(fader.is_clear(), "对话时画面已变亮")
	finish_dialogue(manager)
	check(await wait_until(func(): return music.current_id == "prologue_sleep"), "变暗后播放入睡音乐")
	check(fader.is_black() and not sister.visible, "黑屏期间姐姐消失")
	check(await wait_until(func(): return manager._current_id == "prologue_wake"), "变亮后爱丽丝独白")
	check(fader.is_clear(), "独白时画面已变亮")
	check(not state.can_control(), "独白期间仍锁定操作")
	finish_dialogue(manager)
	check(await wait_until(func(): return finished[0]), "开场结束信号")
	check(state.has_flag("prologue_opening_done"), "开场结束后记录标记")
	check(music.current_id == "forest", "开场后切换为森林音乐")
	check(not state.can_control(), "开场后接兔子出场，仍锁定操作")

	# 兔子出场：镜头平移 → 兔子出现自言自语 → 跑出画面 → 镜头回到爱丽丝 → 爱丽丝独白。
	var camera: CameraRig = director.camera
	var rabbit: Node3D = director.rabbit
	var level: ForestLevel = director.level
	check(await wait_until(func(): return manager._current_id == "prologue_rabbit_pass"), "镜头平移后兔子自言自语")
	var pan_target: Vector3 = director.alice.position + camera.screen_right() * director.pan_distance
	check(not camera.following and camera.focus.distance_to(pan_target) < 0.05, "镜头向屏幕右侧平移")
	check(rabbit.visible, "兔子出现")
	check(manager.box.name_label.text == "？？？", "爱丽丝还不知道兔子的名字")
	var appear_point: Vector3 = rabbit.position
	var screen_x: float = camera.unproject_position(appear_point).x
	check(screen_x > 640, "兔子出现在屏幕右侧（x=%d）" % screen_x)
	finish_dialogue(manager)
	check(await wait_until(func(): return rabbit.position.distance_to(appear_point) > 1.0 and rabbit.visible), "兔子开始奔跑")
	check(rabbit.placeholder.flip_h, "兔子向屏幕右侧跑时贴图翻转（原图朝左）")
	check(await wait_until(func(): return not rabbit.visible), "兔子跑出后消失")
	check(not director.is_on_screen(rabbit.position), "兔子消失时已离开画面")
	check(await wait_until(func(): return manager._current_id == "prologue_alice_curious"), "镜头返回后爱丽丝独白")
	check(camera.following and camera.focus.distance_to(director.alice.position) < 0.05, "镜头回到爱丽丝并恢复跟随")
	finish_dialogue(manager)
	check(await wait_until(func(): return intro_done[0]), "序章开头结束信号")
	check(state.can_control() and state.has_flag("prologue_rabbit_seen"), "兔子出场后恢复操作并记录标记")

	# CameraRig：跟随目标移动
	director.alice.position += Vector3(1, 0, 0)
	check(await wait_until(func(): return camera.focus.distance_to(director.alice.position) < 0.05), "镜头平滑跟随目标")
	scene.queue_free()

	# 跳过开场（开发用）
	state.reset()
	var skipped: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	skipped.get_node("PrologueDirector").skip_opening = true
	root.add_child(skipped)
	check(state.can_control() and not manager.is_active() and state.has_flag("prologue_rabbit_seen"), "skip_opening 直接进入探索")
	var skipped_director: Node = skipped.get_node("PrologueDirector")
	var skipped_rabbit: Node3D = skipped.get_node("Actors/WhiteRabbit")
	check(not skipped.get_node("Actors/Sister").visible, "跳过时姐姐不显示")
	check(skipped_rabbit.visible and skipped_rabbit.position.distance_to(skipped_director.level.point_on_route(skipped_director.rabbit_roots_progress())) < 0.01, "跳过时兔子直接在树根处等待")
	state.reset()
	music.stop(0.0)
	skipped.queue_free()
	await process_frame
	print("Opening sequence: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
