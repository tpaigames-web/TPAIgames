class_name SettingsPanel
extends CanvasLayer

## 设置 + 指南面板（全局可用）

signal closed()
signal save_game_requested()
signal exit_requested()

const ENEMY_PATHS: Array[String] = [
	"res://data/enemies/ant_queen.tres", "res://data/enemies/ant_swarm.tres",
	"res://data/enemies/armadillo.tres", "res://data/enemies/armored_boar.tres",
	"res://data/enemies/boar.tres", "res://data/enemies/crow.tres",
	"res://data/enemies/crow_king.tres", "res://data/enemies/forest_king.tres",
	"res://data/enemies/fox_leader.tres", "res://data/enemies/giant_mole.tres",
	"res://data/enemies/giant_rabbit.tres", "res://data/enemies/locust.tres",
	"res://data/enemies/mole.tres", "res://data/enemies/rat_fat.tres",
	"res://data/enemies/rat_small.tres", "res://data/enemies/snake.tres",
	"res://data/enemies/squirrel.tres", "res://data/enemies/toad.tres",
]

const UPGRADE_PATHS: Array[String] = [
	"res://data/global_upgrades/beehive_aura_o.tres", "res://data/global_upgrades/beehive_dmg_b.tres",
	"res://data/global_upgrades/beehive_poison_b.tres", "res://data/global_upgrades/beehive_spd_o.tres",
	"res://data/global_upgrades/beehive_spd_w.tres", "res://data/global_upgrades/cannon_aoe_b.tres",
	"res://data/global_upgrades/cannon_dmg_b.tres", "res://data/global_upgrades/cannon_dmg_o.tres",
	"res://data/global_upgrades/cannon_dmg_w.tres", "res://data/global_upgrades/chili_cone_o.tres",
	"res://data/global_upgrades/chili_dmg_b.tres", "res://data/global_upgrades/chili_dmg_o.tres",
	"res://data/global_upgrades/chili_dmg_w.tres", "res://data/global_upgrades/chili_mark_b.tres",
	"res://data/global_upgrades/cost_all_o.tres", "res://data/global_upgrades/cost_b.tres",
	"res://data/global_upgrades/cost_elite_b.tres", "res://data/global_upgrades/cost_repair_w.tres",
	"res://data/global_upgrades/cost_upgrade_o.tres", "res://data/global_upgrades/cost_w.tres",
	"res://data/global_upgrades/farmer_crit_b.tres", "res://data/global_upgrades/farmer_dmg_b.tres",
	"res://data/global_upgrades/farmer_dmg_o.tres", "res://data/global_upgrades/farmer_dmg_w.tres",
	"res://data/global_upgrades/farmer_scatter_b.tres", "res://data/global_upgrades/farmer_spd_w.tres",
	"res://data/global_upgrades/global_crit_b.tres", "res://data/global_upgrades/global_dmg_b.tres",
	"res://data/global_upgrades/global_dmg_o.tres", "res://data/global_upgrades/global_dmg_w.tres",
	"res://data/global_upgrades/global_dot_b.tres", "res://data/global_upgrades/global_dot_o.tres",
	"res://data/global_upgrades/global_mark_b.tres", "res://data/global_upgrades/global_mark_o.tres",
	"res://data/global_upgrades/global_pierce_b.tres", "res://data/global_upgrades/global_pierce_o.tres",
	"res://data/global_upgrades/global_rng_b.tres", "res://data/global_upgrades/global_slow_b.tres",
	"res://data/global_upgrades/global_spd_b.tres", "res://data/global_upgrades/global_spd_o.tres",
	"res://data/global_upgrades/global_spd_w.tres", "res://data/global_upgrades/hero_dmg_b.tres",
	"res://data/global_upgrades/hero_dmg_o.tres", "res://data/global_upgrades/hero_dmg_w.tres",
	"res://data/global_upgrades/mushroom_aoe_b.tres", "res://data/global_upgrades/mushroom_dmg_o.tres",
	"res://data/global_upgrades/mushroom_dmg_w.tres", "res://data/global_upgrades/mushroom_poison_b.tres",
	"res://data/global_upgrades/mushroom_rng_w.tres", "res://data/global_upgrades/scarecrow_curse_b.tres",
	"res://data/global_upgrades/scarecrow_dmg_w.tres", "res://data/global_upgrades/scarecrow_rng_b.tres",
	"res://data/global_upgrades/scarecrow_rng_w.tres", "res://data/global_upgrades/scarecrow_spd_o.tres",
	"res://data/global_upgrades/seed_dmg_b.tres", "res://data/global_upgrades/seed_grass_b.tres",
	"res://data/global_upgrades/seed_rng_o.tres", "res://data/global_upgrades/seed_rng_w.tres",
	"res://data/global_upgrades/sun_aura_b.tres", "res://data/global_upgrades/sun_burn_o.tres",
	"res://data/global_upgrades/sun_rng_b.tres", "res://data/global_upgrades/sun_spd_w.tres",
	"res://data/global_upgrades/syn_armor_break.tres", "res://data/global_upgrades/syn_bow_mark.tres",
	"res://data/global_upgrades/syn_chili_wire.tres", "res://data/global_upgrades/syn_control_field.tres",
	"res://data/global_upgrades/syn_dot_empire.tres", "res://data/global_upgrades/syn_farm_legend.tres",
	"res://data/global_upgrades/syn_full_output.tres", "res://data/global_upgrades/syn_hero_empire.tres",
	"res://data/global_upgrades/syn_hero_guard.tres", "res://data/global_upgrades/syn_mark_system.tres",
	"res://data/global_upgrades/syn_mushroom_trap.tres", "res://data/global_upgrades/syn_nature_storm.tres",
	"res://data/global_upgrades/syn_poison_control.tres", "res://data/global_upgrades/syn_poison_regen.tres",
	"res://data/global_upgrades/syn_sun_water.tres", "res://data/global_upgrades/syn_water_wire.tres",
	"res://data/global_upgrades/syn_wire_complex.tres", "res://data/global_upgrades/syn_wire_guard.tres",
	"res://data/global_upgrades/synergy_bloom.tres", "res://data/global_upgrades/synergy_cannon_watch.tres",
	"res://data/global_upgrades/synergy_chili_beehive.tres", "res://data/global_upgrades/synergy_farm_core.tres",
	"res://data/global_upgrades/synergy_farm_full.tres", "res://data/global_upgrades/synergy_fire_wind.tres",
	"res://data/global_upgrades/synergy_full_defense.tres", "res://data/global_upgrades/synergy_hero_all.tres",
	"res://data/global_upgrades/synergy_hive_farmer.tres", "res://data/global_upgrades/synergy_nature.tres",
	"res://data/global_upgrades/synergy_poison_net.tres", "res://data/global_upgrades/synergy_scarecrow_wire.tres",
	"res://data/global_upgrades/synergy_seed_mushroom.tres", "res://data/global_upgrades/synergy_sun_farmer.tres",
	"res://data/global_upgrades/synergy_trap_wire.tres", "res://data/global_upgrades/synergy_triple_atk.tres",
	"res://data/global_upgrades/synergy_watch_seed.tres", "res://data/global_upgrades/synergy_water_gun.tres",
	"res://data/global_upgrades/synergy_water_seed.tres", "res://data/global_upgrades/synergy_wind_cannon.tres",
	"res://data/global_upgrades/trap_aoe_o.tres", "res://data/global_upgrades/trap_dmg_b.tres",
	"res://data/global_upgrades/trap_poison_b.tres", "res://data/global_upgrades/trap_reset_w.tres",
	"res://data/global_upgrades/watch_dmg_b.tres", "res://data/global_upgrades/watch_mark_o.tres",
	"res://data/global_upgrades/watch_pierce_b.tres", "res://data/global_upgrades/watch_rng_o.tres",
	"res://data/global_upgrades/watch_rng_w.tres", "res://data/global_upgrades/water_corr_b.tres",
	"res://data/global_upgrades/water_dmg_w.tres", "res://data/global_upgrades/water_slow_b.tres",
	"res://data/global_upgrades/water_spd_b.tres", "res://data/global_upgrades/water_spd_o.tres",
	"res://data/global_upgrades/wind_aoe_o.tres", "res://data/global_upgrades/wind_dmg_b.tres",
	"res://data/global_upgrades/wind_push_b.tres", "res://data/global_upgrades/wind_spd_w.tres",
	"res://data/global_upgrades/wire_bleed_b.tres", "res://data/global_upgrades/wire_dur_w.tres",
	"res://data/global_upgrades/wire_repair_b.tres", "res://data/global_upgrades/wire_shock_o.tres",
	"res://data/global_upgrades/wire_slow_o.tres",
]

var _effect_entries: Array[Dictionary] = []

var _in_battle: bool = false
var _current_main_tab: int = 0  # 0=设置, 1=指南
var _current_guide_category: int = 0

@onready var dim_bg: ColorRect       = $DimBg
@onready var panel: Panel            = $Panel
@onready var close_btn: TextureButton = $Panel/CloseBtn
@onready var settings_tab_btn: Button = $Panel/MainTabBar/SettingsTabBtn
@onready var guide_tab_btn: Button   = $Panel/MainTabBar/GuideTabBtn
@onready var settings_content: ScrollContainer = $Panel/SettingsContent
@onready var settings_vbox: VBoxContainer = $Panel/SettingsContent/SettingsVBox
@onready var guide_content: Control  = $Panel/GuideContent
@onready var detail_image: TextureRect = $Panel/GuideContent/DetailArea/DetailImage
@onready var detail_name: Label      = $Panel/GuideContent/DetailArea/DetailInfo/DetailName
@onready var detail_desc: Label      = $Panel/GuideContent/DetailArea/DetailInfo/DetailDesc
@onready var detail_stats: Label     = $Panel/GuideContent/DetailArea/DetailInfo/DetailStats
@onready var grid_container: GridContainer = $Panel/GuideContent/GridScroll/GridContainer
@onready var upgrade_area: VBoxContainer = $Panel/GuideContent/UpgradeArea
@onready var grid_scroll: ScrollContainer = $Panel/GuideContent/GridScroll

@onready var category_btns: Array[Button] = [
	$Panel/GuideContent/CategoryBar/EnemyBtn,
	$Panel/GuideContent/CategoryBar/TowerBtn,
	$Panel/GuideContent/CategoryBar/HeroBtn,
	$Panel/GuideContent/CategoryBar/UpgradeBtn,
	$Panel/GuideContent/CategoryBar/EffectBtn,
]


func _ready() -> void:
	close_btn.pressed.connect(_close)
	dim_bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close()
	)
	settings_tab_btn.pressed.connect(func(): _switch_main_tab(0))
	guide_tab_btn.pressed.connect(func(): _switch_main_tab(1))

	for i in category_btns.size():
		var idx := i
		category_btns[i].pressed.connect(func(): _switch_guide_category(idx))

	_effect_entries = [
		{"name": tr("UI_EFFECT_SLOW"), "desc": tr("UI_EFFECT_SLOW_DESC"), "color": Color(0.4, 0.7, 1.0)},
		{"name": tr("UI_EFFECT_BURN"), "desc": tr("UI_EFFECT_BURN_DESC"), "color": Color(1.0, 0.4, 0.2)},
		{"name": tr("UI_EFFECT_POISON"), "desc": tr("UI_EFFECT_POISON_DESC"), "color": Color(0.3, 0.8, 0.3)},
		{"name": tr("UI_EFFECT_STUN"), "desc": tr("UI_EFFECT_STUN_DESC"), "color": Color(0.8, 0.8, 0.2)},
		{"name": tr("UI_EFFECT_MARK"), "desc": tr("UI_EFFECT_MARK_DESC"), "color": Color(1.0, 0.5, 0.8)},
		{"name": tr("UI_EFFECT_PIERCE"), "desc": tr("UI_EFFECT_PIERCE_DESC"), "color": Color(0.9, 0.6, 0.2)},
		{"name": tr("UI_EFFECT_KNOCKBACK"), "desc": tr("UI_EFFECT_KNOCKBACK_DESC"), "color": Color(0.6, 0.6, 0.9)},
		{"name": tr("UI_EFFECT_SPLASH"), "desc": tr("UI_EFFECT_SPLASH_DESC"), "color": Color(1.0, 0.7, 0.3)},
	]


func open(in_battle: bool = false) -> void:
	_in_battle = in_battle
	_build_settings_ui()
	_switch_main_tab(0)
	visible = true
	if in_battle:
		get_tree().paused = true


func _close() -> void:
	SettingsManager.save_settings()
	visible = false
	if _in_battle:
		get_tree().paused = false
	closed.emit()
	queue_free()


# ── 主标签切换 ────────────────────────────────────────────────────────

func _switch_main_tab(tab: int) -> void:
	_current_main_tab = tab
	settings_content.visible = tab == 0
	guide_content.visible = tab == 1

	settings_tab_btn.modulate = Color(1, 1, 1) if tab == 0 else Color(0.6, 0.6, 0.6)
	guide_tab_btn.modulate = Color(1, 1, 1) if tab == 1 else Color(0.6, 0.6, 0.6)

	if tab == 1:
		_switch_guide_category(_current_guide_category)


# ── 设置 UI 构建 ─────────────────────────────────────────────────────

func _build_settings_ui() -> void:
	for c in settings_vbox.get_children():
		c.queue_free()

	# 音频
	_add_section_label(tr("UI_SETTINGS_AUDIO"))
	_add_slider_row(tr("UI_SETTINGS_MUSIC_VOL"), SettingsManager.music_volume, func(val: float):
		SettingsManager.set_music_volume(int(val))
	)
	_add_slider_row(tr("UI_SETTINGS_SFX_VOL"), SettingsManager.sfx_volume, func(val: float):
		SettingsManager.set_sfx_volume(int(val))
	)

	# 画面
	_add_section_label(tr("UI_SETTINGS_DISPLAY"))
	_add_option_row(tr("UI_SETTINGS_QUALITY"), [tr("UI_SETTINGS_QUALITY_LOW"), tr("UI_SETTINGS_QUALITY_MED"), tr("UI_SETTINGS_QUALITY_HIGH")], SettingsManager.quality, func(idx: int):
		SettingsManager.set_quality(idx)
	)
	_add_toggle_row(tr("UI_SETTINGS_PARTICLES"), SettingsManager.particles_enabled, func(toggled: bool):
		SettingsManager.particles_enabled = toggled
	)

	# 游戏辅助
	_add_section_label(tr("UI_SETTINGS_GAMEPLAY"))
	_add_toggle_row(tr("UI_SETTINGS_DMG_NUMBERS"), SettingsManager.damage_numbers, func(toggled: bool):
		SettingsManager.damage_numbers = toggled
	)
	_add_option_row(tr("UI_SETTINGS_RANGE_DISPLAY"), [tr("UI_SETTINGS_RANGE_OFF"), tr("UI_SETTINGS_RANGE_SELECTED"), tr("UI_SETTINGS_RANGE_ALWAYS")], SettingsManager.range_display, func(idx: int):
		SettingsManager.range_display = idx
	)
	_add_option_row(tr("UI_SETTINGS_DEFAULT_SPEED"), ["1x", "2x", "3x"], SettingsManager.default_speed - 1, func(idx: int):
		SettingsManager.default_speed = idx + 1
	)

	# 游戏内专用
	if _in_battle:
		_add_section_label(tr("UI_SETTINGS_BATTLE"))
		var save_btn := Button.new()
		save_btn.text = tr("UI_SETTINGS_SAVE_EXIT")
		save_btn.custom_minimum_size = Vector2(0, 80)
		save_btn.add_theme_font_size_override("font_size", 38)
		save_btn.pressed.connect(func():
			save_game_requested.emit()
			_close()
		)
		settings_vbox.add_child(save_btn)

		var exit_btn := Button.new()
		exit_btn.text = tr("UI_SETTINGS_EXIT_NOSAVE")
		exit_btn.custom_minimum_size = Vector2(0, 80)
		exit_btn.add_theme_font_size_override("font_size", 38)
		exit_btn.pressed.connect(func():
			exit_requested.emit()
			_close()
		)
		settings_vbox.add_child(exit_btn)

	# 语言
	_add_section_label(tr("UI_SETTINGS_LANGUAGE"))
	var lang_options: Array = [tr("UI_LANG_CHINESE"), tr("UI_LANG_ENGLISH"), tr("UI_LANG_MALAY")]
	var lang_locales: Array[String] = ["zh", "en", "ms"]
	var current_lang_idx: int = lang_locales.find(SettingsManager.language)
	if current_lang_idx < 0:
		current_lang_idx = 0
	_add_option_row(tr("UI_SETTINGS_LANGUAGE"), lang_options, current_lang_idx, func(idx: int):
		if lang_locales[idx] == SettingsManager.language:
			return  # 没变化
		queue_free()  # 先关闭设置面板
		SettingsManager.set_language(lang_locales[idx])
	)

	# 版本
	_add_section_label(tr("UI_SETTINGS_OTHER"))
	var ver_lbl := Label.new()
	ver_lbl.text = tr("UI_SETTINGS_VERSION") + " 0.1.0"
	ver_lbl.add_theme_font_size_override("font_size", 32)
	ver_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(ver_lbl)


func _add_section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	settings_vbox.add_child(lbl)


func _add_slider_row(label_text: String, value: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(250, 0)
	lbl.add_theme_font_size_override("font_size", 32)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % value
	val_lbl.custom_minimum_size = Vector2(80, 0)
	val_lbl.add_theme_font_size_override("font_size", 32)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%d%%" % int(v)
		callback.call(v)
	)
	settings_vbox.add_child(row)


func _add_toggle_row(label_text: String, value: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 32)
	row.add_child(lbl)

	var check := CheckBox.new()
	check.button_pressed = value
	check.toggled.connect(callback)
	row.add_child(check)
	settings_vbox.add_child(row)


func _add_option_row(label_text: String, options: Array, current: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 32)
	row.add_child(lbl)

	var opt := OptionButton.new()
	for o in options:
		opt.add_item(o)
	opt.selected = current
	opt.item_selected.connect(callback)
	opt.add_theme_font_size_override("font_size", 28)
	row.add_child(opt)
	settings_vbox.add_child(row)


# ── 指南系统 ─────────────────────────────────────────────────────────

func _switch_guide_category(cat: int) -> void:
	_current_guide_category = cat
	for i in category_btns.size():
		category_btns[i].modulate = Color(1, 1, 1) if i == cat else Color(0.6, 0.6, 0.6)

	# 清空详情
	detail_name.text = tr("UI_GUIDE_SELECT_ITEM")
	detail_desc.text = ""
	detail_stats.text = ""
	detail_image.texture = null

	# 隐藏升级路线区域，恢复网格位置
	_hide_upgrade_area()

	# 清空网格
	for c in grid_container.get_children():
		c.queue_free()

	match cat:
		0: _load_enemies()
		1: _load_towers()
		2: _load_heroes()
		3: _load_upgrades()
		4: _load_effects()


## ── 敌人 ──

func _load_enemies() -> void:
	for path in ENEMY_PATHS:
		var res = load(path)
		if res is EnemyData:
			var data: EnemyData = res
			_add_grid_item(data.display_emoji, TowerResourceRegistry.tr_enemy_name(data), func(): _show_enemy_detail(data))


func _show_enemy_detail(data: EnemyData) -> void:
	detail_name.text = "%s %s" % [data.display_emoji, TowerResourceRegistry.tr_enemy_name(data)]
	var flags: Array[String] = []
	if data.is_flying: flags.append(tr("UI_FLAG_FLYING"))
	if data.is_elite: flags.append(tr("UI_FLAG_ELITE"))
	if data.is_giant: flags.append(tr("UI_FLAG_GIANT"))
	if data.is_fast: flags.append(tr("UI_FLAG_FAST"))
	if data.is_control_immune: flags.append(tr("UI_FLAG_CONTROL_IMMUNE"))
	if data.is_dot_immune: flags.append(tr("UI_FLAG_DOT_IMMUNE"))
	if data.is_berserk: flags.append(tr("UI_FLAG_BERSERK"))
	var type_str: String = "、".join(flags) if flags.size() > 0 else tr("UI_FLAG_NORMAL")
	detail_desc.text = tr("UI_GUIDE_TYPE_FORMAT") % type_str
	var counter: String = data.counter_strategy if data.counter_strategy != "" else tr("UI_GUIDE_NONE")
	detail_stats.text = tr("UI_GUIDE_ENEMY_STATS") % [
		data.max_hp, data.move_speed, data.damage_to_player, data.gold_reward, data.armor, counter
	]
	if data.sprite_texture:
		detail_image.texture = data.sprite_texture
	else:
		detail_image.texture = null


## ── 炮台 ──

func _load_towers() -> void:
	var resources := TowerResourceRegistry.get_all_resources()
	for td: TowerCollectionData in resources:
		if td.is_hero:
			continue
		var emoji := td.tower_emoji if td.tower_emoji != "" else "🏰"
		_add_grid_item(emoji, TowerResourceRegistry.tr_tower_name(td), func(): _show_tower_detail(td))


func _show_tower_detail(td: TowerCollectionData) -> void:
	detail_name.text = "%s %s" % [td.tower_emoji, TowerResourceRegistry.tr_tower_name(td)]
	var rarity_name: String = TowerResourceRegistry.RARITY_NAMES[td.rarity] if td.rarity < TowerResourceRegistry.RARITY_NAMES.size() else "?"
	var atk_types: Array[String] = [tr("UI_ATK_GROUND"), tr("UI_ATK_AIR"), tr("UI_ATK_ALL")]
	var atk_type: String = atk_types[td.attack_type] if td.attack_type < 3 else "?"
	detail_desc.text = tr("UI_GUIDE_RARITY_FORMAT") % [rarity_name, atk_type]
	detail_stats.text = tr("UI_GUIDE_TOWER_STATS") % [
		td.base_damage, td.attack_speed, td.attack_range, td.placement_cost
	]
	if td.collection_texture:
		detail_image.texture = td.collection_texture
	elif td.base_texture:
		detail_image.texture = td.base_texture
	else:
		detail_image.texture = null

	# 显示升级路线
	_show_upgrade_paths(td)


## ── 英雄 ──

func _load_heroes() -> void:
	var resources := TowerResourceRegistry.get_all_resources()
	for td: TowerCollectionData in resources:
		if not td.is_hero:
			continue
		var emoji := td.tower_emoji if td.tower_emoji != "" else "🦸"
		_add_grid_item(emoji, TowerResourceRegistry.tr_tower_name(td), func(): _show_hero_detail(td))


func _show_hero_detail(td: TowerCollectionData) -> void:
	detail_name.text = "%s %s" % [td.tower_emoji, TowerResourceRegistry.tr_tower_name(td)]
	detail_desc.text = tr("UI_GUIDE_HERO_UNIT")
	detail_stats.text = tr("UI_GUIDE_TOWER_STATS") % [
		td.base_damage, td.attack_speed, td.attack_range, td.placement_cost
	]
	if td.collection_texture:
		detail_image.texture = td.collection_texture
	else:
		detail_image.texture = null

	# 显示升级路线
	_show_upgrade_paths(td)


## ── 升级强化 ──

func _load_upgrades() -> void:
	for path in UPGRADE_PATHS:
		var res = load(path)
		if res is GlobalUpgradeData:
			var data: GlobalUpgradeData = res
			var rarity_emojis: Array[String] = ["⬜", "🟢", "🔵", "🟣", "🟠"]
			var rarity_emoji: String = rarity_emojis[data.rarity] if data.rarity < 5 else "❓"
			_add_grid_item(rarity_emoji, data.display_name, func(): _show_upgrade_detail(data))


func _show_upgrade_detail(data: GlobalUpgradeData) -> void:
	detail_name.text = data.display_name
	var rarity_names := [tr("UI_RARITY_WHITE"), tr("UI_RARITY_GREEN"), tr("UI_RARITY_BLUE"), tr("UI_RARITY_PURPLE"), tr("UI_RARITY_ORANGE")]
	var type_names := [tr("UI_UPGRADE_TYPE_TOWER"), tr("UI_UPGRADE_TYPE_GLOBAL"), tr("UI_UPGRADE_TYPE_SYNERGY"), tr("UI_UPGRADE_TYPE_COST")]
	var rarity_str: String = rarity_names[data.rarity] if data.rarity < rarity_names.size() else "?"
	var type_str: String = type_names[data.upgrade_type] if data.upgrade_type < type_names.size() else "?"
	detail_desc.text = "【%s】 %s\n%s" % [rarity_str, type_str, data.description]
	if data.required_tower_ids.size() > 0:
		detail_stats.text = tr("UI_UPGRADE_REQUIRES") % "、".join(data.required_tower_ids)
	else:
		detail_stats.text = ""
	detail_image.texture = null
	if data.get("icon"):
		detail_image.texture = data.icon


## ── 效果 ──

func _load_effects() -> void:
	for entry in _effect_entries:
		_add_grid_item("✨", entry["name"], func(): _show_effect_detail(entry))


func _show_effect_detail(entry: Dictionary) -> void:
	detail_name.text = entry["name"]
	detail_name.add_theme_color_override("font_color", entry["color"])
	detail_desc.text = entry["desc"]
	detail_stats.text = ""
	detail_image.texture = null


## ── 网格项通用 ──

func _add_grid_item(emoji: String, label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 180)
	btn.text = "%s\n%s" % [emoji, label_text]
	btn.add_theme_font_size_override("font_size", 32)
	btn.pressed.connect(callback)
	grid_container.add_child(btn)


# ── 升级路线系统 ─────────────────────────────────────────────────────

func _hide_upgrade_area() -> void:
	upgrade_area.visible = false
	for c in upgrade_area.get_children():
		c.queue_free()
	grid_scroll.offset_top = 410.0


func _show_upgrade_paths(td: TowerCollectionData) -> void:
	# 清空
	for c in upgrade_area.get_children():
		c.queue_free()

	if td.upgrade_paths.size() == 0:
		_hide_upgrade_area()
		return

	upgrade_area.visible = true
	grid_scroll.offset_top = 710.0

	# 标题
	var title_lbl := Label.new()
	title_lbl.text = tr("UI_GUIDE_UPGRADE_PATHS")
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	upgrade_area.add_child(title_lbl)

	# 路线按钮行
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	upgrade_area.add_child(path_row)

	for i in td.upgrade_paths.size():
		var path: TowerUpgradePath = td.upgrade_paths[i]
		var btn := Button.new()
		btn.text = path.path_name
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 32)
		var idx := i
		btn.pressed.connect(func(): _show_path_tiers(td, idx))
		path_row.add_child(btn)


func _show_path_tiers(td: TowerCollectionData, path_idx: int) -> void:
	var path: TowerUpgradePath = td.upgrade_paths[path_idx]

	# 移除旧的层级行和详情（保留标题和路线按钮行）
	var children := upgrade_area.get_children()
	for i in range(children.size() - 1, 1, -1):
		children[i].queue_free()

	# 层级按钮行
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	upgrade_area.add_child(tier_row)

	for i in path.tier_names.size():
		var btn := Button.new()
		btn.text = "T%d" % (i + 1)
		btn.tooltip_text = path.tier_names[i] if i < path.tier_names.size() else ""
		btn.custom_minimum_size = Vector2(0, 55)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 28)
		var tier_idx := i
		btn.pressed.connect(func(): _show_tier_detail(path, tier_idx))
		tier_row.add_child(btn)


func _show_tier_detail(path: TowerUpgradePath, tier_idx: int) -> void:
	# 移除旧的详情（保留标题、路线行、层级行 = 前3个）
	var children := upgrade_area.get_children()
	for i in range(children.size() - 1, 2, -1):
		children[i].queue_free()

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	upgrade_area.add_child(info_box)

	# 层级名称
	var name_lbl := Label.new()
	var tier_name: String = path.tier_names[tier_idx] if tier_idx < path.tier_names.size() else "?"
	name_lbl.text = "T%d — %s" % [tier_idx + 1, tier_name]
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	info_box.add_child(name_lbl)

	# 效果描述
	var effect_lbl := Label.new()
	var effect_text: String = path.tier_effects[tier_idx] if tier_idx < path.tier_effects.size() else ""
	effect_lbl.text = effect_text
	effect_lbl.add_theme_font_size_override("font_size", 32)
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_box.add_child(effect_lbl)

	# 费用
	var cost_lbl := Label.new()
	var cost: int = path.tier_costs[tier_idx] if tier_idx < path.tier_costs.size() else 0
	cost_lbl.text = tr("UI_GUIDE_COST_FORMAT") % cost
	cost_lbl.add_theme_font_size_override("font_size", 32)
	cost_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	info_box.add_child(cost_lbl)
