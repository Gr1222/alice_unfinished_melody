extends SceneTree
## 第 2 步验证：对话数据完整性、左右立绘规则、？？？名字、逐字显示、操作锁。
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error(message)

func run() -> void:
	var manager: Node = root.get_node("DialogueManager")
	var state: Node = root.get_node("GameState")
	var bus: Node = root.get_node("EventBus")
	var box: DialogueBox = manager.box
	state.reset()

	# 数据完整性：每句话的 key 都有中英文，每个说话者都在 characters.json 中。
	check(manager.dialogues.size() >= 8, "序章对话已加载")
	for id: String in manager.dialogues:
		var data: Dictionary = manager.dialogues[id]
		if data.get("mode") == "talk":
			check(manager.characters.has(data.get("with", "")), "%s 的 with 角色存在" % id)
		for line: Dictionary in data.lines:
			if line.has("know"):
				check(manager.characters.has(line.know), "%s 的 know 角色存在" % id)
				continue
			var key := String(line.text)
			for locale in ["zh", "en"]:
				TranslationServer.set_locale(locale)
				check(tr(key) != key, "%s 缺少 %s 文本" % [key, locale])
			TranslationServer.set_locale("zh")
			var speaker := String(line.get("speaker", ""))
			check(speaker.is_empty() or manager.characters.has(speaker), "%s 的说话者 %s 存在" % [key, speaker])

	# 字体覆盖：strings.csv 中每个中文字符都必须能被 UI 字体显示（否则会出现方块）。
	var font: Font = load(ProjectSettings.get_setting("gui/theme/custom_font"))
	var missing := {}
	var csv := FileAccess.open("res://data/i18n/strings.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 2: continue
		for i in range(row[1].length()):
			var code := row[1].unicode_at(i)
			if code > 32 and not font.has_char(code): missing[row[1][i]] = row[0]
	check(missing.is_empty(), "UI 字体缺少字符：%s" % str(missing))

	# 独白：兔子在左侧，名字为 ？？？，立绘翻转以面向屏幕中央（原图朝左）。
	manager.play("prologue_rabbit_pass")
	check(manager.is_active() and box.visible, "独白开始后对话框显示")
	check(not state.can_control(), "对话期间锁定操作")
	check(box.name_label.text == "？？？", "未知的兔子显示 ？？？")
	check(box.left_portrait.visible and not box.right_portrait.visible, "独白只在左侧显示立绘")
	check(box.left_portrait.texture == manager.characters.rabbit.texture and box.left_portrait.flip_h, "兔子独白在左侧并面向中央")
	check(box.is_typing(), "文本逐字显示")
	manager.advance()
	check(not box.is_typing() and box.text_label.visible_characters == -1, "第一次推进补全本句")
	var finished_ids: Array[String] = []
	bus.dialogue_finished.connect(func(id: String): finished_ids.append(id))
	manager.advance()
	check(not manager.is_active() and not box.visible, "最后一句后关闭")
	check(state.can_control(), "对话结束后恢复操作")
	check(finished_ids == ["prologue_rabbit_pass"], "发出 dialogue_finished 信号")

	# 对话：爱丽丝永远在左，兔子在右；名字显示在说话一方。
	manager.play("prologue_rabbit_talk")
	check(box.left_portrait.texture == manager.characters.alice.texture, "对话中爱丽丝在左")
	check(box.right_portrait.texture == manager.characters.rabbit.texture and not box.right_portrait.flip_h, "兔子在右且面向中央")
	check(box.right_portrait.modulate == Color.WHITE and box.left_portrait.modulate != Color.WHITE, "说话一方高亮，另一方变暗")
	check(box.name_tag.position.x > 640, "兔子说话时名字在右侧")
	box.finish_typing()
	manager.advance()
	check(box.name_label.text == "爱丽丝" and box.name_tag.position.x < 640, "爱丽丝说话时名字在左侧")
	var safety := 20
	while manager.is_active() and box.name_label.text != "白兔":
		box.finish_typing()
		manager.advance()
		safety -= 1
		if safety <= 0: break
	check(box.name_label.text == "白兔", "know 之后兔子显示真名")
	while manager.is_active() and safety > 0:
		box.finish_typing()
		manager.advance()
		safety -= 1
	check(not manager.is_active(), "对话可以完整走完")

	# 输入：dialogue_next 推进对话并被吞掉。
	manager.play("prologue_wake")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	manager._input(press)
	check(not box.is_typing(), "Enter 补全当前句")
	# 每句需要两次按键（补全 + 下一句）：第 2 句 2 次、第 3 句 2 次、最后 1 次关闭。
	for i in range(4): manager._input(press)
	check(manager.is_active(), "第 3 句显示完时对话仍未结束")
	manager._input(press)
	check(not manager.is_active(), "再按一次后对话结束")
	check(state.is_character_known("rabbit"), "know 写入 GameState")
	state.reset()
	print("Dialogue manager: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
