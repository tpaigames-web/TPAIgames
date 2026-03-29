class_name PlacedObject extends Area2D
## 地图编辑器中已放置的对象节点
##
## 每个对象是一个 Area2D，含彩色矩形视觉 + 碰撞形状
## 组分配: "path" | "block" | "interactable"
## 碰撞层: path=layer11(1024), block=layer9(256), interactable=layer12(4096)

var obj_type: String = ""
var obj_def:  Dictionary = {}

## 根据定义字典初始化节点
func setup(def: Dictionary) -> void:
	obj_type = def["type"]
	obj_def  = def
	name     = def["type"]

	# ── 物理分组 & 碰撞层 ──────────────────────────────────────────────
	add_to_group(def["group"])
	match def["group"]:
		"path":         collision_layer = 1024   # render layer 11
		"block":        collision_layer = 256    # render layer 9
		"interactable": collision_layer = 4096   # render layer 12
	collision_mask = 0   # 编辑器模式下不需要检测其他对象

	# ── 视觉：彩色矩形 ────────────────────────────────────────────────
	var w: float = def["w"]
	var h: float = def["h"]

	var rect := ColorRect.new()
	rect.size     = Vector2(w, h)
	rect.position = Vector2(-w / 2.0, -h / 2.0)
	rect.color    = def["color"]
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	# ── Emoji 标签（居中显示在矩形上）─────────────────────────────────
	var lbl := Label.new()
	lbl.text = def["emoji"]
	lbl.add_theme_font_size_override("font_size", min(w, h) * 0.5)
	lbl.position = Vector2(-w / 2.0, -h / 2.0)
	lbl.size     = Vector2(w, h)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	# 可拆卸装饰：加黄色边框高亮
	if def["group"] == "interactable":
		var border := ColorRect.new()
		border.size     = Vector2(w + 6, h + 6)
		border.position = Vector2(-w / 2.0 - 3, -h / 2.0 - 3)
		border.color    = Color(1.0, 0.85, 0.0, 0.7)
		border.z_index  = -1
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)

	# ── 碰撞形状 ──────────────────────────────────────────────────────
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape  = shape
	add_child(col)

## 选中高亮（蓝色边框）
func set_selected(selected: bool) -> void:
	modulate = Color(0.6, 0.9, 1.0) if selected else Color.WHITE

## 序列化为保存字典（包含 w/h/group，供战斗场景构建碰撞体使用）
func to_dict() -> Dictionary:
	return {
		"type":  obj_type,
		"x":     position.x,
		"y":     position.y,
		"rot":   rotation_degrees,
		"w":     obj_def.get("w",     80.0),
		"h":     obj_def.get("h",     80.0),
		"group": obj_def.get("group", "block"),
	}
