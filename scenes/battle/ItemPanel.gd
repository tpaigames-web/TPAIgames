class_name ItemPanel
extends Node

## ── 消耗品道具 + 临时炮台 ──────────────────────────────────────────────
const ITEM_PATHS: Array[String] = [
	"res://data/items/gold_bag.tres",
	"res://data/items/landmine.tres",
]

## 临时炮台使用完成信号（BattleScene 连接后处理）
signal temp_tower_selected(tower_data: Resource, hero_config: Dictionary)

## 战局内购买临时炮台的钻石价格
const TEMP_TOWER_GEM_COST: int = 60

var _item_card_entries: Array = []
var _temp_card_entries: Array = []   # 临时炮台卡片
var _buy_card: Control = null        # 购买随机临时炮台按钮
var _used_temp_indices: Array[int] = []  # 本局已使用的临时炮台索引（每种每局限1次）
var _item_preview: Node2D = null
var _item_drag_data: ItemData = null
var _item_dragging: bool = false

var _item_hbox: HBoxContainer
var _battle_scene: Node
var _bottom_panel: Control


func init(item_hbox: HBoxContainer, battle_scene: Node, bottom_panel: Control) -> void:
	_item_hbox = item_hbox
	_battle_scene = battle_scene
	_bottom_panel = bottom_panel


func build_cards() -> void:
	_item_card_entries.clear()
	_temp_card_entries.clear()
	_buy_card = null

	# ── 1. 常规道具卡（金币袋、地雷）──────────────────────────────────
	for path in ITEM_PATHS:
		var data: ItemData = load(path)
		if data == null:
			continue
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(140, 220)
		card.add_theme_constant_override("separation", 4)

		var emoji_lbl := Label.new()
		emoji_lbl.text = data.emoji
		emoji_lbl.add_theme_font_size_override("font_size", 56)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(emoji_lbl)

		var name_lbl := Label.new()
		name_lbl.text = TowerResourceRegistry.tr_item_name(data)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.add_theme_font_size_override("font_size", 22)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(count_lbl)

		var use_btn := Button.new()
		use_btn.custom_minimum_size = Vector2(130, 50)
		use_btn.add_theme_font_size_override("font_size", 20)
		card.add_child(use_btn)

		var captured_data := data
		use_btn.pressed.connect(func(): _on_item_pressed(captured_data))

		_item_hbox.add_child(card)
		_item_card_entries.append({"card": card, "data": data, "count_label": count_lbl, "use_btn": use_btn})

	# ── 2. 临时炮台卡 + 购买按钮 ─────────────────────────────────────
	_rebuild_temp_cards()


func refresh_cards() -> void:
	# 刷新常规道具
	for entry in _item_card_entries:
		var data: ItemData = entry.data
		var count_lbl: Label = entry.count_label
		var use_btn: Button = entry.use_btn
		var count: int = UserManager.get_item_count(data.item_id)
		if count > 0:
			count_lbl.text = tr("UI_ITEM_STOCK") % count
			use_btn.text = tr("UI_ITEM_USE")
			use_btn.disabled = false
		elif UserManager.gems >= data.gem_cost:
			count_lbl.text = tr("UI_ITEM_NO_STOCK")
			use_btn.text = tr("UI_ITEM_BUY") % data.gem_cost
			use_btn.disabled = false
		else:
			count_lbl.text = tr("UI_ITEM_NO_STOCK")
			use_btn.text = tr("UI_ITEM_WATCH_AD")
			use_btn.disabled = false

	# 刷新临时炮台区域（重建）
	_rebuild_temp_cards()


## ── 重建临时炮台卡片 ─────────────────────────────────────────────────
func _rebuild_temp_cards() -> void:
	# 清理旧临时炮台卡
	for entry in _temp_card_entries:
		if is_instance_valid(entry.card):
			entry.card.queue_free()
	_temp_card_entries.clear()

	# 清理购买卡
	if _buy_card and is_instance_valid(_buy_card):
		_buy_card.queue_free()
		_buy_card = null

	# 为每个临时炮台创建独立卡片
	for i in UserManager.temp_tower_inventory.size():
		var entry: Dictionary = UserManager.temp_tower_inventory[i]
		var card := _make_temp_tower_card(entry, i)
		_item_hbox.add_child(card)
		_temp_card_entries.append({"card": card, "index": i, "entry": entry})

	# 购买随机临时炮台按钮（始终在末尾）
	_buy_card = _make_buy_temp_card()
	_item_hbox.add_child(_buy_card)


func _make_temp_tower_card(entry: Dictionary, index: int) -> VBoxContainer:
	var tower_id: String = entry.get("tower_id", "")
	var rarity: int = int(entry.get("rarity", 0))

	var tower_data: Resource = _load_tower_data(tower_id)
	var emoji: String = "📦"
	if tower_data:
		emoji = tower_data.get("tower_emoji") if tower_data.get("tower_emoji") else "📦"

	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.add_theme_constant_override("separation", 4)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# 稀有度色条
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(100, 4)
	color_bar.color = TowerResourceRegistry.RARITY_COLORS[clampi(rarity, 0, 4)]
	color_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(color_bar)

	# 图片区
	var img := Panel.new()
	img.custom_minimum_size = Vector2(100, 140)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tower_data and tower_data.get("collection_texture"):
		var tex := TextureRect.new()
		tex.texture = tower_data.collection_texture
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(tex)
	else:
		var emoji_lbl := Label.new()
		emoji_lbl.text = emoji
		emoji_lbl.add_theme_font_size_override("font_size", 48)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(emoji_lbl)
	card.add_child(img)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = TowerResourceRegistry.get_temp_tower_display_name(entry)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# "临时" + "免费"
	var badge := Label.new()
	badge.text = tr("UI_TEMP_BADGE")
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	var cost_lbl := Label.new()
	cost_lbl.text = tr("UI_TEMP_FREE_PLACE")
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cost_lbl)

	var captured_index: int = index

	if index in _used_temp_indices:
		# 本局已使用 → 变灰
		card.modulate = Color(0.5, 0.5, 0.5, 0.7)
		cost_lbl.text = tr("UI_TEMP_USED")
		cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif tower_data:
		# 直接拖拽放置（和普通炮台一样）
		var cap_td: Resource = tower_data
		var cap_hero_config: Dictionary = {
			"is_hero": entry.get("is_hero", false),
			"hero_level": int(entry.get("hero_level", 0)),
			"hero_directions": entry.get("hero_directions", []),
		}
		card.set_meta("temp_tower_id", tower_id)
		card.set_meta("temp_index", captured_index)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if captured_index in _used_temp_indices:
				return
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					_battle_scene.build_manager.select_tower(cap_td)
					card.set_meta("press_pos", e.global_position)
					card.set_meta("dragging", false)
					card.set_meta("locked_cost", 0)
					card.set_meta("temp_hero_config", cap_hero_config)
				else:
					if card.get_meta("dragging", false):
						_battle_scene.build_manager.release_drag()
						# 放置成功 → 从背包永久删除 + 保存
						_used_temp_indices.append(captured_index)
						UserManager.remove_temp_tower(captured_index)
						SaveManager.save()
						temp_tower_selected.emit(cap_td, cap_hero_config)
						_rebuild_temp_cards()
					else:
						_battle_scene.build_manager.cancel_selection()
					card.set_meta("dragging", false)
			elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var pp: Vector2 = card.get_meta("press_pos", e.global_position)
				if not card.get_meta("dragging", false):
					if e.global_position.distance_to(pp) >= 40.0:
						card.set_meta("dragging", true)
						_battle_scene.build_manager.start_drag_at(e.global_position, 0)
				else:
					_battle_scene.build_manager.move_preview_to(e.global_position)
			elif e is InputEventScreenTouch:
				if e.pressed:
					_battle_scene.build_manager.select_tower(cap_td)
					card.set_meta("press_pos", e.position)
					card.set_meta("dragging", false)
					card.set_meta("locked_cost", 0)
					card.set_meta("temp_hero_config", cap_hero_config)
				else:
					if card.get_meta("dragging", false):
						_battle_scene.build_manager.release_drag()
						_used_temp_indices.append(captured_index)
						UserManager.remove_temp_tower(captured_index)
						SaveManager.save()
						temp_tower_selected.emit(cap_td, cap_hero_config)
						_rebuild_temp_cards()
					else:
						_battle_scene.build_manager.cancel_selection()
					card.set_meta("dragging", false)
			elif e is InputEventScreenDrag:
				var pp: Vector2 = card.get_meta("press_pos", e.position)
				if not card.get_meta("dragging", false):
					if e.position.distance_to(pp) >= 40.0:
						card.set_meta("dragging", true)
						var vp_pos: Vector2 = card.get_viewport().get_mouse_position()
						_battle_scene.build_manager.start_drag_at(vp_pos, 0)
				else:
					var vp_pos: Vector2 = card.get_viewport().get_mouse_position()
					_battle_scene.build_manager.move_preview_to(vp_pos)
		)

	return card


func _make_buy_temp_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(140, 220)
	card.add_theme_constant_override("separation", 4)

	var emoji_lbl := Label.new()
	emoji_lbl.text = "🎲"
	emoji_lbl.add_theme_font_size_override("font_size", 48)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.text = tr("UI_TEMP_BUY_TITLE")
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "💎 %d" % TEMP_TOWER_GEM_COST
	price_lbl.add_theme_font_size_override("font_size", 22)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = tr("UI_TEMP_BUY_BTN")
	buy_btn.custom_minimum_size = Vector2(130, 50)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.pressed.connect(_on_buy_temp_tower)
	card.add_child(buy_btn)

	return card


## 临时炮台现在直接在道具栏拖拽放置，不再需要"使用"按钮


## ── 购买随机临时炮台 ─────────────────────────────────────────────────
func _on_buy_temp_tower() -> void:
	if UserManager.gems < TEMP_TOWER_GEM_COST:
		# 钻石不足 → 看广告
		AdManager.show_rewarded_ad(
			func():
				var entry: Dictionary = TempTowerGenerator.generate_random()
				UserManager.add_temp_tower(entry)
				SaveManager.save()
				_rebuild_temp_cards()
				_show_temp_tower_reveal(entry),
			func(): pass
		)
		return

	# 确认购买弹窗
	var dlg := ConfirmDialog.show_dialog(
		_battle_scene,
		tr("UI_TEMP_BUY_CONFIRM_MSG") % [TEMP_TOWER_GEM_COST, UserManager.gems],
		tr("UI_ITEM_PURCHASE_CONFIRM"),
		tr("UI_DIALOG_CANCEL")
	)
	dlg.confirmed.connect(func():
		if UserManager.spend_gems(TEMP_TOWER_GEM_COST):
			var entry: Dictionary = TempTowerGenerator.generate_random()
			UserManager.add_temp_tower(entry)
			SaveManager.save()
			_rebuild_temp_cards()
			_show_temp_tower_reveal(entry)
	)


## 显示获得的临时炮台（简短提示）
func _show_temp_tower_reveal(entry: Dictionary) -> void:
	var name_str: String = TowerResourceRegistry.get_temp_tower_display_name(entry)
	var rarity: int = int(entry.get("rarity", 0))
	var color: Color = TowerResourceRegistry.RARITY_COLORS[clampi(rarity, 0, 4)]

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_scene.add_child(overlay)

	var lbl := Label.new()
	lbl.text = tr("UI_TEMP_REVEAL") % name_str
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-350, -30)
	lbl.custom_minimum_size = Vector2(700, 60)
	overlay.add_child(lbl)

	# 1.5秒后自动消失，或点击消失
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
		elif event is InputEventScreenTouch and event.pressed:
			overlay.queue_free()
	)
	var tw := overlay.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)


## ── 常规道具按下 ─────────────────────────────────────────────────────
func _on_item_pressed(data: ItemData) -> void:
	var count: int = UserManager.get_item_count(data.item_id)
	if count > 0:
		UserManager.use_item(data.item_id)
		SaveManager.save()
		_start_item_drag(data)
	elif UserManager.gems >= data.gem_cost:
		_show_item_purchase_confirm(data)
	else:
		AdManager.show_rewarded_ad(
			func():
				UserManager.add_item(data.item_id, 1)
				SaveManager.save()
				refresh_cards(),
			func(): pass
		)


func _show_item_purchase_confirm(data: ItemData) -> void:
	var dlg := ConfirmDialog.show_dialog(
		_battle_scene,
		tr("UI_ITEM_PURCHASE_MSG") % [
			data.emoji, TowerResourceRegistry.tr_item_name(data), data.gem_cost, UserManager.gems],
		tr("UI_ITEM_PURCHASE_CONFIRM"),
		tr("UI_DIALOG_CANCEL")
	)
	dlg.confirmed.connect(func():
		if UserManager.spend_gems(data.gem_cost):
			SaveManager.save()
			_start_item_drag(data)
		else:
			refresh_cards()
	)


## ── 道具拖拽放置（通用） ──────────────────────────────────────────────

func _start_item_drag(data: ItemData) -> void:
	if _item_dragging:
		return
	_item_drag_data = data
	_item_dragging = true

	_item_preview = Node2D.new()
	var lbl := Label.new()
	lbl.text = data.emoji
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-28, -28)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_preview.add_child(lbl)

	var map_node := _battle_scene.get_node_or_null("TutorialMap")
	if map_node:
		map_node.add_child(_item_preview)


func _input(event: InputEvent) -> void:
	if not _item_dragging or _item_preview == null:
		return
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pos = event.position
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pos = event.position
	else:
		return

	var map_node := _battle_scene.get_node_or_null("TutorialMap")
	if not map_node:
		return
	_item_preview.position = map_node.to_local(pos)

	var released: bool = false
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		released = true
	elif event is InputEventScreenTouch and not event.pressed:
		released = true

	if released:
		_on_item_drop(pos)


func _on_item_drop(screen_pos: Vector2) -> void:
	_item_dragging = false
	if _item_preview:
		_item_preview.queue_free()
		_item_preview = null

	var panel_top: float = get_viewport().get_visible_rect().size.y + _bottom_panel.offset_top
	if screen_pos.y >= panel_top:
		UserManager.add_item(_item_drag_data.item_id, 1)
		SaveManager.save()
		refresh_cards()
		return

	match _item_drag_data.effect_type:
		"gold_boost":
			GameManager.add_gold(int(_item_drag_data.effect_value))
			refresh_cards()
		"landmine":
			var map_node := _battle_scene.get_node_or_null("TutorialMap")
			if not map_node:
				return
			var local_pos: Vector2 = map_node.to_local(screen_pos)
			var path2d: Path2D = map_node.get_node_or_null("Path2D")
			if path2d and path2d.curve:
				var curve: Curve2D = path2d.curve
				var closest_offset: float = curve.get_closest_offset(local_pos)
				var snap_pos: Vector2 = curve.sample_baked(closest_offset)
				if local_pos.distance_to(snap_pos) > 150.0:
					UserManager.add_item(_item_drag_data.item_id, 1)
					SaveManager.save()
					refresh_cards()
					return
				_spawn_active_mine(snap_pos, _item_drag_data)
			else:
				UserManager.add_item(_item_drag_data.item_id, 1)
				SaveManager.save()
			refresh_cards()


func _spawn_active_mine(mine_pos: Vector2, data: ItemData) -> void:
	var map_node := _battle_scene.get_node_or_null("TutorialMap")
	if not map_node:
		return

	var mine := Area2D.new()
	mine.position = mine_pos
	mine.collision_layer = 0
	mine.collision_mask  = 8
	mine.monitoring      = true

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 60.0
	col.shape = shape
	mine.add_child(col)

	var lbl := Label.new()
	lbl.text = "💣"
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-24, -24)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mine.add_child(lbl)

	var damage: float = data.effect_value
	var blast_r: float = data.blast_radius
	mine.area_entered.connect(func(area: Area2D):
		if area.is_in_group("enemy"):
			for enemy in GameManager.get_all_enemies():
				if is_instance_valid(enemy):
					var dist: float = enemy.global_position.distance_to(mine.global_position)
					if dist <= blast_r:
						CombatService.deal_damage(
								{"source_tower": null, "armor_penetration": 0, "pierce_giant": false, "ignore_dodge": false},
								enemy, float(damage), []
							)
			lbl.text = "💥"
			mine.monitoring = false
			var tw := mine.create_tween()
			tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): mine.queue_free())
	)

	var tower_layer := map_node.get_node_or_null("TowerLayer")
	if tower_layer:
		tower_layer.add_child(mine)
	else:
		map_node.add_child(mine)


## ── 辅助：加载炮台数据 ──────────────────────────────────────────────
func _load_tower_data(tower_id: String) -> Resource:
	for res in TowerResourceRegistry.get_all_resources():
		if res.get("tower_id") == tower_id:
			return res
	return null
