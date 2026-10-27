extends RefCounted
## User-supplied static poses. Bottom-center anchors stay fixed when turning.
const FRONT = preload("res://assets/user_art/alice_front.png")
const SIDE = preload("res://assets/user_art/alice_side.png")
const BACK = preload("res://assets/user_art/alice_back.png")
const RABBIT = preload("res://assets/user_art/rabbit_side.png")
const ALICE_PORTRAIT = preload("res://assets/user_art/alice_portrait.png")
const RABBIT_PORTRAIT = preload("res://assets/user_art/rabbit_portrait.png")
const FRAME = preload("res://assets/user_art/dialogue_frame.png")

static func draw_character(canvas: CanvasItem, feet: Vector2, facing: Vector2, bunny: bool = false, echo: bool = false, height: float = 80.0) -> void:
	var texture: Texture2D = RABBIT if bunny else FRONT
	var flip := bunny and facing.x > 0
	if not bunny:
		if absf(facing.x) > absf(facing.y):
			texture = SIDE
			flip = facing.x < 0
		elif facing.y < 0:
			texture = BACK
	var size := Vector2(texture.get_width(), texture.get_height()) * (height / texture.get_height())
	var origin := feet - Vector2(size.x * 0.5, size.y)
	if flip:
		origin.x += size.x
		size.x = -size.x
	canvas.draw_texture_rect(texture, Rect2(origin, size), false, Color(0.65, 0.95, 0.9, 0.45) if echo else Color.WHITE)
