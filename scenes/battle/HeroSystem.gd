## 英雄系统子系统 — 从 BattleScene.gd 提取
extends Node

signal hero_upgrade_done
signal request_sell_confirm(tower: Area2D, refund: int, is_hero: bool)

const HERO_UPGRADE_INTERVAL: int = 5
const HERO_MAX_UPGRADES: int = 4

const HERO_TERRAIN_INFO := {
	"hero_farmer": {
		"terrain_name": "丰收圣地",
		"base_desc": "圣地内炮台伤害+12%，每次击杀+1金币",
		"upgrades": [
			{"a_icon": "🌾", "a_name": "圣地深耕", "a_desc": "圣地内伤害加成提升至+32%",
			 "b_icon": "💰", "b_name": "金穗满田", "b_desc": "击杀+2金币，精英击杀+5金币"},
			{"a_icon": "🏕️", "a_name": "广袤农场", "a_desc": "圣地半径扩展至260px",
			 "b_icon": "⚡", "b_name": "丰收节奏", "b_desc": "圣地内每10次击杀触发爆发：伤害×2持续3秒"},
			{"a_icon": "🛡️", "a_name": "农神庇护", "a_desc": "圣地内炮台受伤-20%",
			 "b_icon": "💎", "b_name": "黄金地脉", "b_desc": "圣地内炮台升级费用-25%"},
			{"a_icon": "☀️", "a_name": "永恒圣地", "a_desc": "半径扩展至350px，伤害加成叠加全部路线效果",
			 "b_icon": "🌟", "b_name": "农场之神", "b_desc": "圣地内精英击杀10%概率获得免费强化刷新"},
		],
	},
	"farm_guardian": {
		"terrain_name": "禁锢领域",
		"base_desc": "领域内敌人移速-20%，优先朝守卫者移动（嘲讽）",
		"upgrades": [
			{"a_icon": "🪨", "a_name": "铁壁嘲讽", "a_desc": "嘲讽范围200px，敌人停留+1.5秒",
			 "b_icon": "🌀", "b_name": "重力领域", "b_desc": "领域内移速-35%，大型敌人同样生效"},
			{"a_icon": "🗿", "a_name": "石刻地面", "a_desc": "领域每秒对敌人造成8点伤害",
			 "b_icon": "⚔️", "b_name": "破甲领域", "b_desc": "领域内敌人护甲降低10%"},
			{"a_icon": "💥", "a_name": "冲击余波", "a_desc": "每20秒地震100px范围，眩晕1.2秒",
			 "b_icon": "🧲", "b_name": "磁力核心", "b_desc": "将范围外100px的敌人减速50%"},
			{"a_icon": "⛓️", "a_name": "永恒禁锢", "a_desc": "半径扩展至280px，嘲讽期间全场+25%伤害",
			 "b_icon": "🪦", "b_name": "石之迫近", "b_desc": "领域内死亡留下石化标记，后续敌人减速10秒"},
		],
	},
}

var _hero_tower: Area2D = null
var _hero_place_wave: int = -1
var _hero_terrain_data: HeroTerrainData = null
var _hero_panel: Control = null
var _hero_upgrade_panel: Node = null

## UI references (set via init)
var _hud: CanvasLayer = null
var _upgrade_panel: ScrollContainer = null
var _upgrade_vbox: VBoxContainer = null
var _bottom_panel: Control = null
var _tower_scroll: ScrollContainer = null
var _item_scroll: ScrollContainer = null
var _wave_manager: Node = null

## Panel offset constants (must match BattleScene)
var PANEL_EXPANDED_TOP: float = -490.0
var PANEL_UPGRADE_TOP: float = -870.0


func init(hud: CanvasLayer, upgrade_panel: ScrollContainer, upgrade_vbox: VBoxContainer,
		bottom_panel: Control, tower_scroll: ScrollContainer, item_scroll: ScrollContainer,
		wave_mgr: Node, panel_expanded_top: float, panel_upgrade_top: float) -> void:
	_hud = hud
	_upgrade_panel = upgrade_panel
	_upgrade_vbox = upgrade_vbox
	_bottom_panel = bottom_panel
	_tower_scroll = tower_scroll
	_item_scroll = item_scroll
	_wave_manager = wave_mgr
	PANEL_EXPANDED_TOP = panel_expanded_top
	PANEL_UPGRADE_TOP = panel_upgrade_top


## ── 公开 API ──────────────────────────────────────────────────────────

func get_hero_tower() -> Area2D:
	return _hero_tower

func is_hero_placed() -> bool:
	return is_instance_valid(_hero_tower)

func get_hero_place_wave() -> int:
	return _hero_place_wave

func register_hero(tower: Area2D, wave: int) -> void:
	_hero_tower = tower
	_hero_place_wave = wave

func on_hero_sold() -> void:
	_hero_tower = null
	_hero_place_wave = -1
	_hero_terrain_data = null

func get_hero_upgrade_wave(upgrade_index: int) -> int:
	return _hero_place_wave + HERO_UPGRADE_INTERVAL * (upgrade_index + 1)

func get_hero_upgrade_tier(wave_num: int) -> int:
	if _hero_place_wave < 0:
		return 0
	var waves_since: int = wave_num - _hero_place_wave
	if waves_since <= 0 or waves_since % HERO_UPGRADE_INTERVAL != 0:
		return 0
	var tier: int = waves_since / HERO_UPGRADE_INTERVAL
	if tier < 1 or tier > HERO_MAX_UPGRADES:
		return 0
	return tier

func get_hero_chosen_upgrades() -> Array:
	if is_instance_valid(_hero_tower):
		return _hero_tower.hero_chosen_upgrades
	return []

func restore_hero_upgrades(choices: Array) -> void:
	if not is_instance_valid(_hero_tower):
		return
	for choice in choices:
		_hero_tower.hero_chosen_upgrades.append(choice)
		var tier: int = _hero_tower.hero_chosen_upgrades.size()
		var ab = _hero_tower.get("_ability")
		if ab and ab.has_method("apply_upgrade"):
			ab.apply_upgrade(tier, choice)
	_hero_tower.hero_level = _hero_tower.hero_chosen_upgrades.size() + 1


## ── 英雄面板显示 ──────────────────────────────────────────────────────

func show_hero_panel(tower: Area2D, active_tower_ref: Area2D) -> Area2D:
	hide_hero_panel()
	# Close old tower range display
	if is_instance_valid(active_tower_ref) and active_tower_ref != tower:
		active_tower_ref.show_range = false
		active_tower_ref.queue_redraw()

	_tower_scroll.visible = false
	_item_scroll.visible  = false
	tower.show_range = true
	tower.queue_redraw()

	# Load terrain data
	var data := tower.tower_data as TowerCollectionData
	if _hero_terrain_data == null and data:
		var terrain_file: String = "afu" if data.tower_id == "hero_farmer" else "guardian"
		_hero_terrain_data = load("res://data/heroes/%s_terrain.tres" % terrain_file) as HeroTerrainData

	# Reuse upgrade panel area
	for c in _upgrade_vbox.get_children():
		_upgrade_vbox.remove_child(c)
		c.queue_free()
	_upgrade_panel.visible = true
	_bottom_panel.offset_top = PANEL_UPGRADE_TOP
	_upgrade_panel.offset_bottom = -PANEL_UPGRADE_TOP
	_hero_panel = _upgrade_panel

	var vbox := _upgrade_vbox
	var tid: String = data.tower_id if data else ""
	var info: Dictionary = HERO_TERRAIN_INFO.get(tid, {})
	var lv: int = tower.hero_chosen_upgrades.size() + 1
	var t_name: String = info.get("terrain_name", "地形") as String
	var base_effect: String = info.get("base_desc", "") as String
	var upgrades_arr: Array = info.get("upgrades", []) as Array

	# Header
	var header := HBoxContainer.new()
	var back_b := Button.new()
	back_b.text = "← 返回"
	back_b.add_theme_font_size_override("font_size", 28)
	back_b.pressed.connect(hide_hero_panel)
	header.add_child(back_b)

	var title := Label.new()
	var _emoji: String = data.tower_emoji if data else "🗿"
	var _dname: String = data.display_name if data else "英雄"
	title.text = "%s %s  英雄" % [_emoji, _dname]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	header.add_child(title)

	var sell_b := Button.new()
	sell_b.text = "🔥 售出"
	sell_b.add_theme_font_size_override("font_size", 24)
	sell_b.pressed.connect(func():
		request_sell_confirm.emit(tower, 0, true)
	)
	header.add_child(sell_b)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Terrain info
	var terrain_lbl := Label.new()
	terrain_lbl.text = "☀️ %s · 半径 %dpx" % [t_name, int(tower.terrain_radius)]
	terrain_lbl.add_theme_font_size_override("font_size", 30)
	terrain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(terrain_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "等级 Lv.%d / 5" % lv
	lv_lbl.add_theme_font_size_override("font_size", 26)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(lv_lbl)

	vbox.add_child(HSeparator.new())

	# Base skill
	var base_title := Label.new()
	base_title.text = "📋 初始技能"
	base_title.add_theme_font_size_override("font_size", 26)
	base_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(base_title)

	var base_desc := Label.new()
	base_desc.text = "• %s" % base_effect
	base_desc.add_theme_font_size_override("font_size", 24)
	base_desc.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	base_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(base_desc)

	# Chosen upgrades
	var upgrade_title := Label.new()
	upgrade_title.text = "⚡ 已选升级" if tower.hero_chosen_upgrades.size() > 0 else "⚡ 暂无升级"
	upgrade_title.add_theme_font_size_override("font_size", 26)
	upgrade_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	vbox.add_child(upgrade_title)

	var lines: Array[String] = []
	for i in tower.hero_chosen_upgrades.size():
		if i < upgrades_arr.size():
			var upg: Dictionary = upgrades_arr[i]
			var choice: String = tower.hero_chosen_upgrades[i]
			var icon: String = (upg.get("a_icon", "") if choice == "A" else upg.get("b_icon", "")) as String
			var uname: String = (upg.get("a_name", "") if choice == "A" else upg.get("b_name", "")) as String
			var udesc: String = (upg.get("a_desc", "") if choice == "A" else upg.get("b_desc", "")) as String
			lines.append("%s [Lv%d] %s\n    %s" % [icon, i + 2, uname, udesc])

	var upgrade_list := Label.new()
	var first_upg_wave: int = get_hero_upgrade_wave(0)
	upgrade_list.text = "\n".join(lines) if lines.size() > 0 else "（第 %d 波解锁）" % first_upg_wave
	upgrade_list.add_theme_font_size_override("font_size", 24)
	upgrade_list.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	upgrade_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(upgrade_list)

	vbox.add_child(HSeparator.new())

	# Next upgrade hint
	var next_lbl := Label.new()
	var upgrades_done: int = tower.hero_chosen_upgrades.size()
	if upgrades_done >= HERO_MAX_UPGRADES:
		next_lbl.text = "✨ 满级"
	else:
		var next_wave: int = get_hero_upgrade_wave(upgrades_done)
		var current_wave: int = _wave_manager.current_wave if _wave_manager else 0
		var waves_left: int = maxi(next_wave - current_wave, 0)
		next_lbl.text = "⏳ 下次升级: 第 %d 波（还需 %d 波）" % [next_wave, waves_left]
	next_lbl.add_theme_font_size_override("font_size", 24)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	vbox.add_child(next_lbl)

	return tower  # Return as new _active_tower


func hide_hero_panel() -> void:
	_hero_panel = null
	for c in _upgrade_vbox.get_children():
		c.queue_free()
	_upgrade_panel.visible = false
	_bottom_panel.offset_top = PANEL_EXPANDED_TOP
	_upgrade_panel.offset_bottom = 360.0

func is_hero_panel_open() -> bool:
	return _hero_panel != null


## ── 英雄升级面板 ──────────────────────────────────────────────────────

func show_hero_upgrade_panel(wave_num: int, tier: int) -> void:
	if not is_instance_valid(_hero_tower):
		return
	var td := _hero_tower.tower_data as TowerCollectionData
	if not td:
		return

	var info: Dictionary = HERO_TERRAIN_INFO.get(td.tower_id, {})
	var upgrades_arr: Array = info.get("upgrades", [])
	if tier < 1 or tier > upgrades_arr.size() or tier > HERO_MAX_UPGRADES:
		get_tree().paused = false
		return

	var upg_dict: Dictionary = upgrades_arr[tier - 1]
	var current_lv: int = _hero_tower.hero_chosen_upgrades.size() + 1

	var upg_data := HeroUpgradeData.new()
	upg_data.tier = tier
	upg_data.wave_trigger = wave_num
	upg_data.option_a_name = upg_dict.get("a_name", "")
	upg_data.option_a_desc = upg_dict.get("a_desc", "")
	upg_data.option_a_icon = upg_dict.get("a_icon", "🅰️")
	upg_data.option_b_name = upg_dict.get("b_name", "")
	upg_data.option_b_desc = upg_dict.get("b_desc", "")
	upg_data.option_b_icon = upg_dict.get("b_icon", "🅱️")

	get_tree().paused = true
	var panel_scene := preload("res://scenes/hero_upgrade/HeroUpgradePanel.tscn")
	var panel := panel_scene.instantiate()
	_hero_upgrade_panel = panel
	_hud.add_child(panel)
	panel.upgrade_chosen.connect(_on_hero_upgrade_chosen)
	panel.setup(td.tower_id, tier, current_lv, upg_data, td.display_name, td.tower_emoji)


func _on_hero_upgrade_chosen(hero_id: String, tier: int, choice: String) -> void:
	_hero_upgrade_panel = null
	if is_instance_valid(_hero_tower):
		_hero_tower.hero_chosen_upgrades.append(choice)
		_hero_tower.hero_level = _hero_tower.hero_chosen_upgrades.size() + 1
		var ab = _hero_tower.get("_ability")
		if ab and ab.has_method("apply_upgrade"):
			ab.apply_upgrade(tier, choice)
		_hero_tower.queue_redraw()
	get_tree().paused = false
	hero_upgrade_done.emit()
