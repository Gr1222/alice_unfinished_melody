extends Camera3D
class_name CameraRig
## 剧情镜头：平时平滑跟随目标（爱丽丝），演出时可以平移到任意点再返回。
## 用法：await camera.pan_to(point, 2.0) / await camera.return_to_target(1.5)

## 镜头相对注视点的偏移（决定俯视角度与距离）。
@export var offset := Vector3(0, 4.5, 6.5)
## 注视点高于脚底的高度。
@export var look_height := 0.8
## 跟随的平滑程度，越大越紧。
@export var follow_speed := 5.0

var target: Node3D
var following := true
## 当前注视点（脚底高度）。
var focus := Vector3.ZERO
var _tween: Tween

func _process(delta: float) -> void:
	if following and is_instance_valid(target):
		focus = focus.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	apply_focus()

func apply_focus() -> void:
	global_position = focus + offset
	look_at(focus + Vector3(0, look_height, 0))

## 立即对准目标（场景开始时使用）。
func snap_to_target() -> void:
	if is_instance_valid(target): focus = target.global_position
	following = true
	apply_focus()

## 停止跟随，平移到 point。
func pan_to(point: Vector3, duration := 2.0) -> void:
	following = false
	await _tween_focus(point, duration)

## 平移回目标后恢复跟随。
func return_to_target(duration := 1.5) -> void:
	following = false
	if is_instance_valid(target): await _tween_focus(target.global_position, duration)
	following = true

## 屏幕右方向在地面上的投影，用于判断角色在屏幕上向左还是向右移动。
func screen_right() -> Vector3:
	var right := global_basis.x
	right.y = 0
	return right.normalized()

func _tween_focus(point: Vector3, duration: float) -> void:
	if _tween: _tween.kill()
	if duration <= 0.0:
		focus = point
		apply_focus()
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "focus", point, duration)
	await _tween.finished
