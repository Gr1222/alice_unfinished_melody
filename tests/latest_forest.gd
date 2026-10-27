extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(1))
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(label)

func has_3d(node: Node) -> bool:
	if node is Node3D or node is SubViewport:
		return true
	for child: Node in node.get_children():
		if has_3d(child): return true
	return false

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var scene = load("res://scenes/art/LatestForest.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	check(not has_3d(scene),"runtime is 2D only")
	check(scene.SOURCE.get_size() == Vector2(8192,4608),"original 8K source")
	check(scene.overlays.size() == 4,"four silhouette layers")
	for card: Node2D in scene.overlays:
		var sprite: Sprite2D = card.get_child(0)
		check(sprite.texture == scene.SOURCE,"layer reuses exact original RGB")
		var texture: Texture2D = sprite.material.get_shader_parameter("silhouette")
		check(texture.get_size() == Vector2(2048,1152),"mask registration")
	for point: Vector2 in scene.ROUTE:
		check(scene.is_on_path(point),"route point reachable")
	check(not scene.is_on_path(Vector2(200,80)),"distant forest blocked")
	check(not scene.is_on_path(Vector2(600,530)),"pool outside walking route")
	scene._unhandled_key_input(key(KEY_SPACE))
	var steps := 0
	var stayed_on_path := true
	while scene.auto_walk and steps < 2000:
		scene._physics_process(1.0/60.0)
		stayed_on_path = stayed_on_path and scene.is_on_path(scene.player.position)
		steps += 1
	check(stayed_on_path,"auto walk remains on route for the full traversal")
	check(not scene.auto_walk,"auto walk terminates")
	check(scene.player.position.distance_to(scene.ROUTE[-1]) < 6,"auto walk reaches tree doorway")
	scene._unhandled_key_input(key(KEY_H))
	check(not scene.overlays[0].visible,"occlusion comparison hides masks")
	scene._unhandled_key_input(key(KEY_H))
	check(scene.overlays[0].visible,"occlusion comparison restores masks")
	scene._unhandled_key_input(key(KEY_R))
	check(scene.player.position == scene.ROUTE[0],"reset returns to entrance")
	print("Latest forest: %d passed, %d failed; auto walk %d frames" % [passed,failed,steps])
	scene.queue_free()
	quit(0 if failed == 0 else 1)
