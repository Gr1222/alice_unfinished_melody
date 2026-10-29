extends Node3D
## 结尾的音符：发光圆盘（爱丽丝站在上面）+ 上方缓慢旋转浮动的音符符号。
## 符号用 3D 网格拼成（符头 + 符干 + 符尾），不依赖字体里有没有 ♪。

@export var spin_speed := 1.2
@export var bob_height := 0.08
@export var bob_speed := 2.5

@onready var symbol: Node3D = $Symbol

var _time := 0.0
var _symbol_y := 0.0

func _ready() -> void:
	_symbol_y = symbol.position.y

## 爱丽丝踩上来之前收起符号（否则符号会和她的身体重叠）。
func hide_symbol(duration := 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(symbol, "scale", Vector3.ZERO, duration)
	tween.tween_callback(symbol.hide)

func _process(delta: float) -> void:
	if not visible: return
	_time += delta
	symbol.rotation.y += spin_speed * delta
	symbol.position.y = _symbol_y + sin(_time * bob_speed) * bob_height
