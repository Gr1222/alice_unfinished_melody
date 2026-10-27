extends Node
## Standalone 3D art study. Never loaded by the playable prologue.

var camera: Camera3D
var viewport: SubViewport
var groups: Dictionary = {}
var materials: Dictionary = {}
var mesh_cache: Dictionary = {}
var data: Dictionary
var pixel_mode := false
var canopy_visible := true
var caption: Label
var age := 0.0
var captured := false
var assemblies: Dictionary = {}
var sun: DirectionalLight3D

func _ready() -> void:
	get_window().size = Vector2i(960,540)
	get_window().content_scale_size = Vector2i(960,540)
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/forest_study.json"))
	var frame := SubViewportContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch = true
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(frame)
	viewport = SubViewport.new()
	viewport.size = get_viewport().get_visible_rect().size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	for key: String in data.palette:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(data.palette[key])
		material.roughness = 1.0
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if key in ["cyan", "yellow"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[key] = material
	for item: Dictionary in data.objects:
		var group: String = item.group
		if not groups.has(group):
			var collection := Node3D.new()
			collection.name = group
			world.add_child(collection)
			groups[group] = collection
		build_mesh(item, groups[group])
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a1b4be")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	world.add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_color = Color("b3cad4")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = float(data.camera.ortho_size)
	world.add_child(camera)
	camera.position = vector(data.camera.position)
	camera.look_at(vector(data.camera.target))
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	caption = Label.new()
	caption.position = Vector2(20,16)
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(caption)
	update_caption()

func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))

func build_mesh(item: Dictionary, parent: Node3D) -> void:
	var node := MeshInstance3D.new()
	node.name = item.name
	var size := vector(item.s)
	node.position = vector(item.p)
	match String(item.kind):
		"box":
			var mesh := BoxMesh.new()
			mesh.size = size
			node.mesh = mesh
		"sphere", "cap":
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			mesh.radial_segments = 10
			mesh.rings = 5
			node.mesh = mesh
			node.scale = size
		"cylinder", "cone", "branch":
			var mesh := CylinderMesh.new()
			mesh.radial_segments = 10
			mesh.bottom_radius = size.x
			mesh.top_radius = 0.07 if item.kind == "cone" else size.x
			mesh.height = size.y
			if item.kind == "branch":
				var direction := vector(item.end) - node.position
				mesh.top_radius = size.y
				mesh.height = direction.length()
				node.position += direction * 0.5
				node.quaternion = Quaternion(Vector3.UP,direction.normalized())
			else:
				node.scale.z = size.z / size.x
			node.mesh = mesh
		"ring":
			var mesh := TorusMesh.new()
			mesh.inner_radius = size.x - 0.015
			mesh.outer_radius = size.x + 0.015
			mesh.rings = 20
			mesh.ring_segments = 4
			node.mesh = mesh
			node.scale.z = size.z / size.x
		"patch":
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var points: Array = item.points
			for i in range(1,points.size()-1):
				for j: int in [0,i,i+1]:
					surface.set_normal(Vector3.UP)
					surface.add_vertex(vector(points[j]))
			# Points are world coordinates.
			node.position = Vector3.ZERO
			node.mesh = surface.commit()
	node.rotate_y(float(item.get("yaw",0.0)))
	if item.kind not in ["branch","patch"]:
		var key: String = String(item.kind) + ("" if item.kind in ["sphere","cap"] else JSON.stringify(item.s))
		if mesh_cache.has(key):
			node.mesh = mesh_cache[key]
		else:
			mesh_cache[key] = node.mesh
	node.material_override = materials[item.mat]
	parent.add_child(node)
	var assembly: String = item.get("assembly", "")
	if not assembly.is_empty():
		if not assemblies.has(assembly):
			assemblies[assembly] = []
		assemblies[assembly].append(node)
		node.set_meta("assembly", assembly)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_P:
			pixel_mode = not pixel_mode
			viewport.get_parent().stretch_shrink = 3 if pixel_mode else 1
			update_caption()
		KEY_C:
			canopy_visible = not canopy_visible
			groups.Canopy.visible = canopy_visible
		KEY_ESCAPE:
			get_tree().quit()

func update_caption() -> void:
	caption.text = "FOREST / BRIDGE STUDY  01\n3D layout preview · not final pixel art\n[P] %s   [C] Canopy   [Esc] Exit" % ("Native" if pixel_mode else "Pixel preview")

func _process(delta: float) -> void:
	age += delta
	if age > 1.0 and not captured and "--bake-forest-2d" in OS.get_cmdline_user_args():
		captured = true
		await bake_layers()
		return
	if age > 2.0 and not captured and "--capture-forest" in OS.get_cmdline_user_args():
		captured = true
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := "res://output/forest-study/godot-preview.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/forest-study"))
		var error := image.save_png(path)
		print("Forest preview: ",error_string(error)," ",path)
		viewport.get_parent().stretch_shrink = 3
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixel_image := viewport.get_texture().get_image()
		var pixel_error := pixel_image.save_png("res://output/forest-study/godot-pixel-native.png")
		print("Pixel preview: ",error_string(pixel_error)," ",pixel_image.get_size())
		get_tree().quit(0 if error == OK and pixel_error == OK else 1)

func projected_polygon(points: Array) -> Array:
	var result: Array = []
	for point: Array in points:
		var p := camera.unproject_position(vector(point))
		result.append([p.x,p.y])
	return result

func bake_layers() -> void:
	# Offline asset export only. The 2D experiment never loads this 3D scene.
	var folder := "res://assets/forest_prerender/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	viewport.get_parent().stretch_shrink = 2
	caption.hide()
	groups.ScaleReference.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var manifest := {"version":1,"size":[viewport.size.x,viewport.size.y],"layers":[],
		"source":"Godot 4.7.2 offline render of forest_study.json; Blender bake pending",
		"background":"background.png","blockers":[],"bounds":[]}
	# Bake tree/stump shadows into the ground while removing their visible surfaces.
	for meshes: Array in assemblies.values():
		for mesh: MeshInstance3D in meshes:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(folder+"background.png")
	if error != OK:
		push_error("Background export failed: "+error_string(error))
		get_tree().quit(1)
		return
	for collection: Node3D in groups.values():
		for child: MeshInstance3D in collection.get_children():
			child.hide()
	viewport.transparent_bg = true
	sun.shadow_enabled = false
	for key: String in assemblies:
		var meshes: Array = assemblies[key]
		for mesh: MeshInstance3D in meshes:
			mesh.show()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var rect := rendered.get_used_rect()
		if not rect.has_area():
			push_error("Empty assembly: "+key)
			get_tree().quit(1)
			return
		var file := "layer_%02d.png" % manifest.layers.size()
		error = rendered.get_region(rect).save_png(folder+file)
		if error != OK:
			get_tree().quit(1)
			return
		# The first trunk/root starts at the assembly's world footprint.
		var first: MeshInstance3D = meshes[0]
		var base := Vector3(first.position.x,0,first.position.z)
		# Branch centers are offset; use exact root coordinates from layout.
		var parts := key.split("_")
		base = Vector3(float(parts[1]),0,float(parts[2]))
		var pivot := camera.unproject_position(base)
		manifest.layers.append({"id":key,"file":file,"pivot":[pivot.x,pivot.y],
			"offset":[rect.position.x-pivot.x,rect.position.y-pivot.y],
			"size":[rect.size.x,rect.size.y],"collision_radius":5.5 if key.begins_with("tree") else 8.0})
		for mesh: MeshInstance3D in meshes:
			mesh.hide()
	for quad: Array in [
		[[-11,0,.65],[-6.5,0,.65],[-6.5,0,4.1],[-11,0,4.1]],
		[[-4.7,0,.65],[11,0,.65],[11,0,4.1],[-4.7,0,4.1]]]:
		manifest.blockers.append(projected_polygon(quad))
	manifest.bounds = projected_polygon([[-10.6,0,-6.6],[10.6,0,-6.6],[10.6,0,7.5],[-10.6,0,7.5]])
	manifest.spawn = projected_polygon([[-5.6,0,5.3]])[0]
	manifest.occlusion_test = {"layer":"tree_1_-0.3",
		"behind":projected_polygon([[1,0,-1.1]])[0],"front":projected_polygon([[1,0,.35]])[0]}
	var output := FileAccess.open(folder+"manifest.json",FileAccess.WRITE)
	if output == null:
		get_tree().quit(1)
		return
	output.store_string(JSON.stringify(manifest,"\t"))
	output.close()
	print("Baked 2D background + ",manifest.layers.size()," alpha layers at ",viewport.size)
	get_tree().quit()
