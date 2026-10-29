extends RefCounted
class_name ItemDatabase
## 道具定义（只读数据），来自 data/items.json。
## 字段：name / category / description（字符串 key）、icon（图片路径，空 = 用 icon_color 圆形占位）、
##       icon_color、tune_puzzle（有值则详情页显示【调律】按钮）、tune_requires_flag（按钮出现所需的剧情标记）

const ITEMS_PATH := "res://data/items.json"

static var _items: Dictionary = {}

static func all() -> Dictionary:
	if _items.is_empty():
		_items = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	return _items

static func has(item_id: String) -> bool:
	return all().has(item_id)

static func get_item(item_id: String) -> Dictionary:
	if not has(item_id): push_error("找不到道具：%s（请在 %s 中添加）" % [item_id, ITEMS_PATH])
	return all().get(item_id, {})

static func icon_texture(item_id: String) -> Texture2D:
	var path := String(get_item(item_id).get("icon", ""))
	return load(path) if not path.is_empty() else null

static func icon_color(item_id: String) -> Color:
	return Color(String(get_item(item_id).get("icon_color", "#cccccc")))

## 圆形占位图标样式（没有图标图片时使用）。
static func icon_style(item_id: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = icon_color(item_id)
	style.set_corner_radius_all(999)
	style.border_color = style.bg_color.darkened(0.35)
	style.set_border_width_all(4)
	return style
