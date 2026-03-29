extends Node2D
## 地图编辑器（开发者工具）
##
## 功能：
##   • 自由放置路线图案、装饰品、可拆卸装饰品（Area2D + CollisionPolygon2D）
##   • 航点编辑模式（定义敌人行进路线，支持拖拽移动航点）
##   • 点击选中 → 拖拽移动 / 旋转 / 删除
##   • 可拖拽的终点（🏁）标记
##   • 撤销（最多 30 步）
##   • 保存 / 加载（user://maps/{name}.json）
##   • 清空全部

# ── 可放置对象定义 ────────────────────────────────────────────────────
const OBJECT_DEFS: Array[Dictionary] = [
	# 装饰品（group: "block"，深绿色）
	{"type": "deco_tree",    "label": "大树",   "emoji": "🌲",  "color": Color(0.15, 0.45, 0.15),
	 "w": 90.0,  "h": 90.0,  "group": "block",        "section": "装饰品"},
	{"type": "deco_rock",    "label": "岩石",   "emoji": "🪨",  "color": Color(0.45, 0.42, 0.38),
	 "w": 80.0,  "h": 70.0,  "group": "block",        "section": "装饰品"},
	{"type": "deco_house",   "label": "建筑",   "emoji": "🏠",  "color": Color(0.60, 0.35, 0.25),
	 "w": 130.0, "h": 130.0, "group": "block",        "section": "装饰品"},
	{"type": "deco_pond",    "label": "水塘",   "emoji": "💧",  "color": Color(0.20, 0.50, 0.80, 0.8),
	 "w": 120.0, "h": 80.0,  "group": "block",        "section": "装饰品"},
	{"type": "deco_fence",   "label": "栅栏",   "emoji": "🚧",  "color": Color(0.55, 0.42, 0.20),
	 "w": 160.0, "h": 30.0,  "group": "block",        "section": "装饰品"},
	# 可拆卸装饰（group: "interactable"，黄边）
	{"type": "remove_bush",   "label": "灌木丛", "emoji": "🌿", "color": Color(0.30, 0.60, 0.20),
	 "w": 80.0,  "h": 80.0,  "group": "interactable", "section": "可拆卸装饰"},
	{"type": "remove_barrel", "label": "木桶",   "emoji": "🪣", "color": Color(0.55, 0.35, 0.15),
	 "w": 70.0,  "h": 80.0,  "group": "interactable", "section": "可拆卸装饰"},
	{"type": "remove_log",    "label": "木头堆", "emoji": "🪵", "color": Color(0.50, 0.32, 0.12),
	 "w": 110.0, "h": 60.0,  "group": "interactable", "section": "可拆卸装饰"},
]

# ── 地面背景类型 ──────────────────────────────────────────────────────
const GROUND_TYPES: Array[Dictionary] = [
	{"type": "grass",    "label": "🌱 草地", "color": Color(0.25, 0.55, 0.18)},
	{"type": "highland", "label": "🏔 高原",  "color": Color(0.62, 0.56, 0.38)},
	{"type": "farmland", "label": "🌾 农田", "color": Color(0.32, 0.50, 0.20)},
	{"type": "dirt",     "label": "🟫 泥地",  "color": Color(0.55, 0.40, 0.25)},
]

# ── 编辑器模式 ────────────────────────────────────────────────────────
enum EditorMode { PLACE, WAYPOINT }

# ── 节点引用（_ready 中赋值）─────────────────────────────────────────
@onready var _bg_rect:        ColorRect = $Background
@onready var _object_layer:   Node2D   = $ObjectLayer
@onready var _waypoint_layer: Node2D   = $WaypointLayer
@onready var _name_edit:      LineEdit  = $HUD/TopBar/MapNameEdit
@onready var _undo_btn:       Button    = $HUD/TopBar/UndoBtn
@onready var _clear_btn:      Button    = $HUD/TopBar/ClearBtn
@onready var _waypoint_toggle:Button   = $HUD/TopBar/WaypointToggle
@onready var _load_btn:       Button    = $HUD/TopBar/LoadBtn
@onready var _save_btn:       Button    = $HUD/TopBar/SaveBtn
@onready var _toolbar_vbox:   VBoxContainer = $HUD/Toolbar/ToolbarScroll/ToolbarVBox
@onready var _toolbar_panel:  PanelContainer = $HUD/Toolbar
@onready var _sel_overlay:    Control   = $HUD/SelectionOverlay
@onready var _del_btn:        Button    = $HUD/SelectionOverlay/DeleteBtn
@onready var _rot_btn:        Button    = $HUD/SelectionOverlay/RotateBtn
@onready var _waypoint_hint:  Label     = $HUD/WaypointHint
@onready var _path_line:      Line2D    = $WaypointLayer/PathLine

# ── 状态 ─────────────────────────────────────────────────────────────
var _mode:            EditorMode      = EditorMode.PLACE
var _selected_def:    Dictionary      = {}       # 工具栏选中类型
var _selected_obj:    PlacedObject    = null     # 地图上选中对象
var _drag_active:     bool            = false
var _drag_offset:     Vector2         = Vector2.ZERO
var _placed_objects:  Array[PlacedObject] = []
var _waypoints:       Array[Vector2]  = []
var _waypoint_nodes:  Array[Node2D]   = []
var _undo_stack:      Array           = []       # 最多 30 步快照
var _tool_btns:       Array[Button]   = []       # 工具栏按钮（高亮用）

# ── 新增状态：航点拖拽 + 终点标记 + 地面背景 ─────────────────────────
var _wp_drag_idx:      int     = -1                # 正在拖动的航点索引（-1=无）
var _goal_pos:         Vector2 = Vector2(540, 1700) # 终点位置
var _goal_node:        Node2D  = null               # 终点可视节点
var _goal_drag_active: bool    = false              # 终点是否正在被拖动
var _goal_drag_offset: Vector2 = Vector2.ZERO       # 终点拖动偏移
var _bg_type:          String  = "grass"            # 当前地面背景类型
var _ground_btns:      Array[Button] = []           # 地面切换按钮组

# ── 常量 ─────────────────────────────────────────────────────────────
const TOOLBAR_X: float   = 860.0  # 工具栏左边界（x > 此值视为 HUD）
const TOP_BAR_H: float   = 100.0  # 顶栏高度
const MAX_UNDO:  int     = 30
const WP_RADIUS: float   = 20.0   # 航点圆圈半径
const GOAL_HIT:  float   = 50.0   # 终点点击检测半径

# ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_toolbar()
	_connect_buttons()
	_set_mode(EditorMode.PLACE)
	# 创建并放置终点标记
	_goal_node = _make_goal_handle()
	_object_layer.add_child(_goal_node)
	_goal_node.position = _goal_pos
	# 隐藏航点切换按钮（不再开发地图编辑器路线功能）
	_waypoint_toggle.visible = false
	# 构建地面背景选择器（插入右侧工具栏顶部）
	_build_ground_selector()
	# 为航点提示标签添加暗色背景 + 加大字体，使其在地图上清晰可见
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.05, 0.05, 0.05, 0.68)
	hint_style.set_corner_radius_all(6)
	hint_style.content_margin_left   = 10
	hint_style.content_margin_right  = 10
	hint_style.content_margin_top    = 4
	hint_style.content_margin_bottom = 4
	_waypoint_hint.add_theme_stylebox_override("normal", hint_style)
	_waypoint_hint.add_theme_font_size_override("font_size", 28)
	_waypoint_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))

# ── 工具栏动态构建 ────────────────────────────────────────────────────
func _build_toolbar() -> void:
	for child in _toolbar_vbox.get_children():
		child.queue_free()
	_tool_btns.clear()

	var current_section := ""
	for def: Dictionary in OBJECT_DEFS:
		if def["section"] != current_section:
			current_section = def["section"]
			var sec_lbl := Label.new()
			sec_lbl.text = "─ " + current_section + " ─"
			sec_lbl.add_theme_font_size_override("font_size", 22)
			sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sec_lbl.modulate = Color(0.9, 0.9, 0.7)
			_toolbar_vbox.add_child(sec_lbl)

		var btn := Button.new()
		btn.text = "%s %s" % [def["emoji"], def["label"]]
		btn.add_theme_font_size_override("font_size", 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0, 70)
		var cap: Dictionary = def
		btn.pressed.connect(func(): _select_tool(cap))
		_toolbar_vbox.add_child(btn)
		_tool_btns.append(btn)

# ── 地面背景切换选择器（放在右侧工具栏顶部）────────────────────────
func _build_ground_selector() -> void:
	# 分区标题
	var sec_lbl := Label.new()
	sec_lbl.text = "─ 地面背景 ─"
	sec_lbl.add_theme_font_size_override("font_size", 22)
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_lbl.modulate = Color(0.9, 0.9, 0.7)
	_toolbar_vbox.add_child(sec_lbl)
	_toolbar_vbox.move_child(sec_lbl, 0)

	var insert_idx: int = 1
	for gdef: Dictionary in GROUND_TYPES:
		var btn := Button.new()
		btn.text = gdef["label"]
		btn.add_theme_font_size_override("font_size", 26)
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0, 60)
		var cap: Dictionary = gdef
		btn.pressed.connect(func():
			_bg_type = cap["type"]
			_bg_rect.color = cap["color"]
			_update_ground_btn_states()
		)
		_toolbar_vbox.add_child(btn)
		_toolbar_vbox.move_child(btn, insert_idx)
		insert_idx += 1
		_ground_btns.append(btn)
	# 默认选中第一个（草地）
	_update_ground_btn_states()
	_bg_rect.color = GROUND_TYPES[0]["color"]

func _update_ground_btn_states() -> void:
	for i in _ground_btns.size():
		_ground_btns[i].button_pressed = (GROUND_TYPES[i]["type"] == _bg_type)

# ── 终点标记节点 ──────────────────────────────────────────────────────
func _make_goal_handle() -> Node2D:
	var n := Node2D.new()
	var rect := ColorRect.new()
	rect.size     = Vector2(80, 80)
	rect.position = Vector2(-40, -40)
	rect.color    = Color(1.0, 0.2, 0.2, 0.85)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(rect)
	var lbl := Label.new()
	lbl.text = "🏁"
	lbl.position = Vector2(-40, -40)
	lbl.size     = Vector2(80, 80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(lbl)
	return n

# ── 按钮连接 ──────────────────────────────────────────────────────────
func _connect_buttons() -> void:
	$HUD/TopBar/BackBtn.pressed.connect(_on_back)
	_undo_btn.pressed.connect(_on_undo)
	_clear_btn.pressed.connect(_on_clear)
	_waypoint_toggle.pressed.connect(_on_waypoint_toggle)
	_load_btn.pressed.connect(_on_load)
	_save_btn.pressed.connect(_on_save)
	_del_btn.pressed.connect(_on_delete_selected)
	_rot_btn.pressed.connect(_on_rotate_selected)

# ── 模式切换 ──────────────────────────────────────────────────────────
func _set_mode(m: EditorMode) -> void:
	_mode = m
	_toolbar_panel.visible  = (m == EditorMode.PLACE)
	_waypoint_hint.visible  = (m == EditorMode.WAYPOINT)
	_waypoint_toggle.button_pressed = (m == EditorMode.WAYPOINT)
	if m == EditorMode.PLACE:
		_waypoint_hint.text = ""
	else:
		# 根据现有点数显示不同提示
		_rebuild_waypoint_visuals()
		_deselect_object()

func _on_waypoint_toggle() -> void:
	if _mode == EditorMode.PLACE:
		_set_mode(EditorMode.WAYPOINT)
	else:
		_set_mode(EditorMode.PLACE)

# ── 工具选择 ──────────────────────────────────────────────────────────
func _select_tool(def: Dictionary) -> void:
	_selected_def = def
	_deselect_object()
	# 高亮选中的工具按钮
	var idx := 0
	for d: Dictionary in OBJECT_DEFS:
		if idx < _tool_btns.size():
			_tool_btns[idx].modulate = Color(0.6, 1.0, 0.6) if d["type"] == def["type"] else Color.WHITE
		idx += 1

# ── 输入处理 ──────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	var pos := get_local_mouse_position()
	# 忽略 HUD 区域
	if _is_in_hud(pos):
		return

	if _mode == EditorMode.PLACE:
		_handle_place_input(event, pos)
	elif _mode == EditorMode.WAYPOINT:
		_handle_waypoint_input(event, pos)

func _is_in_hud(pos: Vector2) -> bool:
	return pos.x >= TOOLBAR_X or pos.y < TOP_BAR_H

# ── 放置模式输入 ──────────────────────────────────────────────────────
func _handle_place_input(event: InputEvent, pos: Vector2) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				# 优先检查是否点到终点标记（开始拖动终点）
				if _goal_node != null and pos.distance_to(_goal_pos) < GOAL_HIT:
					_push_undo()
					_goal_drag_active = true
					_goal_drag_offset = _goal_pos - pos
					return
				if not _selected_def.is_empty():
					_place_object(pos)
				else:
					_try_select_at(pos)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_deselect_object()
				_selected_def = {}
				_clear_tool_highlight()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_active      = false
			_goal_drag_active = false

	elif event is InputEventMouseMotion:
		if _goal_drag_active:
			_goal_pos = pos + _goal_drag_offset
			_goal_node.position = _goal_pos
		elif _drag_active and _selected_obj and is_instance_valid(_selected_obj):
			_selected_obj.position = pos + _drag_offset
			_update_selection_overlay()

	# 触摸支持
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _goal_node != null and st.position.distance_to(_goal_pos) < GOAL_HIT:
				_push_undo()
				_goal_drag_active = true
				_goal_drag_offset = _goal_pos - st.position
				return
			if not _selected_def.is_empty():
				_place_object(st.position)
			else:
				_try_select_at(st.position)
		elif not st.pressed:
			_drag_active      = false
			_goal_drag_active = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _goal_drag_active:
			_goal_pos = sd.position + _goal_drag_offset
			_goal_node.position = _goal_pos
		elif _drag_active and _selected_obj and is_instance_valid(_selected_obj):
			_selected_obj.position = sd.position + _drag_offset
			_update_selection_overlay()

# ── 放置对象 ──────────────────────────────────────────────────────────
func _place_object(pos: Vector2) -> void:
	_push_undo()
	var obj := PlacedObject.new()
	obj.setup(_selected_def)
	obj.position = pos
	_object_layer.add_child(obj)
	_placed_objects.append(obj)

# ── 选中 / 拖拽对象 ───────────────────────────────────────────────────
func _try_select_at(pos: Vector2) -> void:
	var best: PlacedObject = null
	var best_dist := INF
	for obj: PlacedObject in _placed_objects:
		if not is_instance_valid(obj):
			continue
		var w: float = obj.obj_def.get("w", 80.0)
		var h: float = obj.obj_def.get("h", 80.0)
		var local_pos := pos - obj.position
		# 简单矩形 hit-test（考虑旋转）
		var local_rot := local_pos.rotated(-obj.rotation)
		if abs(local_rot.x) <= w / 2.0 and abs(local_rot.y) <= h / 2.0:
			var dist := obj.position.distance_to(pos)
			if dist < best_dist:
				best_dist = dist
				best = obj
	if best:
		_select_object(best, pos)
	else:
		_deselect_object()

func _select_object(obj: PlacedObject, click_pos: Vector2) -> void:
	if _selected_obj and is_instance_valid(_selected_obj):
		_selected_obj.set_selected(false)
	_selected_obj = obj
	obj.set_selected(true)
	_drag_offset  = obj.position - click_pos
	_drag_active  = true
	_update_selection_overlay()

func _deselect_object() -> void:
	if _selected_obj and is_instance_valid(_selected_obj):
		_selected_obj.set_selected(false)
	_selected_obj = null
	_drag_active  = false
	_sel_overlay.visible = false

func _update_selection_overlay() -> void:
	if not _selected_obj or not is_instance_valid(_selected_obj):
		_sel_overlay.visible = false
		return
	_sel_overlay.visible = true
	# 将 3D 世界坐标转换为屏幕坐标（CanvasLayer 坐标 = 视口坐标）
	var vp_pos := get_viewport().canvas_transform * _selected_obj.global_position
	_sel_overlay.position = vp_pos - Vector2(60, 60)

# ── 删除 / 旋转选中对象 ───────────────────────────────────────────────
func _on_delete_selected() -> void:
	if not _selected_obj or not is_instance_valid(_selected_obj):
		return
	_push_undo()
	_placed_objects.erase(_selected_obj)
	_selected_obj.queue_free()
	_selected_obj = null
	_sel_overlay.visible = false

func _on_rotate_selected() -> void:
	if not _selected_obj or not is_instance_valid(_selected_obj):
		return
	_push_undo()
	_selected_obj.rotation_degrees += 90.0

# ── 工具栏高亮清除 ────────────────────────────────────────────────────
func _clear_tool_highlight() -> void:
	for btn: Button in _tool_btns:
		btn.modulate = Color.WHITE

# ── 航点模式输入（BTD6 风格：拖拽 + 双击插入转折点）────────────────
func _handle_waypoint_input(event: InputEvent, pos: Vector2) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				# 双击：在线段上插入转折点
				if mb.double_click:
					var seg := _nearest_segment_idx(pos, 35.0)
					if seg >= 0:
						_push_undo()
						_waypoints.insert(seg + 1, pos)
						_rebuild_waypoint_visuals()
					return
				# 单击：优先检测是否点到已有航点（开始拖拽）
				var wp_idx := _nearest_waypoint_idx(pos)
				if wp_idx >= 0 and _waypoints[wp_idx].distance_to(pos) < WP_RADIUS * 2.5:
					_push_undo()
					_wp_drag_idx = wp_idx
				elif _waypoints.size() < 2:
					# 少于 2 个点时单击添加起点或终点
					_push_undo()
					_waypoints.append(pos)
					_rebuild_waypoint_visuals()
				# 已有 ≥2 个点时，空白区单击无动作（须双击线段才能插入）
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				# 右键：删除非端点（保留 ≥2 个点）
				var wp_idx := _nearest_waypoint_idx(pos)
				if wp_idx >= 0 and _waypoints[wp_idx].distance_to(pos) < WP_RADIUS * 2.5:
					if _waypoints.size() > 2 and wp_idx > 0 and wp_idx < _waypoints.size() - 1:
						_push_undo()
						_waypoints.remove_at(wp_idx)
						_rebuild_waypoint_visuals()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_wp_drag_idx = -1

	elif event is InputEventMouseMotion:
		if _wp_drag_idx >= 0 and _wp_drag_idx < _waypoints.size():
			_waypoints[_wp_drag_idx] = pos
			_rebuild_waypoint_visuals()

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var wp_idx := _nearest_waypoint_idx(st.position)
			if wp_idx >= 0 and _waypoints[wp_idx].distance_to(st.position) < WP_RADIUS * 2.5:
				_push_undo()
				_wp_drag_idx = wp_idx
			elif _waypoints.size() < 2:
				_push_undo()
				_waypoints.append(st.position)
				_rebuild_waypoint_visuals()
		elif not st.pressed:
			_wp_drag_idx = -1

	elif event is InputEventScreenDrag:
		if _wp_drag_idx >= 0 and _wp_drag_idx < _waypoints.size():
			_waypoints[_wp_drag_idx] = (event as InputEventScreenDrag).position
			_rebuild_waypoint_visuals()

## 返回离 pos 最近的路径线段起始索引（-1 = 超出 threshold 或无线段）
func _nearest_segment_idx(pos: Vector2, threshold: float = 35.0) -> int:
	var best_dist := threshold
	var best_idx  := -1
	for i in _waypoints.size() - 1:
		var a: Vector2 = _waypoints[i]
		var b: Vector2 = _waypoints[i + 1]
		var ab:     Vector2 = b - a
		var len_sq: float   = ab.length_squared()
		if len_sq < 0.001:
			continue
		var t:    float = clamp((pos - a).dot(ab) / len_sq, 0.0, 1.0)
		var dist: float = pos.distance_to(a + ab * t)
		if dist < best_dist:
			best_dist = dist
			best_idx  = i
	return best_idx

func _nearest_waypoint_idx(pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := INF
	for i in _waypoints.size():
		var d := _waypoints[i].distance_to(pos)
		if d < best_dist:
			best_dist = d
			best_idx  = i
	return best_idx

func _remove_nearest_waypoint(pos: Vector2) -> void:
	var idx := _nearest_waypoint_idx(pos)
	if idx < 0:
		return
	if _waypoints[idx].distance_to(pos) > 80.0:
		return  # 太远则不响应
	_push_undo()
	_waypoints.remove_at(idx)
	_rebuild_waypoint_visuals()

# ── 航点视觉重建 ──────────────────────────────────────────────────────
func _rebuild_waypoint_visuals() -> void:
	for n: Node2D in _waypoint_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_waypoint_nodes.clear()

	# 连接线
	_path_line.points = PackedVector2Array(_waypoints)

	# 每个航点：起点▶绿色 / 终点■红色 / 中间节点橙色
	for i in _waypoints.size():
		var handle := _make_waypoint_handle(i, _waypoints[i])
		_waypoint_layer.add_child(handle)
		_waypoint_nodes.append(handle)

	# 更新提示文字
	match _waypoints.size():
		0: _waypoint_hint.text = "点击放置起点 🟢"
		1: _waypoint_hint.text = "点击放置终点 🔴"
		_: _waypoint_hint.text = "拖动节点调整路线 | 双击路线段落添加转折点 | 右键中间节点删除"

func _make_waypoint_handle(idx: int, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos

	var circle := ColorRect.new()
	circle.size     = Vector2(WP_RADIUS * 2, WP_RADIUS * 2)
	circle.position = Vector2(-WP_RADIUS, -WP_RADIUS)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 起点绿色、终点红色、中间橙色
	var last := _waypoints.size() - 1
	if idx == 0:
		circle.color = Color(0.20, 0.85, 0.30, 0.9)  # 绿色 起点
	elif idx == last:
		circle.color = Color(0.90, 0.20, 0.20, 0.9)  # 红色 终点
	else:
		circle.color = Color(1.00, 0.55, 0.10, 0.9)  # 橙色 中间点
	n.add_child(circle)

	var num_lbl := Label.new()
	if idx == 0:
		num_lbl.text = "▶"
	elif idx == last:
		num_lbl.text = "■"
	else:
		num_lbl.text = str(idx)
	num_lbl.position = Vector2(-WP_RADIUS, -WP_RADIUS)
	num_lbl.size     = Vector2(WP_RADIUS * 2, WP_RADIUS * 2)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 22)
	num_lbl.modulate = Color.WHITE
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(num_lbl)

	return n

# ── 撤销系统（含 goal_pos）───────────────────────────────────────────
func _push_undo() -> void:
	if _undo_stack.size() >= MAX_UNDO:
		_undo_stack.pop_front()
	var snap := {
		"objects":   _placed_objects.filter(func(o): return is_instance_valid(o))\
									.map(func(o): return o.to_dict()),
		"waypoints": _waypoints.duplicate(),
		"goal_pos":  _goal_pos,
	}
	_undo_stack.push_back(snap)

func _on_undo() -> void:
	if _undo_stack.is_empty():
		return
	var snap: Dictionary = _undo_stack.pop_back()
	# 清除当前对象
	for obj: PlacedObject in _placed_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_placed_objects.clear()
	_deselect_object()
	# 从快照重建
	for d: Dictionary in snap["objects"]:
		var matches := OBJECT_DEFS.filter(func(x): return x["type"] == d["type"])
		if matches.is_empty():
			continue
		var obj := PlacedObject.new()
		obj.setup(matches[0])
		obj.position = Vector2(d["x"], d["y"])
		obj.rotation_degrees = float(d.get("rot", 0.0))
		_object_layer.add_child(obj)
		_placed_objects.append(obj)
	_waypoints = snap["waypoints"].duplicate()
	_rebuild_waypoint_visuals()
	# 恢复终点位置
	if _goal_node != null:
		_goal_pos = snap.get("goal_pos", Vector2(540, 1700))
		_goal_node.position = _goal_pos

# ── 清空 ──────────────────────────────────────────────────────────────
func _on_clear() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "🧹 清空确认"
	dlg.dialog_text = "清空地图上所有对象和航点？\n此操作可以通过「↩ 撤销」恢复。"
	dlg.ok_button_text = "清空全部"
	dlg.cancel_button_text = "取消"
	dlg.confirmed.connect(func():
		dlg.queue_free()
		_push_undo()
		for obj: PlacedObject in _placed_objects:
			if is_instance_valid(obj): obj.queue_free()
		_placed_objects.clear()
		_deselect_object()
		_waypoints.clear()
		_wp_drag_idx = -1
		_rebuild_waypoint_visuals()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

# ── 加载地图 ──────────────────────────────────────────────────────────
func _on_load() -> void:
	var paths := MapData.list_saved_maps()
	if paths.is_empty():
		var dlg := AcceptDialog.new()
		dlg.title = "📂 加载地图"
		dlg.dialog_text = "暂无已保存的地图。\n请先保存一个地图。"
		dlg.confirmed.connect(func(): dlg.queue_free())
		add_child(dlg)
		dlg.get_label().add_theme_font_size_override("font_size", 28)
		dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
		dlg.popup_centered()
		return

	# 构建选择面板
	var panel := PopupPanel.new()
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "选择要加载的地图："
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	for p: String in paths:
		var map_name := p.get_file().get_basename()
		var btn := Button.new()
		btn.text = "🗺 " + map_name
		btn.add_theme_font_size_override("font_size", 30)
		btn.custom_minimum_size = Vector2(400, 60)
		var cap := p
		btn.pressed.connect(func():
			panel.queue_free()
			_load_map(cap)
		)
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.add_theme_font_size_override("font_size", 26)
	cancel_btn.custom_minimum_size = Vector2(400, 50)
	cancel_btn.pressed.connect(func(): panel.queue_free())
	vbox.add_child(cancel_btn)

	add_child(panel)
	panel.popup_centered()

func _load_map(path: String) -> void:
	var md := MapData.load_from_file(path)
	if not md:
		return
	_push_undo()
	# 清除现有对象
	for obj: PlacedObject in _placed_objects:
		if is_instance_valid(obj): obj.queue_free()
	_placed_objects.clear()
	_deselect_object()
	# 重建对象
	for d: Dictionary in md.objects:
		var matches := OBJECT_DEFS.filter(func(x): return x["type"] == d["type"])
		if matches.is_empty():
			continue
		var obj := PlacedObject.new()
		obj.setup(matches[0])
		obj.position         = Vector2(d["x"], d["y"])
		obj.rotation_degrees = float(d.get("rot", 0.0))
		_object_layer.add_child(obj)
		_placed_objects.append(obj)
	# 恢复航点
	_waypoints = md.waypoints.duplicate()
	_rebuild_waypoint_visuals()
	# 恢复终点位置
	_goal_pos = md.goal_pos
	if _goal_node != null:
		_goal_node.position = _goal_pos
	# 恢复地图名称
	_name_edit.text = md.map_name
	# 恢复地面背景类型
	_bg_type = md.background_type
	var gdef_matches := GROUND_TYPES.filter(func(g: Dictionary): return g["type"] == _bg_type)
	if not gdef_matches.is_empty():
		_bg_rect.color = gdef_matches[0]["color"]
	_update_ground_btn_states()

# ── 保存：点击后弹出命名对话框 ─────────────────────────────────────────
func _on_save() -> void:
	_show_save_name_dialog()

func _show_save_name_dialog() -> void:
	var panel := PopupPanel.new()
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "💾 保存地图"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "地图名称："
	hint.add_theme_font_size_override("font_size", 26)
	vbox.add_child(hint)

	var name_input := LineEdit.new()
	var current_name := _name_edit.text.strip_edges()
	name_input.text = current_name if not current_name.is_empty() else "新地图"
	name_input.max_length = 20
	name_input.add_theme_font_size_override("font_size", 30)
	name_input.custom_minimum_size = Vector2(420, 55)
	vbox.add_child(name_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var save_btn := Button.new()
	save_btn.text = "✅ 保存"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.add_theme_font_size_override("font_size", 28)
	btn_row.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_font_size_override("font_size", 28)
	btn_row.add_child(cancel_btn)

	save_btn.pressed.connect(func():
		var map_name := name_input.text.strip_edges()
		if map_name.is_empty():
			map_name = "新地图"
		_name_edit.text = map_name
		panel.queue_free()
		_do_save(map_name)
	)
	cancel_btn.pressed.connect(func(): panel.queue_free())
	add_child(panel)
	panel.popup_centered()

func _do_save(map_name: String) -> void:
	var md := MapData.new()
	md.map_name = map_name
	# Array[Dictionary] 需要显式 for 循环，.filter().map() 返回无类型 Array 不可直接赋值
	var obj_list: Array[Dictionary] = []
	for o: PlacedObject in _placed_objects:
		if is_instance_valid(o):
			obj_list.append(o.to_dict())
	md.objects = obj_list
	var wp_list: Array[Vector2] = []
	for v: Vector2 in _waypoints:
		wp_list.append(v)
	md.waypoints        = wp_list
	md.goal_pos         = _goal_pos
	md.background_type  = _bg_type
	md.save_to_file()
	_show_save_success_dialog(map_name, "user://maps/" + map_name + ".json",
		obj_list.size(), _waypoints.size())

func _show_save_success_dialog(map_name: String, saved_path: String,
		obj_count: int, wp_count: int) -> void:
	var panel := PopupPanel.new()
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "✅ 保存成功"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var info := Label.new()
	info.text = "地图「%s」\n共 %d 个对象，%d 个航点" % [map_name, obj_count, wp_count]
	info.add_theme_font_size_override("font_size", 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var test_btn := Button.new()
	test_btn.text = "▶ 开始测试"
	test_btn.add_theme_font_size_override("font_size", 30)
	test_btn.custom_minimum_size = Vector2(360, 60)
	var cap := saved_path
	test_btn.pressed.connect(func():
		panel.queue_free()
		GameManager.custom_map_path = cap
		SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")
	)
	vbox.add_child(test_btn)

	var cont_btn := Button.new()
	cont_btn.text = "继续编辑"
	cont_btn.add_theme_font_size_override("font_size", 26)
	cont_btn.custom_minimum_size = Vector2(360, 50)
	cont_btn.pressed.connect(func(): panel.queue_free())
	vbox.add_child(cont_btn)

	add_child(panel)
	panel.popup_centered()

# ── 退出 ──────────────────────────────────────────────────────────────
func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
