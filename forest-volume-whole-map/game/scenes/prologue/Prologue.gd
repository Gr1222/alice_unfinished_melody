extends Node2D

const Art = preload("res://scripts/UserArt.gd")
const ALICE_PORTRAIT_FRAME := Rect2(65, 180, 365, 374)
const NPC_PORTRAIT_FRAME := Rect2(795, 215, 285, 339)
var facing := Vector2.DOWN

@export var melody_phrase: Resource
@onready var melody_puzzle: CanvasLayer = $MelodyPuzzle
const FRAGMENT_POSITIONS := [Vector2(775, 350), Vector2(860, 455)]
const RIM := Vector2(875, 370)
const ROOTS := Vector2(930, 445)
const ENTRY := Vector2(1000, 445)
const TRAIL := [Vector2(860, 375), Vector2(880, 405), Vector2(900, 435), Vector2(935, 455), Vector2(970, 450)]
const HOLE := Vector2(1010, 350)
const WATCH := Vector2(430, 370)
var player := Vector2(120, 370)
var rabbit := Vector2(300, 330)
var stage := 0
var investigated := false
var seen := false
var path_found := false
var observation_reported := false
var melody_response_pending := false
var melody_response_played := false
var response_pulse := 0.0
var past := false
var paused := false
var chapter := false
var running := false
var jumping := false
var hold := 0.0
var observation := 0.0
var time := 0.0
var fade := 1.0
var ending := false
var lines: Array[String] = []
var callback := ""
var title: Label
var status: Label
var prompt: Label
var speech: Label
var panel: PanelContainer
var shade: ColorRect
var pause_label: Label
var help: Label
var portrait: TextureRect
var portrait_frame: Control

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	melody_puzzle.closed.connect(_on_melody_closed)
	melody_puzzle.completed.connect(_on_melody_completed)
	var ui := CanvasLayer.new()
	add_child(ui)
	title = make_label(ui, Vector2(32, 24), Vector2(1080, 85), 24)
	status = make_label(ui, Vector2(32, 115), Vector2(1080, 40), 18)
	prompt = make_label(ui, Vector2(120, 500), Vector2(950, 45), 21)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help = make_label(ui, Vector2(32, 674), Vector2(1100, 35), 17)
	portrait_frame = Control.new()
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	panel = PanelContainer.new()
	panel.position = Vector2(65, 546)
	panel.size = Vector2(1020, 120)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var frame := StyleBoxTexture.new()
	frame.texture = Art.FRAME
	frame.texture_margin_left = 22
	frame.texture_margin_right = 22
	frame.texture_margin_top = 20
	frame.texture_margin_bottom = 22
	frame.content_margin_left = 36
	frame.content_margin_right = 36
	frame.content_margin_top = 18
	frame.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", frame)
	ui.add_child(panel)
	speech = Label.new()
	speech.custom_minimum_size = Vector2(948, 78)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.add_theme_font_size_override("font_size", 21)
	speech.add_theme_color_override("font_color", Color("392f29"))
	panel.add_child(speech)
	pause_label = make_label(ui, Vector2(300, 270), Vector2(600, 150), 32)
	pause_label.text = "已暂停\nEsc 继续 · R 从头开始"
	pause_label.hide()
	shade = ColorRect.new()
	shade.size = Vector2(1152, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	say(["爱丽丝：……这是哪里？我刚才明明还在……", "远处传来钟表声。沿发光脚印前进，寻找声音的来源。"])

func make_label(parent: Node, pos: Vector2, bounds: Vector2, size: int) -> Label:
	var item := Label.new()
	item.position = pos
	item.size = bounds
	item.add_theme_font_size_override("font_size", size)
	parent.add_child(item)
	return item

func say(texts: Array[String], action: String = "") -> void:
	past = false
	hold = 0.0
	lines = texts
	callback = action
	panel.show()
	speech.text = lines[0] + "\n[E / 空格 继续]"
	update_portrait()

func update_portrait() -> void:
	portrait.hide()
	if lines.is_empty(): return
	var current := lines[0]
	if current.begins_with("爱丽丝") and current.contains("："):
		portrait.texture = Art.ALICE_PORTRAIT
		place_portrait(true)
	elif current.begins_with("白兔") and current.contains("："):
		portrait.texture = Art.RABBIT_PORTRAIT
		place_portrait(false)

func place_portrait(is_alice: bool) -> void:
	# Keep the full source image. Its lower body extends behind the dialogue box.
	# The frame clips anything below the opaque box so legs cannot cover controls.
	var frame := ALICE_PORTRAIT_FRAME if is_alice else NPC_PORTRAIT_FRAME
	portrait_frame.position = frame.position
	portrait_frame.size = frame.size
	var source_size := portrait.texture.get_size()
	# Portraits have different anatomy: the rabbit's ears occupy much of its height.
	var waist_fraction := 0.44 if is_alice else 0.70
	var visible_height := panel.position.y - frame.position.y
	var uniform_scale := visible_height / (source_size.y * waist_fraction)
	portrait.size = source_size * uniform_scale
	portrait.position = Vector2((frame.size.x - portrait.size.x) * 0.5, 0)
	portrait.show()

func advance() -> void:
	lines.pop_front()
	if not lines.is_empty():
		speech.text = lines[0] + "\n[E / 空格 继续]"
		update_portrait()
		return
	panel.hide()
	portrait.hide()
	if callback == "jump": jumping = true
	var offer_melody := callback == "arrange" and path_found and MelodyProgress.has_all(melody_phrase) and not MelodyProgress.is_restored(melody_phrase.phrase_id)
	callback = ""
	if offer_melody: open_melody()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	if melody_puzzle.active: return
	if event.pressed and event.keycode == KEY_R:
		MelodyProgress.reset()
		get_tree().reload_current_scene()
		return
	if event.pressed and event.keycode == KEY_M and stage >= 3 and not paused and not ending and lines.is_empty():
		open_melody()
		get_viewport().set_input_as_handled()
		return
	if event.pressed and event.keycode == KEY_ESCAPE and not ending:
		paused = not paused
		past = false
		hold = 0.0
		observation = 0.0
		pause_label.visible = paused
		return
	if paused or ending or chapter: return
	if not lines.is_empty():
		if event.pressed and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			advance()
		return
	if event.keycode == KEY_E:
		if event.pressed:
			hold = 0.001
		else:
			if hold <= 0.0: return
			var held := hold >= 0.25
			hold = 0.0
			past = false
			observation = 0.0
			if held and seen and not observation_reported:
				observation_reported = true
				say(["爱丽丝：刚才那是……白兔留下的影子？", "它绕到了树根后面。怀表让我看见了这里之前发生的事。"])
			elif not held: interact()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		hold = 0.0
		past = false
		observation = 0.0

func _process(delta: float) -> void:
	if paused or melody_puzzle.active: return
	time += delta
	response_pulse = maxf(0.0, response_pulse - delta)
	if ending:
		fade = minf(1, fade + delta * 0.7)
		if fade >= 1:
			chapter = true
			ending = false
			player = Vector2(540, 370)
			past = false
			hold = 0.0
			observation = 0.0
	else:
		fade = maxf(0, fade - delta * 0.8)
	shade.color = Color(0, 0, 0, fade)
	if chapter:
		title.text = "第一章 · 未完成的旋律"
		status.text = "怀表：序章用途已结束 · 大旋律已修复 %d 段" % MelodyProgress.restored.size()
		prompt.text = "M 查看大旋律 / 回听已修复乐句 · R 重新体验序章"
		help.text = "第一章入口占位 · 后续章节收集碎片并修复同一首大旋律的下一段"
		queue_redraw()
		return
	if lines.is_empty() and not running and not jumping and not ending:
		var dir := Vector2(float(key(KEY_D, KEY_RIGHT)) - float(key(KEY_A, KEY_LEFT)), float(key(KEY_S, KEY_DOWN)) - float(key(KEY_W, KEY_UP)))
		if not past and dir != Vector2.ZERO: facing = dir
		if not past: player += dir.normalized() * 235 * delta
		player.x = clampf(player.x, 65, 1080)
		player.y = clampf(player.y, 265, 465)
		# 洞口始终存在；沿外缘绕到树根后，不会因观察而改变碰撞。
		if player.distance_to(HOLE) < 86:
			player = HOLE + (player - HOLE).normalized() * 86
		if hold > 0:
			hold += delta
			past = hold >= 0.25 and investigated and player.distance_to(RIM) < 120
		if past:
			observation += delta
			if observation >= 1.8: seen = true
		else:
			observation = 0.0
		if stage == 0 and player.x > 260:
			stage = 1
			running = true
	if running:
		rabbit.x += delta * 390
		if rabbit.x > 920:
			running = false
			rabbit = Vector2(925, 315)
			say(["白兔：来不及了！", "白兔跑远了，一只金色怀表掉在路边。靠近后轻点 E 调查。"])
	if stage == 2 and player.x > 655 and lines.is_empty():
		stage = 3
		say(["白兔：你拿了我的怀表？", "爱丽丝：这是你掉的。那是什么洞？我怎么回去？", "白兔伸手取表：把它给我！它维持着这个世界的秩序。", "洞口传来一段断续的旋律，像是在等待下一句。", "爱丽丝无意识地接出了后面的几个音。", "白兔停住伸出的手，猛然后退：你怎么会知道后面的旋律？", "白兔：人类不应该听见它真正的声音……"], "jump")
	if jumping:
		rabbit = rabbit.move_toward(HOLE, delta * 140)
		if rabbit.distance_to(HOLE) < 4:
			jumping = false
			say(["白兔消失在洞口，那段旋律也随之断开。", "爱丽丝：刚才那一句……为什么我会知道？", "洞边留着几片带有相似纹样的碎片。爱丽丝：它又是从哪里下去的？脚印到这里就断了。"])
	update_ui()
	queue_redraw()

func key(a: Key, b: Key) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func update_ui() -> void:
	var goal := "沿着脚印，寻找声音的来源"
	if stage == 1: goal = "拾取白兔掉落的怀表"
	if stage == 2: goal = "跟随白兔，前往黑洞"
	if stage == 3: goal = "调查洞口，寻找白兔经过的痕迹"
	if investigated: goal = "在断掉的脚印附近，按住 E 观察过去"
	if seen: goal = "回到现在，沿洞边寻找树根后的小径"
	if path_found: goal = "小径已找到 · 可整理旋律碎片，也可继续追寻白兔"
	if MelodyProgress.is_restored(melody_phrase.phrase_id): goal = "序章乐句已修复 · 沿小径主动进入黑洞"
	title.text = "序章 / 黑森林\n" + goal
	status.text = ("怀表：已获得" if stage >= 2 else "怀表：未获得") + "  ·  " + ("过去 · 白兔残影与旧脚印" if past else "现在") + ("  ·  已发现下行小径" if path_found else "")
	if stage >= 3:
		status.text += "  ·  旋律碎片 %d/3" % MelodyProgress.collected.get(melody_phrase.phrase_id, []).size()
	help.text = "WASD / 方向键 移动    E 调查    E / 空格 / Enter 对话    Esc 暂停    R 重玩"
	if investigated: help.text += "    按住 E 观察过去"
	if stage >= 3: help.text += "    M 乐谱"
	prompt.text = ""
	if not lines.is_empty() or running or jumping: return
	if stage == 1 and player.distance_to(WATCH) < 85: prompt.text = "[E] 拾取白兔的怀表"
	elif stage == 3 and nearby_fragment() >= 0:
		prompt.text = "[E] 拾取旋律碎片 · " + melody_phrase.fragment_names[nearby_fragment()]
	elif stage == 3 and path_found and player.distance_to(ENTRY) < 45:
		prompt.text = "[E] 沿小径进入黑洞    [M] 停下整理旋律碎片"
	elif stage == 3 and not path_found and player.distance_to(ROOTS) < 55:
		prompt.text = "[E] 调查树根后的缝隙"
	elif stage == 3 and not path_found and player.distance_to(RIM) < 120:
		prompt.text = "[E] 调查断掉的脚印" if not investigated else ("白兔的残影绕向树根后 · 松开 E 回到现在" if past else "按住 E 观察过去 · 松开回到现在")

func interact() -> void:
	if running or jumping or paused or ending or chapter or past or melody_puzzle.active or not lines.is_empty(): return
	if stage == 1 and player.distance_to(WATCH) < 85:
		stage = 2
		say(["获得物品 · 白兔的怀表", "指针逆向转动。表盘上的刻度像某种陌生的乐谱。", "短促的旋律响起，森林里的滴答声重叠了一瞬，又恢复安静。"])
	elif stage == 3 and nearby_fragment() >= 0:
		var index := nearby_fragment()
		MelodyProgress.collect(melody_phrase.phrase_id, melody_phrase.fragment_ids[index])
		var pickup_lines: Array[String] = ["拾起带有相同乐谱纹样的碎片 · " + melody_phrase.fragment_names[index], "碎片上的痕迹：" + melody_phrase.visual_clues[index] + "。它和刚才断掉的那一句有关。"]
		if path_found and MelodyProgress.has_all(melody_phrase):
			pickup_lines.append("爱丽丝：碎片的纹样能接在一起……我想试着把刚才那一句找回来。")
		say(pickup_lines, "arrange")
	elif stage == 3 and path_found and player.distance_to(ENTRY) < 45:
		past = false
		hold = 0.0
		ending = true
	elif stage == 3 and not path_found and player.distance_to(ROOTS) < 55:
		path_found = true
		MelodyProgress.collect(melody_phrase.phrase_id, melody_phrase.fragment_ids[2])
		var path_lines: Array[String] = ["树根后藏着一条下行小径，边缘留有新鲜的擦痕。", "爱丽丝：原来路一直在这里，只是被树根挡住了视线。", "树根间还夹着一枚相同纹样的碎片 · 余韵（回声 → 静默）。"]
		path_lines.append("爱丽丝：刚才断掉的那一句……好像就在这些碎片里。" if MelodyProgress.has_all(melody_phrase) else "爱丽丝：洞边似乎还有同样的碎片。也许它们原本连在一起。")
		say(path_lines, "arrange")
	elif stage == 3 and not path_found and player.distance_to(RIM) < 120:
		if not investigated:
			investigated = true
			say(["脚印在洞口边缘断了。怀表指针忽然停顿，空气中响起重叠的滴答声。", "爱丽丝：它在回应这里的痕迹……（按住 E 观察，松开回到现在）"])
		elif seen:
			say(["爱丽丝：白兔的影子绕向了树根后面，我应该去那里看看。"])
		else: say(["脚印像是被时间抹去了。怀表的指针仍在轻轻颤动。"])

func nearby_fragment() -> int:
	for i in range(FRAGMENT_POSITIONS.size()):
		if player.distance_to(FRAGMENT_POSITIONS[i]) < 42 and not MelodyProgress.has_fragment(melody_phrase.phrase_id, melody_phrase.fragment_ids[i]):
			return i
	return -1

func open_melody() -> void:
	past = false
	hold = 0.0
	observation = 0.0
	melody_puzzle.open(melody_phrase)

func _on_melody_closed() -> void:
	hold = 0.0
	if melody_response_pending and not chapter and not ending:
		melody_response_pending = false
		melody_response_played = true
		response_pulse = 4.0
		say(["拼起的纹样逐一亮起。洞中的光也循着相同的节奏回应。", "爱丽丝：它认得这一句……但后面还有一段，我没有的部分。", "原来还没有结束。白兔和后面的旋律，都在里面。"])
	update_ui()

func _on_melody_completed() -> void:
	if not melody_response_played and not chapter:
		melody_response_pending = true

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), Color("223e49") if past else Color("111b24"))
	if chapter:
		draw_rect(Rect2(150, 260, 850, 210), Color("34474d"))
		draw_person(player, false)
		return
	draw_rect(Rect2(45, 250, 1060, 235), Color("426063") if past else Color("29353b"))
	for i in range(18):
		var x := 45.0 + i * 62
		draw_rect(Rect2(x, 160, 18, 90), Color("1b2b30"))
		draw_circle(Vector2(x + 9, 158), 40, Color("182a2e"))
		draw_rect(Rect2(x + 16, 485, 14, 45), Color("1b2b30"))
	for i in range(22):
		draw_circle(Vector2(180 + i * 35, 390 + sin(i * 0.65) * 25), 4, Color(0.7, 0.85, 0.8, 0.45 + sin(time * 2 - i) * 0.2))
	draw_circle(HOLE, 82, Color("514357"))
	draw_circle(HOLE, 68 + sin(time * 2) * 3, Color("06090e"))
	draw_arc(HOLE, 77, time, time + 3, 32, Color("c8b77c"), 3)
	if response_pulse > 0:
		draw_arc(HOLE, 83 + sin(time * 5) * 4, 0, TAU, 48, Color(0.9, 0.8, 0.5, minf(response_pulse, 1.0)), 4)
	# 小径和树根在现在/过去中几何位置一致，发现只改变目标与提示。
	for i in range(6):
		draw_rect(Rect2(900 + i * 17, 446 - i * 2, 15, 18), Color("52615b"))
	draw_line(Vector2(910, 400), Vector2(947, 439), Color("26352d"), 18)
	draw_line(Vector2(947, 439), Vector2(977, 422), Color("26352d"), 12)
	draw_line(Vector2(910, 400), Vector2(891, 458), Color("26352d"), 13)
	for i in range(3):
		draw_circle(RIM + Vector2(-25 + i * 9, -9 + i * 5), 3, Color("728078"))
	if stage >= 3 and not jumping and callback != "jump":
		for i in range(FRAGMENT_POSITIONS.size()):
			if not MelodyProgress.has_fragment(melody_phrase.phrase_id, melody_phrase.fragment_ids[i]):
				var position: Vector2 = FRAGMENT_POSITIONS[i]
				draw_circle(position, 17 + sin(time * 3) * 2, Color(0.9, 0.7, 0.4, 0.18))
				draw_rect(Rect2(position - Vector2(8, 12), Vector2(16, 24)), Color("d3ba7d"))
				draw_line(position + Vector2(-4, -3), position + Vector2(4, -3), Color("4a4848"), 2)
	if past:
		for i in range(TRAIL.size()):
			if observation >= i * 0.3:
				draw_circle(TRAIL[i] + Vector2(-4, -3), 3, Color("d8cda0"))
				draw_circle(TRAIL[i] + Vector2(4, 3), 3, Color("d8cda0"))
		var progress := clampf(observation / 1.8, 0.0, 1.0) * (TRAIL.size() - 1)
		var segment := mini(int(progress), TRAIL.size() - 2)
		var echo_position: Vector2 = TRAIL[segment].lerp(TRAIL[segment + 1], progress - segment)
		draw_person(echo_position, true, true)
	if stage == 1:
		draw_circle(WATCH, 21 + sin(time * 3) * 3, Color(0.8, 0.7, 0.4, 0.16))
		draw_circle(WATCH, 10, Color("dfc580"))
		draw_line(WATCH, WATCH + Vector2(cos(-time * 3), sin(-time * 3)) * 8, Color("413a2e"), 2)
	if running or stage == 2 or jumping: draw_person(rabbit, true)
	draw_person(player, false)

func draw_person(pos: Vector2, bunny: bool, echo: bool = false) -> void:
	draw_circle(pos + Vector2(0, 5), 16, Color(0, 0, 0, 0.3))
	Art.draw_character(self, pos + Vector2(0, 5), Vector2.RIGHT if bunny else facing, bunny, echo)
