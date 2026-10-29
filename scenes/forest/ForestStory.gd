extends "res://scenes/prologue/Prologue.gd"
## Reuse the original story, portraits and puzzle; bind locations to the 3D map.
var world: Node3D

func _ready() -> void:
	external_world = true
	rabbit_run_speed = 160.0
	super._ready()
	world = get_parent()
	shade.size = get_viewport_rect().size
	set_process(false)
	set_process_input(false)

func key(_a: Key, _b: Key) -> bool:
	return false # CharacterBody3D is the only exploration controller.

func _draw() -> void:
	if chapter:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("111b24"))
		super._draw()

func nearby_fragment() -> int:
	if not is_instance_valid(world) or not is_instance_valid(world.get("actor")):return -1
	for i in range(2):
		if world.call("at_landmark","fragment_%d" % i,.55) and not MelodyProgress.has_fragment(melody_phrase.phrase_id,melody_phrase.fragment_ids[i]):return i
	return -1

func interact() -> void:
	world.call("sync_story_position")
	super.interact()

func update_ui() -> void:
	super.update_ui()
	help.text = "WASD / 方向键移动　空格跳跃　E 调查 / Enter 继续　Esc 暂停　R 重玩　Tab 全图"
	if investigated:help.text += "　按住 E 观察过去"
	if stage>=3:help.text += "　M 乐谱"
	if world!=null and world.call("at_landmark","roots",.7) and not path_found and stage==3 and lines.is_empty():
		prompt.text = "[E] 调查侧根后一直存在的小径"
