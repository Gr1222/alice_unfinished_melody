extends RigidBody2D
class_name PuzzleSegment
## 下方音轨被切开后的一个片段：真实物理（下落、与边框和其他片段碰撞、旋转）。
## 宽度与音频时长成正比；片段上画出拍线，方便玩家对齐。

## 撞击速度足够大时发出（解谜界面据此抖动）。
signal impacted(speed: float)

const HEIGHT := 64.0
const CORNER_RADIUS := 10
const IMPACT_MIN_SPEED := 220.0

var index := 0
## 片段在原音轨中的起止时间（秒）。
var from := 0.0
var to := 0.0
var size := Vector2(100, HEIGHT)
var color := Color("e0bd62")
var pixels_per_second := 125.0
var beat := 0.5
## 已放到音轨上（不再参与物理）。
var placed := false
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

var _last_speed := 0.0
## slide_to() 的移动状态。
var _slide_from := Vector2.ZERO
var _slide_to := Vector2.ZERO
var _slide_rotation_from := 0.0
var _slide_time := 0.0
var _slide_t := -1.0

func setup(segment_index: int, start: float, end: float, scale_px: float, beat_length: float, segment_color: Color) -> void:
	index = segment_index
	from = start
	to = end
	pixels_per_second = scale_px
	beat = beat_length
	color = segment_color
	size = Vector2((end - start) * scale_px, HEIGHT)

func _ready() -> void:
	name = "Segment%d" % index
	contact_monitor = true
	max_contacts_reported = 4
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.8
	physics_material_override = material
	var shape := RectangleShape2D.new()
	# 略小于画面尺寸，避免相邻片段一开始就互相挤压
	shape.size = size - Vector2(2, 2)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_last_speed = linear_velocity.length()
	if _slide_t < 0.0: return
	_slide_t = minf(_slide_t + delta / _slide_time, 1.0)
	var eased := 1.0 - pow(1.0 - _slide_t, 3.0)
	global_position = _slide_from.lerp(_slide_to, eased)
	rotation = lerpf(_slide_rotation_from, 0.0, eased)
	sync_to_physics()
	if _slide_t >= 1.0: _slide_t = -1.0

## 把节点当前的位置直接写进物理引擎。
## 冻结的刚体只改节点位置时，物理引擎可能还保留旧位置，之后又把节点“拉回去”（片段跳回出生点的 bug）。
func sync_to_physics() -> void:
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

## 冻结并平滑移动到 target（同时转正）。
## 注意：物理刚体的位置由物理引擎管理，不能用普通 Tween 移动，必须在物理帧里设置。
func slide_to(target: Vector2, duration := 0.2) -> void:
	freeze = true
	_slide_from = global_position
	_slide_to = target
	_slide_rotation_from = rotation
	_slide_time = maxf(duration, 0.001)
	_slide_t = 0.0

## 立即冻结并停在当前位置（拖拽开始时）。
func hold() -> void:
	freeze = true
	_slide_t = -1.0
	sync_to_physics()

func is_sliding() -> bool:
	return _slide_t >= 0.0

func _on_body_entered(_body: Node) -> void:
	if _last_speed >= IMPACT_MIN_SPEED: impacted.emit(_last_speed)

## 屏幕坐标（解谜画布坐标）是否落在片段上（考虑旋转）。
func contains_point(point: Vector2) -> bool:
	return Rect2(-size * 0.5, size).has_point(to_local(point))

## 放回物理中（重置或拖拽松手时）。
func release() -> void:
	_slide_t = -1.0
	placed = false
	collision_layer = 1
	collision_mask = 1
	freeze = false

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(0.25) if highlighted else color
	style.border_color = Color.WHITE if highlighted else color.darkened(0.4)
	style.set_border_width_all(4 if highlighted else 3)
	style.set_corner_radius_all(CORNER_RADIUS)
	var rect := Rect2(-size * 0.5, size)
	draw_style_box(style, rect)
	# 拍线：按原音轨中的绝对时间画，片段换位置后玩家仍能看出节拍
	var first := ceili(from / beat - 0.001)
	var k := first
	while k * beat < to - 0.001:
		var x := rect.position.x + (k * beat - from) * pixels_per_second
		if k * beat > from + 0.001:
			draw_line(Vector2(x, rect.position.y + 10), Vector2(x, rect.end.y - 10), color.darkened(0.35), 2.0)
		# 每拍一个小“滴答”圆点
		draw_circle(Vector2(x + beat * pixels_per_second * 0.5, 0), 5.0, color.darkened(0.45))
		k += 1
