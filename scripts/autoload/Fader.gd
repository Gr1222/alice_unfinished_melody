extends CanvasLayer
## Autoload：全屏淡入淡出。用法：await Fader.fade_out(1.0) / await Fader.fade_in(1.0)
## 位于最上层（盖住对话框与所有 UI），不拦截鼠标。

const FADE_LAYER := 100

var _rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = FADE_LAYER
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

## 变黑。
func fade_out(duration := 1.0) -> void:
	await _fade_to(1.0, duration)

## 变亮。
func fade_in(duration := 1.0) -> void:
	await _fade_to(0.0, duration)

## 立即变黑或变亮（无动画）。
func set_black(black: bool) -> void:
	if _tween: _tween.kill()
	_rect.modulate.a = 1.0 if black else 0.0

func is_black() -> bool:
	return _rect.modulate.a >= 0.999

func is_clear() -> bool:
	return _rect.modulate.a <= 0.001

func _fade_to(alpha: float, duration: float) -> void:
	if _tween: _tween.kill()
	if duration <= 0.0:
		_rect.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", alpha, duration)
	await _tween.finished
