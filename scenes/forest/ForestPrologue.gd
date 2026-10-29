extends "res://scenes/forest/VolumeForest.gd"
## Forest exploration plus all existing prologue story/gameplay, in one scene.
const RABBIT_ART = preload("res://assets/user_art/rabbit_side.png")
@onready var story: Node2D = $Story
var route_lengths: Array[float] = [0.0]
var locations: Dictionary = {}
var rabbit_actor: Sprite3D
var echo_actor: Sprite3D
var watch_item: Node3D
var fragment_items: Array[Node3D] = []
var old_prints: Array[MeshInstance3D] = []
var portal_response: MeshInstance3D
var existing_path: Node3D
var rabbit_departed := false
var story_initialized := false

func _ready() -> void:
	super._ready()
	ui.hide()
	for i in range(1,route.size()):route_lengths.append(route_lengths[-1]+route[i-1].distance_to(route[i]))
	var total := route_lengths[-1]
	locations = {
		"watch":point_on_route(7.4),
		"encounter":point_on_route(total-5.2),
		"rim":point_on_route(total-3.4),
		"fragment_0":point_on_route(total-5.4),
		"fragment_1":point_on_route(total-2.7),
		"roots":point_on_route(total-1.4),
		"entry":point_on_route(total-.05)
	}
	make_story_objects()
	story_initialized = true
	sync_story_position()
	update_story_objects()
	print("FOREST_PROLOGUE_READY: rabbit, watch, fragments, observation, dialogue, puzzle")
	if "--capture-story" in OS.get_cmdline_user_args():
		frozen = true
		capture_story()

func point_on_route(distance: float) -> Vector3:
	distance = clampf(distance,0,route_lengths[-1])
	for i in range(route.size()-1):
		if route_lengths[i+1]>=distance:
			return route[i].lerp(route[i+1],(distance-route_lengths[i])/maxf(.0001,route_lengths[i+1]-route_lengths[i]))
	return route[-1]

func route_progress(point: Vector3) -> float:
	point.y = 0
	var best := INF
	var distance := 0.0
	for i in range(route.size()-1):
		var nearest := Geometry3D.get_closest_point_to_segment(point,route[i],route[i+1])
		var error := point.distance_squared_to(nearest)
		if error<best:
			best = error
			distance = route_lengths[i]+route[i].distance_to(nearest)
	return distance

func at_landmark(id: String, radius: float) -> bool:
	if not locations.has(id):return false
	var flat := Vector3(actor.position.x,0,actor.position.z)
	return flat.distance_to(locations[id])<radius

func sync_story_position() -> void:
	if not story_initialized or story.chapter:return
	var distance := route_progress(actor.position)
	# Keep original story thresholds, but the reunion happens near the portal.
	story.player = Vector2(120+distance/route_lengths[-1]*900,370)
	if story.stage==2:
		story.player.x = 680.0 if at_landmark("encounter",1.0) or distance>route_lengths[-1]-4.8 else minf(story.player.x,650)
	if story.stage==1 and at_landmark("watch",.85):story.player = story.WATCH
	if story.stage==3:
		# Semantic locations replace the old flat map's pixel-distance checks.
		story.player = Vector2(700,280)
		if at_landmark("rim",1.0):story.player = story.RIM
		if at_landmark("roots",.62):story.player = story.ROOTS
		if story.path_found and at_landmark("entry",.5):story.player = story.ENTRY

func movement_locked() -> bool:
	return story.paused or story.past or story.running or story.jumping or story.ending or story.chapter or story.melody_puzzle.active or not story.lines.is_empty()

func _physics_process(delta: float) -> void:
	if not story_initialized:return
	if movement_locked():
		actor.velocity.x = 0
		actor.velocity.z = 0
		update_alice_animation(Vector3.ZERO)
		automatic = false
		jump_direction = Vector3.ZERO
		if story.paused:return
		# A dialogue can start while airborne; settle to the floor without sliding.
		if not actor.is_on_floor():
			actor.velocity.y -= GRAVITY*delta
			actor.move_and_slide()
		update_camera(delta)
		update_contact_shadow()
		return
	super._physics_process(delta)
	sync_story_position()

func _process(delta: float) -> void:
	if not story_initialized or frozen:return
	sync_story_position()
	story._process(delta)
	if story.stage==3 and not story.jumping and story.callback!="jump":rabbit_departed = true
	update_story_objects()
	if story.chapter:
		get_node("ForestModel").hide()
		actor.hide()
		rabbit_actor.hide()
		echo_actor.hide()
		contact_shadow.hide()

func _input(event: InputEvent) -> void:
	if not story_initialized or not event is InputEventKey:return
	sync_story_position()
	# Puzzle owns its own input, including Esc and keyboard focus navigation.
	if story.melody_puzzle.active:return
	story._input(event)
	if event.keycode in [KEY_E,KEY_ENTER,KEY_ESCAPE,KEY_R,KEY_M]:
		get_viewport().set_input_as_handled()
	update_story_objects()

func _unhandled_key_input(event: InputEvent) -> void:
	if not story_initialized or movement_locked():return
	if event is InputEventKey and event.keycode in [KEY_E,KEY_ESCAPE,KEY_R,KEY_M,KEY_P,KEY_F2]:return
	super._unhandled_key_input(event)

func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(story):
		story._notification(what)

func update_camera(delta: float, snap := false) -> void:
	if not story_initialized or overview:
		super.update_camera(delta,snap)
		return
	var cinematic: bool = story.running or story.jumping or (story.stage==3 and story.callback=="jump")
	if not cinematic:
		super.update_camera(delta,snap)
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var focus := rabbit_position()
	var offset := Vector3(sin(yaw)*11,9,cos(yaw)*11)
	camera.position = camera.position.lerp(focus+offset,1.0-exp(-4.0*delta))
	camera.look_at(focus+Vector3(0,.7,0))

func rabbit_position() -> Vector3:
	var total := route_lengths[-1]
	if story.jumping:
		var t := clampf((story.rabbit.x-925.0)/85.0,0,1)
		return point_on_route(total-1.8).lerp(Vector3(9,.45,-6.4),t)+Vector3(0,sin(t*PI)*.7,0)
	if story.running:
		var t := clampf((story.rabbit.x-300.0)/620.0,0,1)
		return point_on_route(4.4+(total-1.8-4.4)*t)
	return point_on_route(total-1.8) if story.stage>=1 else point_on_route(4.4)

func make_billboard(id: String, texture: Texture2D, height: float) -> Sprite3D:
	var item := Sprite3D.new()
	item.name = id
	item.texture = texture
	item.pixel_size = height/texture.get_height()
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	item.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	item.shaded = true
	add_child(item)
	return item

func solid_material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
	return material

func sphere_item(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = point
	item.scale = size
	item.material_override = solid_material(color,true)
	parent.add_child(item)
	return item

func make_story_objects() -> void:
	rabbit_actor = make_billboard("WhiteRabbit",RABBIT_ART,1.65)
	echo_actor = make_billboard("RabbitPastEcho",RABBIT_ART,1.65)
	echo_actor.modulate = Color(.56,.92,.89,.5)
	echo_actor.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	echo_actor.no_depth_test = false
	watch_item = Node3D.new()
	watch_item.name = "DroppedPocketWatch"
	watch_item.position = locations.watch+Vector3(0,.15,0)
	add_child(watch_item)
	var face := CylinderMesh.new()
	face.top_radius = .12
	face.bottom_radius = .12
	face.height = .04
	var face_item := MeshInstance3D.new()
	face_item.mesh = face
	face_item.material_override = solid_material(Color("d6bc72"),true)
	watch_item.add_child(face_item)
	sphere_item(watch_item,Vector3(0,.025,.02),Vector3(.01,.025,.13),Color("443625"))
	for i in range(3):
		var item := Node3D.new()
		item.name = "MelodyFragment%d" % i
		item.position = locations["fragment_%d" % i] if i<2 else locations.roots
		item.position.y = .2
		add_child(item)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.17,.015,.25)
		var card := MeshInstance3D.new()
		card.mesh = mesh
		card.material_override = solid_material(Color("d3ba7d"),true)
		item.add_child(card)
		for j in range(i+1):sphere_item(item,Vector3(-.05+j*.05,.012,0),Vector3(.015,.008,.1),Color("544a45"))
		fragment_items.append(item)
	for i in range(8):
		var point := point_on_route(route_lengths[-1]-3.4+float(i)/7*2)
		var mark := sphere_item(self,point+Vector3(.07 if i%2 else -.07,.035,0),Vector3(.035,.006,.08),Color("d5cfa0"))
		mark.name = "OldFootprint%d" % i
		old_prints.append(mark)
	existing_path = Node3D.new()
	existing_path.name = "AlwaysExistingRootPath"
	add_child(existing_path)
	for i in range(6):
		var step := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.6,.025,.19)
		step.mesh = mesh
		step.position = point_on_route(route_lengths[-1]-1.3+float(i)*.21)+Vector3(0,.025,0)
		step.material_override = solid_material(Color("465958"))
		existing_path.add_child(step)
	portal_response = MeshInstance3D.new()
	portal_response.name = "MelodyResponseRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 1.59
	ring.outer_radius = 1.64
	portal_response.mesh = ring
	portal_response.rotation.x = PI*.5
	portal_response.scale.z = 1.3
	portal_response.position = Vector3(9,2.45,-5.85)
	portal_response.material_override = solid_material(Color("d9c88b"),true)
	add_child(portal_response)

func update_story_objects() -> void:
	if not is_instance_valid(rabbit_actor):return
	rabbit_actor.visible = not rabbit_departed and not story.chapter
	rabbit_actor.position = rabbit_position()+Vector3(0,.825,0)
	watch_item.visible = story.stage==1
	for i in range(3):
		fragment_items[i].visible = story.stage==3 and not story.chapter and rabbit_departed and not MelodyProgress.has_fragment(story.melody_phrase.phrase_id,story.melody_phrase.fragment_ids[i])
		fragment_items[i].rotation.y = sin(story.time*1.3+i)*.12
	echo_actor.visible = story.past
	var t := clampf(story.observation/1.8,0,1)
	echo_actor.position = point_on_route(route_lengths[-1]-3.4+t*2)+Vector3(0,.825,0)
	for i in range(old_prints.size()):old_prints[i].visible = story.past and story.observation>=i*.22
	portal_response.visible = story.response_pulse>0 and not story.chapter
	paused = story.paused

func capture_story() -> void:
	story.fade = 0
	story.shade.color = Color.TRANSPARENT
	story.update_ui()
	actor.position = point_on_route(2.4)+Vector3(0,.03,0)
	update_camera(1,true)
	for i in range(5):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/volume-forest/story-opening.png")
	story.lines.clear()
	story.panel.hide()
	story.portrait.hide()
	story.stage = 2
	actor.position = locations.encounter+Vector3(0,.03,0)
	update_story_objects()
	update_camera(1,true)
	for i in range(5):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/volume-forest/story-rabbit.png")
	get_tree().quit()
