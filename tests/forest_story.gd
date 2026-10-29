extends SceneTree
var passed := 0
var failed := 0
var world
var story
var progress: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:passed += 1
	else:
		failed += 1
		push_error(message)

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	world._input(event)
	if not root.is_input_handled():world._unhandled_key_input(event)

func drain() -> void:
	var safety := 40
	while not story.lines.is_empty() and safety>0:
		story.advance()
		safety -= 1
	world.update_story_objects()

func place(id: String) -> void:
	world.actor.position = world.locations[id]+Vector3(0,.02,0)
	world.actor.velocity = Vector3.ZERO
	world.sync_story_position()

func tap_e() -> void:
	key(KEY_E)
	key(KEY_E,false)

func fresh() -> void:
	if is_instance_valid(world):
		world.free()
	progress.reset()
	world = load("res://scenes/forest/ForestPrologue.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	story = world.story
	world.set_process(false)
	world.set_physics_process(false)
	story.fade = 0
	story.shade.color = Color.TRANSPARENT

func run() -> void:
	progress = root.get_node("MelodyProgress")
	fresh()
	check(world.rabbit_actor.visible and world.rabbit_actor.texture==world.RABBIT_ART,"rabbit is present in forest at opening")
	check(not story.is_processing() and not story.is_processing_input(),"one shared story clock and input owner")
	check(not story.lines.is_empty() and story.panel.visible,"original opening and dialogue frame migrated")
	check(story.portrait.visible and story.portrait.texture==story.Art.ALICE_PORTRAIT,"Alice supplied portrait migrated")
	if "--screenshots" in OS.get_cmdline_user_args():await capture("migrated-opening")
	var old_lines: Array = story.lines.duplicate()
	key(KEY_SPACE)
	check(story.lines==old_lines and world.jump_count==0,"space neither advances dialogue nor jumps during reading")
	var start: Vector3 = world.actor.position
	Input.action_press("forest_right")
	world._physics_process(.1)
	Input.action_release("forest_right")
	check(Vector2(world.actor.position.x,world.actor.position.z).distance_to(Vector2(start.x,start.z))<.01,"movement blocked during dialogue")
	drain()
	world.actor.position = world.point_on_route(5)
	world._process(.02)
	check(story.running and story.stage==1,"approaching rabbit starts crossing")
	world._process(4)
	check(not story.running and story.stage==1 and world.watch_item.visible,"rabbit drops visible watch")
	check(not world.fragment_items[0].visible,"no fragments before rabbit departure")
	drain()
	place("watch")
	tap_e()
	check(story.stage==2 and not story.lines.is_empty(),"short E picks up watch in forest")
	drain()
	place("encounter")
	world._process(.02)
	check(story.stage==3 and story.callback=="jump","reunion uses original melody dialogue")
	if "--screenshots" in OS.get_cmdline_user_args():await capture("migrated-reunion")
	check(world.rabbit_actor.visible,"rabbit remains visible through confrontation")
	drain()
	check(story.jumping,"last dialogue starts rabbit departure")
	world._process(2)
	check(not story.jumping and world.rabbit_departed and not world.rabbit_actor.visible,"rabbit actually disappears into portal")
	check(world.fragment_items[0].visible and world.fragment_items[1].visible,"fragments appear after rabbit departure")
	drain()
	place("rim")
	tap_e()
	check(story.investigated and not story.path_found,"broken footprints investigation migrated")
	drain()
	key(KEY_E)
	world._process(.4)
	check(story.past and not story.seen and world.echo_actor.visible,"hold E reveals gradual rabbit echo")
	if "--screenshots" in OS.get_cmdline_user_args():await capture("migrated-watch-echo")
	world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not story.past and story.hold==0,"focus loss resets watch without interaction")
	key(KEY_E,false)
	check(story.lines.is_empty(),"release after focus loss does not interact")
	key(KEY_E)
	world._process(2)
	check(story.seen and story.past and not story.path_found,"observation reveals route evidence without changing path")
	key(KEY_E,false)
	check(not story.past and not story.lines.is_empty(),"release restores present and reflection dialogue")
	drain()
	place("roots")
	tap_e()
	check(story.path_found and progress.has_fragment("prologue","rest"),"root investigation finds existing path and third fragment")
	check(world.existing_path.visible,"root path exists throughout")
	drain()
	for i in range(2):
		place("fragment_%d" % i)
		tap_e()
		drain()
	check(progress.has_all(story.melody_phrase) and story.melody_puzzle.active,"collecting all fragments invites original puzzle")
	var puzzle: Node = story.melody_puzzle
	if "--screenshots" in OS.get_cmdline_user_args():
		await capture("migrated-puzzle")
		await pointer_drag(puzzle)
	puzzle.place_fragment("glimmer",0)
	puzzle.place_fragment("echo",1)
	puzzle.close()
	story.open_melody()
	check(puzzle.arrangement==["glimmer","echo"],"puzzle draft survives closing in forest")
	puzzle.place_fragment("rest",2)
	puzzle.submit()
	check(progress.is_restored("prologue"),"native puzzle restores cumulative phrase")
	check(not puzzle.audio_player.playing,"no fabricated music when audio missing")
	puzzle.close()
	world.update_story_objects()
	check(story.melody_response_played and world.portal_response.visible,"first completion lights portal and original monologue")
	drain()
	story.open_melody()
	puzzle.submit()
	puzzle.close()
	check(story.lines.is_empty(),"completion response remains one-time")
	place("entry")
	tap_e()
	check(story.ending,"explicit portal entry starts transition")
	world._process(2)
	check(story.chapter and not story.past,"chapter entry retains original progress and disables watch")
	key(KEY_E)
	world._process(2)
	check(not story.past,"chapter cannot use watch")
	# Independent exploration alternative, without observing or solving melody.
	fresh()
	drain()
	story.stage = 3
	world.rabbit_departed = true
	place("roots")
	tap_e()
	check(story.path_found and not story.seen and not story.investigated,"direct exploration route works in 3D")
	drain()
	place("entry")
	tap_e()
	check(story.ending and not progress.is_restored("prologue"),"no music lock on forest exit")
	world._process(2)
	check(story.chapter and progress.restored.is_empty(),"unfinished melody honestly carried to chapter")
	print("Forest story: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)

func capture(id: String) -> void:
	story.update_ui()
	world.update_camera(1,true)
	world.update_story_objects()
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/volume-forest/"+id+".png")==OK,"capture "+id)

func pointer_drag(puzzle: Node) -> void:
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
	move.position = start+Vector2(24,24)
	move.relative = Vector2(24,24)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move)
	await process_frame
	check(root.gui_is_dragging(),"native GUI drag works over forest")
	move = InputEventMouseMotion.new()
	move.position = finish
	move.relative = finish-start-Vector2(24,24)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = finish
	root.push_input(release)
	await process_frame
	check(puzzle.arrangement==["glimmer"],"native drop places fragment in migrated puzzle")
