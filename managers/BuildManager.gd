extends Node

## 炮台成功放置后发出（携带已放置的炮台节点引用）
signal tower_placed(tower: Area2D)

@export var tower_scene: PackedScene

## 对应地图的 TowerLayer 路径（在编辑器中为每个场景单独配置）
@export var tower_layer_path: NodePath = NodePath("../TutorialMap/TowerLayer")

var preview_tower: Area2D = null
var is_dragging: bool = false

## 触屏拖拽时炮台向上偏移（视口像素），避免手指遮挡炮台
@export var touch_drag_offset_y: float = -120.0

## 当前选中的炮台集合数据（由炮台面板 BattleScene.gd 调用 select_tower() 设置）
var _selected_data: Resource = null

## 拖拽开始时已锁定的放置费用（含折扣），松手扣费直接使用此值，保证验证与扣费一致
var _locked_placement_cost: int = -1

## 英雄已在场标志（由 BattleScene 通过 set_hero_placed 维护，避免每次拖拽遍历全树）
var _hero_placed: bool = false


## 由炮台面板调用，设置当前选中的炮台
func select_tower(data: Resource) -> void:
	_selected_data = data

## 由 BattleScene 调用，同步英雄是否已放置（避免在 _start_drag 里遍历全树）
func set_hero_placed(placed: bool) -> void:
	_hero_placed = placed


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
			var touch_ev := event as InputEventScreenTouch
			# _unhandled_input 的触屏坐标需要用 get_global_mouse_position 作为参考
			var pos: Vector2 = get_viewport().get_mouse_position()
			_start_drag(pos + Vector2(0, touch_drag_offset_y))
		else:
			_release_pointer()

	# ===== 鼠标移动 =====
	if event is InputEventMouseMotion:
		if is_dragging and preview_tower:
			preview_tower.global_position = event.position

	# ===== 触屏拖动 =====
	if event is InputEventScreenDrag:
		if is_dragging and preview_tower:
			# 使用 get_mouse_position 获取已经转换好的视口坐标
			var pos: Vector2 = get_viewport().get_mouse_position()
			preview_tower.global_position = pos + Vector2(0, touch_drag_offset_y)


# ── 公开拖拽 API（供炮台面板格子直接调用）────────────────────────────

## 由炮台格子按下时调用，立即发起拖拽；cost 为调用方已计算含折扣的最终费用
func start_drag_at(pos: Vector2, cost: int = -1) -> void:
	_locked_placement_cost = cost
	# pos 来自 gui_input 回调，已经是视口坐标，直接使用
	_start_drag(pos + Vector2(0, touch_drag_offset_y))

## 由炮台格子拖拽事件调用，更新预览位置
func move_preview_to(pos: Vector2) -> void:
	if is_dragging and preview_tower:
		# pos 来自 gui_input 回调，已经是视口坐标，直接使用
		preview_tower.global_position = pos + Vector2(0, touch_drag_offset_y)

## 由炮台格子释放事件调用，完成放置判断
func release_drag() -> void:
	_release_pointer()

## 取消当前选择（拖拽未达阈值放弃时调用，无预览存在）
func cancel_selection() -> void:
	_selected_data = null


func _start_drag(pos: Vector2) -> void:

	if is_dragging:
		return

	if not tower_scene:
		push_warning("BuildManager: tower_scene 未设置，无法拖拽放置")
		return

	if not _selected_data:
		push_warning("BuildManager: 未选择炮台，请先点击炮台卡片")
		return

	# 英雄塔每局限 1 个（使用缓存标志，避免遍历全树）
	var sel_td := _selected_data as TowerCollectionData
	if sel_td and sel_td.is_hero and _hero_placed:
		push_warning("BuildManager: 英雄已放置，每局只能放 1 个")
		return

	# 优先使用炮台专属场景（含独立碰撞多边形），无则回退通用 Tower.tscn
	var sel_scene: PackedScene = null
	var sel_tcd := _selected_data as TowerCollectionData
	if sel_tcd and sel_tcd.tower_scene:
		sel_scene = sel_tcd.tower_scene
	else:
		sel_scene = tower_scene
	preview_tower = sel_scene.instantiate()

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
	# 优先使用拖拽开始时锁定的费用（由 BattleScene 计算含折扣），
	# 回退到预览炮台的 global_cost_discount 属性（两者来源相同，保持一致性）
	var cost: int
	if _locked_placement_cost >= 0:
		cost = _locked_placement_cost
	else:
		var base_cost: int = _selected_data.placement_cost if _selected_data else 0
		var discount: float = preview_tower.global_cost_discount if preview_tower and preview_tower.has_method("apply_global_buffs") else 0.0
		cost = int(base_cost * (1.0 - clamp(discount, 0.0, 0.9)))
	if not GameManager.spend_gold(cost):
		_cancel_preview()   # 金不够，取消放置
		return

	var placed: Area2D = preview_tower
	placed.is_preview = false

	# ── 路面陷阱自动对齐路径方向 ──
	var sel_tcd := placed.tower_data as TowerCollectionData
	if sel_tcd and sel_tcd.place_on_path_only:
		_align_to_path(placed)

	placed.queue_redraw()
	preview_tower = null
	is_dragging = false
	_selected_data = null
	_locked_placement_cost = -1
	tower_placed.emit(placed)


## 将路面陷阱旋转对齐路径方向（横着铺在路上）
func _align_to_path(tower: Area2D) -> void:
	# 查找场景中的 Path2D
	var path2d: Path2D = null
	for node in get_tree().get_nodes_in_group("path"):
		if node is Path2D:
			path2d = node
			break
	if path2d == null:
		# 遍历父节点查找
		var parent := tower.get_parent()
		while parent:
			for child in parent.get_children():
				if child is Path2D:
					path2d = child
					break
			if path2d:
				break
			parent = parent.get_parent()
	if path2d == null or path2d.curve == null:
		return

	# 找到路径上距离炮台最近的点，获取该点的方向
	var curve: Curve2D = path2d.curve
	var tower_local_pos: Vector2 = path2d.to_local(tower.global_position)
	var closest_offset: float = curve.get_closest_offset(tower_local_pos)

	# ── 位置吸附：将陷阱移到路径曲线上最近的点 ──
	var closest_point: Vector2 = curve.sample_baked(closest_offset)
	tower.global_position = path2d.to_global(closest_point)

	# 取前后两个小偏移点计算方向
	var delta: float = 10.0
	var p1: Vector2 = curve.sample_baked(max(closest_offset - delta, 0.0))
	var p2: Vector2 = curve.sample_baked(min(closest_offset + delta, curve.get_baked_length()))
	var direction: Vector2 = (p2 - p1).normalized()
	if direction.length_squared() > 0.01:
		# 铁网图片默认朝3点方向（右），旋转至路径方向
		tower.rotation = direction.angle()


func _cancel_preview() -> void:
	if is_instance_valid(preview_tower):
		preview_tower.queue_free()
	preview_tower = null
	is_dragging = false
	_selected_data = null            # 防止残留选择导致后续地图点击二次放置
	_locked_placement_cost = -1
