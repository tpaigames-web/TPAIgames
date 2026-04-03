class_name BgFxLayer
extends Control

## 飘动几何形状 + 粒子光点背景效果
## 用法：在任意 Control 节点的 _ready 中调用
##   var fx = BgFxLayer.create_and_attach(self, $Background)

const SHAPE_CHARS: Array[String] = ["▲", "■", "★", "◆", "●", "▶", "✦"]
const SHAPE_COUNT: int = 18
const PARTICLE_COUNT: int = 25

var _shape_nodes: Array = []
var _particle_nodes: Array = []
var _vp_size: Vector2 = Vector2(1080, 1920)


## 创建并附加到父节点（插入到 bg_node 后面）
## 低画质时不创建（直接返回 null 节省 43 个节点）
static func create_and_attach(parent: Control, bg_node: Node = null) -> BgFxLayer:
	if not SettingsManager.particles_enabled:
		return null
	var fx := BgFxLayer.new()
	fx.name = "BgFxLayer"
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fx)
	# 插入到背景后面、内容前面
	if bg_node:
		parent.move_child(fx, bg_node.get_index() + 1)
	fx._spawn_shapes()
	fx._spawn_particles()
	return fx


func _spawn_shapes() -> void:
	for i in SHAPE_COUNT:
		var lbl := Label.new()
		lbl.text = SHAPE_CHARS[i % SHAPE_CHARS.size()]
		var font_sz: int = randi_range(32, 72)
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5, randf_range(0.08, 0.2)))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = Vector2(randf_range(-100, _vp_size.x), randf_range(0, _vp_size.y))
		lbl.rotation_degrees = randf_range(-30, 30)
		add_child(lbl)
		_shape_nodes.append({
			"node": lbl,
			"speed": Vector2(randf_range(15, 45), randf_range(-30, -12)),
			"rot_speed": randf_range(-15, 15),
		})


func _spawn_particles() -> void:
	for i in PARTICLE_COUNT:
		var dot := Label.new()
		dot.text = "·"
		dot.add_theme_font_size_override("font_size", randi_range(24, 48))
		dot.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, randf_range(0.12, 0.3)))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(randf_range(0, _vp_size.x), randf_range(0, _vp_size.y))
		add_child(dot)
		_particle_nodes.append({
			"node": dot,
			"speed": Vector2(randf_range(8, 25), randf_range(-18, -6)),
			"phase": randf_range(0, TAU),
		})


func _process(delta: float) -> void:
	# 不可见或低画质时跳过
	if not is_visible_in_tree():
		return
	if not SettingsManager.particles_enabled:
		return
	for s in _shape_nodes:
		var node: Label = s["node"]
		if not is_instance_valid(node):
			continue
		node.position += s["speed"] * delta
		node.rotation_degrees += s["rot_speed"] * delta
		if node.position.x > _vp_size.x + 80 or node.position.y < -80:
			node.position.x = randf_range(-120, -30)
			node.position.y = randf_range(_vp_size.y * 0.5, _vp_size.y + 100)

	for p in _particle_nodes:
		var node: Label = p["node"]
		if not is_instance_valid(node):
			continue
		p["phase"] += delta * 1.5
		var wave: float = sin(p["phase"]) * 12.0
		node.position += (p["speed"] + Vector2(wave, 0)) * delta
		if node.position.x > _vp_size.x + 40 or node.position.y < -40:
			node.position.x = randf_range(-60, -10)
			node.position.y = randf_range(_vp_size.y * 0.4, _vp_size.y + 60)
