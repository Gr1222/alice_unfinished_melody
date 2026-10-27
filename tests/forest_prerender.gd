extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Forest test timed out")
		quit(1))
	call_deferred("execute")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: "+label)

func contains_3d(node: Node) -> bool:
	if node is Node3D or node is SubViewport:
		return true
	for child: Node in node.get_children():
		if contains_3d(child):
			return true
	return false

func execute() -> void:
	var scene = load("res://scenes/art/ForestPrerender2D.tscn").instantiate()
	root.add_child(scene)
	scene.player.movement_enabled = false
	await physics_frame
	await physics_frame
	check(not contains_3d(scene),"2D runtime contains no Node3D or render viewport")
	check(scene.sorted.y_sort_enabled,"objects and player share Y sorting")
	var background: Sprite2D = scene.get_node("BakedGround")
	check(background.texture.get_size() == Vector2(480,270),"baked native resolution")
	for layer: Dictionary in scene.manifest.layers:
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(scene.FOLDER+layer.file))
		check(not image.is_empty() and not image.is_invisible(),"nonempty layer "+layer.id)
		check(image.get_used_rect().has_area() and image.detect_alpha() != Image.ALPHA_NONE,"alpha layer "+layer.id)
	var target: Node2D = scene.anchors[scene.manifest.occlusion_test.layer]
	var behind: Vector2 = scene.point(scene.manifest.occlusion_test.behind)
	var front: Vector2 = scene.point(scene.manifest.occlusion_test.front)
	check(behind.y < target.position.y and front.y > target.position.y,"sample crosses tree sorting baseline")
	# Sweep the player across the full bridge, then through the river beside it.
	scene.player.position = scene.point(scene.manifest.spawn)
	var bridge_hit: KinematicCollision2D = scene.player.move_and_collide(Vector2(0,-60))
	check(bridge_hit == null,"bridge permits crossing from south bank to north bank")
	var water: PackedVector2Array = scene.points(scene.manifest.blockers[1])
	var center_x := (water[0].x+water[1].x)*0.5
	scene.player.position = Vector2(center_x,water[0].y-12)
	var river_hit: KinematicCollision2D = scene.player.move_and_collide(Vector2(0,50))
	check(river_hit != null,"river blocks walking outside bridge")
	scene.player.position = target.position+Vector2(15,0)
	var trunk_hit: KinematicCollision2D = scene.player.move_and_collide(Vector2(-20,0))
	check(trunk_hit != null,"tree footprint blocks player")
	print("Forest prerender: %d passed, %d failed" % [passed,failed])
	scene.queue_free()
	quit(0 if failed == 0 else 1)
