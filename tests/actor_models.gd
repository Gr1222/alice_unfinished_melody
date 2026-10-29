extends SceneTree
## 外观槽验证：爱丽丝 / 兔子 / 姐姐 / 兔子洞的外观由 data/models.json 配置，
## 换成正式 .glb 模型时无需改代码。这里用代码生成的假模型模拟“换模型”。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

## 生成一个带 idle / walk / jump 动画的假模型，动画名故意带前缀，检验映射。
## 三视图占位：朝向镜头 = 正面，背对 = 背面，左右 = 侧面（按原图朝向翻转）。
func check_directional(prologue: Node, actor: Node3D, label: String, side_faces: String) -> void:
	var cam: Camera3D = prologue.get_node("Camera")
	actor.camera = cam
	var sprite: Sprite3D = actor.placeholder
	var right := cam.global_basis.x
	var toward := cam.global_basis.z
	actor.face_toward(toward)
	var front: Texture2D = sprite.texture
	actor.face_toward(-toward)
	var back: Texture2D = sprite.texture
	check(front != back, "%s：朝向镜头与背对镜头用不同贴图" % label)
	actor.face_toward(right)
	var side: Texture2D = sprite.texture
	var flip_right := sprite.flip_h
	actor.face_toward(-right)
	check(sprite.texture == side and sprite.flip_h != flip_right, "%s：向左/向右用同一张侧面图并翻转" % label)
	check(side != front and side != back, "%s：侧面图与正反面不同" % label)
	check(flip_right == (side_faces == "left"), "%s：向右走时%s" % [label, "翻转" if side_faces == "left" else "不翻转"])
	check(is_equal_approx(sprite.offset.y, sprite.texture.get_height() * 0.5), "%s：贴图底边对齐脚底" % label)

func make_fake_model(path: String) -> void:
	var root := Node3D.new()
	root.name = "FakeModel"
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	for animation_name in ["Armature|Idle", "Armature|Walk", "Armature|Jump"]:
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(animation_name, animation)
	player.add_animation_library("", library)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path)
	root.free()

func run() -> void:
	# 1. models.json 合法，所有填了的模型路径都存在
	var file := FileAccess.open("res://data/models.json", FileAccess.READ)
	var all = JSON.parse_string(file.get_as_text())
	check(all is Dictionary, "models.json 是合法 JSON")
	for id in ["alice", "rabbit", "sister", "rabbit_hole"]:
		check(all.has(id), "models.json 有 %s" % id)
		var scene_path: String = all[id].get("scene", "")
		check(scene_path == "" or ResourceLoader.exists(scene_path), "%s 的模型路径存在（%s）" % [id, scene_path])

	# 2. 序章里的四个外观槽
	var prologue: Node = load("res://scenes/chapters/prologue/Prologue3D.tscn").instantiate()
	root.add_child(prologue)
	await process_frame
	var alice_model: Node3D = prologue.get_node("Actors/Alice/Model")
	var rabbit: Node3D = prologue.get_node("Actors/WhiteRabbit")
	var sister: Node3D = prologue.get_node("Actors/Sister")
	var hole: Node3D = prologue.get_node("Props/RabbitHole")
	check(alice_model.placeholder is AnimatedSprite3D and alice_model.model == null, "爱丽丝没有正式模型时显示占位行走图")
	check(rabbit.placeholder is Sprite3D and sister.placeholder is Sprite3D, "兔子、姐姐显示三视图贴图")
	check_directional(prologue, rabbit, "side_faces_left", "left")
	check_directional(prologue, sister, "side_faces_right", "right")
	check(hole.placeholder is MeshInstance3D and hole.model == null, "兔子洞没有模型时显示地面深色圆盘占位")

	# 3. 换成假模型：爱丽丝
	var fake_path := "user://fake_model.tscn"
	make_fake_model(fake_path)
	var config := {
		"scene": fake_path, "scale": 2.0, "offset": [0, 0.5, 0], "yaw_degrees": 90,
		"animations": {"idle": "Armature|Idle", "walk": "Armature|Walk", "jump": "Armature|Jump"},
		"placeholder": {"type": "none"}
	}
	alice_model.apply_config(config)
	check(alice_model.model != null and alice_model.placeholder == null, "填了 scene 后显示正式模型，占位消失")
	check(alice_model.model.get_parent().scale.is_equal_approx(Vector3.ONE * 2.0), "scale 生效")
	check(alice_model.model.get_parent().position.is_equal_approx(Vector3(0, 0.5, 0)), "offset 生效")
	var player: AnimationPlayer = alice_model.animation_player
	check(player != null and player.current_animation == "Armature|Idle", "默认播放映射后的待机动画")
	check(player.get_animation("Armature|Walk").loop_mode == Animation.LOOP_LINEAR, "待机/行走动画自动设为循环")
	alice_model.set_motion(Vector3.RIGHT, true)
	check(player.current_animation == "Armature|Walk", "移动时播放行走动画")
	alice_model.set_motion(Vector3.RIGHT, false)
	check(player.current_animation == "Armature|Idle", "停下后播放待机动画")
	alice_model.set_motion(Vector3.RIGHT, true, true)
	check(player.current_animation == "Armature|Jump", "在空中播放跳跃动画")

	# 朝向：模型平滑转向行走方向（+X → yaw = 90° + yaw_degrees 修正）
	alice_model.face_toward(Vector3.RIGHT)
	for i in range(60): await process_frame
	var visual: Node3D = alice_model.model.get_parent()
	check(absf(angle_difference(visual.rotation.y, PI)) < 0.05, "模型转向行走方向（yaw=%.2f）" % visual.rotation.y)

	# 4. 兔子：换模型后导演用到的接口仍可用
	rabbit.apply_config(config)
	rabbit.face_toward(Vector3(0, 0, -1))
	rabbit.play_state("jump")
	check(rabbit.animation_player.current_animation == "Armature|Jump", "兔子跳跃播放跳跃动画")
	rabbit.play_state("nonexistent")
	check(rabbit.animation_player.current_animation == "Armature|Jump", "没有对应动画时保持当前，不报错")

	# 5. 兔子洞换模型
	hole.apply_config({"scene": fake_path, "scale": 1.0, "offset": [0, 0, 0], "animations": {"idle": "Armature|Idle"}})
	check(hole.model != null, "兔子洞可以换模型")

	# 6. 路径写错：退回占位，不崩溃
	sister.apply_config({"scene": "res://assets/models/不存在.glb", "placeholder": all["sister"]["placeholder"]})
	check(sister.model == null and sister.placeholder != null, "模型路径错误时退回占位")

	print("actor_models: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
