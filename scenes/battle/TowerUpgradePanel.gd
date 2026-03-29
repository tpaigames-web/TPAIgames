extends Node
## 炮台升级面板子系统
## 管理：升级面板显示、BTD6路线锁定、售出确认、炮台详情、免费配额追踪

signal tower_sold(tower: Area2D)
signal request_apply_upgrades       # 升级后需全局重刷 buff
signal request_hero_panel(tower: Area2D)  # 英雄炮台点击时转交
signal request_hide_hero_panel      # 英雄售出时关闭英雄面板
signal request_refresh_card_affordability
signal panel_hidden                 # 面板关闭后通知外部刷新 tab

var _active_tower: Area2D = null
## 免费升级路径占用表
## key: "tower_id:path_idx"  →  占用该免费配额的炮台实例（Area2D）
## 若对应实例已失效（被售出），视为未占用
var _free_upgrade_owners: Dictionary = {}
var _info_dialog: AcceptDialog = null

# UI refs — 通过 init() 注入
var _hud: CanvasLayer
var _upgrade_panel: ScrollContainer
var _upgrade_vbox: VBoxContainer
var _bottom_panel: Control
var _tower_scroll: ScrollContainer
var _item_scroll: ScrollContainer
var _build_manager: Node
var _tutorial_guide_fn: Callable   # 返回教学引导实例或 null

var PANEL_EXPANDED_TOP: float
var PANEL_UPGRADE_TOP: float

# ───────────────────────────────────────────────────────────────────────
func init(
	hud: CanvasLayer,
	upgrade_panel: ScrollContainer,
	upgrade_vbox: VBoxContainer,
	bottom_panel: Control,
	tower_scroll: ScrollContainer,
	item_scroll: ScrollContainer,
	build_manager: Node,
	panel_expanded_top: float,
	panel_upgrade_top: float,
	tutorial_guide_fn: Callable = Callable()
) -> void:
	_hud = hud
	_upgrade_panel = upgrade_panel
	_upgrade_vbox = upgrade_vbox
	_bottom_panel = bottom_panel
	_tower_scroll = tower_scroll
	_item_scroll = item_scroll
	_build_manager = build_manager
	PANEL_EXPANDED_TOP = panel_expanded_top
	PANEL_UPGRADE_TOP = panel_upgrade_top
	if tutorial_guide_fn.is_valid():
		_tutorial_guide_fn = tutorial_guide_fn

# ── 外部调用入口 ──────────────────────────────────────────────────────────

func get_active_tower() -> Area2D:
	return _active_tower

func on_tower_tapped(tower: Area2D) -> void:
	# 通知教学引导
	var guide = _get_tutorial_guide()
	if is_instance_valid(guide):
		guide.notify_tower_tapped()
	var td := tower.tower_data as TowerCollectionData
	if td and td.is_hero:
		request_hero_panel.emit(tower)
	else:
		# 铁网损坏时点击触发维修
		if tower.get("_ability") and tower._ability.has_method("start_repair"):
			if tower._ability.get("_state") == 1:   # State.BROKEN = 1
				tower._ability.start_repair()
		show_upgrade_panel(tower)

func show_upgrade_panel(tower: Area2D) -> void:
	# 关闭旧炮台的范围显示
	if is_instance_valid(_active_tower) and _active_tower != tower:
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = tower
	_tower_scroll.visible = false
	_item_scroll.visible  = false
	_populate_upgrade_panel(tower)
	_upgrade_panel.visible = true
	# 面板上移，为升级内容提供更大空间
	_bottom_panel.offset_top = PANEL_UPGRADE_TOP
	_upgrade_panel.offset_bottom = -PANEL_UPGRADE_TOP
	# 显示炮台攻击范围圆（点击后高亮）
	tower.show_range = true
	tower.queue_redraw()

func hide_upgrade_panel() -> void:
	if is_instance_valid(_active_tower):
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = null
	_upgrade_panel.visible = false
	# 恢复面板位置和内容区高度
	_bottom_panel.offset_top = PANEL_EXPANDED_TOP
	_upgrade_panel.offset_bottom = 360.0
	panel_hidden.emit()

# ── 售出确认弹窗 ─────────────────────────────────────────────────────────

func _show_sell_confirm(tower: Area2D, sell_val: int, is_hero: bool) -> void:
	if not is_instance_valid(tower):
		return
	# 半透明遮罩 + 居中弹窗
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(overlay)

	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = Vector2(600, 300)
	dialog.position = Vector2(-300, -150)
	overlay.add_child(dialog)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog.add_child(vb)

	var msg := Label.new()
	var td := tower.tower_data as TowerCollectionData
	var name_str: String = td.display_name if td else "炮台"
	if is_hero:
		msg.text = "确定售出 %s？\n\n⚠️ 售出后地形效果消失\n重新放置需从 Lv1 开始成长" % name_str
	else:
		msg.text = "确定售出 %s？\n返还 %d 🪙" % [name_str, sell_val]
	msg.add_theme_font_size_override("font_size", 32)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 40)
	vb.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(200, 70)
	cancel_btn.add_theme_font_size_override("font_size", 32)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "确认售出"
	confirm_btn.custom_minimum_size = Vector2(200, 70)
	confirm_btn.add_theme_font_size_override("font_size", 32)
	confirm_btn.modulate = Color(1.0, 0.4, 0.3)
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		GameManager.add_gold(sell_val)
		if is_hero:
			request_hide_hero_panel.emit()
			_build_manager.set_hero_placed(false)
			request_refresh_card_affordability.emit()
		else:
			hide_upgrade_panel()
			if tower.tower_data and (tower.tower_data as TowerCollectionData).is_hero:
				_build_manager.set_hero_placed(false)
				request_refresh_card_affordability.emit()
		for key in _free_upgrade_owners.keys():
			if _free_upgrade_owners[key] == tower:
				_free_upgrade_owners.erase(key)
		tower_sold.emit(tower)
		tower.queue_free()
	)
	btn_row.add_child(confirm_btn)

# ── 升级面板内容填充 ─────────────────────────────────────────────────────

func _populate_upgrade_panel(tower: Area2D) -> void:
	if not is_instance_valid(tower):
		return
	for c in _upgrade_vbox.get_children():
		c.queue_free()
	var data: TowerCollectionData = tower.tower_data as TowerCollectionData
	if not data:
		return

	# 顶部：返回按钮 + 炮台名称
	var header := HBoxContainer.new()
	var back   := Button.new()
	back.text  = "← 返回"
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(hide_upgrade_panel)
	header.add_child(back)
	var title := Label.new()
	title.text = "%s %s" % [data.tower_emoji, data.display_name]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var sell_val := int(tower.stat_total_spent * 0.65)
	var sell_btn := Button.new()
	sell_btn.text = "💰 售出\n%d🪙" % sell_val
	sell_btn.add_theme_font_size_override("font_size", 24)
	sell_btn.pressed.connect(func():
		_show_sell_confirm(tower, sell_val, false)
	)
	header.add_child(sell_btn)
	var info_btn := Button.new()
	info_btn.text = "ⓘ"
	info_btn.add_theme_font_size_override("font_size", 26)
	info_btn.pressed.connect(func(): _show_tower_info(tower))
	header.add_child(info_btn)
	_upgrade_vbox.add_child(header)

	# 当前有效属性展示行
	var stats_lbl := Label.new()
	var eff_dmg: float = tower.get_effective_damage()
	var eff_ivl: float = tower.get_effective_attack_interval()
	stats_lbl.text = "⚔️ %.1f  ⚡ %.2f/s  🎯 %.0f px" % [eff_dmg, 1.0 / maxf(eff_ivl, 0.001), data.attack_range]
	stats_lbl.add_theme_font_size_override("font_size", 24)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.modulate = Color(0.9, 1.0, 0.7)
	_upgrade_vbox.add_child(stats_lbl)

	# 攻击目标选择行
	var target_row := HBoxContainer.new()
	var _modes := [["第一个", 0], ["靠近", 1], ["强力", 2], ["最后", 3]]
	for md in _modes:
		var btn := Button.new()
		btn.text = md[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 24)
		var idx: int = md[1]
		if tower.target_mode == idx:
			btn.disabled = true
		btn.pressed.connect(func():
			tower.target_mode = idx
			_populate_upgrade_panel(tower))
		target_row.add_child(btn)
	_upgrade_vbox.add_child(target_row)

	# 4 条路径行
	for i in data.upgrade_paths.size():
		_upgrade_vbox.add_child(_make_upgrade_row(tower, i))

# ── 浮动文字 ─────────────────────────────────────────────────────────────

## 浮动升级文字提示（英雄升级时显示）
func show_float_text(msg: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.modulate = Color(1.0, 0.9, 0.2)
	lbl.z_index  = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.global_position = pos + Vector2(-60, -60)
	get_tree().current_scene.add_child(lbl)
	var tween := lbl.create_tween()   # 绑定到 lbl，lbl 被释放时 tween 自动停止
	tween.tween_property(lbl, "position:y", lbl.position.y - 80, 1.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)

# ── 炮台详细信息弹窗 ─────────────────────────────────────────────────────

func _show_tower_info(tower: Area2D) -> void:
	var data := tower.tower_data as TowerCollectionData
	if not data:
		return

	var text: String = ""

	# ── 伤害分解 ──
	var dmg: Dictionary = tower.get_damage_breakdown()
	if not dmg.is_empty():
		text += "─── 伤害分解 ───\n"
		text += "基础伤害:  %.1f\n" % dmg.get("base", 0)
		var pb: float = dmg.get("path_bonus", 0)
		if pb > 0:
			text += "路线升级:  +%d%% (+%.1f)\n" % [int(pb * 100), dmg.get("base", 0) * pb]
		var gb: float = dmg.get("global_bonus", 0)
		if gb > 0:
			text += "波次强化:  +%d%%\n" % int(gb * 100)
		var hb: float = dmg.get("hero_bonus", 0)
		if hb > 0:
			text += "英雄加成:  +%d%%\n" % int(hb * 100)
		var tb: float = dmg.get("terrain_bonus", 0)
		if tb > 0:
			text += "圣地加成:  +%d%%\n" % int(tb * 100)
		var bm: float = dmg.get("buff_mult", 1.0)
		if not is_equal_approx(bm, 1.0):
			text += "光环加成:  ×%.2f\n" % bm
		for ab in dmg.get("aura_buffs", []):
			text += "%s %s:  +%d%%\n" % [ab.get("emoji", ""), ab.get("name", ""), int(ab.get("value", 0) * 100)]
		text += "最终伤害:  %.1f\n\n" % dmg.get("final", 0)

	# ── 攻速分解 ──
	var spd: Dictionary = tower.get_speed_breakdown()
	if not spd.is_empty() and spd.get("base_interval", 0) > 0:
		text += "─── 攻速分解 ───\n"
		text += "基础间隔:  %.2fs\n" % spd.get("base_interval", 0)
		var sp: float = spd.get("path_bonus", 0)
		if sp > 0:
			text += "路线升级:  +%d%%\n" % int(sp * 100)
		var sg: float = spd.get("global_bonus", 0)
		if sg > 0:
			text += "波次强化:  +%d%%\n" % int(sg * 100)
		var sm: float = spd.get("buff_mult", 1.0)
		if not is_equal_approx(sm, 1.0):
			text += "光环加成:  ×%.2f\n" % sm
		for ab in spd.get("aura_buffs", []):
			text += "%s %s:  ×%.2f\n" % [ab.get("emoji", ""), ab.get("name", ""), ab.get("value", 0)]
		text += "最终间隔:  %.2fs (%.1f次/秒)\n\n" % [spd.get("final_interval", 0), spd.get("attacks_per_sec", 0)]

	# ── 射程分解 ──
	var rng: Dictionary = tower.get_range_breakdown()
	if not rng.is_empty():
		text += "─── 射程分解 ───\n"
		text += "基础射程:  %.0fpx\n" % rng.get("base", 0)
		var rp: float = rng.get("path_bonus", 0)
		if rp > 0:
			text += "路线升级:  +%d%%\n" % int(rp * 100)
		var rg: float = rng.get("global_bonus", 0)
		if rg > 0:
			text += "波次强化:  +%d%%\n" % int(rg * 100)
		text += "最终射程:  %.0fpx\n\n" % rng.get("final", 0)

	# ── 特殊加成 ──
	var specials: Array[String] = tower.get_special_bonuses()
	# Buff 来源特殊效果
	for bs in tower.buff_sources:
		if bs.get("type") == "special":
			specials.append("%s %s: %s" % [bs.get("emoji", ""), bs.get("name", ""), bs.get("desc", "")])
	if not specials.is_empty():
		text += "─── 特殊加成 ───\n"
		for s in specials:
			text += "• %s\n" % s
		text += "\n"

	# ── 统计 ──
	text += "─── 战斗统计 ───\n"
	text += "💰 总花费: %d\n" % tower.stat_total_spent
	text += "⚔️ 造成伤害: %.0f\n" % tower.stat_damage_dealt
	text += "💀 击杀数量: %d\n" % tower.stat_kills
	text += "🌊 放置波次: 第 %d 波\n" % tower.stat_wave_placed

	# 关闭旧的详情弹窗
	if is_instance_valid(_info_dialog):
		_info_dialog.queue_free()
	var dlg := AcceptDialog.new()
	dlg.title = "%s %s — 详细信息" % [data.tower_emoji, data.display_name]
	dlg.dialog_text = text
	dlg.exclusive = false   # 不阻止其他 UI 交互
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 24)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.confirmed.connect(func(): _info_dialog = null)
	dlg.canceled.connect(func(): _info_dialog = null)
	_info_dialog = dlg
	dlg.popup_centered()

# ── 升级行构建 ───────────────────────────────────────────────────────────

func _make_upgrade_row(tower: Area2D, path_idx: int) -> VBoxContainer:
	var data         := tower.tower_data as TowerCollectionData
	var path         := data.upgrade_paths[path_idx] as TowerUpgradePath
	var cur_tier     : int  = tower._in_game_path_levels[path_idx]
	var arsenal_tier : int  = CollectionManager.get_path_level(data.tower_id, path_idx)
	var at_max       : bool = cur_tier >= 5

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)

	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = path.path_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 26)
	row.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d/5" % cur_tier
	tier_lbl.add_theme_font_size_override("font_size", 26)
	row.add_child(tier_lbl)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 26)
	if at_max:
		btn.text     = "MAX"
		btn.disabled = true
	else:
		var is_locked := not _can_upgrade_ingame(tower, path_idx)
		if is_locked:
			btn.text     = "🔒 锁定"
			btn.disabled = true
		else:
			var is_free : bool = (cur_tier + 1) <= arsenal_tier \
				and _is_free_available(data.tower_id, path_idx, tower)
			if is_free:
				btn.text = "升级 FREE"
			else:
				var cost : int = path.tier_costs[cur_tier] if cur_tier < path.tier_costs.size() else 0
				btn.text = "升级 🪙%d" % cost
				btn.disabled = (GameManager.gold < cost)
			var ci := path_idx
			btn.pressed.connect(func() -> void: _do_upgrade(tower, ci))
	row.add_child(btn)
	wrap.add_child(row)

	# 下一层升级效果说明
	if not at_max and cur_tier < path.tier_effects.size():
		var fx_lbl := Label.new()
		fx_lbl.text = "→ " + path.tier_effects[cur_tier]
		fx_lbl.add_theme_font_size_override("font_size", 22)
		fx_lbl.modulate = Color(1.0, 0.9, 0.5)
		fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrap.add_child(fx_lbl)

	return wrap

# ── BTD6 风格升级路线战局锁定规则 ────────────────────────────────────────
##   最多同时升级 2 条路线（cur==0 时不能开启第 3 条）
##   若有任意路线已达 3 层，其他路线最多升到 2 层

func _can_upgrade_ingame(tower: Area2D, path_idx: int) -> bool:
	var levels: Array[int] = tower._in_game_path_levels
	var cur: int = levels[path_idx]
	if cur >= 5:
		return false
	# 统计已激活（>0）的路线数
	var active: int = 0
	for lvl: int in levels:
		if lvl > 0:
			active += 1
	# 不允许开启第 3 条路线
	if cur == 0 and active >= 2:
		return false
	# 若有其他路线已达 3 层，本路线上限受 other_cap 限制
	var other_cap: int = 2
	for i: int in levels.size():
		if i != path_idx and levels[i] >= 3 and cur >= other_cap:
			return false
	return true

func _do_upgrade(tower: Area2D, path_idx: int) -> void:
	if not is_instance_valid(tower):
		return
	if not _can_upgrade_ingame(tower, path_idx):
		return
	var data         := tower.tower_data as TowerCollectionData
	var path         := data.upgrade_paths[path_idx] as TowerUpgradePath
	var cur_tier     : int  = tower._in_game_path_levels[path_idx]
	var arsenal_tier : int  = CollectionManager.get_path_level(data.tower_id, path_idx)
	if cur_tier >= 5:
		return
	var is_free : bool = (cur_tier + 1) <= arsenal_tier \
		and _is_free_available(data.tower_id, path_idx, tower)
	if not is_free:
		var cost : int = path.tier_costs[cur_tier] if cur_tier < path.tier_costs.size() else 0
		if not GameManager.spend_gold(cost):
			return
		tower.stat_total_spent += cost
	else:
		# 标记此路线的免费配额已被本炮台占用
		_free_upgrade_owners["%s:%d" % [data.tower_id, path_idx]] = tower
	tower._in_game_path_levels[path_idx] += 1
	tower.apply_stat_upgrades()
	# 重新应用全局强化，防止单塔升级覆盖波次强化加成
	request_apply_upgrades.emit()
	_populate_upgrade_panel(tower)
	# 通知教学引导单塔升级完成
	var guide = _get_tutorial_guide()
	if is_instance_valid(guide):
		guide.notify_single_upgrade_chosen()

## 判断指定炮台是否可使用该路线的免费配额
## 未被占用、或占用者已被销毁（售出）、或占用者就是本塔 → 可用
func _is_free_available(tower_id: String, path_idx: int, tower: Area2D) -> bool:
	if GameManager.challenge_mode:
		return false   # 挑战模式：兵工厂配额全部禁用
	var key := "%s:%d" % [tower_id, path_idx]
	if not _free_upgrade_owners.has(key):
		return true
	var owner = _free_upgrade_owners[key]
	return not is_instance_valid(owner) or owner == tower

# ── 辅助 ─────────────────────────────────────────────────────────────────

func _get_tutorial_guide():
	if _tutorial_guide_fn.is_valid():
		return _tutorial_guide_fn.call()
	return null

## 清除已失效炮台的免费配额记录
func cleanup_free_owners_for(tower: Area2D) -> void:
	for key in _free_upgrade_owners.keys():
		if _free_upgrade_owners[key] == tower:
			_free_upgrade_owners.erase(key)

## 重置所有状态（新一局开始时调用）
func reset() -> void:
	_active_tower = null
	_free_upgrade_owners.clear()
	if is_instance_valid(_info_dialog):
		_info_dialog.queue_free()
		_info_dialog = null
