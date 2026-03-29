## 全局升级（波次强化）子系统
## 从 BattleScene.gd 提取，管理升级池、已选升级、图标HUD、详情弹窗
extends Node

signal upgrade_chosen(upg: GlobalUpgradeData)

## 升级触发波次
const UPGRADE_WAVE_TRIGGERS: Array[int] = [5, 10, 15, 20, 25, 30, 35]
const UPGRADE_POOL_DIR := "res://data/global_upgrades/"

## 显式文件列表（DirAccess 在导出后无法遍历 res:// 打包目录）
const _UPGRADE_FILES: Array[String] = [
	"beehive_dmg_b.tres", "beehive_spd_o.tres", "beehive_spd_w.tres",
	"beehive_aura_o.tres", "beehive_poison_b.tres",
	"cannon_aoe_b.tres", "cannon_dmg_b.tres", "cannon_dmg_o.tres", "cannon_dmg_w.tres",
	"chili_cone_o.tres", "chili_dmg_b.tres", "chili_dmg_o.tres", "chili_dmg_w.tres",
	"chili_mark_b.tres",
	"cost_all_o.tres", "cost_b.tres", "cost_elite_b.tres", "cost_repair_w.tres",
	"cost_upgrade_o.tres", "cost_w.tres",
	"farmer_crit_b.tres", "farmer_dmg_b.tres", "farmer_dmg_o.tres", "farmer_dmg_w.tres",
	"farmer_scatter_b.tres", "farmer_spd_w.tres",
	"global_crit_b.tres", "global_dmg_b.tres", "global_dmg_o.tres", "global_dmg_w.tres",
	"global_dot_b.tres", "global_dot_o.tres", "global_mark_b.tres", "global_mark_o.tres",
	"global_pierce_b.tres", "global_pierce_o.tres", "global_rng_b.tres",
	"global_slow_b.tres", "global_spd_b.tres", "global_spd_o.tres", "global_spd_w.tres",
	"hero_dmg_b.tres", "hero_dmg_o.tres", "hero_dmg_w.tres",
	"mushroom_aoe_b.tres", "mushroom_dmg_o.tres", "mushroom_dmg_w.tres",
	"mushroom_poison_b.tres", "mushroom_rng_w.tres",
	"scarecrow_curse_b.tres", "scarecrow_dmg_w.tres",
	"scarecrow_rng_b.tres", "scarecrow_rng_w.tres", "scarecrow_spd_o.tres",
	"seed_dmg_b.tres", "seed_grass_b.tres", "seed_rng_o.tres", "seed_rng_w.tres",
	"sun_aura_b.tres", "sun_burn_o.tres", "sun_rng_b.tres", "sun_spd_w.tres",
	"syn_armor_break.tres", "syn_bow_mark.tres", "syn_chili_wire.tres",
	"syn_control_field.tres", "syn_dot_empire.tres", "syn_farm_legend.tres",
	"syn_full_output.tres", "syn_hero_empire.tres", "syn_hero_guard.tres",
	"syn_mark_system.tres", "syn_mushroom_trap.tres", "syn_nature_storm.tres",
	"syn_poison_control.tres", "syn_poison_regen.tres", "syn_sun_water.tres",
	"syn_water_wire.tres", "syn_wire_complex.tres", "syn_wire_guard.tres",
	"synergy_bloom.tres", "synergy_cannon_watch.tres", "synergy_chili_beehive.tres",
	"synergy_farm_core.tres", "synergy_farm_full.tres", "synergy_fire_wind.tres",
	"synergy_full_defense.tres", "synergy_hero_all.tres", "synergy_hive_farmer.tres",
	"synergy_nature.tres", "synergy_poison_net.tres", "synergy_scarecrow_wire.tres",
	"synergy_seed_mushroom.tres", "synergy_sun_farmer.tres", "synergy_trap_wire.tres",
	"synergy_triple_atk.tres", "synergy_watch_seed.tres", "synergy_water_gun.tres",
	"synergy_water_seed.tres", "synergy_wind_cannon.tres",
	"trap_aoe_o.tres", "trap_dmg_b.tres", "trap_poison_b.tres", "trap_reset_w.tres",
	"watch_dmg_b.tres", "watch_mark_o.tres", "watch_pierce_b.tres",
	"watch_rng_o.tres", "watch_rng_w.tres",
	"water_corr_b.tres", "water_dmg_w.tres", "water_slow_b.tres",
	"water_spd_b.tres", "water_spd_o.tres",
	"wind_aoe_o.tres", "wind_dmg_b.tres", "wind_push_b.tres", "wind_spd_w.tres",
	"wire_bleed_b.tres", "wire_dur_w.tres", "wire_repair_b.tres",
	"wire_shock_o.tres", "wire_slow_o.tres",
]

var _upgrade_pool:    Array[GlobalUpgradeData] = []
var _active_upgrades: Array[GlobalUpgradeData] = []
var _upgrade_icon_container: VBoxContainer = null
var _upgrade_popup: PanelContainer = null
var _upgrade_popup_overlay: ColorRect = null
var _global_upgrade_panel: Node = null

var _hud: CanvasLayer = null


func init(hud: CanvasLayer) -> void:
	_hud = hud
	_load_upgrade_pool()
	_build_upgrade_icons_hud()


## ── 公开 API ──────────────────────────────────────────────────────────

func get_active_upgrades() -> Array[GlobalUpgradeData]:
	return _active_upgrades

func get_active_upgrade_ids() -> Array:
	var ids: Array = []
	for upg in _active_upgrades:
		ids.append(upg.upgrade_id)
	return ids

func restore_upgrades(ids: Array) -> void:
	_active_upgrades.clear()
	for uid in ids:
		for upg in _upgrade_pool:
			if upg.upgrade_id == uid:
				_active_upgrades.append(upg)
				break
	_apply_upgrades_to_all_towers()
	_update_upgrade_icons_hud()

func get_cost_discount_for(tower_id: String) -> float:
	var disc := 0.0
	for upg_raw in _active_upgrades:
		var upg := upg_raw as GlobalUpgradeData
		if upg == null: continue
		if upg.upgrade_type != GlobalUpgradeData.UpgradeType.COST_REDUCTION: continue
		if upg.stat_type != GlobalUpgradeData.StatType.COST: continue
		if upg.target_tower_id == "" or upg.target_tower_id == tower_id:
			disc += upg.stat_bonus
	return clamp(disc, 0.0, 0.9)

func should_trigger_on_wave(wave_num: int) -> bool:
	return wave_num in UPGRADE_WAVE_TRIGGERS and _active_upgrades.size() < 8


## ── 面板弹出 ──────────────────────────────────────────────────────────

func show_upgrade_panel(wave_num: int) -> void:
	if not is_inside_tree():
		return
	if _active_upgrades.size() >= 8:
		return
	if is_instance_valid(_global_upgrade_panel):
		return
	get_tree().paused = true
	var panel_scene := preload("res://scenes/global_upgrade/GlobalUpgradePanel.tscn")
	var panel := panel_scene.instantiate()
	_global_upgrade_panel = panel
	_hud.add_child(panel)
	panel.upgrade_chosen.connect(_on_upgrade_chosen)
	panel.setup(_upgrade_pool, _active_upgrades, wave_num)


func _on_upgrade_chosen(upg: GlobalUpgradeData) -> void:
	_global_upgrade_panel = null
	_active_upgrades.append(upg)
	_apply_upgrades_to_all_towers()
	_update_upgrade_icons_hud()
	upgrade_chosen.emit(upg)


## ── 应用升级到所有炮台 ──────────────────────────────────────────────────

func _apply_upgrades_to_all_towers() -> void:
	var synergy := check_synergies()
	for t in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(t):
			t.apply_global_buffs(_active_upgrades, synergy)

func check_synergies() -> Dictionary:
	var placed_ids: Array[String] = []
	for t in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(t) and not t.is_preview and t.tower_data:
			placed_ids.append(t.tower_data.tower_id)
	var result: Dictionary = {}
	for upg_raw in _active_upgrades:
		var upg := upg_raw as GlobalUpgradeData
		if upg == null or upg.upgrade_type != GlobalUpgradeData.UpgradeType.SYNERGY:
			continue
		var all_present: bool = upg.required_tower_ids.all(
			func(tid: String) -> bool: return tid in placed_ids
		)
		if all_present:
			result[upg.upgrade_id] = true
	return result


## ── HUD 图标 ──────────────────────────────────────────────────────────

func _build_upgrade_icons_hud() -> void:
	_upgrade_icon_container = VBoxContainer.new()
	_upgrade_icon_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_upgrade_icon_container.position = Vector2(6, 110)
	_upgrade_icon_container.visible  = false
	_hud.add_child(_upgrade_icon_container)

	_upgrade_popup_overlay = ColorRect.new()
	_upgrade_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upgrade_popup_overlay.color       = Color(0, 0, 0, 0)
	_upgrade_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_popup_overlay.visible     = false
	_upgrade_popup_overlay.gui_input.connect(_on_popup_overlay_input)
	_hud.add_child(_upgrade_popup_overlay)

	_upgrade_popup = PanelContainer.new()
	_upgrade_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_upgrade_popup.custom_minimum_size = Vector2(320, 0)
	_upgrade_popup.visible = false
	_hud.add_child(_upgrade_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_upgrade_popup.add_child(vbox)

	var emoji_lbl := Label.new()
	emoji_lbl.name = "EmojiLbl"
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 60)
	vbox.add_child(emoji_lbl)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.name = "RarityLbl"
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(rarity_lbl)

	vbox.add_child(HSeparator.new())

	var desc_lbl := Label.new()
	desc_lbl.name = "DescLbl"
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	var cond_lbl := Label.new()
	cond_lbl.name = "CondLbl"
	cond_lbl.add_theme_font_size_override("font_size", 22)
	cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cond_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cond_lbl.visible = false
	vbox.add_child(cond_lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.custom_minimum_size = Vector2(0, 54)
	close_btn.pressed.connect(_hide_popup)
	vbox.add_child(close_btn)


func _update_upgrade_icons_hud() -> void:
	if _upgrade_icon_container == null:
		return
	for c in _upgrade_icon_container.get_children():
		c.queue_free()
	_upgrade_icon_container.visible = not _active_upgrades.is_empty()
	for upg_raw in _active_upgrades:
		var upg := upg_raw as GlobalUpgradeData
		var btn := Button.new()
		btn.text                = upg.icon_emoji
		btn.custom_minimum_size = Vector2(46, 46)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _show_popup(upg, btn))
		_upgrade_icon_container.add_child(btn)


func _show_popup(upg: GlobalUpgradeData, anchor: Control) -> void:
	if _upgrade_popup == null:
		return
	var vbox := _upgrade_popup.get_child(0) as VBoxContainer
	(vbox.get_node("EmojiLbl")  as Label).text = upg.icon_emoji
	(vbox.get_node("NameLbl")   as Label).text = upg.display_name
	(vbox.get_node("DescLbl")   as Label).text = upg.description

	const COLORS := [Color(0.75,0.75,0.75), Color(0.20,0.45,0.90), Color(0.90,0.50,0.10), Color(0.85,0.15,0.15)]
	const NAMES  := ["普通", "稀有", "史诗", "传说"]
	var r: int = clampi(upg.rarity, 0, 2)
	var rarity_lbl := vbox.get_node("RarityLbl") as Label
	rarity_lbl.text = "【%s】" % NAMES[r]
	rarity_lbl.add_theme_color_override("font_color", COLORS[r])

	var cond_lbl := vbox.get_node("CondLbl") as Label
	if upg.required_tower_ids.size() > 0:
		cond_lbl.text    = "⚠ 需要：" + "、".join(upg.required_tower_ids)
		cond_lbl.visible = true
	else:
		cond_lbl.visible = false

	var icon_pos: Vector2 = anchor.get_global_rect().position
	var popup_x: float = icon_pos.x + anchor.size.x + 4
	var popup_y: float = icon_pos.y
	_upgrade_popup.position = Vector2(popup_x, popup_y)
	_upgrade_popup_overlay.visible = true
	_upgrade_popup.visible = true


func _hide_popup() -> void:
	if _upgrade_popup != null:
		_upgrade_popup.visible = false
	if _upgrade_popup_overlay != null:
		_upgrade_popup_overlay.visible = false


func _on_popup_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_popup()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_hide_popup()


## ── 数据加载 ──────────────────────────────────────────────────────────

func _load_upgrade_pool() -> void:
	_upgrade_pool.clear()
	var dir := DirAccess.open(UPGRADE_POOL_DIR)
	if dir:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var res := load(UPGRADE_POOL_DIR + fname) as GlobalUpgradeData
				if res:
					_upgrade_pool.append(res)
			fname = dir.get_next()
		dir.list_dir_end()
	else:
		for fname2 in _UPGRADE_FILES:
			var res := load(UPGRADE_POOL_DIR + fname2) as GlobalUpgradeData
			if res:
				_upgrade_pool.append(res)
			else:
				push_warning("GlobalUpgrade: 无法加载 " + UPGRADE_POOL_DIR + fname2)
	if _upgrade_pool.is_empty():
		push_warning("GlobalUpgrade: 升级池为空！检查 data/global_upgrades/ 目录")
