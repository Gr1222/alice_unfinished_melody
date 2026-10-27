extends CanvasLayer

signal closed
signal completed

const DISPLAY_ORDER := [2, 0, 1]
const TILE_SCRIPT := preload("res://scenes/music/MelodyTile.gd")
var phrase: Resource
var arrangement: Array[String] = []
var drafts: Dictionary = {}
var selected_slot := -1
var active := false
var audio_queue: Array[AudioStream] = []
@onready var layout: VBoxContainer = $Backdrop/Margin/Layout
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

func _ready() -> void:
	hide()
	layout.get_node("Actions/Undo").pressed.connect(undo)
	layout.get_node("Actions/Check").pressed.connect(submit)
	layout.get_node("Actions/Listen").pressed.connect(listen_arrangement)
	layout.get_node("Actions/Whole").pressed.connect(listen_restored)
	layout.get_node("Actions/Close").pressed.connect(close)
	audio_player.finished.connect(play_next)

func open(data: Resource) -> void:
	stop_audio()
	phrase = data
	active = true
	arrangement.clear()
	arrangement.assign(drafts.get(phrase.phrase_id, phrase.solution if MelodyProgress.is_restored(phrase.phrase_id) else []))
	selected_slot = -1
	show()
	for child in layout.get_node("Fragments").get_children():
		child.free()
	# 序章展示顺序固定以便教学；后续乐句可有任意数量碎片。
	var order: Array = DISPLAY_ORDER if phrase.fragment_ids.size() == 3 else range(phrase.fragment_ids.size())
	for index in order:
		var button := Button.new()
		button.set_script(TILE_SCRIPT)
		button.puzzle = self
		button.custom_minimum_size = Vector2(0, 100)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 21)
		var id: String = phrase.fragment_ids[index]
		button.fragment_id = id
		button.text = "%d · %s\n%s" % [layout.get_node("Fragments").get_child_count() + 1, phrase.fragment_names[index], phrase.visual_clues[index]]
		button.disabled = not MelodyProgress.has_fragment(phrase.phrase_id, id)
		if button.disabled: button.text = "尚未找到"
		button.pressed.connect(choose.bind(id))
		layout.get_node("Fragments").add_child(button)
	for child in layout.get_node("Slots").get_children(): child.free()
	for index in range(phrase.fragment_ids.size()):
		var slot := Button.new()
		slot.set_script(TILE_SCRIPT)
		slot.puzzle = self
		slot.slot_index = index
		slot.custom_minimum_size = Vector2(0, 90)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_font_size_override("font_size", 21)
		slot.pressed.connect(select_slot.bind(index))
		layout.get_node("Slots").add_child(slot)
	layout.get_node("Heading").text = "未完成的旋律 / " + phrase.display_name
	layout.get_node("Feedback").text = "已修复的开头仍在这里；后面的乐句还散落在别处。" if MelodyProgress.is_restored(phrase.phrase_id) else "这些纹样也许能接回刚才断掉的那一句。可以随时返回探索。"
	layout.get_node("AudioStatus").text = "音频待上传，当前用视觉线索拼合。P 试听排列，L 回听。"
	refresh()
	(layout.get_node("Actions/Close") as Button).grab_focus()

func refresh() -> void:
	var names: PackedStringArray = []
	for id in arrangement:
		names.append("□" if id.is_empty() else phrase.fragment_names[phrase.fragment_ids.find(id)])
	layout.get_node("Arrangement").text = "当前排列：" + ("（空）" if names.is_empty() else " → ".join(names))
	layout.get_node("Progress").text = "大旋律：" + MelodyProgress.summary()
	for i in range(layout.get_node("Fragments").get_child_count()):
		var index: int = DISPLAY_ORDER[i] if phrase.fragment_ids.size() == 3 else i
		var id: String = phrase.fragment_ids[index]
		layout.get_node("Fragments").get_child(i).disabled = id in arrangement or not MelodyProgress.has_fragment(phrase.phrase_id, id)
	for i in range(layout.get_node("Slots").get_child_count()):
		var slot: Button = layout.get_node("Slots").get_child(i)
		slot.fragment_id = arrangement[i] if i < arrangement.size() else ""
		slot.text = "%d · 空槽\n拖入碎片" % (i + 1)
		if not slot.fragment_id.is_empty():
			var index: int = phrase.fragment_ids.find(slot.fragment_id)
			slot.text = "%d · %s\n%s" % [i + 1, phrase.fragment_names[index], phrase.visual_clues[index]]
		slot.modulate = Color(1.0, 0.86, 0.55) if selected_slot == i else Color.WHITE
		if arrangement == phrase.solution and MelodyProgress.is_restored(phrase.phrase_id):
			slot.modulate = Color(0.7, 1.0, 0.8)

func choose(id: String) -> void:
	if id in arrangement: return
	var empty_slot := arrangement.find("")
	place_fragment(id, selected_slot if selected_slot >= 0 else (empty_slot if empty_slot >= 0 else arrangement.size()))

func can_place(id: String, index: int) -> bool:
	return active and index >= 0 and index < phrase.fragment_ids.size() and id in phrase.fragment_ids and MelodyProgress.has_fragment(phrase.phrase_id, id)

func place_fragment(id: String, index: int) -> void:
	if not can_place(id, index): return
	stop_audio()
	var source := arrangement.find(id)
	# 精确放入指定槽位；允许先填第三槽，再补前面的空槽。
	while arrangement.size() <= index: arrangement.append("")
	if source >= 0:
		var other := arrangement[index]
		arrangement[index] = id
		arrangement[source] = other
	else:
		arrangement[index] = id
	trim_empty_tail()
	selected_slot = -1
	refresh()
	layout.get_node("Feedback").text = "已放入「%s」。对照两侧意象，连接下一枚碎片。" % phrase.fragment_names[phrase.fragment_ids.find(id)]
	listen_ids([id])

func select_slot(index: int) -> void:
	if not active: return
	if selected_slot == index:
		selected_slot = -1
	elif selected_slot >= 0 and selected_slot < arrangement.size() and index < arrangement.size():
		place_fragment(arrangement[selected_slot], index)
		return
	else:
		selected_slot = index
	refresh()

func remove_fragment(index: int) -> void:
	if not active or index < 0 or index >= arrangement.size(): return
	stop_audio()
	arrangement.remove_at(index)
	trim_empty_tail()
	selected_slot = -1
	layout.get_node("Feedback").text = "已移回碎片托盘，后面的碎片向前补位。"
	refresh()

func trim_empty_tail() -> void:
	while not arrangement.is_empty() and arrangement.back().is_empty():
		arrangement.pop_back()

func undo() -> void:
	if not active: return
	stop_audio()
	selected_slot = -1
	if not arrangement.is_empty(): arrangement.pop_back()
	trim_empty_tail()
	layout.get_node("Feedback").text = "已撤回，可以重新排列。"
	refresh()

func submit() -> void:
	if not active: return
	stop_audio()
	var was_restored: bool = MelodyProgress.is_restored(phrase.phrase_id)
	if MelodyProgress.restore_phrase(phrase, arrangement):
		layout.get_node("Feedback").text = "纹样接上了，洞口的光正回应这一句……\n返回探索，看看它还想告诉爱丽丝什么。" if phrase.phrase_id == "prologue" else "本章乐句已接回大旋律。"
		listen_arrangement()
		refresh()
		if not was_restored: completed.emit()
	else:
		layout.get_node("Feedback").text = "还未接通。检查相邻碎片的末尾与开头是否一致；需要使用全部碎片。"

func listen_arrangement() -> void:
	listen_ids(arrangement)

func listen_ids(ids: Array[String]) -> void:
	stop_audio()
	if ids.is_empty():
		layout.get_node("AudioStatus").text = "请先选择碎片。"
		return
	for id in ids:
		var stream: AudioStream = phrase.audio_for(id)
		if stream == null:
			stop_audio()
			layout.get_node("AudioStatus").text = "音频待上传 · 可根据碎片意象完成拼合与视觉回应。"
			return
		audio_queue.append(stream)
	layout.get_node("AudioStatus").text = "正在试听……"
	play_next()

func listen_restored() -> void:
	stop_audio()
	if MelodyProgress.restored.is_empty():
		layout.get_node("AudioStatus").text = "尚无修复完成的乐句。"
		return
	for restored_phrase in MelodyProgress.restored:
		for id in restored_phrase.solution:
			var stream: AudioStream = restored_phrase.audio_for(id)
			if stream == null:
				stop_audio()
				layout.get_node("AudioStatus").text = "已记录修复进度；累计旋律等待音频上传。"
				return
			audio_queue.append(stream)
	play_next()

func play_next() -> void:
	if audio_queue.is_empty(): return
	audio_player.stream = audio_queue.pop_front()
	audio_player.play()

func stop_audio() -> void:
	audio_player.stop()
	audio_queue.clear()

func close() -> void:
	if not active: return
	drafts[phrase.phrase_id] = arrangement.duplicate()
	stop_audio()
	active = false
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]: return
	# 允许焦点导航；快捷键独立消费，避免 Enter 同时提交并触发按钮。
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_ESCAPE: close()
		KEY_BACKSPACE: undo()
		KEY_ENTER: submit()
		KEY_DELETE: remove_fragment(selected_slot if selected_slot >= 0 else arrangement.size() - 1)
		KEY_P: listen_arrangement()
		KEY_L: listen_restored()
		KEY_1, KEY_2, KEY_3:
			var slot: int = event.keycode - KEY_1
			if slot < layout.get_node("Fragments").get_child_count():
				var index: int = DISPLAY_ORDER[slot] if phrase.fragment_ids.size() == 3 else slot
				choose(phrase.fragment_ids[index])
