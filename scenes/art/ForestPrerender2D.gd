extends Node2D
## Runtime contains only images, 2D sorting and 2D collisions. No 3D rendering.

const FOLDER := "res://assets/forest_prerender/"
const Player = preload("res://scenes/art/ForestStudyPlayer.gd")
var player: CharacterBody2D
var sorted: Node2D
var manifest: Dictionary
var ui: CanvasLayer
var anchors: Dictionary = {}

func _ready() -> void:
	get_window().size = Vector2i(960,540)
	get_window().content_scale_size = Vector2i(480,270)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"manifest.json"))
	var background := Sprite2D.new()
	background.name = "BakedGround"
	background.texture = load(FOLDER+manifest.background)
	background.centered = false
	add_child(background)
	sorted = Node2D.new()
	sorted.name = "SortedObjects"
	sorted.y_sort_enabled = true
	add_child(sorted)
	for layer: Dictionary in manifest.layers:
		var anchor := Node2D.new()
		anchor.name = layer.id
		anchor.position = point(layer.pivot)
		sorted.add_child(anchor)
		anchors[layer.id] = anchor
		var sprite := Sprite2D.new()
		sprite.texture = load(FOLDER+layer.file)
		sprite.centered = false
		sprite.position = point(layer.offset)
		anchor.add_child(sprite)
		var body := StaticBody2D.new()
		anchor.add_child(body)
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = float(layer.collision_radius)
		collision.shape = shape
		body.add_child(collision)
	for polygon: Array in manifest.blockers:
		var body := StaticBody2D.new()
		var shape := CollisionPolygon2D.new()
		shape.polygon = points(polygon)
		body.add_child(shape)
		add_child(body)
	var bounds := points(manifest.bounds)
	for i in range(bounds.size()):
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var segment := SegmentShape2D.new()
		segment.a = bounds[i]
		segment.b = bounds[(i+1)%bounds.size()]
		collision.shape = segment
		body.add_child(collision)
		add_child(body)
	player = Player.new()
	player.name = "Player"
	player.position = point(manifest.spawn)
	sorted.add_child(player)
	ui = CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.position = Vector2(8,6)
	label.add_theme_font_size_override("font_size",10)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.text = "PRERENDER + 2D / EXPERIMENT\nWASD / Arrows: move   R: reset   Esc: exit\nBaked images + Y sorting / Alice static direction poses"
	ui.add_child(label)
	if "--capture-prerender" in OS.get_cmdline_user_args():
		capture()

func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func points(values: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for value: Array in values:
		polygon.append(point(value))
	return polygon

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_R:
		player.position = point(manifest.spawn)

func capture() -> void:
	player.movement_enabled = false
	ui.hide()
	for pose: String in ["overview","behind","front"]:
		if pose != "overview":
			player.position = point(manifest.occlusion_test[pose])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png("res://output/forest-study/prerender-2d-"+pose+".png")
		if error != OK:
			get_tree().quit(1)
			return
	print("2D prerender screenshots saved; no Node3D runtime.")
	get_tree().quit()
