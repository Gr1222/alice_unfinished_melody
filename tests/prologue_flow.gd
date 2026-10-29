extends SceneTree

var failed := 0
var passed := 0
var game: Node
var progress: Node

func _initialize() -> void:
	call_deferred("execute")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func drain() -> void:
	var remaining := 30
	while not game.lines.is_empty() and remaining > 0:
		game.advance()
		remaining -= 1
	check(game.lines.is_empty(), "dialogue terminates")

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	game._input(event)

func execute() -> void:
	if run_flow() != true:
		failed += 1
		push_error("Flow did not complete (runtime error)")
	if failed == 0 and "--screenshots" in OS.get_cmdline_user_args():
		await capture_previews()
	print("Results: %d passed, %d failed" % [passed, failed])
	if is_instance_valid(game): game.queue_free()
	quit(1 if failed > 0 else 0)

func run_flow() -> bool:
	progress = root.get_node("MelodyProgress")
	progress.reset()
	game = load("res://scenes/prologue/Prologue.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var opening_lines: Array = game.lines.duplicate()
	key_event(KEY_SPACE,true)
	check(game.lines==opening_lines,"space does not advance dialogue")
	key_event(KEY_SPACE,false)
	drain()
	key_event(KEY_E, false)
	check(game.hold == 0.0 and not game.investigated, "dialogue release consumed")
	game.player.x = 275
	game._process(0.02)
	check(game.running, "rabbit crossing starts")
	game._process(2.0)
	drain()
	game.player = game.WATCH
	game.interact()
	check(game.stage == 2, "watch pickup")
	drain()
	game.player = Vector2(680, 350)
	game._process(0.02)
	drain()
	game._process(1.0)
	drain()
	check(not game.jumping and game.stage == 3, "rabbit leaves before investigation")
	game.player = game.RIM
	game.interact()
	check(game.investigated and not game.path_found, "broken footprints investigated")
	drain()
	key_event(KEY_E, true)
	game._process(0.4)
	check(game.past and not game.seen, "past reveals gradually")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.past and game.hold == 0 and game.observation == 0, "focus clears unfinished observation")
	key_event(KEY_E, false)
	check(game.lines.is_empty(), "focus-loss release cannot trigger interaction")
	key_event(KEY_E, true)
	game._process(2.0)
	check(game.past and game.seen and not game.path_found, "observation reveals evidence without creating a path")
	key_event(KEY_E, false)
	check(not game.past and not game.lines.is_empty(), "release returns to present and reflects on echo")
	drain()
	key_event(KEY_E, true)
	game._process(0.5)
	key_event(KEY_ESCAPE, true)
	check(game.paused and not game.past and game.hold == 0, "pause resets watch")
	key_event(KEY_ESCAPE, true)
	game.player = game.ROOTS
	game.interact()
	check(game.path_found and not game.ending, "roots reveal existing path without auto-entry")
	drain()
	game.interact()
	check(game.lines.is_empty(), "path investigation does not repeat reward dialogue")
	game.player = game.ENTRY
	game.open_melody()
	check(game.melody_puzzle.active and not game.ending, "music puzzle is a separate optional interaction")
	game.melody_puzzle.choose("glimmer")
	check(game.melody_puzzle.arrangement.is_empty(), "uncollected fragment cannot be placed")
	game.melody_puzzle.submit()
	check(not progress.is_restored("prologue"), "missing fragments cannot complete phrase")
	game.melody_puzzle.close()
	collect_ground_fragments()
	game.player = game.ENTRY
	check(game.melody_puzzle.active, "all fragments naturally invite arrangement after path discovery")
	var stopped_at: Vector2 = game.player
	game._process(0.5)
	check(game.player == stopped_at, "music panel locks exploration")
	var puzzle: Node = game.melody_puzzle
	puzzle.choose("rest")
	puzzle.choose("rest")
	check(puzzle.arrangement.size() == 1, "same fragment cannot fill two slots")
	puzzle.choose("echo")
	puzzle.choose("glimmer")
	puzzle.submit()
	check(not progress.is_restored("prologue") and puzzle.active, "wrong order gives retry without losing fragments")
	puzzle.undo()
	puzzle.undo()
	puzzle.undo()
	check(puzzle.arrangement.is_empty(), "undo permits retry")
	puzzle.place_fragment("rest", 2)
	check(puzzle.arrangement == ["", "", "rest"], "drop into third slot preserves its exact position")
	puzzle.choose("glimmer")
	puzzle.choose("echo")
	check(puzzle.arrangement == game.melody_phrase.solution, "click placement fills earlier empty slots")
	puzzle.undo()
	puzzle.undo()
	puzzle.undo()
	puzzle.place_fragment("rest", 0)
	puzzle.place_fragment("glimmer", 1)
	puzzle.place_fragment("echo", 2)
	puzzle.select_slot(0)
	puzzle.select_slot(1)
	puzzle.select_slot(1)
	puzzle.select_slot(2)
	check(puzzle.arrangement == game.melody_phrase.solution, "clicking two slots swaps fragments")
	puzzle.remove_fragment(1)
	check(puzzle.arrangement.size() == 2, "right-click action returns a fragment to tray")
	var slot: Button = puzzle.layout.get_node("Slots").get_child(1)
	check(not slot._can_drop_data(Vector2.ZERO, {"fragment": "echo", "puzzle": -1}), "foreign drag data rejected")
	var drag_data := {"fragment": "echo", "puzzle": puzzle.get_instance_id()}
	check(slot._can_drop_data(Vector2.ZERO, drag_data), "owned fragment accepted by drop slot")
	slot._drop_data(Vector2.ZERO, drag_data)
	check(puzzle.arrangement == ["glimmer", "echo"], "drop replaces slot and returns displaced fragment")
	puzzle.close()
	game.open_melody()
	check(puzzle.arrangement == ["glimmer", "echo"], "closing and reopening preserves draft")
	puzzle.choose("glimmer")
	puzzle.choose("echo")
	puzzle.choose("rest")
	puzzle.submit()
	check(progress.is_restored("prologue") and progress.restored.size() == 1, "prologue repairs only one part of the grand melody")
	puzzle.submit()
	check(progress.restored.size() == 1, "repeat completion does not duplicate cumulative phrase")
	puzzle.listen_restored()
	check(not puzzle.audio_player.playing, "missing audio is a supported silent placeholder")
	puzzle.close()
	check(game.melody_response_played and not game.lines.is_empty(), "first completion causes narrative response rather than unlocking a gate")
	drain()
	game.open_melody()
	puzzle.submit()
	puzzle.close()
	check(game.lines.is_empty(), "replaying completed melody does not repeat story")
	game.interact()
	check(game.ending, "explicit entry starts transition")
	game._process(2.0)
	check(game.chapter and not game.past and game.hold == 0, "chapter transition resets watch")
	game.queue_free()
	progress.reset()
	game = load("res://scenes/prologue/Prologue.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	drain()
	game.stage = 3
	game.player = game.ROOTS
	game._process(0.02)
	check(game.player.x > 800, "no old invisible gate boundary")
	game.interact()
	check(game.path_found and not game.seen and not game.investigated, "direct exploration is a valid alternative")
	drain()
	collect_ground_fragments()
	game.player = game.ENTRY
	game.interact()
	for id in game.melody_phrase.solution: game.melody_puzzle.choose(id)
	game.melody_puzzle.submit()
	game.melody_puzzle.close()
	drain()
	game.interact()
	game._process(2.0)
	check(game.chapter, "alternative route reaches chapter")
	key_event(KEY_M, true)
	check(game.melody_puzzle.active and progress.is_restored("prologue"), "chapter retains melody and opens collection")
	game.melody_puzzle.close()
	key_event(KEY_E, true)
	game._process(2.0)
	check(not game.past, "watch cannot be used after prologue")
	# 模拟未来章节贡献一段，不实现或杜撰未来关卡。
	var next_phrase: Resource = game.melody_phrase.duplicate(true)
	next_phrase.phrase_id = "chapter_one_test"
	next_phrase.display_name = "测试用下一章乐句"
	next_phrase.sequence_index = 1
	for id in next_phrase.fragment_ids: progress.collect(next_phrase.phrase_id, id)
	check(progress.restore_phrase(next_phrase, next_phrase.solution), "same system accepts a later chapter phrase")
	check(progress.restored.size() == 2 and progress.restored[0].phrase_id == "prologue", "grand melody appends chapter phrases in order")
	progress.restored.pop_back()
	progress.collected.erase("chapter_one_test")
	game.queue_free()
	progress.reset()
	game = load("res://scenes/prologue/Prologue.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	drain()
	game.stage = 3
	game.player = game.ROOTS
	game.interact()
	drain()
	game.player = game.ENTRY
	game.interact()
	check(game.ending and not game.melody_puzzle.active and not progress.is_restored("prologue"), "entry never requires collecting or solving music")
	game._process(2.0)
	check(game.chapter and progress.restored.is_empty(), "skip route retains honest unfinished progress")
	return true

func collect_ground_fragments() -> void:
	for position in game.FRAGMENT_POSITIONS:
		game.player = position
		game.interact()
		drain()
	check(progress.has_all(game.melody_phrase), "all three prologue fragments collected")

func capture_previews() -> void:
	game.chapter = false
	game.ending = false
	game.stage = 3
	game.path_found = false
	game.investigated = true
	game.player = game.RIM
	game.fade = 0.0
	game.hold = 0.3
	game._process(1.9)
	DirAccess.make_dir_recursive_absolute("res://output")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-past.png") == OK, "past screenshot saved")
	game.hold = 0.0
	game.past = false
	game._process(0.02)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-present.png") == OK, "present screenshot saved")
	for id in game.melody_phrase.fragment_ids: progress.collect("prologue", id)
	game.open_melody()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-melody.png") == OK, "melody puzzle screenshot saved")
	await test_pointer_drag()
	for code in [KEY_3, KEY_1, KEY_ENTER]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = true
		root.push_input(event)
		await process_frame
	check(progress.is_restored("prologue"), "viewport keyboard input completes dragged arrangement")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-melody-complete.png") == OK, "completed melody screenshot saved")
	game.melody_puzzle.close()
	game._process(0.02)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-melody-response.png") == OK, "story response screenshot saved")
	var art_lines: Array[String] = ["爱丽丝：这段旋律……好像在哪里听过。", "白兔：你怎么会知道后面的旋律？", "森林恢复了安静。"]
	game.say(art_lines)
	check(game.portrait.visible and game.portrait.texture == game.Art.ALICE_PORTRAIT, "Alice dialogue selects supplied portrait")
	check(game.portrait.get_global_rect().end.x < 576, "Alice portrait stays on left")
	var alice_scale: Vector2 = game.portrait.size / game.portrait.texture.get_size()
	check(is_equal_approx(alice_scale.x, alice_scale.y), "Alice preserves original aspect ratio")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/prologue-art-alice.png") == OK, "Alice art screenshot saved")
	game.advance()
	check(game.portrait.visible and game.portrait.texture == game.Art.RABBIT_PORTRAIT, "rabbit dialogue switches supplied portrait")
	check(game.portrait.get_global_rect().position.x > 576, "NPC portrait stays on right")
	var rabbit_scale: Vector2 = game.portrait.size / game.portrait.texture.get_size()
	check(is_equal_approx(rabbit_scale.x, rabbit_scale.y), "NPC preserves original aspect ratio")
	check(game.portrait.get_global_rect().end.y > game.panel.position.y, "full portrait continues beneath dialogue frame")
	check(game.portrait_frame.clip_contents and game.portrait_frame.get_global_rect().end.y <= 674, "lower body cannot spill below dialogue onto controls")
	await RenderingServer.frame_post_draw
	check(game.panel.get_global_rect().end.y <= 674, "textured dialogue panel stays above controls")
	check(root.get_texture().get_image().save_png("res://output/prologue-art-rabbit.png") == OK, "rabbit art screenshot saved")
	game.advance()
	check(not game.portrait.visible, "narration hides speaking portrait")
	game.advance()
	check(not game.portrait.visible and not game.panel.visible, "dialogue close hides portrait and frame")

func test_pointer_drag() -> void:
	var puzzle: Node = game.melody_puzzle
	var source: Control = puzzle.layout.get_node("Fragments").get_child(1)
	var target: Control = puzzle.layout.get_node("Slots").get_child(0)
	var start := source.get_global_rect().get_center()
	var finish := target.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press)
	await process_frame
	var move := InputEventMouseMotion.new()
	move.position = start + Vector2(24, 24)
	move.relative = Vector2(24, 24)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move)
	await process_frame
	check(root.gui_is_dragging(), "real pointer movement starts a Godot GUI drag")
	move = InputEventMouseMotion.new()
	move.position = finish
	move.relative = finish - start - Vector2(24, 24)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = finish
	root.push_input(release)
	await process_frame
	check(puzzle.arrangement == ["glimmer"], "real pointer drop fills first music slot")
