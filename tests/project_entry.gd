extends SceneTree
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func run() -> void:
	# 主场景已切换为新序章；旧 demo 场景仍作为回归测试直接加载。
	var main := String(ProjectSettings.get_setting("application/run/main_scene"))
	check(main=="res://scenes/chapters/prologue/Prologue3D.tscn","F5 starts the new prologue")
	var scene: Node = load("res://scenes/forest/ForestPrologue.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	check(scene.get_node_or_null("ForestModel")!=null,"forest model serialized in scene tree")
	check(scene.get_node("ForestModel").get_child_count()>20,"forest model resources imported")
	var models := 0
	for child: Node in scene.get_children():
		if child is Node3D and child.get_child_count()>20 and child.name!="OuterPathWalls" and child.name!="TreesAndStandingStoneCollision":models += 1
	check(models==1,"no duplicated runtime model")
	check(scene.get_node_or_null("Story/MelodyPuzzle")!=null,"original puzzle in same forest scene")
	check(scene.get("rabbit_actor").visible,"rabbit present in default project entry")
	check(not scene.get("story").lines.is_empty(),"original opening dialogue in forest")
	check(ResourceLoader.exists("res://scenes/prologue/Prologue.tscn"),"original 2D regression scene retained")
	print("Project entry: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
