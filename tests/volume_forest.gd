extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4
	create_timer(60).timeout.connect(func() -> void:
		push_error("Whole map test timed out")
		quit(1))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:passed += 1
	else:
		failed += 1
		push_error(message)

func run() -> void:
	var scene = load("res://scenes/forest/VolumeForest.tscn").instantiate()
	root.add_child(scene)
	check(scene.route[0].distance_to(Vector3(-12,0,9))<.01,"whole map starts at southwest entrance")
	check(scene.route[-1].distance_to(Vector3(9,0,-5.2))<.01,"whole map ends at northeast portal")
	check(scene.map_layout.tree_proxies.size()>=60,"dense left and distant woodland present")
	check(scene.map_layout.pools.size()==2,"both pools present")
	check(scene.get_node("OuterPathWalls").get_child_count()>100,"continuous physical path boundary")
	check(scene.source_lights.size()==10,"all mushroom and rune sources connected")
	check(scene.actor.find_children("*","Light3D",true,false).is_empty(),"no actor-attached lamp")
	check(scene.landmarks.size()==2,"stone and portal interaction areas")
	var visible_volumes := 0
	var image_plate := false
	for mesh: MeshInstance3D in scene.get_child(0).find_children("*","MeshInstance3D",true,false):
		if mesh.mesh.get_aabb().size.y>4:visible_volumes += 1
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(surface)
			if material is StandardMaterial3D and material.albedo_texture!=null:
				image_plate = image_plate or "painting" in material.albedo_texture.resource_path or "original-8k" in material.albedo_texture.resource_path
	check(visible_volumes>=4 and not image_plate,"real volumetric forest without original-art plate")
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	var initial_z: float = scene.actor.position.z
	for i in range(12):await physics_frame
	check(Input.is_action_pressed("forest_up") and scene.actor.position.z<initial_z and scene.jump_count==0,"W moves forward without jumping")
	forward.pressed = false
	Input.parse_input_event(forward)
	# Real physics, no teleporting around the obstacle or forged jump animation.
	scene.actor.position = Vector3(3.05,.08,1.6)
	for i in range(12):await physics_frame
	Input.action_press("forest_right")
	Input.action_press("forest_up")
	for i in range(65):await physics_frame
	var blocked: Vector3 = scene.actor.position
	check(scene.actor.is_on_wall() and blocked.x<3.6,"walking is stopped by low log")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	scene._unhandled_key_input(event)
	check(scene.jump_count==1,"space starts jump")
	check(not scene.automatic,"space does not start automatic tour")
	check(not scene.request_jump(),"airborne repeated jump rejected")
	var peak := 0.0
	for i in range(70):
		await physics_frame
		peak = maxf(peak,scene.actor.position.y)
	Input.action_release("forest_right")
	Input.action_release("forest_up")
	for i in range(15):await physics_frame
	check(peak>.65 and scene.actor.position.x>blocked.x+.55,"jump crosses log")
	check(scene.actor.is_on_floor(),"land after jumping")
	scene.reset_actor()
	for i in range(10):await physics_frame
	scene.automatic = true
	var steps := 0
	var stayed := true
	while scene.automatic and steps<3000:
		await physics_frame
		stayed = stayed and scene.on_route(scene.actor.position)
		steps += 1
	print("Whole map traversal: ",scene.actor.position," target=",scene.route[-1]," index=",scene.index," steps=",steps," jumps=",scene.jump_count)
	check(stayed,"entire traversal stays inside path")
	var flat := Vector3(scene.actor.position.x,0,scene.actor.position.z)
	check(not scene.automatic and flat.distance_to(scene.route[-1])<.13,"continuous route reaches portal")
	check(scene.jump_count>=2,"full traversal jumps the log")
	var old_camera: Vector3 = scene.camera.position
	scene.overview = true
	scene.update_camera(1,true)
	check(scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and scene.camera.position.distance_to(old_camera)>1,"whole map overview works")
	scene.overview = false
	scene.update_camera(1,true)
	check(scene.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"return to spatial follow camera")
	scene.actor.position = Vector3(6.5,.02,-4.1)
	check(scene.nearby_landmark()!=null,"standing stone is inspectable from path")
	scene.inspect_landmark()
	check(scene.inspected.has("stone"),"stone inspection signal and state")
	scene.actor.position = scene.route[-1]+Vector3(0,.02,0)
	check(scene.nearby_landmark()!=null,"portal interaction reachable")
	scene.inspect_landmark()
	await process_frame
	check(current_scene!=null and current_scene.get("chapter")==true,"portal reaches existing chapter entry without melody lock")
	print("Volume forest: %d passed, %d failed; apex %.3f" % [passed,failed,peak])
	quit(0 if failed==0 else 1)
