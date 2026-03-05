extends Node

## 炮台成功放置后发出（携带已放置的炮台节点引用）
signal tower_placed(tower: Area2D)

@export var tower_scene: PackedScene

## 对应地图的 TowerLayer 路径（在编辑器中为每个场景单独配置）
@export var tower_layer_path: NodePath = NodePath("../TutorialMap/TowerLayer")

var preview_tower: Area2D = null
var is_dragging: bool = false

## 当前选中的炮台集合数据（由炮台面板 TutorialScene.gd 调用 select_tower() 设置）
var _selected_data: Resource = null


## 由炮台面板调用，设置当前选中的炮台
func select_tower(data: Resource) -> void:
	_selected_data = data


func _unhandled_input(event):

	# ===== 鼠标 =====
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_release_pointer()

	# ===== 触屏 =====
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_release_pointer()

	# ===== 鼠标移动 =====
	if event is InputEventMouseMotion:
		if is_dragging and preview_tower:
			preview_tower.global_position = event.position

	# ===== 触屏拖动 =====
	if event is InputEventScreenDrag:
		if is_dragging and preview_tower:
			preview_tower.global_position = event.position


# ── 公开拖拽 API（供炮台面板格子直接调用）────────────────────────────

## 由炮台格子按下时调用，立即发起拖拽
func start_drag_at(pos: Vector2) -> void:
	_start_drag(pos)

## 由炮台格子拖拽事件调用，更新预览位置
func move_preview_to(pos: Vector2) -> void:
	if is_dragging and preview_tower:
		preview_tower.global_position = pos

## 由炮台格子释放事件调用，完成放置判断
func release_drag() -> void:
	_release_pointer()


func _start_drag(pos: Vector2) -> void:

	if is_dragging:
		return

	if not tower_scene:
		push_warning("BuildManager: tower_scene 未设置，无法拖拽放置")
		return

	if not _selected_data:
		push_warning("BuildManager: 未选择炮台，请先点击炮台卡片")
		return

	preview_tower = tower_scene.instantiate()

	# 在 add_child 之前设置 tower_data，使 _ready() 触发时即有数据
	# TowerCollectionData 含有 attack_range 字段，供 _draw() 画出射程圈
	preview_tower.tower_data = _selected_data

	var layer: Node = get_node_or_null(tower_layer_path)
	if layer == null:
		push_error("BuildManager: 找不到 TowerLayer，路径: " + str(tower_layer_path))
		preview_tower.queue_free()
		preview_tower = null
		return

	layer.add_child(preview_tower)   # _ready() 在此触发，apply_tower_data() 设置射程形状
	preview_tower.global_position = pos
	is_dragging = true


func _release_pointer() -> void:

	if not is_dragging or not preview_tower:
		return

	if not preview_tower.can_place:
		_cancel_preview()
		return

	_finalize_tower()


func _finalize_tower() -> void:

	# 扣除战斗金币（使用 GameManager autoload，不再依赖本地节点）
	var cost: int = _selected_data.placement_cost if _selected_data else 0
	if not GameManager.spend_gold(cost):
		_cancel_preview()   # 金不够，取消放置
		return

	var placed: Area2D = preview_tower
	placed.is_preview = false
	placed.queue_redraw()
	preview_tower = null
	is_dragging = false
	_selected_data = null
	tower_placed.emit(placed)


func _cancel_preview() -> void:

	preview_tower.queue_free()
	preview_tower = null
	is_dragging = false
