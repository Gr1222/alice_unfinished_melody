extends "res://scenes/art/SpatialForest.gd"
## Complete fixed-camera painted relief map. Reuses validated movement/jump logic.
## Does not replace or rewrite the narrative prologue.

signal landmark_inspected(id: String)
signal portal_entered

const FOLDER := "res://assets/complete_forest/"
const RELIEF_SHADER = preload("res://assets/complete_forest/painted_relief.gdshader")
const PAINTING = preload("res://assets/complete_forest/painting.png")
const ELEVATION := deg_to_rad(50.0)
const UNIT := 32.0/2048.0
var layout: Dictionary
var model: Node3D
var messages: Label
var hint: Label
var materials: Array[ShaderMaterial] = []
var effects := true
var elapsed := 0.0
var entered := false
var paused := false
var last_landmark := ""
var landmarks: Array[Area3D] = []
var boundary_count := 0
var capture_mode := false
var motes: MultiMeshInstance3D

func ground_point(pixel: Vector2, height := 0.0) -> Vector3:
	return Vector3((pixel.x-1024.0)*UNIT,height,((pixel.y-576.0)*UNIT+height*cos(ELEVATION))/sin(ELEVATION))

func pixel_point(point: Vector3) -> Vector2:
	return Vector2(point.x/UNIT+1024.0,(point.z*sin(ELEVATION)-point.y*cos(ELEVATION))/UNIT+576.0)

func _ready() -> void:
	capture_mode = "--capture-complete" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1920,1080) if capture_mode else Vector2i(1280,720)
	get_window().content_scale_size = get_window().size
	for action: String in ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		owned_actions.append(action)
		for code: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
	layout = JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"layout.json"))
	for point: Array in layout.route:
		route.append(ground_point(Vector2(float(point[0]),float(point[1]))))
	model = load(FOLDER+"forest.glb").instantiate()
	model.name = "FullForestRelief"
	add_child(model)
	var ids: Dictionary = {}
	for item: Dictionary in layout.layers: ids[item.id] = item
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var material := ShaderMaterial.new()
		material.shader = RELIEF_SHADER
		material.set_shader_parameter("painting",PAINTING)
		if ids.has(String(mesh.name)) and ids[String(mesh.name)].kind != "ground":
			material.set_shader_parameter("masked",true)
			material.set_shader_parameter("silhouette",load(FOLDER+String(mesh.name)+".png"))
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		materials.append(material)
	add_floor()
	add_boundaries()
	var obstacle: Dictionary = layout.obstacle
	var a := ground_point(Vector2(float(obstacle.a[0]),float(obstacle.a[1])),.25)
	var b := ground_point(Vector2(float(obstacle.b[0]),float(obstacle.b[1])),.25)
	add_log_collision({"points":[[a.x,a.y,a.z],[b.x,b.y,b.z]],"radii":[.19,.19]})
	# Major immovable landmarks use broad proxy capsules, not decorative triangles.
	add_proxy("AncientTreeBlocker",ground_point(Vector2(1750,302)),1.55,5.0)
	add_proxy("RuneStoneBlocker",ground_point(Vector2(1420,407)),.27,1.5)
	add_proxy("CentralTreeBlocker",ground_point(Vector2(1160,544)),.48,4.2)
	make_actor()
	make_lighting()
	add_contact_shadow()
	camera = Camera3D.new()
	camera.name = "FixedGameplayCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.near = .1
	camera.far = 120
	camera.position = Vector3(0,40*sin(ELEVATION),40*cos(ELEVATION))
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	make_landmarks()
	make_motes()
	make_ui()
	if "--auto-complete" in OS.get_cmdline_user_args(): automatic = true
	if capture_mode:
		frozen = true
		capture_complete()

func make_actor() -> void:
	actor = CharacterBody3D.new()
	actor.name = "Alice"
	actor.position = route[0]+Vector3(0,.06,0)
	actor.floor_snap_length = .12
	actor.safe_margin = .002
	var shape := CapsuleShape3D.new()
	shape.radius = .13
	shape.height = .9
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = .45
	actor.add_child(collision)
	add_child(actor)
	sprite = Sprite3D.new()
	sprite.texture = FRONT
	sprite.position.y = .5
	sprite.pixel_size = 1.0/FRONT.get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.modulate = Color(.78,.85,.92)
	actor.add_child(sprite)

func add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(36,.1,29)
	var collision := CollisionShape3D.new()
	collision.position.y = -.05
	collision.shape = shape
	floor_body.add_child(collision)
	add_child(floor_body)

func add_proxy(id: String, point: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = id
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.position = point+Vector3(0,height*.5,0)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func path_radius(segment: int) -> float:
	return .76 if segment>8 else .98

func add_boundaries() -> void:
	var body := StaticBody3D.new()
	body.name = "FullPathBoundaries"
	for i in range(route.size()-1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i+1]
		var d := a.direction_to(b)
		var side := Vector3(-d.z,0,d.x)
		for sign_value: float in [-1.0,1.0]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(.12,3.0,a.distance_to(b))
			collision.shape = shape
			collision.position = (a+b)*.5+side*sign_value*(path_radius(i)+.21)+Vector3(0,1.5,0)
			collision.rotation.y = atan2(d.x,d.z)
			body.add_child(collision)
			boundary_count += 1
	body.collision_layer = 2
	body.collision_mask = 1
	# The controller uses the same corridor to avoid segment-joint snags; outer
	# walls remain physical protection against teleport/large-step escape.
	add_child(body)
	actor = null

func on_route(point: Vector3) -> bool:
	point.y = 0
	for i in range(route.size()-1):
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point,route[i],route[i+1]))<=path_radius(i):return true
	return false

func update_camera(_delta: float, _snap := false) -> void:
	pass # Fixed projection: no orbit or follow that exposes unpainted surfaces.

func make_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aebdca")
	env.ambient_light_energy = .7
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "CanopyMoonlight"
	moon.rotation_degrees = Vector3(-52,-22,0)
	moon.light_color = Color("b9ced9")
	moon.light_energy = .4
	add_child(moon)
	for point: Array in layout.sources:
		var light := OmniLight3D.new()
		light.name = "VisibleMushroomOrRuneSource"
		light.position = ground_point(Vector2(float(point[0]),float(point[1])),.35)
		light.light_color = Color("8cd9d3")
		light.light_energy = .24
		light.omni_range = 1.8
		add_child(light)
		source_lights.append(light)

func make_landmarks() -> void:
	for item: Dictionary in layout.interactions:
		var area := Area3D.new()
		area.name = String(item.id).capitalize()+"Interaction"
		area.position = ground_point(Vector2(float(item.point[0]),float(item.point[1])))
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

func nearest_landmark() -> Area3D:
	var nearest: Area3D = null
	var distance := 1000.0
	for area: Area3D in landmarks:
		var d := actor.position.distance_to(area.position)
		var shape: SphereShape3D = area.get_child(0).shape
		if d<shape.radius and d<distance:
			distance = d
			nearest = area
	return nearest

func inspect_landmark() -> void:
	var area := nearest_landmark()
	if area == null:return
	automatic = false
	last_landmark = String(area.get_meta("id"))
	messages.text = String(area.get_meta("text"))
	landmark_inspected.emit(last_landmark)
	if last_landmark == "portal":
		entered = true
		portal_entered.emit()
		# Reuse the actual existing chapter-entry presentation without replaying
		# prologue rewards, creating a music lock, or resetting MelodyProgress.
		var existing: Node = load("res://scenes/prologue/Prologue.tscn").instantiate()
		existing.set("chapter",true)
		get_tree().root.add_child(existing)
		get_tree().current_scene = existing
		queue_free()

func make_motes() -> void:
	motes = MultiMeshInstance3D.new()
	motes.name = "SubtleForestMotes"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(.035,.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("86bdbd")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	multimesh.mesh = quad
	multimesh.instance_count = 28
	var rng := RandomNumberGenerator.new()
	rng.seed = 271027
	for i in range(28):
		var point := ground_point(Vector2(rng.randf_range(800,1960),rng.randf_range(140,950)),rng.randf_range(.25,1.0))
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
	motes.multimesh = multimesh
	add_child(motes)

func make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.position = Vector2(18,14)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.text = "迷雾森林 · 全图\n方向键移动　W 跳过低树根　E 调查 / 进入洞口\n空格 自动巡游　L 微光开关　R 回到入口　Esc 暂停"
	ui.add_child(label)
	messages = Label.new()
	messages.position = Vector2(18,665)
	messages.add_theme_font_size_override("font_size",16)
	messages.add_theme_color_override("font_shadow_color",Color.BLACK)
	messages.add_theme_constant_override("shadow_offset_x",2)
	messages.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(messages)
	hint = Label.new()
	hint.position = Vector2(18,642)
	hint.add_theme_color_override("font_color",Color("b3ddd4"))
	ui.add_child(hint)

func _physics_process(delta: float) -> void:
	if paused or entered:return
	super._physics_process(delta)
	if is_instance_valid(sprite):sprite.pixel_size = 1.0/sprite.texture.get_height()
	if is_instance_valid(hint):hint.text = "E · 调查附近的光纹" if nearest_landmark()!=null else ""

func _process(delta: float) -> void:
	if paused or frozen:return
	elapsed += delta
	if is_instance_valid(motes):motes.position.y = sin(elapsed*.5)*.045

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():return
	if event.keycode==KEY_ESCAPE:
		paused = not paused
		automatic = false
		actor.velocity = Vector3.ZERO
		messages.text = "已暂停 · Esc 继续" if paused else ""
		return
	if paused:return
	if event.keycode==KEY_E:
		inspect_landmark()
		get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_C:return
	if event.keycode==KEY_L:
		effects = not effects
		for material: ShaderMaterial in materials:material.set_shader_parameter("effects_enabled",effects)
		motes.visible = effects
	super._unhandled_key_input(event)

func capture_complete() -> void:
	ui.hide()
	for material: ShaderMaterial in materials:material.set_shader_parameter("effects_enabled",false)
	motes.hide()
	for pose: String in ["full-scene","entrance","root-behind","root-front","jump","portal"]:
		actor.visible = pose!="full-scene"
		contact_shadow.visible = actor.visible
		match pose:
			"entrance":actor.position = route[0]+Vector3(0,.015,0)
			"root-behind":actor.position = ground_point(Vector2(1337,648),.015)
			"root-front":actor.position = ground_point(Vector2(1302,707),.015)
			"jump":actor.position = ground_point(Vector2(1342,682),0)+Vector3(0,.84,0)
			"portal":actor.position = route[-1]+Vector3(0,.015,0)
		update_contact_shadow()
		for i in range(4):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://output/forest-production/"+pose+".png")
		if error!=OK:
			get_tree().quit(1)
			return
	print("Full-map camera captures saved")
	get_tree().quit()
