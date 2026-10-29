extends CanvasLayer
class_name DialogueBox
## 对话框界面：只负责显示（立绘、名字、逐字文本），不读取数据，由 DialogueManager 驱动。
## 布局与样式都在 DialogueBox.tscn 中，美术可以直接在编辑器里调整。

const CHARS_PER_SECOND := 40.0
## 非说话一方的立绘变暗。
const DIM_COLOR := Color(0.55, 0.55, 0.6)
## 名字标签与对话框左右边缘的距离。
const NAME_INSET := 40.0

@onready var left_portrait: TextureRect = $Root/LeftArea/LeftPortrait
@onready var right_portrait: TextureRect = $Root/RightArea/RightPortrait
@onready var panel: Control = $Root/Panel
@onready var text_label: RichTextLabel = $Root/Panel/Text
@onready var name_tag: PanelContainer = $Root/NameTag
@onready var name_label: Label = $Root/NameTag/NameLabel
@onready var next_indicator: Label = $Root/NextIndicator

var _typing := false
var _shown := 0.0
var _time := 0.0

func _ready() -> void:
	hide()

func open() -> void:
	show()

func close() -> void:
	_typing = false
	left_portrait.hide()
	right_portrait.hide()
	hide()

## left / right：角色数据（含 texture、faces、waist），空字典表示该侧无人。
## active："left" / "right" 为说话一方，"" 为旁白（两侧都变暗，不显示名字）。
func show_line(display_name: String, text: String, left: Dictionary, right: Dictionary, active: String) -> void:
	set_portrait(left_portrait, left, true, active == "left")
	set_portrait(right_portrait, right, false, active == "right")
	name_tag.visible = not display_name.is_empty()
	if name_tag.visible:
		name_label.text = display_name
		name_tag.reset_size()
		var x := panel.position.x + NAME_INSET
		if active == "right":
			x = panel.position.x + panel.size.x - NAME_INSET - name_tag.size.x
		name_tag.position = Vector2(x, panel.position.y - name_tag.size.y + 6)
	text_label.text = text
	text_label.visible_characters = 0
	_shown = 0.0
	_typing = true

func is_typing() -> bool:
	return _typing

func finish_typing() -> void:
	_typing = false
	text_label.visible_characters = -1

## 立绘按 waist（腰部位于原图高度的比例）缩放，使头到腰正好填满显示区域，腰以下被裁掉。
## 立绘始终面向屏幕中央：faces 为原图朝向（left / right / front）。
func set_portrait(rect: TextureRect, data: Dictionary, on_left: bool, highlighted: bool) -> void:
	var texture: Texture2D = data.get("texture")
	rect.visible = texture != null
	if texture == null: return
	rect.texture = texture
	var area: Control = rect.get_parent()
	var source_size := texture.get_size()
	rect.size = source_size * (area.size.y / (source_size.y * float(data.get("waist", 0.5))))
	rect.position = Vector2((area.size.x - rect.size.x) * 0.5, 0)
	var faces := String(data.get("faces", "front"))
	rect.flip_h = faces == "left" if on_left else faces == "right"
	rect.modulate = Color.WHITE if highlighted else DIM_COLOR

func _process(delta: float) -> void:
	if not visible: return
	_time += delta
	if _typing:
		_shown += CHARS_PER_SECOND * delta
		if _shown >= text_label.get_total_character_count():
			finish_typing()
		else:
			text_label.visible_characters = int(_shown)
	next_indicator.visible = not _typing
	next_indicator.modulate.a = 0.55 + 0.45 * sin(_time * 5.0)
