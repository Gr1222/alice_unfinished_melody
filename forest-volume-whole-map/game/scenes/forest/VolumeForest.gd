extends "res://scenes/art/SpatialForest.gd"
## Full solid-volume map built from the approved W-jump forest study.

signal landmark_inspected(id: String)
var map_layout: Dictionary
var overview := false
var paused := false
var hint: Label
var landmarks: Array[Area3D] = []
var inspected: Array[String] = []
var tour_recording := false

func _ready() -> void:
	super._ready()
	map_layout = JSON.parse_string(FileAccess.get_file_as_string(forest_assets+"layout.json"))
	for mesh: MeshInstance3D in get_child(0).find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			if original is StandardMaterial3D and ("MAT_void" in original.resource_name or ("05_Portal" in mesh.name and "MAT_crease" in original.resource_name)):
				var dark := ShaderMaterial.new()
				dark.shader = load("res://assets/volume_forest/portal_interior.gdshader")
				mesh.set_surface_override_material(surface,dark)
			if mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				var material := ShaderMaterial.new()
				material.shader = load("res://assets/volume_forest/painted_ground.gdshader")
				mesh.set_surface_override_material(surface,material)
	actor.collision_mask = 3
	add_landmark_collisions()
	add_path_boundaries()
	add_landmark_areas()
	var label: Label = ui.get_child(0)
	label.text = "森林全图 · 实体场景\n方向键移动　W 跳过低横木　E 调查　空格 自动巡游\nTab 全图 / 跟随镜头　C 观察侧面　L 光源对比　R 回入口　Esc 暂停"
	hint = Label.new()
	hint.position = Vector2(18,666)
	hint.add_theme_font_size_override("font_size",18)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x",2)
	hint.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(hint)
	if "--capture-volume" in OS.get_cmdline_user_args():
		frozen = true
		capture_volume()
	if "--tour-volume" in OS.get_cmdline_user_args():
		reset_actor()
		automatic = true
		tour_recording = true
		ui.hide()

func add_landmark_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "TreesAndStandingStoneCollision"
	for item: Dictionary in map_layout.tree_proxies:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = float(item.radius)
		shape.height = float(item.height)
		collision.shape = shape
		collision.position = vector(item.position)+Vector3(0,shape.height*.5,0)
		body.add_child(collision)
	# Portal opening remains free; only the two solid side buttresses block.
	for point: Vector3 in [Vector3(6.9,1.8,-6.8),Vector3(11.1,1.8,-6.8),Vector3(6.8,.94,-5)]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6,3.6,1.6) if point.y>1 else Vector3(.85,1.88,.48)
		collision.shape = shape
		collision.position = point
		body.add_child(collision)
	add_child(body)

func add_path_boundaries() -> void:
	var body := StaticBody3D.new()
	body.name = "OuterPathWalls"
	body.collision_layer = 2
	body.collision_mask = 1
	for i in range(route.size()-1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i+1]
		var direction := a.direction_to(b)
		var side := Vector3(-direction.z,0,direction.x)
		for sign_value: float in [-1,1]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(.12,3,a.distance_to(b)+.08)
			collision.shape = shape
			collision.position = (a+b)*.5+side*sign_value*1.15+Vector3(0,1.5,0)
			collision.rotation.y = atan2(direction.x,direction.z)
			body.add_child(collision)
	add_child(body)

func add_landmark_areas() -> void:
	for item: Dictionary in map_layout.interactions:
		var area := Area3D.new()
		area.name = String(item.id).capitalize()+"Interaction"
		area.position = vector(item.point)
		area.collision_layer = 0
		area.collision_mask = 1
		area.set_meta("id",item.id)
		area.set_meta("text",item.text)
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = float(item.radius)
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		landmarks.append(area)

func nearby_landmark() -> Area3D:
	for area: Area3D in landmarks:
		var shape: SphereShape3D = area.get_child(0).shape
		if actor.position.distance_to(area.position)<shape.radius:return area
	return null

func inspect_landmark() -> void:
	var area := nearby_landmark()
	if area==null:return
	automatic = false
	var id := String(area.get_meta("id"))
	if not inspected.has(id):inspected.append(id)
	landmark_inspected.emit(id)
	hint.text = String(area.get_meta("text"))
	if id=="portal":
		var existing: Node = load("res://scenes/prologue/Prologue.tscn").instantiate()
		existing.set("chapter",true)
		get_tree().root.add_child(existing)
		get_tree().current_scene = existing
		queue_free()

func update_camera(delta: float, snap := false) -> void:
	if overview:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 38.0*9.0/16.0
		camera.position = Vector3(0,29,29)
		camera.look_at(Vector3(0,1,-1))
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		super.update_camera(delta,snap)

func _physics_process(delta: float) -> void:
	if paused:return
	super._physics_process(delta)
	if is_instance_valid(hint) and hint.text.is_empty() and nearby_landmark()!=null:
		hint.text = "E · 调查光纹 / 洞口"
	if tour_recording and not automatic and not frozen:
		print("Volume tour complete; jumps=",jump_count," endpoint=",actor.position)
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():return
	if event.keycode==KEY_ESCAPE:
		paused = not paused
		automatic = false
		actor.velocity = Vector3.ZERO
		hint.text = "已暂停 · Esc 继续" if paused else ""
		return
	if paused:return
	if event.keycode==KEY_TAB:
		overview = not overview
		update_camera(1,true)
		get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_E:
		inspect_landmark()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func capture_volume() -> void:
	ui.hide()
	for pose: String in ["whole-map","entrance","root","root-side","portal","pool"]:
		overview = pose=="whole-map"
		actor.visible = not overview
		contact_shadow.visible = actor.visible
		match pose:
			"entrance":actor.position = route[0]+Vector3(0,.03,0)
			"root","root-side":actor.position = Vector3(2.8,.03,1.6)
			"portal":actor.position = route[-1]+Vector3(0,.03,0)
			"pool":actor.position = Vector3(1.8,.03,8.7)
		yaw = .55 if pose=="root-side" else 0.0
		update_camera(1,true)
		update_contact_shadow()
		for i in range(4):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://output/volume-forest/"+pose+".png")
		if error!=OK:
			get_tree().quit(1)
			return
	print("Solid-volume whole-map screenshots saved")
	get_tree().quit()
