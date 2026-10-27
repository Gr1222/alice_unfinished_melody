extends Node2D
## Source-preserving fixed-camera scene. Original RGB + offline Blender masks.

const Player = preload("res://scenes/art/LatestForestPlayer.gd")
const SOURCE = preload("res://assets/latest_forest/original-8k.png")
const FOLDER := "res://assets/latest_forest/"
const ROUTE := [Vector2(30,535),Vector2(100,467),Vector2(205,425),Vector2(322,389),Vector2(410,335),Vector2(470,324),Vector2(535,358),Vector2(606,367),Vector2(674,337),Vector2(735,299),Vector2(794,267),Vector2(842,226),Vector2(885,194)]
const MASK_SHADER := "shader_type canvas_item; uniform sampler2D silhouette : filter_nearest, repeat_disable; void fragment() { vec4 original = texture(TEXTURE, UV); float alpha = step(0.5, texture(silhouette, UV).r); COLOR = vec4(original.rgb, original.a * alpha); }"
var player: CharacterBody2D
var sorted: Node2D
var overlays: Array[Node2D] = []
var auto_walk := false
var auto_index := 1
var controls_enabled := true
var ui: CanvasLayer
var elapsed := 0.0

func _ready() -> void:
	get_window().size = Vector2i(1024,576)
	get_window().content_scale_size = Vector2i(1024,576)
	var background := Sprite2D.new()
	background.name = "OriginalBackground"
	background.texture = SOURCE
	background.centered = false
	background.scale = Vector2.ONE / 8.0
	add_child(background)
	sorted = Node2D.new()
	sorted.name = "Sorted"
	sorted.y_sort_enabled = true
	add_child(sorted)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"manifest.json"))
	for entry: Dictionary in manifest.layers:
		var anchor := Node2D.new()
		anchor.name = entry.id
		anchor.position = Vector2(float(entry.pivot[0]),float(entry.pivot[1])) * .5
		if entry.order == "front":
			anchor.z_index = 10
		sorted.add_child(anchor)
		var card := Sprite2D.new()
		card.texture = SOURCE
		card.centered = false
		card.position = -anchor.position
		card.scale = Vector2.ONE / 8.0
		var shader := Shader.new()
		shader.code = MASK_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("silhouette",load(FOLDER+"masks/"+entry.id+".png"))
		card.material = material
		anchor.add_child(card)
		overlays.append(anchor)
	player = Player.new()
	player.name = "Alice"
	player.position = ROUTE[0]
	sorted.add_child(player)
	ui = CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.position = Vector2(16,12)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.text = "森林场景 · 预渲染演示\nWASD / 方向键 移动　空格 自动走一遍　H 遮挡对比　R 重置"
	ui.add_child(label)
	if "--capture-latest" in OS.get_cmdline_user_args():
		controls_enabled = false
		capture()

func is_on_path(point: Vector2) -> bool:
	for i in range(ROUTE.size()-1):
		var closest := Geometry2D.get_closest_point_to_segment(point,ROUTE[i],ROUTE[i+1])
		var radius := 22.0 if i > 8 else 27.0
		if point.distance_to(closest) <= radius:
			return true
	return false

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if input != Vector2.ZERO:
		auto_walk = false
	var direction := input.limit_length()
	if auto_walk:
		var target: Vector2 = ROUTE[auto_index]
		if player.position.distance_to(target) < 5:
			auto_index += 1
			if auto_index >= ROUTE.size():
				auto_walk = false
				direction = Vector2.ZERO
			else:
				target = ROUTE[auto_index]
		if auto_walk:
			direction = player.position.direction_to(target)
	if direction != Vector2.ZERO:
		player.facing = direction
		player.queue_redraw()
	var step := direction * 100.0 * minf(delta,.05)
	var candidate := player.position + step
	if is_on_path(candidate):
		player.position = candidate
	else:
		for axis: Vector2 in [Vector2(step.x,0),Vector2(0,step.y)]:
			if is_on_path(player.position+axis):
				player.position += axis

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_SPACE:
			if not auto_walk:
				player.position = ROUTE[0]
				auto_index = 1
			auto_walk = not auto_walk
		KEY_R:
			player.position = ROUTE[0]
			auto_walk = false
		KEY_H:
			for card: Node2D in overlays:
				card.visible = not card.visible
		KEY_ESCAPE:
			get_tree().quit()

func capture() -> void:
	ui.hide()
	var output := "res://output/finished-latest-forest/previews/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for pose: String in ["unchanged","entrance","root-behind","root-front"]:
		player.visible = pose != "unchanged"
		if pose == "root-behind":
			player.position = Vector2(674,322)
		elif pose == "root-front":
			player.position = Vector2(674,365)
		else:
			player.position = ROUTE[0]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(output+"godot-"+pose+".png")
		if error != OK:
			get_tree().quit(1)
			return
	print("Latest forest screenshots saved")
	get_tree().quit()
