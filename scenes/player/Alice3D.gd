extends CharacterBody3D
class_name Alice3D
## 爱丽丝：WASD / 方向键移动，空格跳跃。GameState 锁定操作时（对话、演出）不响应输入。
## 移动方向相对镜头：W 永远是屏幕上方。移动/跳跃逻辑参考旧 demo 的 SpatialForest.gd。

@export var speed := 2.4
@export var jump_speed := 4.8
@export var gravity := 13.0
## 用于把输入转换为屏幕方向；为空时使用世界坐标轴（x 向右，-z 向上）。
@export var camera: Camera3D

## 累计行走距离（米），新手教程用来判断玩家是否学会了移动。
var walked_distance := 0.0
var facing := Vector3(0, 0, 1)
## 起跳时的水平方向：空中松开方向键时继续保持。
var _air_direction := Vector3.ZERO

## 外观槽（占位贴图或正式模型），配置在 data/models.json 的 "alice"。
@onready var model: ActorModel = $Model

func _physics_process(delta: float) -> void:
	var controllable: bool = GameState.can_control()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if controllable else Vector2.ZERO
	var direction := input_to_world(input)
	if is_on_floor():
		_air_direction = Vector3.ZERO
		if velocity.y < 0: velocity.y = 0
		if controllable and Input.is_action_just_pressed("jump"):
			velocity.y = jump_speed
			_air_direction = direction
	if not is_on_floor() or velocity.y > 0:
		velocity.y -= gravity * delta
		if direction == Vector3.ZERO: direction = _air_direction
	var before := global_position
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	var step := global_position - before
	step.y = 0
	walked_distance += step.length()
	update_animation(direction)

func input_to_world(input: Vector2) -> Vector3:
	if input == Vector2.ZERO: return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera:
		right = camera.global_basis.x
		forward = -camera.global_basis.z
	right.y = 0
	forward.y = 0
	return (right.normalized() * input.x + forward.normalized() * -input.y).normalized()

## 记录朝向并交给外观槽播放动画（占位贴图与正式模型共用）。
func update_animation(direction: Vector3) -> void:
	var moving := direction.length_squared() > 0.0001
	if moving: facing = direction
	model.camera = camera
	model.set_motion(facing, moving, not is_on_floor())
