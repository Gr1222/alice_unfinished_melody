extends Node3D
## 序章主场景：森林、角色与剧情导演（PrologueDirector）。

@onready var level: ForestLevel = $ForestLevel

func _ready() -> void:
	print("PROLOGUE3D_READY: route_points=%d route_length=%.2f" % [level.route.size(), level.route_length()])
