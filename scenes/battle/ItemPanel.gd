class_name ItemPanel
extends Node

## ── 消耗品道具 ───────────────────────────────────────────────────────
const ITEM_PATHS: Array[String] = [
	"res://data/items/gold_bag.tres",
	"res://data/items/landmine.tres",
]

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
		name_lbl.text = data.display_name
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


func _show_item_purchase_confirm(data: ItemData) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("UI_ITEM_PURCHASE_TITLE")
	dlg.dialog_text = tr("UI_ITEM_PURCHASE_MSG") % [
		data.emoji, data.display_name, data.gem_cost, UserManager.gems]
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
