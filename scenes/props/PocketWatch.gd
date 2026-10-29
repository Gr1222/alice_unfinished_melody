extends Node3D
## 地上发光的怀表：上下浮动并缓慢旋转。被拾取后调用 collect() 隐藏。

@export var bob_height := 0.06
@export var bob_speed := 2.0
@export var spin_speed := 0.8

@onready var visual: Node3D = $Visual
@onready var interactable: Interactable = $Interactable

var _time := 0.0
var _base_y := 0.0

func _ready() -> void:
	_base_y = visual.position.y

func _process(delta: float) -> void:
	_time += delta
	visual.position.y = _base_y + sin(_time * bob_speed) * bob_height
	visual.rotation.y += spin_speed * delta

func collect() -> void:
	interactable.enabled = false
	hide()
