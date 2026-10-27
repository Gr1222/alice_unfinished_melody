extends CharacterBody2D
## Static Alice direction poses, shared with the playable prologue.
const Art = preload("res://scripts/UserArt.gd")
var facing := Vector2.DOWN

@export var speed := 52.0
var movement_enabled := true

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2.5
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	velocity = direction.limit_length() * speed
	if direction != Vector2.ZERO: facing = direction
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	Art.draw_character(self, Vector2.ZERO, facing, false, false, 24.0)
