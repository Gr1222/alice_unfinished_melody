extends SceneTree
## 第 8 步验证：解谜数据、占位音频、多音轨播放器、完整解谜流程（试听 → 切开掉落 → 试听/拖拽/重置 → 确认）、
## 结束后的道具弹窗与结果保存。
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

## 把片段拖到下方音轨上。
func drag_to_lane(puzzle: Node, segment: Node) -> void:
	var lane: Rect2 = puzzle.item_lane_rect()
	puzzle.begin_drag(segment, segment.global_position)
	puzzle.drag_to(lane.get_center())
	puzzle.end_drag(lane.get_center())
	# 放入有 0.2 秒的滑动动画，多等一会儿
	await frames(30)

func run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset()

	# 解谜数据：切点从 0 开始到 duration 结束、严格递增、切成 3~5 段；道具存在
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles/watch.json"))
	var cuts: Array = config.cuts
	check(is_equal_approx(float(cuts[0]), 0.0) and is_equal_approx(float(cuts[-1]), float(config.duration)), "切点从 0 到音轨长度")
	var increasing := true
	for i in range(1, cuts.size()): increasing = increasing and float(cuts[i]) > float(cuts[i - 1])
	check(increasing, "切点严格递增")
	check(cuts.size() - 1 >= 3 and cuts.size() - 1 <= 5, "切成 3~5 段（当前 %d 段）" % (cuts.size() - 1))
	check(ItemDatabase.has(config.consume_item) and ItemDatabase.has(config.reward_item), "消耗与奖励道具存在")

	# 占位音频
	var piano: AudioStreamWAV = ToneGenerator.piano(config.placeholder.melody_notes, 0.5, 8.0)
	var ticks: AudioStreamWAV = ToneGenerator.ticks(8.0, 0.5, config.placeholder.bell_notes)
	check(absf(piano.get_length() - 8.0) < 0.01 and absf(ticks.get_length() - 8.0) < 0.01, "占位音频长度 = 8 秒")
	var silent := true
	for i in range(0, piano.data.size(), 2000):
		if piano.data[i] != 0: silent = false
	check(not silent, "占位钢琴不是静音")

	# TrackSequencer：按顺序播放多个时间段
	var sequencer := TrackSequencer.new()
	root.add_child(sequencer)
	sequencer.time_scale = 20.0
	var done := [false]
	sequencer.finished.connect(func(): done[0] = true)
	sequencer.play([{"id": "a", "stream": piano, "ranges": [Vector2(0, 8)]}, {"id": "b", "stream": ticks, "ranges": [Vector2(6, 8), Vector2(0, 2)]}])
	check(sequencer.playing and is_equal_approx(sequencer.duration, 8.0), "多音轨总长取最长音轨")
	check(await wait_until(func(): return done[0], 300), "播放结束发出 finished")
	sequencer.play([{"id": "a", "stream": piano, "ranges": [Vector2(0, 8)]}])
	sequencer.stop()
	await frames(5)
	check(not sequencer.playing, "stop() 停止播放")
	sequencer.queue_free()

	# 回归测试：片段掉落后第一次被抓取、放入音轨，之后不能跳回出生点。
	# （冻结的刚体只改节点位置时，物理引擎会保留旧位置并把节点拉回去。）
	var standalone: Node = load("res://scenes/puzzles/TuningPuzzle.tscn").instantiate()
	standalone.time_scale = 3.0
	root.add_child(standalone)
	standalone.run()
	check(await wait_until(func(): return standalone.interactive, 900), "独立解谜进入可操作状态")
	for i in range(40): await process_frame
	var last: Node = standalone.segments[-1]
	await drag_to_lane(standalone, last)
	var expected_x: float = standalone.LANE_X + last.size.x * 0.5
	check(absf(last.global_position.x - expected_x) < 1.0, "第一次放入的片段停在音轨最左边，不会跳回出生点（x=%.1f，应为 %.1f）" % [last.global_position.x, expected_x])
	standalone.queue_free()
	await process_frame
	state.reset()

	# 完整流程（通过导演，与游戏中相同）
	var scene: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	var director: Node = scene.get_node("PrologueDirector")
	director.skip_opening = true
	director.puzzle_time_scale = 8.0
	root.add_child(scene)
	await frames(5)
	state.add_item("watch")
	state.unlock_inventory()
	state.set_flag("prologue_rabbit_talked")
	var inventory: Node = scene.get_node("HUD/Inventory")
	var popup: Node = scene.get_node("HUD/ItemPopup")
	check(root.get_node("Music").current_id == "forest", "解谜前正在播放森林音乐")
	inventory.open()
	inventory.tune_button.pressed.emit()
	await process_frame
	var puzzle: Node = scene.get_node_or_null("TuningPuzzle")
	check(puzzle != null, "点击【调律】进入解谜")
	check(not state.can_control(), "解谜期间锁定操作")
	var music: Node = root.get_node("Music")
	check(music.current_id == "", "进入解谜时停止背景音乐")

	# 开头试听：不能操作，键盘输入被吞掉（无法退出）
	check(await wait_until(func(): return puzzle.sequencer.playing), "开头完整播放两条音轨")
	check(not puzzle.interactive and puzzle.segments.is_empty(), "试听期间不能操作，音轨还未切开")
	await press("pause")
	await press("inventory")
	check(is_instance_valid(puzzle) and puzzle.is_inside_tree() and not inventory.is_open(), "Esc / B 无法退出解谜")

	# 切开并掉落
	check(await wait_until(func(): return puzzle.interactive), "试听结束后可以操作")
	var segments: Array = puzzle.segments
	check(segments.size() == cuts.size() - 1, "下方音轨切成 %d 段" % (cuts.size() - 1))
	var total_px := 0.0
	for segment in segments: total_px += segment.size.x
	check(absf(total_px - puzzle.LANE_WIDTH) < 0.5, "片段总长 = 音轨长度")
	check(not is_equal_approx(segments[0].size.x, segments[1].size.x), "片段长度可以不等")
	await frames(90)
	var all_in_tray := true
	for segment in segments:
		var p: Vector2 = segment.global_position
		all_in_tray = all_in_tray and p.y > puzzle.ITEM_LANE_Y + puzzle.LANE_HEIGHT and p.x > puzzle.TRAY_LEFT and p.x < puzzle.TRAY_RIGHT and p.y < puzzle.TRAY_FLOOR
	check(all_in_tray, "片段掉落并停在托盘里（没有飞出边框）")

	# 点击试听（不放入）
	var first: Node = segments[0]
	puzzle.begin_drag(first, first.global_position)
	puzzle.end_drag(first.global_position)
	check(first.highlighted and puzzle.sequencer.playing and not first.placed, "点击片段单独试听，不会放入音轨")
	await frames(5)
	check(not first.freeze, "试听后片段回到物理中")

	# 拖到别处松手：不放入
	puzzle.begin_drag(segments[1], segments[1].global_position)
	puzzle.drag_to(Vector2(640, 600))
	puzzle.end_drag(Vector2(640, 600))
	check(puzzle.placed.is_empty(), "拖到音轨以外松手不会放入")

	# 拖入音轨：按放入顺序首尾相接
	await drag_to_lane(puzzle, segments[2])
	check(puzzle.placed == [segments[2]], "拖到音轨上放入")
	check(absf(segments[2].global_position.x - (puzzle.LANE_X + segments[2].size.x * 0.5)) < 1.0, "第一个放入的片段排在最左边（x=%.2f，应为 %.2f）" % [segments[2].global_position.x, puzzle.LANE_X + segments[2].size.x * 0.5])
	check(not puzzle.confirm_button.visible, "未全部放入时不显示【确认】")
	await drag_to_lane(puzzle, segments[0])
	check(absf(segments[0].global_position.x - (puzzle.LANE_X + segments[2].size.x + segments[0].size.x * 0.5)) < 1.0, "第二个片段紧接在第一个后面")

	# 重置
	puzzle.reset_button.pressed.emit()
	await frames(3)
	check(puzzle.placed.is_empty() and not segments[2].placed and not segments[2].freeze, "【重置】后所有片段回到托盘")

	# 自由排序（与原顺序不同）。重置后片段还在下落时就开始抓取：
	# 回归测试——冻结的刚体只改节点位置会被物理引擎拉回出生点。
	var order := [3, 1, 0, 2]
	for i in order: await drag_to_lane(puzzle, segments[i])
	check(puzzle.arrangement() == order, "排列结果按放入顺序记录")
	await frames(60)
	var slot_x: float = puzzle.LANE_X
	var slots_ok := true
	var slot_report: PackedStringArray = []
	for i in order:
		var expected: float = slot_x + segments[i].size.x * 0.5
		slots_ok = slots_ok and absf(segments[i].global_position.x - expected) < 1.0 and absf(segments[i].global_position.y - (puzzle.ITEM_LANE_Y + puzzle.LANE_HEIGHT * 0.5)) < 1.0
		slot_report.append("#%d x=%.1f/%.1f" % [i, segments[i].global_position.x, expected])
		slot_x += segments[i].size.x
	check(slots_ok, "全部片段停在各自位置，首尾相接不重叠（%s）" % ", ".join(slot_report))
	check(puzzle.confirm_button.visible and puzzle.hint_label.text.contains("确认"), "全部放入后出现【确认】")

	# 确认 → 播放玩家的旋律 → 结束动画 → 弹窗
	puzzle.confirm_button.pressed.emit()
	check(not puzzle.interactive and not puzzle.confirm_button.visible, "确认后不能再操作")
	check(await wait_until(func(): return scene.get_node_or_null("TuningPuzzle") == null, 1500), "播放与结束动画后解谜关闭")
	check(await wait_until(func(): return popup.visible), "出现弹窗")
	check(popup.title_label.text == "失去道具" and popup.item_label.text == "怀表", "弹窗【失去道具 怀表】")
	check(not state.has_item("watch"), "怀表已从背包移除")
	await press("dialogue_next")
	check(await wait_until(func(): return popup.visible and popup.title_label.text == "获得道具"), "接着弹窗【获得道具】")
	check(popup.item_label.text == "音符 A" and state.has_item("note_a"), "获得音符 A")
	await press("dialogue_next")
	check(await wait_until(func(): return state.can_control()), "弹窗结束后恢复操作")
	check(state.puzzle_results.get("watch") == order, "玩家的排列已保存到 GameState（后期回放用）")
	check(state.quest_key == "QUEST_PRO_APPROACH_HOLE", "任务变为【靠近兔子洞】")
	check(music.current_id == "forest", "解谜结束后恢复森林背景音乐")

	# 不能重复解谜
	root.get_node("EventBus").tune_requested.emit("watch")
	await process_frame
	check(scene.get_node_or_null("TuningPuzzle") == null, "解谜完成后不会再次进入")

	state.reset()
	scene.queue_free()
	await process_frame
	print("Tuning puzzle: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
