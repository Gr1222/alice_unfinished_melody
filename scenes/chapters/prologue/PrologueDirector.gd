extends Node
## 序章导演：用 await 按顺序编排剧情，各系统（对话、淡入淡出、音乐、镜头）只通过接口调用。
## 每段剧情写成一个函数，后续步骤继续往下加。

signal opening_finished
signal intro_finished
signal move_tutorial_finished
signal watch_collected
signal rabbit_talk_finished
signal tuning_finished
signal ending_finished

const LOCK_REASON := "cutscene"
const TUNING_PUZZLE := preload("res://scenes/puzzles/TuningPuzzle.tscn")

@export var level: ForestLevel
@export var camera: CameraRig
@export var alice: Alice3D
@export var sister: Node3D
@export var rabbit: ActorModel
@export var tutorial: TutorialHint
@export var item_popup: ItemPopup
## 地上的怀表（PocketWatch.tscn 实例）。
@export var watch: Node3D
## 兔子洞交互点（子节点 Interactable）与结尾的音符（MusicNote.tscn 实例）。
@export var hole: ActorModel
@export var note: Node3D
## 开发用：跳过开场与兔子出场，直接进入探索。
@export var skip_opening := false
## 开发/测试用：调律解谜的计时倍速（1 = 正常；音频本身不会变快）。
@export var puzzle_time_scale := 1.0

@export_group("新手教程")
## 玩家走够这么多米后，移动教程提示消失。
@export var move_tutorial_distance := 1.5

@export_group("开场时间（秒）")
@export var opening_fade_in := 1.5
@export var sleep_fade_out := 2.0
@export var sleep_hold := 5.0
@export var wake_fade_in := 2.0

@export_group("开场位置")
## 树下位置：距离路线起点的米数（待建模确认开场的树）。
@export var opening_route_distance := 1.6
@export var sister_offset := Vector3(0.7, 0, -0.2)

@export_group("兔子出场")
## 镜头向屏幕右侧平移的距离（米）。
@export var pan_distance := 4.5
@export var pan_time := 2.0
## 兔子出现在路线上第一个落入屏幕此比例右侧的位置（0.7 = 屏幕右侧 30% 区域）。
@export var rabbit_appear_screen_x := 0.7
@export var rabbit_speed := 4.0
@export var rabbit_hop_height := 0.18
@export var return_time := 1.5

@export_group("怀表")
## 怀表在路线上的位置：距离路线起点的米数（在兔子消失的方向上）。
@export var watch_route_distance := 8.0

@export_group("树根处的兔子")
## 兔子在树根处的位置：距离路线终点（兔子洞）的米数。
@export var rabbit_roots_from_end := 1.8
## 爱丽丝沿路线走到离兔子这么多米时，兔子开始自言自语。
@export var rabbit_notice_distance := 5.0
## 兔子自言自语时镜头移到两人中间的时长（秒）。
@export var rabbit_notice_pan_time := 0.8
## 兔子洞口相对路线终点的位置（兔子跳向这里）。
@export var hole_offset := Vector3(0, 0.45, -1.2)
@export var rabbit_jump_time := 0.9
@export var rabbit_jump_height := 0.8

@export_group("结尾（兔子洞）")
## 音符落点：相对路线终点（洞口前）的位置。
@export var note_landing_offset := Vector3(0, 0, -0.2)
@export var note_fly_time := 1.6
@export var note_arc_height := 1.2
## 音符刚飞出时的大小（1 = 落地后的大小）。
@export var note_start_scale := 0.15
## 爱丽丝跳上音符的时长（秒）与弧线高度（米）。
@export var alice_step_time := 0.6
@export var alice_step_height := 0.5
## 音符带着爱丽丝下沉的深度（米）与时长（秒）。
@export var sink_depth := 2.5
@export var sink_time := 3.0
## 下沉过程中，画面与音乐在最后这么多秒内淡出。
@export var ending_fade_out := 2.0
@export_file("*.tscn") var next_scene := "res://scenes/chapters/chapter1/Chapter1.tscn"

func _ready() -> void:
	# 等整个场景（包括排在后面的 HUD）都准备好再开始，否则 UI 节点还没初始化。
	if not owner.is_node_ready(): await owner.ready
	place_actors()
	setup_watch()
	setup_hole()
	EventBus.tune_requested.connect(_on_tune_requested)
	camera.target = alice
	camera.snap_to_target()
	rabbit.hide()
	if skip_opening:
		sister.hide()
		GameState.set_flag("prologue_opening_done")
		GameState.set_flag("prologue_rabbit_seen")
		Music.play("forest", 0.0)
		opening_finished.emit()
		intro_finished.emit()
		start_exploration()
		return
	run_intro()

func place_actors() -> void:
	# 略高于地面，由重力落地，避免一开始卡进地面碰撞。
	alice.position = level.point_on_route(opening_route_distance) + Vector3(0, 0.06, 0)
	sister.position = level.point_on_route(opening_route_distance) + sister_offset
	watch.position = level.point_on_route(watch_route_distance)

## 怀表：第一次靠近时显示 E 拾取教程；拾取后进入 run_watch_pickup。
func setup_watch() -> void:
	var interactable: Interactable = watch.interactable
	interactable.player_entered.connect(_on_watch_approached)
	interactable.interacted.connect(run_watch_pickup, CONNECT_ONE_SHOT)

func _on_watch_approached() -> void:
	if not GameState.has_flag("tutorial_interact_done"):
		tutorial.show_hint("TUTORIAL_INTERACT")

## 拾取怀表 → 弹窗【获得道具 怀表】→ 解锁背包 → 背包教程（打开背包后消失）。
func run_watch_pickup() -> void:
	watch.collect()
	tutorial.hide_hint("TUTORIAL_INTERACT")
	GameState.set_flag("tutorial_interact_done")
	GameState.add_item("watch")
	await item_popup.show_item("watch")
	GameState.unlock_inventory()
	watch_collected.emit()
	tutorial.show_hint("TUTORIAL_INVENTORY")
	await EventBus.inventory_opened
	tutorial.hide_hint("TUTORIAL_INVENTORY")
	GameState.set_flag("tutorial_inventory_done")

## 序章开头：开场 + 兔子出场，全程锁定操作。
func run_intro() -> void:
	GameState.lock_control(LOCK_REASON)
	await run_opening()
	opening_finished.emit()
	await run_rabbit_pass()
	GameState.unlock_control(LOCK_REASON)
	intro_finished.emit()
	start_exploration()

## 探索开始：任务【追上会说话的兔子】+ 移动教程，玩家走够距离后教程消失。
## 同时开始等待玩家走到树根处的兔子（run_rabbit_roots 与移动教程并行）。
func start_exploration() -> void:
	GameState.set_quest("QUEST_PRO_FOLLOW_RABBIT")
	run_rabbit_roots()
	tutorial.show_hint("TUTORIAL_MOVE")
	var start := alice.walked_distance
	while alice.walked_distance - start < move_tutorial_distance:
		if not await next_frame(): return
	tutorial.hide_hint("TUTORIAL_MOVE")
	GameState.set_flag("tutorial_move_done")
	move_tutorial_finished.emit()

## 开场：与姐姐对话 → 变暗并播放音乐 → 姐姐消失 → 变亮 → 爱丽丝独白。
func run_opening() -> void:
	Fader.set_black(true)
	await Fader.fade_in(opening_fade_in)
	await DialogueManager.play("prologue_sister")
	await Fader.fade_out(sleep_fade_out)
	Music.play("prologue_sleep", 1.0)
	sister.hide()
	await get_tree().create_timer(sleep_hold).timeout
	await Fader.fade_in(wake_fade_in)
	await DialogueManager.play("prologue_wake")
	Music.play("forest")
	GameState.set_flag("prologue_opening_done")

## 兔子出场：镜头向屏幕右侧平移 → 兔子在屏幕右侧出现并自言自语 → 沿路线跑出画面 → 镜头回到爱丽丝。
func run_rabbit_pass() -> void:
	await camera.pan_to(alice.position + camera.screen_right() * pan_distance, pan_time)
	var start := find_route_on_screen(level.route_progress(alice.position), rabbit_appear_screen_x)
	rabbit.position = level.point_on_route(start)
	rabbit.show()
	await DialogueManager.play("prologue_rabbit_pass")
	if not await run_off_screen(rabbit, start, rabbit_speed, rabbit_hop_height): return
	rabbit.hide()
	await camera.return_to_target(return_time)
	await DialogueManager.play("prologue_alice_curious")
	GameState.set_flag("prologue_rabbit_seen")

## 从 from 米开始沿路线向前找，返回第一个投影在屏幕 screen_x 比例右侧（且在画面内）的位置。
func find_route_on_screen(from: float, screen_x: float) -> float:
	var size := get_viewport().get_visible_rect().size
	var distance := from
	while distance < level.route_length():
		var point := level.point_on_route(distance)
		if is_on_screen(point) and camera.unproject_position(point).x >= size.x * screen_x:
			return distance
		distance += 0.1
	return from

func is_on_screen(point: Vector3) -> bool:
	return not camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(camera.unproject_position(point))

## 让角色沿路线向前跑，直到离开画面（或到达路线终点），带跳跃起伏；按屏幕方向自动翻转贴图。
## 朝向交给 ActorModel.face_toward（占位贴图按镜头翻转，正式模型转身）。返回 false 表示导演已离开场景。
func run_off_screen(actor: ActorModel, from: float, speed: float, hop_height := 0.0) -> bool:
	var distance := from
	# 用头顶判断：整个身体都离开画面后才算跑出。
	var head := Vector3(0, 1.3, 0)
	while distance < level.route_length() and (is_on_screen(actor.position) or is_on_screen(actor.position + head)):
		if not await next_frame(): return false
		var previous := level.point_on_route(distance)
		distance = minf(distance + speed * get_process_delta_time(), level.route_length())
		var point := level.point_on_route(distance)
		actor.position = point + Vector3(0, absf(sin(distance * 3.0)) * hop_height, 0)
		actor.face_toward(point - previous)
		actor.play_state("walk")
	return true

func rabbit_roots_progress() -> float:
	return level.route_length() - rabbit_roots_from_end

func alice_progress() -> float:
	return level.route_progress(alice.global_position)

## 等爱丽丝沿路线走到 distance 米。返回 false 表示导演已离开场景。
func wait_until_progress(distance: float) -> bool:
	while alice_progress() < distance:
		if not await next_frame(): return false
	return true

## 等一帧。导演已离开场景树（正在换场景）时返回 false，调用方必须立刻 return，
## 否则后面的剧情会在被销毁的场景里继续执行（曾导致第一章残留对话锁）。
func next_frame() -> bool:
	if not is_inside_tree(): return false
	await get_tree().process_frame
	return is_inside_tree()

## 安全网：离开场景时释放自己的操作锁（GameState 跨场景保存）。
func _exit_tree() -> void:
	GameState.unlock_control(LOCK_REASON)

## 让兔子面向爱丽丝。
func face_rabbit_to_alice() -> void:
	rabbit.face_toward(alice.global_position - rabbit.global_position)
	rabbit.play_state("idle")

## 树根处的兔子：
## 带着怀表靠近 → 兔子自言自语（镜头移到两人中间）→ F 对话教程 → 对话 → 兔子跳进洞
## → 爱丽丝想研究怀表 → 任务【研究一下怀表】+ 调律教程（点击【调律】后结束）。
## 没拿怀表就走到这里时，爱丽丝提醒自己回去看看，等她拿到怀表再继续。
func run_rabbit_roots() -> void:
	rabbit.position = level.point_on_route(rabbit_roots_progress())
	rabbit.show()
	face_rabbit_to_alice()
	var notice_at := rabbit_roots_progress() - rabbit_notice_distance
	while true:
		if not await wait_until_progress(notice_at): return
		if GameState.has_item("watch"): break
		await DialogueManager.play("prologue_no_watch")
		# 等玩家往回走一段，避免站在原地反复触发。
		while alice_progress() > notice_at - 1.0:
			if not await next_frame(): return

	GameState.lock_control(LOCK_REASON)
	var middle := (alice.global_position + rabbit.global_position) * 0.5
	middle.y = 0
	await camera.pan_to(middle, rabbit_notice_pan_time)
	await DialogueManager.play("prologue_rabbit_roots")
	await camera.return_to_target(rabbit_notice_pan_time)
	GameState.unlock_control(LOCK_REASON)

	var talk: Interactable = rabbit.get_node("Interactable")
	talk.enabled = true
	if not talk.player_in_range: await talk.player_entered
	tutorial.show_hint("TUTORIAL_TALK")
	await talk.interacted
	talk.enabled = false
	tutorial.hide_hint("TUTORIAL_TALK")
	GameState.set_flag("tutorial_talk_done")

	GameState.lock_control(LOCK_REASON)
	face_rabbit_to_alice()
	await DialogueManager.play("prologue_rabbit_talk")
	if not await rabbit_jump_into_hole(): return
	GameState.set_flag("prologue_rabbit_talked")
	await DialogueManager.play("prologue_alice_study")
	GameState.unlock_control(LOCK_REASON)
	GameState.set_quest("QUEST_PRO_STUDY_WATCH")
	tutorial.show_hint("TUTORIAL_TUNE")
	rabbit_talk_finished.emit()
	await EventBus.tune_requested
	tutorial.hide_hint("TUTORIAL_TUNE")

## 兔子沿抛物线跳进洞口，落下时缩小后消失。返回 false 表示导演已离开场景。
func rabbit_jump_into_hole() -> bool:
	var from := rabbit.position
	var to := level.route[-1] + hole_offset
	rabbit.face_toward(to - from)
	rabbit.play_state("jump")
	var t := 0.0
	while t < 1.0:
		if not await next_frame(): return false
		t = minf(t + get_process_delta_time() / rabbit_jump_time, 1.0)
		rabbit.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * rabbit_jump_height, 0)
		rabbit.scale = Vector3.ONE * lerpf(1.0, 0.3, clampf((t - 0.6) / 0.4, 0.0, 1.0))
	rabbit.hide()
	rabbit.scale = Vector3.ONE
	return true

func _on_tune_requested(item_id: String) -> void:
	if item_id == "watch" and not GameState.has_flag("puzzle_watch_done"):
		run_tuning_puzzle("watch")

## 调律解谜 → 保存玩家的排列 → 弹窗【失去道具 怀表】【获得道具 音符 A】→ 任务【靠近兔子洞】。
## 消耗与奖励的道具来自 data/puzzles/<id>.json 的 consume_item / reward_item。
func run_tuning_puzzle(puzzle_id: String) -> void:
	GameState.lock_control(LOCK_REASON)
	var puzzle: TuningPuzzle = TUNING_PUZZLE.instantiate()
	puzzle.puzzle_id = puzzle_id
	puzzle.time_scale = puzzle_time_scale
	owner.add_child(puzzle)
	var arrangement: Array = await puzzle.run()
	var consume := String(puzzle.config.get("consume_item", ""))
	var reward := String(puzzle.config.get("reward_item", ""))
	puzzle.queue_free()
	GameState.save_puzzle_result(puzzle_id, arrangement)
	GameState.set_flag("puzzle_%s_done" % puzzle_id)
	if not consume.is_empty() and GameState.remove_item(consume):
		await item_popup.show_item(consume, true)
	if not reward.is_empty() and GameState.add_item(reward):
		await item_popup.show_item(reward)
	GameState.unlock_control(LOCK_REASON)
	GameState.set_quest("QUEST_PRO_APPROACH_HOLE")
	enable_hole()
	tuning_finished.emit()

## 兔子洞：放在路线终点，解谜完成后才能按 F 交互。
func setup_hole() -> void:
	hole.position = level.route[-1]
	note.hide()
	hole.get_node("Interactable").interacted.connect(run_ending, CONNECT_ONE_SHOT)
	if GameState.has_flag("puzzle_watch_done"): enable_hole()

func enable_hole() -> void:
	hole.get_node("Interactable").enabled = true

## 结尾：独白 → 音符从爱丽丝身上飞出、逐渐变大、落在洞口 → 爱丽丝跳上音符
## → 音符带着爱丽丝缓缓下沉，画面与音乐淡出 → 进入下一章。
func run_ending() -> void:
	hole.get_node("Interactable").enabled = false
	GameState.lock_control(LOCK_REASON)
	await DialogueManager.play("prologue_note_hole")
	# 演出期间关闭爱丽丝的物理，由演出直接移动她（否则会被地面碰撞挡住，无法下沉）。
	alice.set_physics_process(false)
	alice.update_animation(Vector3.ZERO)
	var landing := level.route[-1] + note_landing_offset
	note.position = alice.position + Vector3(0, 0.9, 0)
	note.scale = Vector3.ONE * note_start_scale
	note.show()
	await arc_move(note, note.position, landing, note_fly_time, note_arc_height, note_start_scale, 1.0)
	note.hide_symbol(alice_step_time * 0.5)
	await arc_move(alice, alice.position, landing + Vector3(0, 0.1, 0), alice_step_time, alice_step_height)
	GameState.set_flag("prologue_finished")
	var sink := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sink.tween_property(note, "position:y", note.position.y - sink_depth, sink_time)
	sink.tween_property(alice, "position:y", alice.position.y - sink_depth, sink_time)
	await get_tree().create_timer(maxf(0.0, sink_time - ending_fade_out)).timeout
	Music.stop(ending_fade_out)
	await Fader.fade_out(ending_fade_out)
	# 操作锁保存在 GameState（跨场景），换场景前必须解锁，否则下一章无法操作。
	GameState.unlock_control(LOCK_REASON)
	ending_finished.emit()
	get_tree().change_scene_to_file(next_scene)

## 沿抛物线移动 Node3D（可同时缩放）。
func arc_move(node: Node3D, from: Vector3, to: Vector3, duration: float, height: float, from_scale := -1.0, to_scale := -1.0) -> void:
	var step := func(t: float) -> void:
		node.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * height, 0)
		if from_scale >= 0.0: node.scale = Vector3.ONE * lerpf(from_scale, to_scale, t)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(step, 0.0, 1.0, duration)
	await tween.finished
