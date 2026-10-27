extends Node3D
## Grounded lights, physical grass and a solid low obstacle jumped with W.

const FRONT = preload("res://assets/user_art/alice_front.png")
const SIDE = preload("res://assets/user_art/alice_side.png")
const BACK = preload("res://assets/user_art/alice_back.png")
const SPEED := 2.4
const JUMP_SPEED := 4.8
const GRAVITY := 13.0
const ACTIONS := {"forest_left":[KEY_LEFT,KEY_A],"forest_right":[KEY_RIGHT,KEY_D],"forest_up":[KEY_UP],"forest_down":[KEY_DOWN,KEY_S],"forest_jump":[KEY_W]}
var owned_actions: Array[String] = []
var route: Array[Vector3] = []
var actor: CharacterBody3D
var sprite: Sprite3D
var camera: Camera3D
var source_lights: Array[OmniLight3D] = []
var contact_shadow: MeshInstance3D
var ui: CanvasLayer
var automatic := false
var index := 1
var yaw := 0.0
var frozen := false
var last_direction := Vector3(1,0,-.7).normalized()
var jump_direction := Vector3.ZERO
var jump_count := 0
var record_jump_demo := false
var demo_time := 0.0
var demo_jump_sent := false
@export var art_focus := false

func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	get_window().content_scale_size = Vector2i(1280,720)
	for action: String in ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		owned_actions.append(action)
		for code: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
	var model: Node3D = load("res://assets/spatial_forest/forest.glb").instantiate()
	add_child(model)
	# The importer retains COLOR_0 but does not enable it on these materials.
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			if original is StandardMaterial3D and ("EarthMoss" in original.resource_name or "DirtPath" in original.resource_name or "LivingGrass" in original.resource_name):
				var painted: StandardMaterial3D = original.duplicate()
				painted.vertex_color_use_as_albedo = true
				painted.vertex_color_is_srgb = false
				mesh.set_surface_override_material(surface,painted)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/spatial_forest/layout.json"))
	for point: Array in layout.route: route.append(vector(point))
	add_floor()
	add_log_collision(layout.jump_obstacle)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14232f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("86939d")
	env.ambient_light_energy = .28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("233844")
	env.fog_density = .009
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-55,-32,0)
	moon.light_color = Color("bac8d0")
	moon.light_energy = .72
	moon.light_angular_distance = 1.5
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	moon.shadow_bias = .025
	moon.shadow_normal_bias = .55
	moon.directional_shadow_max_distance = 45
	moon.directional_shadow_blend_splits = true
	add_child(moon)
	actor = CharacterBody3D.new()
	actor.name = "Alice"
	actor.position = Vector3(2.4,.06,1.6) if art_focus else route[0]+Vector3(0,.06,0)
	actor.floor_snap_length = .12
	actor.safe_margin = .002
	var shape := CapsuleShape3D.new()
	shape.radius = .18
	shape.height = 1.3
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = .65
	actor.add_child(collision)
	add_child(actor)
	sprite = Sprite3D.new()
	sprite.texture = FRONT
	sprite.pixel_size = 1.5 / FRONT.get_height()
	sprite.position.y = .75
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	actor.add_child(sprite)
	for point: Vector3 in [Vector3(-4,.4,1.4),Vector3(1.8,.4,-2.8),Vector3(4,.4,3.8),Vector3(7,.4,-2.6),Vector3(-8,.4,4.8),Vector3(9,1.8,-5.5)]:
		var light := OmniLight3D.new()
		light.name = "MushroomLight" if point.y<1 else "RuneLight"
		light.position = point
		light.light_color = Color("7db7c3") if point.y<1 else Color("c5ce9a")
		light.light_energy = .38
		light.omni_range = 2.1 if point.y<1 else 2.8
		light.shadow_enabled = true
		light.shadow_blur = 2.0
		light.shadow_bias = .025
		light.shadow_normal_bias = .5
		add_child(light)
		source_lights.append(light)
	add_contact_shadow()
	camera = Camera3D.new()
	camera.fov = 43
	camera.near = .1
	camera.far = 90
	add_child(camera)
	camera.current = true
	update_camera(1,true)
	ui = CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.position = Vector2(18,16)
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.text = "森林样段 · W 跳过横木\n方向键移动　W 跳跃　空格 自动演示　C 观察角度　L 光源对比　R 重置"
	ui.add_child(label)
	if "--auto-spatial" in OS.get_cmdline_user_args():
		automatic = true
		actor.position = route[0]+Vector3(0,.06,0)
		ui.hide()
	if "--record-log-jump" in OS.get_cmdline_user_args():
		record_jump_demo = true
		actor.position = Vector3(3.05,.06,1.6)
		ui.hide()
	if "--capture-spatial" in OS.get_cmdline_user_args():
		frozen = true
		capture()

func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))

func add_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(29,.1,23)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -.04
	body.add_child(collision)
	add_child(body)

func add_log_collision(data: Dictionary) -> void:
	var points: Array = data.points
	var radii: Array = data.radii
	var body := StaticBody3D.new()
	body.name = "LowJumpLogCollision"
	for i in range(points.size()-1):
		var a := vector(points[i])
		var b := vector(points[i+1])
		var shape := CapsuleShape3D.new()
		shape.radius = maxf(float(radii[i]),float(radii[i+1]))
		shape.height = a.distance_to(b)+2*shape.radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = (a+b)*.5
		collision.quaternion = Quaternion(Vector3.UP,a.direction_to(b))
		body.add_child(collision)
	add_child(body)

func add_contact_shadow() -> void:
	contact_shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(.7,.46)
	contact_shadow.mesh = plane
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment(){ float d=length((UV-vec2(0.5))*vec2(1.0,1.1)); ALBEDO=vec3(0.025,0.04,0.05); ALPHA=(1.0-smoothstep(0.1,0.5,d))*0.3; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	contact_shadow.material_override = material
	add_child(contact_shadow)
	update_contact_shadow()

func update_contact_shadow() -> void:
	contact_shadow.position = Vector3(actor.position.x,.023,actor.position.z)
	var factor := 1.0-clampf(actor.position.y,0,1)*.28
	contact_shadow.scale = Vector3(factor,1,factor)

func update_camera(delta: float, snap := false) -> void:
	var distance := 8.0 if art_focus else 11.0
	var offset := Vector3(sin(yaw)*distance,6.3 if art_focus else 9.0,cos(yaw)*distance)
	var focus := Vector3(actor.position.x,.06,actor.position.z)
	camera.position = focus+offset if snap else camera.position.lerp(focus+offset,1.0-exp(-5.0*delta))
	camera.look_at(focus+Vector3(0,.7,0))

func on_route(point: Vector3) -> bool:
	point.y = 0
	for i in range(route.size()-1):
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point,route[i],route[i+1]))<=.72:
			return true
	return false

func request_jump(direction := Vector3.ZERO) -> bool:
	if frozen or not actor.is_on_floor() or actor.velocity.y>0: return false
	actor.velocity.y = JUMP_SPEED
	jump_direction = last_direction if direction == Vector3.ZERO else direction.normalized()
	jump_count += 1
	return true

func _physics_process(delta: float) -> void:
	if frozen: return
	var input := Input.get_vector("forest_left","forest_right","forest_up","forest_down")
	var direction := Vector3(input.x,0,input.y)
	if record_jump_demo:
		demo_time += delta
		direction = Vector3(1,0,-1).normalized() if demo_time>.45 and demo_time<2.55 else Vector3.ZERO
		if demo_time>=1.3 and not demo_jump_sent:
			demo_jump_sent = true
			var event := InputEventKey.new()
			event.keycode = KEY_W
			event.physical_keycode = KEY_W
			event.pressed = true
			_unhandled_key_input(event)
	if direction != Vector3.ZERO: automatic = false
	if automatic:
		var flat := Vector3(actor.position.x,0,actor.position.z)
		if flat.distance_to(route[index])<.12:
			index += 1
			if index>=route.size(): automatic = false
		if automatic:
			direction = flat.direction_to(route[index])
			if actor.is_on_wall() and actor.is_on_floor(): request_jump(direction)
	if direction != Vector3.ZERO: last_direction = direction
	if not actor.is_on_floor() or actor.velocity.y>0:
		actor.velocity.y -= GRAVITY*delta
		if direction == Vector3.ZERO: direction = jump_direction
	else:
		actor.velocity.y = 0
		jump_direction = Vector3.ZERO
	if not on_route(actor.position+direction*SPEED*delta): direction = Vector3.ZERO
	actor.velocity.x = direction.x*SPEED
	actor.velocity.z = direction.z*SPEED
	actor.move_and_slide()
	if direction != Vector3.ZERO:
		var texture: Texture2D = BACK if direction.z<0 else FRONT
		if absf(direction.x)>absf(direction.z): texture = SIDE
		sprite.texture = texture
		sprite.pixel_size = 1.5/texture.get_height()
		sprite.flip_h = texture == SIDE and direction.x<0
	update_camera(delta)
	update_contact_shadow()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("forest_jump"):
		request_jump()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_SPACE:
			if automatic: automatic = false
			else:
				reset_actor()
				automatic = true
		KEY_C: yaw = .42 if yaw==0 else 0.0
		KEY_L:
			for light: OmniLight3D in source_lights: light.visible = not light.visible
		KEY_R: reset_actor()
		KEY_ESCAPE: get_tree().quit()

func reset_actor() -> void:
	actor.position = route[0]+Vector3(0,.06,0)
	actor.velocity = Vector3.ZERO
	jump_direction = Vector3.ZERO
	automatic = false
	index = 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(actor):
		automatic = false
		jump_direction = Vector3.ZERO
		actor.velocity.x = 0
		actor.velocity.z = 0

func _exit_tree() -> void:
	for action: String in owned_actions: InputMap.erase_action(action)

func capture() -> void:
	ui.hide()
	for pose: String in ["entrance","middle","angle","light-off","jump","land","door"]:
		actor.position = route[0]+Vector3(0,.03,0) if pose=="entrance" else (route[-1]+Vector3(0,.03,0) if pose=="door" else Vector3(2.8,.03,1.6))
		if pose=="jump": actor.position = Vector3(3.55,.84,.95)
		if pose=="land": actor.position = Vector3(4.6,.03,.4)
		yaw = .42 if pose=="angle" else 0.0
		for light: OmniLight3D in source_lights: light.visible = pose!="light-off"
		update_camera(1,true)
		update_contact_shadow()
		for i in range(3): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var prefix := "corrected-art-" if art_focus else "corrected-"
		var error := get_viewport().get_texture().get_image().save_png("res://output/spatial-forest/"+prefix+pose+".png")
		if error != OK:
			get_tree().quit(1)
			return
	print("Grounded lighting and low jump obstacle previews saved")
	get_tree().quit()
