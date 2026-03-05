extends Control

# ── 资源路径 ─────────────────────────────────────────────────────────
const TOWER_RESOURCE_PATHS: Array[String] = [
	"res://data/towers/scarecrow_collection.tres",
	"res://data/towers/water_pipe_collection.tres",
	"res://data/towers/farmer_collection.tres",
	"res://data/towers/bear_trap_collection.tres",
	"res://data/towers/beehive_collection.tres",
	"res://data/towers/farm_cannon_collection.tres",
	"res://data/towers/barbed_wire_collection.tres",
	"res://data/towers/windmill_collection.tres",
	"res://data/towers/seed_shooter_collection.tres",
	"res://data/towers/mushroom_bomb_collection.tres",
	"res://data/towers/chili_flamer_collection.tres",
	"res://data/towers/watchtower_collection.tres",
	"res://data/towers/sunflower_collection.tres",
	"res://data/towers/hero_farmer_collection.tres",
]

const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  # 0 白
	Color(0.2,  0.75, 0.2 ),  # 1 绿
	Color(0.2,  0.5,  0.95),  # 2 蓝
	Color(0.7,  0.2,  0.9 ),  # 3 紫
	Color(1.0,  0.55, 0.0 ),  # 4 橙
]
const RARITY_NAMES: Array[String] = ["白", "绿", "蓝", "紫", "橙"]

# 卡片尺寸（5:7 图片区 + 60px 碎片信息条）
const CARD_W: int = 316
const CARD_IMG_H: int = 442   # 316 × 1.4 ≈ 442（5:7 比例）
const CARD_FRAG_H: int = 60   # 底部碎片信息条高度
const CARD_H: int = CARD_IMG_H + CARD_FRAG_H   # 502

# ── 节点引用 ─────────────────────────────────────────────────────────
@onready var tower_grid: GridContainer = $GridScrollContainer/TowerGrid

# ── 状态 ─────────────────────────────────────────────────────────────
var _all_towers: Array = []
var _card_nodes: Array = []
var _active_filter: int = -1  # -1=全部
var _rebuild_pending: bool = false  # 防止同帧多次重建

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	# 加载炮台资源
	for path in TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res:
			_all_towers.append(res)

	# 创建卡片
	for data in _all_towers:
		var card = _make_tower_card(data)
		tower_grid.add_child(card)
		_card_nodes.append(card)

	# 连接筛选按钮（顺序：全部/白/绿/蓝/紫/橙）
	var filter_row: HBoxContainer = $FilterRow
	var btns = filter_row.get_children()
	if btns.size() >= 6:
		btns[0].pressed.connect(func(): _set_filter(-1))
		btns[1].pressed.connect(func(): _set_filter(0))
		btns[2].pressed.connect(func(): _set_filter(1))
		btns[3].pressed.connect(func(): _set_filter(2))
		btns[4].pressed.connect(func(): _set_filter(3))
		btns[5].pressed.connect(func(): _set_filter(4))

	# 监听 CollectionManager 碎片变化 → 实时刷新卡片
	CollectionManager.collection_changed.connect(_on_collection_changed)

# ── 卡片创建 ──────────────────────────────────────────────────────────
func _make_tower_card(data: TowerCollectionData) -> Control:
	var status: int = CollectionManager.get_tower_status(data.tower_id)
	var is_level_locked: bool = (status == 0)
	var is_unlocked: bool     = (status == 2)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.set_meta("tower_data", data)

	# ── 图片区（上方 5:7）──────────────────────────────────────────
	var img_area := Panel.new()
	img_area.set_anchors_preset(Control.PRESET_TOP_WIDE)
	img_area.offset_bottom = CARD_IMG_H
	img_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(img_area)

	# 顶部稀有度色条
	var stripe := ColorRect.new()
	stripe.color = RARITY_COLORS[data.rarity]
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_bottom = 14.0
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_area.add_child(stripe)

	# 中央图片 / emoji（等级不足时半透明）
	if not is_level_locked and data.collection_texture:
		var tex := TextureRect.new()
		tex.texture      = data.collection_texture
		tex.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_area.add_child(tex)
	else:
		var emoji := Label.new()
		emoji.text = "?" if is_level_locked else data.tower_emoji
		emoji.set_anchors_preset(Control.PRESET_CENTER)
		emoji.offset_left   = -52.0
		emoji.offset_top    = -52.0
		emoji.offset_right  =  52.0
		emoji.offset_bottom =  30.0
		emoji.add_theme_font_size_override("font_size", 72)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_level_locked:
			emoji.modulate = Color(1, 1, 1, 0.4)
		img_area.add_child(emoji)

	# 稀有度角标（右上，着色）
	var rarity_lbl := Label.new()
	rarity_lbl.text = RARITY_NAMES[data.rarity]
	rarity_lbl.modulate = RARITY_COLORS[data.rarity]
	rarity_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rarity_lbl.offset_left   = -56.0
	rarity_lbl.offset_top    =  18.0
	rarity_lbl.offset_right  =  -6.0
	rarity_lbl.offset_bottom =  50.0
	rarity_lbl.add_theme_font_size_override("font_size", 22)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_area.add_child(rarity_lbl)

	# 底部名称（等级不足显示 "Lv.X 解锁"，灰色）
	var name_lbl := Label.new()
	if is_level_locked:
		name_lbl.text = "Lv.%d 解锁" % data.level_required
		name_lbl.modulate = Color(1, 1, 1, 0.45)
	else:
		name_lbl.text = data.display_name
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top    = -52.0
	name_lbl.offset_bottom =  -4.0
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_area.add_child(name_lbl)

	# ── 碎片信息条（下方 60px）——仅等级达到的炮台显示 ──────────────
	if not is_level_locked:
		var frag_bar := ColorRect.new()
		frag_bar.color = Color(0, 0, 0, 0.5)
		frag_bar.offset_top  = CARD_IMG_H
		frag_bar.offset_right  = float(CARD_W)
		frag_bar.offset_bottom = float(CARD_H)
		frag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frag_bar)

		var owned: int = CollectionManager.get_fragments(data.tower_id)
		var frag_lbl := Label.new()
		frag_lbl.text = "碎片: %d/%d" % [owned, data.unlock_fragments]
		frag_lbl.offset_top    = CARD_IMG_H + 4.0
		frag_lbl.offset_left   = 8.0
		frag_lbl.offset_right  = float(CARD_W) - 80.0
		frag_lbl.offset_bottom = float(CARD_H) - 4.0
		frag_lbl.add_theme_font_size_override("font_size", 20)
		frag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frag_lbl)

		var status_lbl := Label.new()
		if is_unlocked:
			status_lbl.text = "已解锁"
			status_lbl.modulate = Color(0.4, 1.0, 0.4)
		else:
			status_lbl.text = "解锁"
			status_lbl.modulate = Color(1.0, 0.8, 0.2)
		status_lbl.offset_top    = CARD_IMG_H + 4.0
		status_lbl.offset_left   = float(CARD_W) - 76.0
		status_lbl.offset_right  = float(CARD_W) - 4.0
		status_lbl.offset_bottom = float(CARD_H) - 4.0
		status_lbl.add_theme_font_size_override("font_size", 22)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_lbl)

	# 点击事件
	card.gui_input.connect(_on_card_clicked.bind(data))
	return card

# ── 筛选 ─────────────────────────────────────────────────────────────
func _set_filter(rarity: int) -> void:
	_active_filter = rarity
	_apply_filter()

func _apply_filter() -> void:
	for card in _card_nodes:
		var d: TowerCollectionData = card.get_meta("tower_data")
		card.visible = (_active_filter == -1 or d.rarity == _active_filter)

# ── 卡片点击 ─────────────────────────────────────────────────────────
func _on_card_clicked(event: InputEvent, data: TowerCollectionData) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var status: int = CollectionManager.get_tower_status(data.tower_id)
	if status == 0:
		# 等级不足 → 显示所需等级提示
		var req_lv: int = CollectionManager.get_level_required(data.tower_id)
		var home = get_tree().get_first_node_in_group("home_scene")
		if home:
			home.show_locked("🔒 需要达到 Lv.%d\n才能解锁此炮台" % req_lv)
	else:
		# 等级已达（无论是否解锁）→ 打开详情界面
		var panel = load("res://scenes/tower_detail/TowerDetailPanel.tscn").instantiate()
		get_tree().root.add_child(panel)
		panel.setup(data)

# ── Coming Soon ───────────────────────────────────────────────────────
func _on_coming_soon() -> void:
	var home = get_tree().get_first_node_in_group("home_scene")
	if home:
		home.show_coming_soon()

# ── 可见时刷新卡片（Tab 切换触发） ──────────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		if _all_towers.size() > 0:
			_rebuild_grid()

# ── CollectionManager 碎片变化时触发（宝箱、解锁等） ─────────────────
func _on_collection_changed() -> void:
	# 只有兵工厂 Tab 当前可见才需要立即刷新；
	# 若不可见，切换回来时 _notification 会处理。
	# 使用 _rebuild_pending 防止同一帧内多次信号重复重建。
	if not is_visible_in_tree() or _all_towers.is_empty():
		return
	if not _rebuild_pending:
		_rebuild_pending = true
		call_deferred("_deferred_rebuild")

func _deferred_rebuild() -> void:
	_rebuild_pending = false
	_rebuild_grid()

func _rebuild_grid() -> void:
	for child in tower_grid.get_children():
		child.queue_free()
	_card_nodes.clear()
	for data in _all_towers:
		var card = _make_tower_card(data)
		tower_grid.add_child(card)
		_card_nodes.append(card)
	_apply_filter()
