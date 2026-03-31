extends Control

const TOWER_DETAIL_PANEL = preload("res://scenes/tower_detail/TowerDetailPanel.tscn")

# ── 卡框纹理（按稀有度索引）─────────────────────────────────────────────
const CARD_FRAMES: Array[String] = [
	"res://assets/sprites/Cards/Card_w.png",   # 0 白
	"res://assets/sprites/Cards/Card_g.png",   # 1 绿
	"res://assets/sprites/Cards/Card_b.png",   # 2 蓝
	"res://assets/sprites/Cards/Card_p.png",   # 3 紫
	"res://assets/sprites/Cards/Card_o.png",   # 4 橙
]
const CARD_PAPER      = preload("res://assets/sprites/Cards/Game Card_Paper.png")
const NOTIF_SMALL_TEX = preload("res://assets/sprites/ui/Level_bottom/Notification_small.png")
const CARD_CAT_TEX    = preload("res://assets/sprites/ui/Card_categories.png")
const SHORT_TEX       = preload("res://assets/sprites/ui/Short.png")

# ── 卡片尺寸 ─────────────────────────────────────────────────────────
const CARD_W: int = 316
const CARD_H: int = 502
const CLICK_THRESHOLD: float = 20.0

# ── 特殊筛选值 ───────────────────────────────────────────────────────
const FILTER_ALL: int = -1
const FILTER_UPGRADABLE: int = 99


## 判断炮台是否可解锁或可升级（碎片足够）
static func _can_upgrade_or_unlock(data: TowerCollectionData) -> bool:
	var status: int = CollectionManager.get_tower_status(data.tower_id)
	var frags: int = CollectionManager.get_fragments(data.tower_id)
	# 可解锁：等级够但未解锁，碎片足够
	if status == 1 and data.unlock_fragments > 0 and frags >= data.unlock_fragments:
		return true
	# 可升级：已解锁，等级未满，碎片足够升下一级
	if status == 2:
		var level: int = CollectionManager.get_tower_level(data.tower_id)
		if level < data.max_level and level >= 1:
			var upgrade_idx: int = level - 1  # upgrade_fragments[0] = 升到 Lv.2
			if upgrade_idx < data.upgrade_fragments.size():
				if frags >= data.upgrade_fragments[upgrade_idx]:
					return true
	return false

# ── 缓存卡框纹理 ─────────────────────────────────────────────────────
var _frame_textures: Array[Texture2D] = []

# ── 节点引用 ─────────────────────────────────────────────────────────
@onready var tower_grid: GridContainer = $GridScrollContainer/TowerGrid

# ── 状态 ─────────────────────────────────────────────────────────────
var _all_towers: Array = []
var _card_nodes: Array = []
var _item_nodes: Array = []
var _active_filter: int = FILTER_ALL
var _active_type: int = 0     # 0=炮台  1=英雄  2=道具
var _rebuild_pending: bool = false


# ══════════════════════════════════════════════════════════════════════
# 初始化
# ══════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# 预加载卡框
	for path in CARD_FRAMES:
		_frame_textures.append(load(path) as Texture2D)

	# 加载并按稀有度排序（白→绿→蓝→紫→橙）
	_all_towers = TowerResourceRegistry.get_all_resources().duplicate()
	_all_towers.sort_custom(func(a, b): return a.rarity < b.rarity)

	# 创建卡片
	for data in _all_towers:
		var card: Control = _make_tower_card(data)
		var status: int = CollectionManager.get_tower_status(data.tower_id)
		card.set_meta("level_locked", status == 0)
		tower_grid.add_child(card)
		_card_nodes.append(card)

	# 背景飘动效果
	BgFxLayer.create_and_attach(self, $Background)

	# 美化分类栏和筛选栏
	_setup_type_row()
	_setup_filter_row()

	# 监听碎片变化
	CollectionManager.collection_changed.connect(_on_collection_changed)

	# 默认显示炮台
	_set_type(0)


# ══════════════════════════════════════════════════════════════════════
# 分类栏（炮台/英雄/道具）— Card_categories 背景
# ══════════════════════════════════════════════════════════════════════
func _setup_type_row() -> void:
	var type_row: HBoxContainer = $TypeRow
	var btn_idx: int = 0
	for child in type_row.get_children():
		if child is Button:
			_apply_texture_bg(child, CARD_CAT_TEX)
			var captured_idx: int = btn_idx
			child.pressed.connect(func(): _set_type(captured_idx))
			btn_idx += 1


# ══════════════════════════════════════════════════════════════════════
# 筛选栏（全部/白/绿/蓝/紫/橙/升级）— Short.png 背景
# ══════════════════════════════════════════════════════════════════════
func _setup_filter_row() -> void:
	var filter_row: HBoxContainer = $FilterRow

	# 清空原有按钮
	for child in filter_row.get_children():
		child.queue_free()

	# 筛选项定义：[filter_value, display_text]
	var filters: Array = [
		[FILTER_ALL, tr("UI_FACTORY_FILTER_ALL")],
		[0, tr("UI_RARITY_WHITE")],
		[1, tr("UI_RARITY_GREEN")],
		[2, tr("UI_RARITY_BLUE")],
		[3, tr("UI_RARITY_PURPLE")],
		[4, tr("UI_RARITY_ORANGE")],
		[FILTER_UPGRADABLE, tr("UI_FACTORY_FILTER_UPGRADE")],
	]

	for f in filters:
		var btn := _make_filter_btn(f[1])
		var captured_val: int = f[0]
		btn.pressed.connect(func(): _set_filter(captured_val))
		filter_row.add_child(btn)


func _make_filter_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 22)
	_apply_texture_bg(btn, SHORT_TEX)
	return btn


## 为 Button 设置图片背景板（通过 StyleBoxTexture）
func _apply_texture_bg(btn: Button, tex: Texture2D) -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left   = 12
	sb.texture_margin_right  = 12
	sb.texture_margin_top    = 8
	sb.texture_margin_bottom = 8
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus",   sb)


# ══════════════════════════════════════════════════════════════════════
# 卡片创建 — 使用卡框美术
# ══════════════════════════════════════════════════════════════════════
func _make_tower_card(data: TowerCollectionData) -> Control:
	var status: int = CollectionManager.get_tower_status(data.tower_id)
	var is_level_locked: bool = (status == 0)
	var is_unlocked: bool     = (status == 2)
	var owned_frags: int = CollectionManager.get_fragments(data.tower_id)
	var can_unlock: bool = _can_upgrade_or_unlock(data)

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.set_meta("tower_data", data)

	# ── 卡框背景 ──────────────────────────────────────────────────
	var frame_tex: Texture2D
	if is_level_locked:
		frame_tex = CARD_PAPER
	else:
		var r: int = clampi(data.rarity, 0, _frame_textures.size() - 1)
		frame_tex = _frame_textures[r]

	var frame_bg := TextureRect.new()
	frame_bg.texture = frame_tex
	frame_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame_bg)

	# ── 炮台图片 / emoji（居中偏上）──────────────────────────────
	if not is_level_locked and data.collection_texture:
		var tex := TextureRect.new()
		tex.texture = data.collection_texture
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_CENTER)
		tex.offset_left   = -120.0
		tex.offset_top    = -160.0
		tex.offset_right  =  120.0
		tex.offset_bottom =  60.0
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tex)
	else:
		var emoji := Label.new()
		emoji.text = "?" if is_level_locked else data.tower_emoji
		emoji.set_anchors_preset(Control.PRESET_CENTER)
		emoji.offset_left   = -60.0
		emoji.offset_top    = -100.0
		emoji.offset_right  =  60.0
		emoji.offset_bottom =  0.0
		emoji.add_theme_font_size_override("font_size", 80)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_level_locked:
			emoji.modulate = Color(1, 1, 1, 0.4)
		card.add_child(emoji)

	# ── 名称（图片下方）─────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	if is_level_locked:
		name_lbl.text = tr("UI_FACTORY_LV_UNLOCK") % data.level_required
		name_lbl.modulate = Color(1, 1, 1, 0.45)
	else:
		name_lbl.text = TowerResourceRegistry.tr_tower_name(data)
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top    = -100.0
	name_lbl.offset_bottom = -60.0
	name_lbl.offset_left   = 16.0
	name_lbl.offset_right  = -16.0
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# ── 左上角：碎片数量 ─────────────────────────────────────────
	if not is_level_locked:
		var frag_lbl := Label.new()
		frag_lbl.name = "FragLbl"
		frag_lbl.text = "🧩 %d/%d" % [owned_frags, data.unlock_fragments]
		frag_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		frag_lbl.offset_left   = 20.0
		frag_lbl.offset_top    = 20.0
		frag_lbl.offset_right  = 180.0
		frag_lbl.offset_bottom = 52.0
		frag_lbl.add_theme_font_size_override("font_size", 20)
		frag_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
		frag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frag_lbl)

		# ── Notification_small（可解锁红点）──────────────────────
		if can_unlock:
			var notif := TextureRect.new()
			notif.name = "NotifDot"
			notif.texture = NOTIF_SMALL_TEX
			notif.set_anchors_preset(Control.PRESET_TOP_LEFT)
			notif.offset_left   = 6.0
			notif.offset_top    = 6.0
			notif.offset_right  = 42.0
			notif.offset_bottom = 42.0
			notif.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			notif.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(notif)

	# ── 右下角：解锁状态 ─────────────────────────────────────────
	if not is_level_locked:
		var status_lbl := Label.new()
		status_lbl.name = "StatusLbl"
		if is_unlocked:
			status_lbl.text = "✓"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			status_lbl.text = "🔒"
		status_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		status_lbl.offset_left   = -70.0
		status_lbl.offset_top    = -56.0
		status_lbl.offset_right  = -16.0
		status_lbl.offset_bottom = -16.0
		status_lbl.add_theme_font_size_override("font_size", 28)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_lbl)

	# ── 点击处理（松手触发，防拖拽）─────────────────────────────
	var captured_data := data
	card.gui_input.connect(func(event: InputEvent) -> void:
		_on_card_input(event, card, captured_data)
	)

	return card


# ══════════════════════════════════════════════════════════════════════
# 卡片点击（防拖拽）
# ══════════════════════════════════════════════════════════════════════
func _on_card_input(event: InputEvent, card: Control, data: TowerCollectionData) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			card.set_meta("press_pos", event.global_position)
		else:
			var pp: Vector2 = card.get_meta("press_pos", event.global_position)
			if event.global_position.distance_to(pp) < CLICK_THRESHOLD:
				_open_tower_detail(data)
	elif event is InputEventScreenTouch:
		if event.pressed:
			card.set_meta("press_pos", event.position)
		else:
			var pp: Vector2 = card.get_meta("press_pos", event.position)
			if event.position.distance_to(pp) < CLICK_THRESHOLD:
				_open_tower_detail(data)


func _open_tower_detail(data: TowerCollectionData) -> void:
	var status: int = CollectionManager.get_tower_status(data.tower_id)
	if status == 0:
		var req_lv: int = CollectionManager.get_level_required(data.tower_id)
		var home = get_tree().get_first_node_in_group("home_scene")
		if home:
			home.show_locked(tr("UI_FACTORY_LEVEL_REQ") % req_lv)
	else:
		var panel = TOWER_DETAIL_PANEL.instantiate()
		get_tree().root.add_child(panel)
		panel.setup(data)


# ══════════════════════════════════════════════════════════════════════
# 筛选
# ══════════════════════════════════════════════════════════════════════
func _set_type(type: int) -> void:
	_active_type = type
	$FilterRow.visible = (type == 0)
	if type == 1:
		_active_filter = FILTER_ALL
	_apply_filter()

func _set_filter(rarity: int) -> void:
	_active_filter = rarity
	_apply_filter()

func _apply_filter() -> void:
	# 清理旧道具卡
	for node in _item_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_item_nodes.clear()

	for card in _card_nodes:
		var d: TowerCollectionData = card.get_meta("tower_data")
		var show := true
		match _active_type:
			0:  # 炮台 — 排除英雄
				show = not d.is_hero
				if show and _active_filter == FILTER_UPGRADABLE:
					show = _can_upgrade_or_unlock(d)
				elif show and _active_filter != FILTER_ALL:
					show = (d.rarity == _active_filter)
			1:  # 英雄
				show = d.is_hero
			2:  # 道具
				show = false
		card.visible = show

	if _active_type == 2:
		_build_item_cards()


# ══════════════════════════════════════════════════════════════════════
# 道具卡（type=2）— 也使用卡框
# ══════════════════════════════════════════════════════════════════════
func _build_item_cards() -> void:
	var mine_count: int = UserManager.get_item_count("landmine")
	_item_nodes.append(_make_item_card("💣", tr("ITEM_LANDMINE"), "x%d" % mine_count, 0))
	var gold_count: int = UserManager.get_item_count("gold_bag")
	_item_nodes.append(_make_item_card("💰", tr("ITEM_GOLD_BAG"), "x%d" % gold_count, 0))
	for entry in UserManager.temp_tower_inventory:
		var tower_id: String = entry.get("tower_id", "")
		var rarity: int = int(entry.get("rarity", 0))
		var emoji: String = "📦"
		for res in TowerResourceRegistry.get_all_resources():
			if res.get("tower_id") == tower_id:
				emoji = res.get("tower_emoji") if res.get("tower_emoji") else "📦"
				break
		var display_name: String = TowerResourceRegistry.get_temp_tower_display_name(entry)
		_item_nodes.append(_make_item_card(emoji, display_name, tr("UI_TEMP_BADGE"), rarity))

	for node in _item_nodes:
		tower_grid.add_child(node)


func _make_item_card(emoji: String, title: String, subtitle: String, rarity: int) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	# 卡框背景
	var r: int = clampi(rarity, 0, _frame_textures.size() - 1)
	var frame_bg := TextureRect.new()
	frame_bg.texture = _frame_textures[r]
	frame_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame_bg)

	# emoji
	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.set_anchors_preset(Control.PRESET_CENTER)
	emoji_lbl.offset_left   = -60.0
	emoji_lbl.offset_top    = -100.0
	emoji_lbl.offset_right  =  60.0
	emoji_lbl.offset_bottom =  0.0
	emoji_lbl.add_theme_font_size_override("font_size", 72)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(emoji_lbl)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top    = -100.0
	name_lbl.offset_bottom = -60.0
	name_lbl.offset_left   = 16.0
	name_lbl.offset_right  = -16.0
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# 数量
	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub_lbl.offset_top    = -60.0
	sub_lbl.offset_bottom = -20.0
	sub_lbl.offset_left   = 16.0
	sub_lbl.offset_right  = -16.0
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sub_lbl)

	return card


# ══════════════════════════════════════════════════════════════════════
# 刷新
# ══════════════════════════════════════════════════════════════════════
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		if _all_towers.size() > 0:
			_rebuild_grid()

func _on_collection_changed() -> void:
	if not is_visible_in_tree() or _all_towers.is_empty():
		return
	if not _rebuild_pending:
		_rebuild_pending = true
		call_deferred("_deferred_rebuild")

func _deferred_rebuild() -> void:
	_rebuild_pending = false
	_rebuild_grid()

func _rebuild_grid() -> void:
	if _card_nodes.size() == _all_towers.size():
		var needs_full_rebuild := false
		for i in _all_towers.size():
			var data: TowerCollectionData = _all_towers[i]
			var card: Control = _card_nodes[i]
			var status: int = CollectionManager.get_tower_status(data.tower_id)
			var is_level_locked: bool = (status == 0)
			var was_level_locked: bool = card.get_meta("level_locked", true)
			if is_level_locked != was_level_locked:
				needs_full_rebuild = true
				break
			# 就地更新碎片数 / 解锁状态
			var frag_lbl := card.get_node_or_null("FragLbl") as Label
			if frag_lbl:
				var owned: int = CollectionManager.get_fragments(data.tower_id)
				frag_lbl.text = "🧩 %d/%d" % [owned, data.unlock_fragments]
			var status_lbl := card.get_node_or_null("StatusLbl") as Label
			if status_lbl:
				var is_unlocked: bool = (status == 2)
				status_lbl.text = "✓" if is_unlocked else "🔒"
				if is_unlocked:
					status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			# 更新通知红点
			var notif := card.get_node_or_null("NotifDot")
			var can_unlock: bool = _can_upgrade_or_unlock(data)
			if notif:
				notif.visible = can_unlock
			elif can_unlock and not is_level_locked:
				var notif_new := TextureRect.new()
				notif_new.name = "NotifDot"
				notif_new.texture = NOTIF_SMALL_TEX
				notif_new.set_anchors_preset(Control.PRESET_TOP_LEFT)
				notif_new.offset_left = 6.0
				notif_new.offset_top = 6.0
				notif_new.offset_right = 42.0
				notif_new.offset_bottom = 42.0
				notif_new.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				notif_new.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				notif_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(notif_new)
		if not needs_full_rebuild:
			_apply_filter()
			return
	# 全量重建
	for child in tower_grid.get_children():
		child.queue_free()
	_card_nodes.clear()
	for data in _all_towers:
		var card: Control = _make_tower_card(data)
		var status: int = CollectionManager.get_tower_status(data.tower_id)
		card.set_meta("level_locked", status == 0)
		tower_grid.add_child(card)
		_card_nodes.append(card)
	_apply_filter()
