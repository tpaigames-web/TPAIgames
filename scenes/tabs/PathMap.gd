@tool
class_name PathMapControl
extends Control

## 关卡路径地图 — 包含所有关卡卡片的位置（Marker2D）和背景
## 在编辑器中可视化拖拽 Marker2D 调整卡片位置
## 运行时由 BattleTab 调用 get_card_positions() 获取位置后动态创建卡片

const DAY_CARD_SCENE = preload("res://scenes/components/DayCard.tscn")

## 关卡总数（不含教学）
@export var total_days: int = 40
## 卡片宽高（仅用于编辑器预览）
@export var card_w: float = 320.0
@export var card_h: float = 110.0

## 编辑器预览节点容器
var _preview_nodes: Array[Control] = []
## 用于检测 Marker2D 位置变化
var _last_positions: Array[Vector2] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_previews()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# 检测 Marker2D 位置变化，同步预览
	var positions := get_card_positions()
	if positions.size() != _last_positions.size():
		_refresh_previews()
		return
	for i in positions.size():
		if not positions[i].is_equal_approx(_last_positions[i]):
			_sync_preview_positions(positions)
			break


## 返回所有卡片位置（按 CardSlot_00, CardSlot_01... 排序）
func get_card_positions() -> Array[Vector2]:
	var markers: Array[Marker2D] = []
	for c in get_children():
		if c is Marker2D and c.name.begins_with("CardSlot_"):
			markers.append(c)
	markers.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	var result: Array[Vector2] = []
	for m in markers:
		result.append(m.position)
	return result


## 计算地图总高度
func get_total_height() -> float:
	var max_y: float = 0.0
	for pos in get_card_positions():
		if pos.y + card_h > max_y:
			max_y = pos.y + card_h
	return max_y + 300.0


## ── 编辑器预览 ──────────────────────────────────────────────────────────────

func _refresh_previews() -> void:
	# 清理旧预览
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_preview_nodes.clear()

	var positions := get_card_positions()
	_last_positions = positions.duplicate()

	for i in positions.size():
		var preview := _create_preview_card(i)
		preview.position = positions[i]
		add_child(preview)
		preview.z_index = 10
		_preview_nodes.append(preview)


func _sync_preview_positions(positions: Array[Vector2]) -> void:
	_last_positions = positions.duplicate()
	for i in mini(positions.size(), _preview_nodes.size()):
		if is_instance_valid(_preview_nodes[i]):
			_preview_nodes[i].position = positions[i]


func _create_preview_card(idx: int) -> Control:
	# 编辑器中用简单的 ColorRect + Label 做占位预览
	var card := Control.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.size = Vector2(card_w, card_h)
	bg.color = Color(0.2, 0.5, 0.2, 0.7) if idx == 0 else Color(0.3, 0.25, 0.15, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	var lbl := Label.new()
	lbl.text = "Tutorial" if idx == 0 else "Day %02d" % idx
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(card_w, card_h)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	return card
