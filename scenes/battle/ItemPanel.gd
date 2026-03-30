class_name ItemPanel
extends Node

## ── 消耗品道具 ───────────────────────────────────────────────────────
const ITEM_PATHS: Array[String] = [
	"res://data/items/gold_bag.tres",
	"res://data/items/landmine.tres",
	"res://data/items/trial_ticket.tres",
]

## 试用炮台选择完成信号（BattleScene 连接后处理）
signal trial_tower_selected(tower_data: Resource)

var _item_card_entries: Array = []
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
	for path in ITEM_PATHS:
		var data: ItemData = load(path)
		if data == null:
			continue
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(140, 220)
		card.add_theme_constant_override("separation", 4)

		# emoji 图标
		var emoji_lbl := Label.new()
		emoji_lbl.text = data.emoji
		emoji_lbl.add_theme_font_size_override("font_size", 56)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(emoji_lbl)

		# 名称
		var name_lbl := Label.new()
		name_lbl.text = TowerResourceRegistry.tr_item_name(data)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_lbl)

		# 库存/价格标签（动态更新）
		var count_lbl := Label.new()
		count_lbl.add_theme_font_size_override("font_size", 22)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(count_lbl)

		# 使用/购买按钮
		var use_btn := Button.new()
		use_btn.custom_minimum_size = Vector2(130, 50)
		use_btn.add_theme_font_size_override("font_size", 20)
		card.add_child(use_btn)

		var captured_data := data
		use_btn.pressed.connect(func(): _on_item_pressed(captured_data))

		_item_hbox.add_child(card)
		_item_card_entries.append({"card": card, "data": data, "count_label": count_lbl, "use_btn": use_btn})
	refresh_cards()


func refresh_cards() -> void:
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


func _on_item_pressed(data: ItemData) -> void:
	# 试用券特殊处理：不拖拽，弹出炮台选择
	if data.effect_type == "trial_tower":
		_handle_trial_ticket(data)
		return

	var count: int = UserManager.get_item_count(data.item_id)
	if count > 0:
		# 有库存 → 开始拖拽
		UserManager.use_item(data.item_id)
		SaveManager.save()
		_start_item_drag(data)
	elif UserManager.gems >= data.gem_cost:
		# 无库存 → 确认购买弹窗
		_show_item_purchase_confirm(data)
	else:
		# 无钻石 → 看广告
		AdManager.show_rewarded_ad(
			func():
				UserManager.add_item(data.item_id, 1)
				SaveManager.save()
				refresh_cards(),
			func(): pass
		)


## ── 试用券逻辑 ──────────────────────────────────────────────────────
func _handle_trial_ticket(data: ItemData) -> void:
	var count: int = UserManager.get_item_count(data.item_id)
	if count <= 0:
		if UserManager.gems >= data.gem_cost:
			_show_item_purchase_confirm(data)
		else:
			AdManager.show_rewarded_ad(
				func():
					UserManager.add_item(data.item_id, 1)
					SaveManager.save()
					refresh_cards(),
				func(): pass
			)
		return
	# 有库存 → 弹出紫/橙炮台选择面板
	_show_trial_tower_select()


func _show_trial_tower_select() -> void:
	# 收集所有紫（3）和橙（4）炮台
	var options: Array = []
	for res in TowerResourceRegistry.get_all_resources():
		var td = res as TowerCollectionData
		if td and td.rarity >= 3 and not td.is_hero:
			options.append(td)

	if options.is_empty():
		return

	# 创建选择弹窗
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_scene.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 500)
	panel.position = Vector2(-350, -250)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_TRIAL_SELECT_TITLE")
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for td in options:
		var btn := Button.new()
		var tname: String = TowerResourceRegistry.get_tower_display_name(td.tower_id, td.display_name)
		btn.text = "%s\n%s" % [td.tower_emoji, tname]
		btn.custom_minimum_size = Vector2(200, 100)
		btn.add_theme_font_size_override("font_size", 28)
		var captured_td = td
		btn.pressed.connect(func():
			overlay.queue_free()
			# 消耗试用券
			UserManager.use_item("trial_ticket")
			SaveManager.save()
			refresh_cards()
			# 通知 BattleScene 添加临时炮台
			trial_tower_selected.emit(captured_td)
		)
		grid.add_child(btn)

	# 取消按钮
	var cancel := Button.new()
	cancel.text = tr("UI_DIALOG_CANCEL")
	cancel.add_theme_font_size_override("font_size", 32)
	cancel.custom_minimum_size = Vector2(0, 60)
	cancel.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel)


func _show_item_purchase_confirm(data: ItemData) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("UI_ITEM_PURCHASE_TITLE")
	dlg.dialog_text = tr("UI_ITEM_PURCHASE_MSG") % [
		data.emoji, TowerResourceRegistry.tr_item_name(data), data.gem_cost, UserManager.gems]
	dlg.ok_button_text = tr("UI_ITEM_PURCHASE_CONFIRM")
	dlg.cancel_button_text = tr("UI_DIALOG_CANCEL")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if UserManager.spend_gems(data.gem_cost):
			SaveManager.save()
			_start_item_drag(data)
		else:
			refresh_cards()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	_battle_scene.add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


## ── 道具拖拽放置（通用） ──────────────────────────────────────────────

func _start_item_drag(data: ItemData) -> void:
	if _item_dragging:
		return
	_item_drag_data = data
	_item_dragging = true

	# 创建预览（跟随手指）
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

	# 松开 → 判断放置
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

	# 判断是否在操作台（底部面板）区域内 → 放回库存
	var panel_top: float = get_viewport().get_visible_rect().size.y + _bottom_panel.offset_top
	if screen_pos.y >= panel_top:
		# 放回库存
		UserManager.add_item(_item_drag_data.item_id, 1)
		SaveManager.save()
		refresh_cards()
		return

	# 在地图区域 → 使用道具
	match _item_drag_data.effect_type:
		"gold_boost":
			GameManager.add_gold(int(_item_drag_data.effect_value))
			refresh_cards()
		"landmine":
			var map_node := _battle_scene.get_node_or_null("TutorialMap")
			if not map_node:
				return
			var local_pos: Vector2 = map_node.to_local(screen_pos)
			# 吸附路径
			var path2d: Path2D = map_node.get_node_or_null("Path2D")
			if path2d and path2d.curve:
				var curve: Curve2D = path2d.curve
				var closest_offset: float = curve.get_closest_offset(local_pos)
				var snap_pos: Vector2 = curve.sample_baked(closest_offset)
				if local_pos.distance_to(snap_pos) > 150.0:
					# 距路径太远 → 返还
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
	mine.collision_mask  = 8   # 检测敌人层
	mine.monitoring      = true

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 60.0   # 触发范围（小），爆炸伤害范围用 blast_radius
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
			# 爆炸：对范围内所有敌人造成伤害
			for enemy in GameManager.get_all_enemies():
				if is_instance_valid(enemy):
					var dist: float = enemy.global_position.distance_to(mine.global_position)
					if dist <= blast_r:
						enemy.take_damage(damage)
			# 爆炸特效
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
