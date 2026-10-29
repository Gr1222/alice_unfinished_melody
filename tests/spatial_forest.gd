extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("Spatial test timed out")
		quit(1))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func run() -> void:
	var scene = load("res://scenes/art/SpatialForest.tscn").instantiate()
	root.add_child(scene)
	check(scene.camera.projection == Camera3D.PROJECTION_PERSPECTIVE,"perspective camera")
	check(scene.sprite is AnimatedSprite3D and scene.sprite.shaded,"lit animated sprite in 3D")
	check(scene.sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED,"Alice sprite faces the camera")
	check(scene.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,"Alice sprite uses nearest filtering")
	scene.update_alice_animation(Vector3(-1,0,0))
	check(scene.sprite.animation == "walk_right" and scene.sprite.flip_h,"left movement flips the side walk cycle")
	scene.update_alice_animation(Vector3.ZERO)
	check(scene.sprite.animation == "idle_right" and scene.sprite.flip_h,"stationary Alice keeps her last facing")
	check(scene.actor is CharacterBody3D,"physical player body")
	check(scene.actor.find_children("*","Light3D",true,false).is_empty(),"no invisible player lamp")
	check(scene.source_lights.size() == 6,"visible scene sources only")
	check(InputMap.action_get_events("forest_jump")[0].physical_keycode == KEY_SPACE,"space is jump")
	check(InputMap.action_get_events("forest_up")[1].physical_keycode == KEY_W,"W moves forward")
	var mesh_count := 0
	var actual_volume := false
	var grass_vertices := 0
	var ground_has_texture := false
	for node: Node in scene.get_child(0).find_children("*","MeshInstance3D",true,false):
		mesh_count += 1
		var box: AABB = node.mesh.get_aabb()
		if box.size.y > 5.0 and box.size.z > 1.0: actual_volume = true
		for surface in range(node.mesh.get_surface_count()):
			var material = node.get_active_material(surface)
			if "LivingGrass" in material.resource_name:
				grass_vertices += node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
			if "EarthMoss" in material.resource_name:
				ground_has_texture = material.albedo_texture != null
	check(mesh_count >= 8 and actual_volume,"actual volumetric forest meshes")
	check(grass_vertices > 10000,"grass uses volumetric blades")
	check(not ground_has_texture,"ground contains no painted plant carpet")
	var old_camera: Vector3 = scene.camera.position
	scene.actor.position = scene.route[3]
	scene.update_camera(1,true)
	check(scene.camera.position.distance_to(old_camera)>1,"camera follows actor through space")
	# Actual physics: approach without jumping, then press W and clear the log.
	scene.actor.position = Vector3(3.05,.08,1.6)
	scene.actor.velocity = Vector3.ZERO
	for i in range(12): await physics_frame
	Input.action_press("forest_right")
	Input.action_press("forest_up")
	var start: Vector3 = scene.actor.position
	for i in range(65): await physics_frame
	var blocked: Vector3 = scene.actor.position
	print("Log approach: ",start," -> ",blocked)
	check(scene.actor.is_on_wall() and blocked.distance_to(start)<1.0,"walking is blocked by log")
	var before: int = scene.jump_count
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	scene._unhandled_key_input(event)
	check(scene.jump_count == before+1 and scene.actor.velocity.y>0,"W initiates jump")
	check(not scene.request_jump(),"midair/repeated jump is rejected")
	var peak := 0.0
	for i in range(70):
		await physics_frame
		peak = maxf(peak,scene.actor.position.y)
	Input.action_release("forest_right")
	Input.action_release("forest_up")
	for i in range(10): await physics_frame
	print("Jump result: peak=",peak," landing=",scene.actor.position)
	check(peak>.65,"jump apex clears low log")
	check(scene.actor.position.x > blocked.x+.55,"jump crosses obstacle")
	check(scene.actor.is_on_floor() and absf(scene.actor.position.y-.01)<.035,"player lands on ground")
	scene.reset_actor()
	for i in range(10): await physics_frame
	scene.automatic = true
	var steps := 0
	var stayed := true
	var initial_jumps: int = scene.jump_count
	while scene.automatic and steps<1500:
		await physics_frame
		stayed = stayed and scene.on_route(scene.actor.position)
		steps += 1
	check(stayed,"whole traversal stays inside path")
	var flat := Vector3(scene.actor.position.x,0,scene.actor.position.z)
	check(not scene.automatic and flat.distance_to(scene.route[-1])<.13,"traversal reaches hollow tree")
	check(scene.jump_count>initial_jumps,"automatic demonstration jumps, not walks under log")
	print("Spatial forest: %d passed, %d failed; %d meshes, %d simulated frames" % [passed,failed,mesh_count,steps])
	scene.queue_free()
	quit(0 if failed == 0 else 1)
