extends Button

## 碎片托盘和拼合槽共用的拖放控件。
var puzzle: Node
var fragment_id := ""
var slot_index := -1

func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or fragment_id.is_empty(): return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 22)
	set_drag_preview(preview)
	return {"fragment": fragment_id, "puzzle": puzzle.get_instance_id()}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if slot_index < 0 or not data is Dictionary: return false
	if data.get("puzzle", -1) != puzzle.get_instance_id(): return false
	return puzzle.can_place(data.get("fragment", ""), slot_index)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	puzzle.place_fragment(data["fragment"], slot_index)

func _gui_input(event: InputEvent) -> void:
	if slot_index >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		puzzle.remove_fragment(slot_index)
		accept_event()
