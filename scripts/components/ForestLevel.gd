extends Node3D
class_name ForestLevel
## 森林关卡组件：给建模组导出的 forest.glb 补上材质、灯光、环境和碰撞。
## 逻辑复制自旧 demo 的 SpatialForest.gd / VolumeForest.gd，不继承它们，也不修改模型文件。
## 子节点 ForestModel 必须是 forest.glb 的实例。

## 碰撞层：1 = 地面/树木/横木，2 = 路径两侧的隐形墙。
const PATH_WALL_LAYER := 2
const PATH_HALF_WIDTH := 1.15

@export var forest_assets := "res://assets/volume_forest/"
@export var floor_size := Vector3(34, 0.1, 28)

var layout: Dictionary
## 路线点（地面高度 y=0），从入口到兔子洞。
var route: Array[Vector3] = []
var route_lengths: Array[float] = [0.0]

func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(forest_assets + "layout.json"))
	for point: Array in layout.route: route.append(to_vector(point))
	for i in range(1, route.size()):
		route_lengths.append(route_lengths[-1] + route[i - 1].distance_to(route[i]))
	fix_materials($ForestModel)
	add_environment()
	add_floor()
	add_log_collision(layout.jump_obstacle)
	add_tree_collisions()
	add_path_walls()

static func to_vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func route_length() -> float:
	return route_lengths[-1]

## 路线上距离入口 distance 米处的点，供剧情摆放道具和角色。
func point_on_route(distance: float) -> Vector3:
	distance = clampf(distance, 0, route_length())
	for i in range(route.size() - 1):
		if route_lengths[i + 1] >= distance:
			var span := maxf(0.0001, route_lengths[i + 1] - route_lengths[i])
			return route[i].lerp(route[i + 1], (distance - route_lengths[i]) / span)
	return route[-1]

## 某个点在路线上的进度（米），用于判断玩家走到了哪里。
func route_progress(point: Vector3) -> float:
	point.y = 0
	var best := INF
	var distance := 0.0
	for i in range(route.size() - 1):
		var nearest := Geometry3D.get_closest_point_to_segment(point, route[i], route[i + 1])
		var error := point.distance_squared_to(nearest)
		if error < best:
			best = error
			distance = route_lengths[i] + route[i].distance_to(nearest)
	return distance

func fix_materials(model: Node) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			var has_colors: bool = mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR != 0
			# 导入器保留了顶点色但没有启用，地面需要用顶点色着色器还原调色。
			if has_colors:
				var painted := ShaderMaterial.new()
				painted.shader = load(forest_assets + "painted_ground.gdshader")
				mesh.set_surface_override_material(surface, painted)
			elif original is StandardMaterial3D and ("MAT_void" in original.resource_name or ("05_Portal" in mesh.name and "MAT_crease" in original.resource_name)):
				var dark := ShaderMaterial.new()
				dark.shader = load(forest_assets + "portal_interior.gdshader")
				mesh.set_surface_override_material(surface, dark)

func add_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14232f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("86939d")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("233844")
	env.fog_density = 0.009
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-55, -32, 0)
	moon.light_color = Color("bac8d0")
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	moon.shadow_bias = 0.025
	moon.shadow_normal_bias = 0.55
	moon.directional_shadow_max_distance = 45
	add_child(moon)
	# 蘑菇（低处，蓝绿）与符文（高处，黄绿）的局部光源。
	for point: Array in layout.get("sources", []):
		var position_3d := to_vector(point)
		var light := OmniLight3D.new()
		light.name = "MushroomLight" if position_3d.y < 1 else "RuneLight"
		light.position = position_3d
		light.light_color = Color("7db7c3") if position_3d.y < 1 else Color("c5ce9a")
		light.light_energy = 0.38
		light.omni_range = 2.1 if position_3d.y < 1 else 2.8
		light.shadow_enabled = true
		add_child(light)

func add_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = floor_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -0.04
	body.add_child(collision)
	add_child(body)

## 路线上的低横木，需要按空格跳过。
func add_log_collision(data: Dictionary) -> void:
	var points: Array = data.points
	var radii: Array = data.radii
	var body := StaticBody3D.new()
	body.name = "LowJumpLogCollision"
	for i in range(points.size() - 1):
		var a := to_vector(points[i])
		var b := to_vector(points[i + 1])
		var shape := CapsuleShape3D.new()
		shape.radius = maxf(float(radii[i]), float(radii[i + 1]))
		shape.height = a.distance_to(b) + 2 * shape.radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = (a + b) * 0.5
		collision.quaternion = Quaternion(Vector3.UP, a.direction_to(b))
		body.add_child(collision)
	add_child(body)

func add_tree_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "TreesAndStandingStoneCollision"
	for item: Dictionary in layout.tree_proxies:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = float(item.radius)
		shape.height = float(item.height)
		collision.shape = shape
		collision.position = to_vector(item.position) + Vector3(0, shape.height * 0.5, 0)
		body.add_child(collision)
	# 洞口保持畅通，只有两侧的树墩和石碑阻挡。
	for point: Vector3 in [Vector3(6.9, 1.8, -6.8), Vector3(11.1, 1.8, -6.8), Vector3(6.8, 0.94, -5)]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 3.6, 1.6) if point.y > 1 else Vector3(0.85, 1.88, 0.48)
		collision.shape = shape
		collision.position = point
		body.add_child(collision)
	add_child(body)

## 沿路线两侧放置隐形墙，序章地图只有一条路。
func add_path_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "OuterPathWalls"
	body.collision_layer = PATH_WALL_LAYER
	body.collision_mask = 1
	for i in range(route.size() - 1):
		var a := route[i]
		var b := route[i + 1]
		var direction := a.direction_to(b)
		var side := Vector3(-direction.z, 0, direction.x)
		for sign_value: float in [-1.0, 1.0]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.12, 3, a.distance_to(b) + 0.08)
			collision.shape = shape
			collision.position = (a + b) * 0.5 + side * sign_value * PATH_HALF_WIDTH + Vector3(0, 1.5, 0)
			collision.rotation.y = atan2(direction.x, direction.z)
			body.add_child(collision)
	# 路线两端封口：防止从起点往回走、或从终点走出地图（进洞由结尾动画完成）。
	for end in [[route[0], route[1]], [route[-1], route[-2]]]:
		var outward: Vector3 = end[1].direction_to(end[0])
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(PATH_HALF_WIDTH * 2 + 0.2, 3, 0.12)
		collision.shape = shape
		collision.position = end[0] + outward * 0.3 + Vector3(0, 1.5, 0)
		collision.rotation.y = atan2(outward.x, outward.z)
		body.add_child(collision)
	add_child(body)
