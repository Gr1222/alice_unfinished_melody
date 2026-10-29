extends CanvasLayer
class_name TuningPuzzle
## 调律解谜（序章：怀表）。流程见 run()：
##   开场动画 → 上下两条音轨完整播放（不能操作）→ 下方音轨切成 3~5 段并掉落（真实物理 + 界面抖动）
##   → 点击片段试听、拖到下方音轨上按放入顺序排列（顺序自由）→ 全部放入后出现【确认】
##   → 播放玩家的排列 → 结束动画 → 返回排列结果（片段编号数组）。
## 进入后不能中途退出：所有键盘输入都被吞掉。数据来自 data/puzzles/<puzzle_id>.json。

signal confirm_requested

const LOCK_REASON := "puzzle"
const PUZZLE_DIR := "res://data/puzzles/"
## 音轨区域（像素）：左边缘、宽度、两条音轨的顶部 y 与高度。
const LANE_X := 140.0
const LANE_WIDTH := 1000.0
const MELODY_LANE_Y := 120.0
const ITEM_LANE_Y := 230.0
const LANE_HEIGHT := 80.0
## 物理托盘的边框：左右墙与地面（片段从下方音轨掉进这里）。
const TRAY_LEFT := 40.0
const TRAY_RIGHT := 1240.0
const TRAY_FLOOR := 700.0
const SEGMENT_COLORS := [Color("e0bd62"), Color("e8a35a"), Color("d6c36e"), Color("eec07a"), Color("c9a24e")]
const MELODY_COLOR := Color("4a8fe0")
## 鼠标按下到松开移动不超过这个距离算“点击”（试听），否则算拖拽。
const CLICK_DISTANCE := 8.0
## 拖到音轨附近多少像素内松手就算放入。
const DROP_MARGIN := 40.0
const SHAKE_DECAY := 40.0
## 进入解谜时背景音乐淡出、结束后淡入恢复的时长（秒）。
const MUSIC_FADE := 1.0

@export var puzzle_id := "watch"
## 测试用：加快所有等待与播放计时。
@export var time_scale := 1.0
@export var intro_time := 1.0
@export var settle_time := 1.2
@export var outro_time := 1.2
## 片段掉落时随机冲量的大小。
@export var scatter_impulse := Vector2(180, 80)

var config: Dictionary
var duration := 8.0
var beat := 0.5
var cuts: Array = []
var melody_stream: AudioStream
var item_stream: AudioStream
var segments: Array[PuzzleSegment] = []
var placed: Array[PuzzleSegment] = []
var interactive := false
var cut_done := false

var _drag: PuzzleSegment = null
var _drag_offset := Vector2.ZERO
var _press_position := Vector2.ZERO
var _previewing: PuzzleSegment = null
var _shake := 0.0
var _show_playhead := false

@onready var root_control: Control = $Root
@onready var decor: Control = $Root/Decor
@onready var title_label: Label = $Root/Title
@onready var hint_label: Label = $Root/Hint
@onready var melody_name: Label = $Root/MelodyHeader/Box/Name
@onready var item_name: Label = $Root/ItemHeader/Box/Name
@onready var melody_volume: HSlider = $Root/MelodyHeader/Box/Volume
@onready var item_volume: HSlider = $Root/ItemHeader/Box/Volume
@onready var playhead: ColorRect = $Root/Playhead
@onready var reset_button: Button = $Root/Reset
@onready var confirm_button: Button = $Root/Confirm
@onready var flash: ColorRect = $Flash
@onready var tray: Node2D = $Tray
@onready var sequencer: TrackSequencer = $Sequencer

func _ready() -> void:
	load_config()
	title_label.text = tr("UI_TUNE")
	melody_name.text = tr(String(config.get("melody_track_name", "NAME_ALICE")))
	item_name.text = tr(String(config.get("item_track_name", "")))
	reset_button.text = tr("UI_RESET")
	confirm_button.text = tr("UI_PUZZLE_CONFIRM")
	confirm_button.hide()
	reset_button.disabled = true
	playhead.hide()
	reset_button.pressed.connect(reset_segments)
	confirm_button.pressed.connect(_on_confirm_pressed)
	melody_volume.value_changed.connect(func(v: float): sequencer.set_volume("melody", v))
	item_volume.value_changed.connect(func(v: float): sequencer.set_volume("item", v))
	decor.draw.connect(_draw_decor)
	build_tray_walls()
	sequencer.time_scale = time_scale

func load_config() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(PUZZLE_DIR + puzzle_id + ".json"))
	duration = float(config.duration)
	cuts = config.cuts
	var placeholder: Dictionary = config.get("placeholder", {})
	beat = float(placeholder.get("beat", 0.5))
	var melody_path := String(config.get("melody", ""))
	var item_path := String(config.get("item_track", ""))
	melody_stream = load(melody_path) if not melody_path.is_empty() else ToneGenerator.piano(placeholder.get("melody_notes", []), beat, duration)
	item_stream = load(item_path) if not item_path.is_empty() else ToneGenerator.ticks(duration, beat, placeholder.get("bell_notes", []))

func pixels_per_second() -> float:
	return LANE_WIDTH / duration

func item_lane_rect() -> Rect2:
	return Rect2(LANE_X, ITEM_LANE_Y, LANE_WIDTH, LANE_HEIGHT)

## 完整流程。返回玩家的排列（片段编号，按放入顺序）。
func run() -> Array:
	GameState.lock_control(LOCK_REASON)
	# 解谜期间停止背景音乐（避免与两条音轨混在一起），结束后恢复原来的曲目。
	var resume_music: String = Music.current_id
	Music.stop(MUSIC_FADE)
	await play_intro_animation()
	set_hint("PUZZLE_HINT_LISTEN")
	await play_and_wait([full_layer("melody"), full_layer("item")])
	await cut_and_drop()
	interactive = true
	reset_button.disabled = false
	set_hint("PUZZLE_HINT_ARRANGE")
	await confirm_requested
	interactive = false
	reset_button.disabled = true
	confirm_button.hide()
	set_hint("PUZZLE_HINT_RESULT")
	var arranged: Array = []
	for segment in placed: arranged.append(Vector2(segment.from, segment.to))
	await play_and_wait([full_layer("melody"), {"id": "item", "stream": item_stream, "ranges": arranged, "volume": item_volume.value}])
	await play_outro_animation()
	if not resume_music.is_empty(): Music.play(resume_music, MUSIC_FADE)
	GameState.unlock_control(LOCK_REASON)
	return arrangement()

func arrangement() -> Array:
	var result: Array = []
	for segment in placed: result.append(segment.index)
	return result

func full_layer(id: String) -> Dictionary:
	var melody := id == "melody"
	return {"id": id, "stream": melody_stream if melody else item_stream, "ranges": [Vector2(0, duration)], "volume": (melody_volume if melody else item_volume).value}

func play_and_wait(layers: Array) -> void:
	_show_playhead = true
	sequencer.play(layers)
	await sequencer.finished
	_show_playhead = false
	playhead.hide()

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / time_scale).timeout

func set_hint(key: String) -> void:
	hint_label.text = tr(key)

## 下方音轨按 cuts 切开，变成物理片段掉进托盘。
func cut_and_drop() -> void:
	cut_done = true
	decor.queue_redraw()
	var scale_px := pixels_per_second()
	for i in range(cuts.size() - 1):
		var segment := PuzzleSegment.new()
		segment.setup(i, float(cuts[i]), float(cuts[i + 1]), scale_px, beat, SEGMENT_COLORS[i % SEGMENT_COLORS.size()])
		segment.position = Vector2(LANE_X + (segment.from + segment.to) * 0.5 * scale_px, ITEM_LANE_Y + LANE_HEIGHT * 0.5)
		segment.impacted.connect(_on_segment_impacted)
		tray.add_child(segment)
		segments.append(segment)
	shake(8.0)
	for segment in segments:
		segment.apply_central_impulse(Vector2(randf_range(-scatter_impulse.x, scatter_impulse.x), randf_range(-scatter_impulse.y, scatter_impulse.y * 0.5)))
		segment.angular_velocity = randf_range(-4.0, 4.0)
	await wait(settle_time)

func build_tray_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "TrayWalls"
	var height := TRAY_FLOOR + 200.0
	for rect: Rect2 in [Rect2(TRAY_LEFT - 40, 0, 40, height), Rect2(TRAY_RIGHT, 0, 40, height), Rect2(TRAY_LEFT - 40, TRAY_FLOOR, TRAY_RIGHT - TRAY_LEFT + 80, 60)]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	tray.add_child(walls)

func segment_at(point: Vector2) -> PuzzleSegment:
	# 后添加的画在上面，优先命中
	for i in range(segments.size() - 1, -1, -1):
		if segments[i].contains_point(point): return segments[i]
	return null

func begin_drag(segment: PuzzleSegment, point: Vector2) -> void:
	if segment.placed:
		preview(segment)
		return
	_drag = segment
	_press_position = point
	_drag_offset = segment.global_position - point
	segment.hold()
	segment.z_index = 10

## 拖拽时跟随鼠标（slide_to 在物理帧里移动，同时把片段转正）。
func drag_to(point: Vector2) -> void:
	if _drag: _drag.slide_to(point + _drag_offset, 0.05)

func end_drag(point: Vector2) -> void:
	var segment := _drag
	if segment == null: return
	_drag = null
	segment.z_index = 0
	if point.distance_to(_press_position) < CLICK_DISTANCE:
		preview(segment)
		segment.release()
	elif item_lane_rect().grow(DROP_MARGIN).has_point(point):
		place(segment)
	else:
		segment.release()

## 放到下方音轨的下一个位置（按放入顺序首尾相接）。
func place(segment: PuzzleSegment) -> void:
	if segment.placed: return
	var start_px := 0.0
	for other in placed: start_px += other.size.x
	placed.append(segment)
	segment.placed = true
	segment.set_deferred("collision_layer", 0)
	segment.set_deferred("collision_mask", 0)
	segment.slide_to(Vector2(LANE_X + start_px + segment.size.x * 0.5, ITEM_LANE_Y + LANE_HEIGHT * 0.5), 0.2)
	shake(3.0)
	preview(segment)
	update_confirm()

## 【重置】：所有已放入的片段掉回托盘。
func reset_segments() -> void:
	if not interactive: return
	stop_preview()
	for segment in placed:
		segment.release()
		segment.apply_central_impulse(Vector2(randf_range(-scatter_impulse.x, scatter_impulse.x), 0))
	placed.clear()
	shake(5.0)
	update_confirm()

func update_confirm() -> void:
	var complete := placed.size() == segments.size() and not segments.is_empty()
	confirm_button.visible = complete
	set_hint("PUZZLE_HINT_CONFIRM" if complete else "PUZZLE_HINT_ARRANGE")

func _on_confirm_pressed() -> void:
	if interactive and confirm_button.visible:
		stop_preview()
		confirm_requested.emit()

## 单独试听一个片段（可反复点击）。
func preview(segment: PuzzleSegment) -> void:
	stop_preview()
	_previewing = segment
	segment.highlighted = true
	sequencer.play([{"id": "item", "stream": item_stream, "ranges": [Vector2(segment.from, segment.to)], "volume": item_volume.value}])
	await sequencer.finished
	if _previewing == segment: stop_preview()

func stop_preview() -> void:
	if _previewing: _previewing.highlighted = false
	_previewing = null
	if interactive: sequencer.stop()

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)

func _on_segment_impacted(speed: float) -> void:
	shake(clampf(speed / 120.0, 1.0, 6.0))

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		offset = Vector2.ZERO
	if _show_playhead and sequencer.playing:
		playhead.show()
		playhead.position.x = LANE_X + clampf(sequencer.elapsed / duration, 0.0, 1.0) * LANE_WIDTH - playhead.size.x * 0.5

func _input(event: InputEvent) -> void:
	# 无法中途退出：吞掉所有键盘输入（包括 Esc、B、WASD）。
	if event is InputEventKey or event is InputEventAction:
		get_viewport().set_input_as_handled()
		return
	if not interactive: return
	var point := Vector2.ZERO
	if event is InputEventMouse: point = event.position - offset
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var segment := segment_at(point)
			if segment:
				get_viewport().set_input_as_handled()
				begin_drag(segment, point)
		elif _drag:
			get_viewport().set_input_as_handled()
			end_drag(point)
	elif event is InputEventMouseMotion and _drag:
		drag_to(point)

## 音轨背景：拍线网格、上方钢琴音轨、（切开之前的）完整怀表音轨。
func _draw_decor() -> void:
	var scale_px := pixels_per_second()
	for lane_y in [MELODY_LANE_Y, ITEM_LANE_Y]:
		decor.draw_rect(Rect2(LANE_X, lane_y, LANE_WIDTH, LANE_HEIGHT), Color(1, 1, 1, 0.06))
		var t := 0.0
		while t <= duration + 0.001:
			var x := LANE_X + t * scale_px
			decor.draw_line(Vector2(x, lane_y), Vector2(x, lane_y + LANE_HEIGHT), Color(1, 1, 1, 0.12 if fmod(t, beat * 4) < 0.001 else 0.05), 1.0)
			t += beat
	var melody_rect := Rect2(LANE_X + 2, MELODY_LANE_Y + 8, LANE_WIDTH - 4, LANE_HEIGHT - 16)
	var style := StyleBoxFlat.new()
	style.bg_color = MELODY_COLOR
	style.border_color = MELODY_COLOR.lightened(0.4)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	decor.draw_style_box(style, melody_rect)
	# 占位“音符”：按占位旋律的音高画短横线
	var notes: Array = config.get("placeholder", {}).get("melody_notes", [])
	for i in range(notes.size()):
		if int(notes[i]) <= 0: continue
		var y := melody_rect.end.y - 10 - (int(notes[i]) - 66) * 2.6
		decor.draw_line(Vector2(LANE_X + i * beat * scale_px + 10, y), Vector2(LANE_X + (i + 0.8) * beat * scale_px, y), MELODY_COLOR.lightened(0.6), 4.0)
	if not cut_done:
		var item_style := StyleBoxFlat.new()
		item_style.bg_color = SEGMENT_COLORS[0]
		item_style.border_color = SEGMENT_COLORS[0].darkened(0.4)
		item_style.set_border_width_all(3)
		item_style.set_corner_radius_all(10)
		decor.draw_style_box(item_style, Rect2(LANE_X + 2, ITEM_LANE_Y + 8, LANE_WIDTH - 4, LANE_HEIGHT - 16))

## 开场动画（占位，美术替换）：黑底淡入 + 金色闪光。
func play_intro_animation() -> void:
	root_control.modulate.a = 0.0
	flash.color = Color(1, 0.9, 0.6, 0.0)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.8, intro_time * 0.4 / time_scale)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.01)
	tween.tween_property(flash, "color:a", 0.0, intro_time * 0.6 / time_scale)
	await tween.finished

## 结束动画（占位，美术替换）：金色闪光后整体淡出。
func play_outro_animation() -> void:
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.9, outro_time * 0.5 / time_scale)
	tween.tween_property(root_control, "modulate:a", 0.0, 0.01)
	tween.parallel().tween_property(tray, "modulate:a", 0.0, 0.01)
	tween.tween_property(flash, "color:a", 0.0, outro_time * 0.5 / time_scale)
	await tween.finished
