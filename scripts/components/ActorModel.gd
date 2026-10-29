extends Node3D
class_name ActorModel
## 角色/道具的“外观槽”：按 data/models.json 里的 model_id 显示 3D 模型，没有模型时显示占位贴图。
## 换成正式模型只需：把 .glb 放进 assets/models/，在 models.json 填 scene 路径（必要时调 scale / offset / yaw_degrees）。
## 导演与角色脚本只调用本类的 face_toward / set_motion / play_state，不关心里面是模型还是贴图。

const MODELS_PATH := "res://data/models.json"
## 模型转向的速度（弧度/秒）。
@export var turn_speed := 12.0
@export var model_id := ""

## 当前实例化出来的正式模型（没有则为 null）与占位节点（有模型时为 null）。
var model: Node3D
var placeholder: Node3D
var animation_player: AnimationPlayer
## 用于判断“屏幕左右”的镜头；为空时用当前视口的镜头。
var camera: Camera3D
var state := ""
var _config := {}
var _target_yaw := 0.0
var _faces := "front"
var _visual: Node3D

func _ready() -> void:
	if model_id != "": apply_config(load_config(model_id))

static func load_config(id: String) -> Dictionary:
	var file := FileAccess.open(MODELS_PATH, FileAccess.READ)
	if file == null:
		push_error("找不到 %s" % MODELS_PATH)
		return {}
	var all = JSON.parse_string(file.get_as_text())
	if all is Dictionary and all.has(id): return all[id]
	push_warning("models.json 中没有 %s" % id)
	return {}

## 按配置重建外观（测试或运行中换模型也可调用）。
func apply_config(config: Dictionary) -> void:
	if _visual: _visual.queue_free()
	_visual = null
	model = null
	placeholder = null
	animation_player = null
	state = ""
	_config = config
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var path := String(config.get("scene", ""))
	if path != "": _build_model(path)
	if model == null: _build_placeholder(config.get("placeholder", {}))
	_visual.scale = Vector3.ONE * float(config.get("scale", 1.0))
	_visual.position = _vec3(config.get("offset", [0, 0, 0]))
	_target_yaw = deg_to_rad(float(config.get("yaw_degrees", 0)))
	_visual.rotation.y = _target_yaw
	play_state("idle")

func _build_model(path: String) -> void:
	var resource: Resource = load(path) if ResourceLoader.exists(path) else null
	if not resource is PackedScene:
		push_warning("%s: 模型 %s 无法加载，改用占位" % [model_id, path])
		return
	model = resource.instantiate()
	_visual.add_child(model)
	animation_player = _find_animation_player(model)
	if animation_player:
		# 导入的动画默认不循环，待机和行走需要循环。
		for key in ["idle", "walk"]:
			var animation: Variant = _animation_for(key)
			if animation != null and animation_player.has_animation(animation):
				animation_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR

func _build_placeholder(spec: Dictionary) -> void:
	var type := String(spec.get("type", "none"))
	if type == "none": return
	var node: Node3D
	if type == "animated_sprite":
		var animated := AnimatedSprite3D.new()
		animated.sprite_frames = load(spec["frames"])
		animated.animation = &"idle_down"
		_style_sprite(animated, spec)
		node = animated
	else:
		var sprite := Sprite3D.new()
		sprite.texture = load(spec["texture"])
		_style_sprite(sprite, spec)
		if spec.has("tint"):
			var tint: Array = spec["tint"]
			sprite.modulate = Color(tint[0], tint[1], tint[2])
		node = sprite
	node.name = "Placeholder"
	_faces = String(spec.get("faces", "front"))
	_visual.add_child(node)
	placeholder = node

func _style_sprite(sprite: SpriteBase3D, spec: Dictionary) -> void:
	sprite.pixel_size = float(spec.get("pixel_size", 0.01))
	var offset: Array = spec.get("offset", [0, 0])
	sprite.offset = Vector2(offset[0], offset[1])
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = bool(spec.get("shaded", false))

func _vec3(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _view_camera() -> Camera3D:
	return camera if camera else get_viewport().get_camera_3d()

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer: return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found: return found
	return null

func _animation_for(key: String) -> Variant:
	var names: Dictionary = _config.get("animations", {})
	return names.get(key)

## 播放状态动画（idle / walk / jump）。模型里没有对应动画就保持当前，不报错。
func play_state(new_state: String) -> void:
	if new_state == state: return
	state = new_state
	if animation_player == null: return
	var animation: Variant = _animation_for(new_state)
	if animation != null and animation_player.has_animation(animation):
		animation_player.play(animation)

## 面向世界坐标里的某个方向。模型：平滑转身；单张贴图：按镜头左右翻转。
func face_toward(direction: Vector3) -> void:
	direction.y = 0
	if direction.length_squared() < 0.0001: return
	if model != null:
		_target_yaw = atan2(direction.x, direction.z) + deg_to_rad(float(_config.get("yaw_degrees", 0)))
	elif placeholder is Sprite3D:
		var view := _view_camera()
		if view == null or _faces == "front": return
		var to_right := direction.dot(view.global_basis.x) > 0
		placeholder.flip_h = to_right if _faces == "left" else not to_right

## 每帧由角色脚本调用：facing 是最近一次的朝向，moving 是否在走，airborne 是否在空中。
func set_motion(facing: Vector3, moving: bool, airborne := false) -> void:
	if model != null:
		if moving: face_toward(facing)
		play_state("jump" if airborne and _animation_for("jump") != null else ("walk" if moving else "idle"))
	elif placeholder is AnimatedSprite3D:
		_update_four_direction(placeholder, facing, moving)
	elif moving:
		face_toward(facing)

## 占位行走图：侧面贴图原图朝右，向左走时翻转。
func _update_four_direction(sprite: AnimatedSprite3D, facing: Vector3, moving: bool) -> void:
	var local := facing
	var view := _view_camera()
	if view:
		local = Vector3(facing.dot(view.global_basis.x), 0, facing.dot(view.global_basis.z))
	var animation := "walk_" if moving else "idle_"
	var flip := false
	if absf(local.x) > absf(local.z):
		animation += "right"
		flip = local.x < 0
	elif local.z >= 0:
		animation += "down"
	else:
		animation += "up"
	sprite.flip_h = flip
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)

func _process(delta: float) -> void:
	if model == null or _visual == null: return
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, minf(1.0, turn_speed * delta))
