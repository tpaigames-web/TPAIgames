extends Node

## 炮台卡片面板子系统
## 管理底部炮台卡片的构建、高亮、费用刷新、可购买性刷新、敌人刷新按钮

# ── 常量 ──────────────────────────────────────────────────────────────
const DRAG_THRESHOLD: float = 40.0
const TUTORIAL_TOWERS: Array[String] = ["scarecrow", "water_pipe", "beehive", "farmer"]

# ── 内部状态 ──────────────────────────────────────────────────────────
var _tower_card_entries: Array = []
var _last_selected_card: VBoxContainer = null

# ── 外部依赖（通过 init 注入）────────────────────────────────────────
var _tower_hbox: HBoxContainer
var _build_manager: Node
var _get_cost_discount_fn: Callable   # (tower_id: String) -> float


func init(tower_hbox: HBoxContainer, build_manager: Node, get_cost_discount_fn: Callable) -> void:
	_tower_hbox = tower_hbox
	_build_manager = build_manager
	_get_cost_discount_fn = get_cost_discount_fn


# ── 公共方法 ──────────────────────────────────────────────────────────

func build_cards() -> void:
	_build_tower_cards()


func refresh_affordability(is_hero_placed_fn: Callable = Callable()) -> void:
	_refresh_card_affordability(is_hero_placed_fn)


func refresh_costs(get_cost_discount_fn: Callable) -> void:
	_get_cost_discount_fn = get_cost_discount_fn
	_refresh_card_costs()


func highlight_card(card: VBoxContainer) -> void:
	_highlight_selected_card(card)


func get_entries() -> Array:
	return _tower_card_entries


# ── 内部实现 ──────────────────────────────────────────────────────────

func _build_tower_cards() -> void:
	_tower_card_entries.clear()
	for path in TowerResourceRegistry.TOWER_RESOURCE_PATHS:
		var data: Resource = load(path)
		if data == null:
			continue
		# 教学关只显示指定的 4 个炮台
		if GameManager.current_day == 0 and not GameManager.test_mode:
			if data.tower_id not in TUTORIAL_TOWERS:
				continue
		# 测试模式下显示所有炮台，否则只显示已解锁（status=2）的
		elif not GameManager.test_mode and CollectionManager.get_tower_status(data.tower_id) != 2:
			continue
		var card: VBoxContainer = _make_tower_card(data)
		_tower_hbox.add_child(card)
		_tower_card_entries.append({card = card, data = data})
	_refresh_card_affordability()
	# 测试模式：在炮台列表末尾追加敌人刷新按钮
	if GameManager.test_mode:
		_append_enemy_spawn_buttons()


## 生成单个炮台格子（VBoxContainer）
func _make_tower_card(data: Resource) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 图片区（5:7 比例 = 100×140）──
	var img := Panel.new()
	img.custom_minimum_size = Vector2(100, 140)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_tex: Texture2D = null
	if data.icon_texture:
		card_tex = data.icon_texture
	elif data.collection_texture:
		card_tex = data.collection_texture
	if card_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = card_tex
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(tex_rect)
	else:
		var emoji_lbl := Label.new()
		emoji_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		emoji_lbl.text = data.tower_emoji
		emoji_lbl.add_theme_font_size_override("font_size", 48)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(emoji_lbl)
	card.add_child(img)

	# ── 炮台名称 ──
	var name_lbl := Label.new()
	name_lbl.text = data.display_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# ── 攻击类型 ──
	var atk_lbl := Label.new()
	var atk_names: Array[String] = [tr("UI_ATK_GROUND"), tr("UI_ATK_AIR"), tr("UI_ATK_ALL")]
	var atk_colors: Array[Color] = [Color(0.6, 0.4, 0.2), Color(0.3, 0.7, 1.0), Color(0.2, 1.0, 0.4)]
	var atk_idx: int = clampi(data.attack_type, 0, 2)
	atk_lbl.text = atk_names[atk_idx]
	atk_lbl.add_theme_font_size_override("font_size", 18)
	atk_lbl.add_theme_color_override("font_color", atk_colors[atk_idx])
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(atk_lbl)

	# ── 放置费用 ──
	var cost_lbl := Label.new()
	cost_lbl.text = "🪙 %d" % data.placement_cost
	cost_lbl.add_theme_font_size_override("font_size", 22)
	cost_lbl.name = "CostLbl"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cost_lbl)

	# ── 拖拽放置（须移动超过阈值才创建预览，防止误触）──────────────
	var cap: Resource = data
	var bm := _build_manager
	var disc_fn := _get_cost_discount_fn
	card.gui_input.connect(func(e: InputEvent) -> void:
		# ── 鼠标 ──────────────────────────────────────────────────────
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var _disc: float = disc_fn.call(cap.tower_id)
				var _cost: int = int(cap.placement_cost * (1.0 - _disc))
				if GameManager.gold < _cost:
					return   # 金币不足，不响应
				bm.select_tower(cap)
				_highlight_selected_card(card)
				card.set_meta("press_pos", e.global_position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", _cost)   # 锁定费用，拖拽触发时传给 BuildManager
			else:
				if card.get_meta("dragging", false):
					bm.release_drag()
				else:
					bm.cancel_selection()
					_highlight_selected_card(null)
				card.set_meta("dragging", false)

		elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pp: Vector2 = card.get_meta("press_pos", e.global_position)
			if not card.get_meta("dragging", false):
				if e.global_position.distance_to(pp) >= DRAG_THRESHOLD:
					card.set_meta("dragging", true)
					bm.start_drag_at(e.global_position, card.get_meta("locked_cost", -1))
			else:
				bm.move_preview_to(e.global_position)

		# ── 触屏 ──────────────────────────────────────────────────────
		elif e is InputEventScreenTouch:
			if e.pressed:
				var _disc: float = disc_fn.call(cap.tower_id)
				var _cost: int = int(cap.placement_cost * (1.0 - _disc))
				if GameManager.gold < _cost:
					return
				bm.select_tower(cap)
				_highlight_selected_card(card)
				card.set_meta("press_pos", e.position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", _cost)
			else:
				if card.get_meta("dragging", false):
					bm.release_drag()
				else:
					bm.cancel_selection()
					_highlight_selected_card(null)
				card.set_meta("dragging", false)

		elif e is InputEventScreenDrag:
			var pp: Vector2 = card.get_meta("press_pos", e.position)
			if not card.get_meta("dragging", false):
				if e.position.distance_to(pp) >= DRAG_THRESHOLD:
					card.set_meta("dragging", true)
					# 用 get_mouse_position 获取正确的视口坐标（e.position 可能是物理坐标）
					var vp_pos: Vector2 = get_viewport().get_mouse_position()
					bm.start_drag_at(vp_pos, card.get_meta("locked_cost", -1))
			else:
				var vp_pos: Vector2 = get_viewport().get_mouse_position()
				bm.move_preview_to(vp_pos)
	)

	return card

# ── 高亮选中格子 ──────────────────────────────────────────────────────
func _highlight_selected_card(card: VBoxContainer) -> void:
	if _last_selected_card and is_instance_valid(_last_selected_card):
		_last_selected_card.modulate = Color(1, 1, 1, 1)
	_last_selected_card = card
	if is_instance_valid(card):
		card.modulate = Color(0.5, 1.0, 0.5, 1.0)

# ── 金币可购买性刷新 ──────────────────────────────────────────────────
func _refresh_card_affordability(is_hero_placed_fn: Callable = Callable()) -> void:
	var gold: int = GameManager.gold
	for entry in _tower_card_entries:
		var disc: float = _get_cost_discount_fn.call(entry.data.tower_id)
		var cost: int = int(entry.data.placement_cost * (1.0 - disc))
		var ok: bool = gold >= cost
		# 英雄已在场时锁住英雄卡片
		var entry_td: TowerCollectionData = entry.data as TowerCollectionData
		if entry_td and entry_td.is_hero and is_hero_placed_fn.is_valid() and is_hero_placed_fn.call():
			ok = false
		entry.card.modulate = Color(1, 1, 1, 1) if ok else Color(0.5, 0.5, 0.5, 1)

## 刷新所有炮台卡片上的费用文字（激活费用折扣升级后调用）
func _refresh_card_costs() -> void:
	for entry in _tower_card_entries:
		var cost_lbl := entry.card.get_node_or_null("CostLbl") as Label
		if cost_lbl == null: continue
		var disc: float = _get_cost_discount_fn.call(entry.data.tower_id)
		var orig: int = entry.data.placement_cost
		if disc > 0.001:
			var final_cost: int = int(orig * (1.0 - disc))
			cost_lbl.text = "🪙 %d→%d" % [orig, final_cost]
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			cost_lbl.text = "🪙 %d" % orig
			cost_lbl.remove_theme_color_override("font_color")
	_refresh_card_affordability()

# ── 测试模式：敌人刷新按钮 ──────────────────────────────────────────
func _append_enemy_spawn_buttons() -> void:
	# 需要通过 tree 获取 wave_manager，或者外部注入
	var wave_manager: Node = _tower_hbox.get_tree().get_first_node_in_group("wave_manager") if _tower_hbox else null
	if wave_manager == null:
		# 回退：尝试从父级场景获取
		var battle_scene := _tower_hbox.owner
		if battle_scene and battle_scene.has_node("WaveManager"):
			wave_manager = battle_scene.get_node("WaveManager")
	if wave_manager == null:
		return

	# 分隔标签
	var sep := Label.new()
	sep.text = "──🐾──"
	sep.add_theme_font_size_override("font_size", 22)
	sep.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.custom_minimum_size  = Vector2(60, 100)
	_tower_hbox.add_child(sep)

	# 遍历 enemy_data_map，为每种敌人生成刷新按钮
	for etype: String in wave_manager.enemy_data_map.keys():
		var edata: Resource = wave_manager.enemy_data_map[etype]
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(80, 100)

		var btn := Button.new()
		var emoji: String = edata.display_emoji if edata.display_emoji != "" else "👾"
		btn.text = emoji
		btn.custom_minimum_size = Vector2(70, 60)
		btn.add_theme_font_size_override("font_size", 32)
		var cap := etype
		btn.pressed.connect(func():
			wave_manager.spawn_enemy(cap)
		)
		vbox.add_child(btn)

		var lbl := Label.new()
		lbl.text = edata.enemy_id if edata.enemy_id != "" else etype
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(80, 0)
		vbox.add_child(lbl)

		_tower_hbox.add_child(vbox)
