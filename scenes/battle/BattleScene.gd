extends Node

## 战斗场景编排器（Orchestrator）
## 协调 6 个子系统，管理 HUD、波次流程、存档恢复、地图视觉
## 子系统：GlobalUpgradeSystem, GameEndFlow, HeroSystem, TowerCardPanel, ItemPanel, TowerUpgradePanel

# ── 节点引用（来自 BattleScene.tscn）─────────────────────────────────────
@onready var build_manager:  Node           = $BuildManager
@onready var wave_manager:   Node           = $WaveManager
@onready var back_btn:       TextureButton   = $HUD/TopBar/BackBtn
@onready var hp_label:       Label           = $HUD/StatusBars/HPBar/HPLabel
@onready var wave_label:     Label           = $HUD/TopBar/WaveLabel
@onready var gold_label:     Label           = $HUD/StatusBars/GoldBar/GoldLabel
@onready var gem_label:      Label           = $HUD/StatusBars/GemBar/GemLabel
@onready var speed_btn:      Button          = $HUD/TopBar/SpeedBtn
@onready var pause_btn:      Button          = $HUD/TopBar/PauseBtn
@onready var tower_scroll:   ScrollContainer = $HUD/BottomPanel/TowerScroll
@onready var tower_hbox:     HBoxContainer   = $HUD/BottomPanel/TowerScroll/TowerHBox
@onready var item_scroll:    ScrollContainer = $HUD/BottomPanel/ItemScroll
@onready var item_hbox:      HBoxContainer   = $HUD/BottomPanel/ItemScroll/ItemHBox
@onready var _upgrade_panel: ScrollContainer = $HUD/BottomPanel/UpgradePanel
@onready var _upgrade_vbox:  VBoxContainer   = $HUD/BottomPanel/UpgradePanel/UpgradeVBox
@onready var bottom_panel:   Control         = $HUD/BottomPanel
@onready var _tower_tab_btn: Button          = $HUD/BottomPanel/TabBar/TowerTabBtn
@onready var _hero_tab_btn:  Button          = $HUD/BottomPanel/TabBar/HeroTabBtn
@onready var _item_tab_btn:  Button          = $HUD/BottomPanel/TabBar/ItemTabBtn
@onready var _panel_bg_tower: TextureRect     = $HUD/BottomPanel/PanelBgTower
@onready var _panel_bg_hero:  TextureRect     = $HUD/BottomPanel/PanelBgHero
@onready var _panel_bg_item:  TextureRect     = $HUD/BottomPanel/PanelBgItem

# ── 常量 ──────────────────────────────────────────────────────────────────
const PANEL_EXPANDED_TOP  = -490.0
const PANEL_UPGRADE_TOP   = -870.0
const SETTINGS_PANEL_SCENE = preload("res://scenes/settings/SettingsPanel.tscn")

# ── 编排器自身状态 ────────────────────────────────────────────────────────
var _active_tab:         int      = 0   # 0=炮台  1=英雄  2=道具
var _game_ended:         bool     = false
var _game_started:       bool     = false
var _upgrade_panel_dirty: bool    = false
var _pre_pause_speed:    float    = 1.0
var _is_paused:          bool     = false
var _settings_panel_ref: SettingsPanel = null

# ── 新手教学引导 ──────────────────────────────────────────────────────────
var _tutorial_guide: TutorialGuide = null
var _tutorial_guide_done: bool = false

# ── 6 个子系统引用 ────────────────────────────────────────────────────────
var _global_upgrade_system: Node = null
var _game_end_flow:         Node = null
var _hero_system:           Node = null
var _tower_card_panel:      Node = null
var _item_panel:            Node = null
var _tower_upgrade_panel:   Node = null

# ── 对象池 ────────────────────────────────────────────────────────────────
var _bullet_pool: ObjectPool = null

# ── 试用炮台追踪 ──────────────────────────────────────────────────────────
var _trial_tower_ids: Array[String] = []  # 本局已试用的炮台 tower_id


# ══════════════════════════════════════════════════════════════════════════
# _ready：初始化全局状态 → 创建子系统 → 连接信号
# ══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# ── 重置全局战斗状态 ──────────────────────────────────────────────
	if GameManager.test_mode:
		GameManager.player_life = 999999
		GameManager.gold        = 999999
	else:
		GameManager.player_life = 100
		if GameManager.current_day == 0:
			GameManager.gold = 1500
			wave_manager.use_tutorial_waves()
		else:
			wave_manager.apply_day_difficulty(GameManager.current_day)
			if GameManager.current_day <= 8:
				GameManager.gold = 650
			elif GameManager.current_day <= 16:
				GameManager.gold = 600
			elif GameManager.current_day <= 24:
				GameManager.gold = 550
			elif GameManager.current_day <= 32:
				GameManager.gold = 500
			else:
				GameManager.gold = 450

	# ── 创建并初始化 6 个子系统 ──────────────────────────────────────
	_create_subsystems()

	# ── 子弹对象池 ──────────────────────────────────────────────────
	_bullet_pool = ObjectPool.new()
	_bullet_pool.pool_scene = preload("res://bullet/Bullet.tscn")
	_bullet_pool.initial_size = 30
	_bullet_pool.max_size = 150
	_bullet_pool.name = "BulletPool"
	add_child(_bullet_pool)

	# ── 连接 GameManager / WaveManager 信号 → HUD ────────────────────
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	wave_manager.all_waves_cleared.connect(_on_victory)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	wave_manager.treasure_enemy_spawned.connect(_on_treasure_enemy_spawned)

	# ── 连接按钮 ─────────────────────────────────────────────────────
	back_btn.pressed.connect(_on_back)
	speed_btn.pressed.connect(_on_speed_btn_pressed)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	pause_btn.disabled = true
	build_manager.tower_placed.connect(_on_tower_placed)

	# ── 底部 Tab 按钮 ────────────────────────────────────────────────
	_tower_tab_btn.pressed.connect(func(): _set_tab(0))
	_hero_tab_btn.pressed.connect(func():  _set_tab(1))
	_item_tab_btn.pressed.connect(func():  _set_tab(2))

	# ── 构建卡片 + 初始 HUD ──────────────────────────────────────────
	_tower_card_panel.build_cards()
	_item_panel.build_cards()
	_refresh_tab_state()
	_refresh_displays()

	# ── 全局升级面板（第 0 波）────────────────────────────────────────
	var _is_tutorial_mode: bool = GameManager.current_day == 0 and not UserManager.tutorial_completed and not GameManager.test_mode and not GameManager.resume_battle
	if not GameManager.resume_battle and not _is_tutorial_mode:
		call_deferred("_deferred_show_global_upgrade", 0)

	# ── 自定义地图 ───────────────────────────────────────────────────
	if GameManager.custom_map_path != "":
		_replace_map_with_custom(GameManager.custom_map_path)
		GameManager.custom_map_path = ""

	# ── 战局恢复 ─────────────────────────────────────────────────────
	if GameManager.resume_battle:
		GameManager.resume_battle = false
		call_deferred("_resume_from_save")

	# ── 地图视觉动效 + 可交互装饰品 ─────────────────────────────────
	_setup_map_vfx()
	_connect_interactable_decors()

	# ── 新手教学引导 ─────────────────────────────────────────────────
	if _is_tutorial_mode:
		call_deferred("_start_tutorial_guide")


func _deferred_show_global_upgrade(wave_num: int) -> void:
	_global_upgrade_system.show_upgrade_panel(wave_num)


# ══════════════════════════════════════════════════════════════════════════
# 子系统创建与信号连接
# ══════════════════════════════════════════════════════════════════════════
func _create_subsystems() -> void:
	# ── GlobalUpgradeSystem ──────────────────────────────────────────
	var gus_script = load("res://scenes/battle/GlobalUpgradeSystem.gd")
	_global_upgrade_system = Node.new()
	_global_upgrade_system.name = "GlobalUpgradeSystem"
	_global_upgrade_system.set_script(gus_script)
	add_child(_global_upgrade_system)
	_global_upgrade_system.init($HUD)
	_global_upgrade_system.upgrade_chosen.connect(_on_global_upgrade_chosen)

	# ── GameEndFlow ──────────────────────────────────────────────────
	var gef_script = load("res://scenes/battle/GameEndFlow.gd")
	_game_end_flow = Node.new()
	_game_end_flow.name = "GameEndFlow"
	_game_end_flow.set_script(gef_script)
	add_child(_game_end_flow)
	_game_end_flow.init(self, wave_manager, speed_btn, wave_label, _disconnect_signals)
	_game_end_flow.game_ended_signal.connect(func():
		_game_ended = true
		_show_trial_end_popup()
	)
	_game_end_flow.endless_entered.connect(_on_endless_entered)
	_game_end_flow.request_reconnect_signals.connect(_reconnect_signals)

	# ── HeroSystem ───────────────────────────────────────────────────
	var hs_script = load("res://scenes/battle/HeroSystem.gd")
	_hero_system = Node.new()
	_hero_system.name = "HeroSystem"
	_hero_system.set_script(hs_script)
	add_child(_hero_system)
	_hero_system.init(
		$HUD, _upgrade_panel, _upgrade_vbox,
		bottom_panel, tower_scroll, item_scroll,
		wave_manager, PANEL_EXPANDED_TOP, PANEL_UPGRADE_TOP
	)
	_hero_system.hero_upgrade_done.connect(_on_hero_upgrade_done)
	_hero_system.request_sell_confirm.connect(_on_hero_sell_requested)

	# ── TowerCardPanel ───────────────────────────────────────────────
	var tcp_script = load("res://scenes/battle/TowerCardPanel.gd")
	_tower_card_panel = Node.new()
	_tower_card_panel.name = "TowerCardPanel"
	_tower_card_panel.set_script(tcp_script)
	add_child(_tower_card_panel)
	_tower_card_panel.init(
		tower_hbox, build_manager,
		func(tid: String) -> float: return _global_upgrade_system.get_cost_discount_for(tid)
	)

	# ── ItemPanel ────────────────────────────────────────────────────
	var ip_script = load("res://scenes/battle/ItemPanel.gd")
	_item_panel = Node.new()
	_item_panel.name = "ItemPanel"
	_item_panel.set_script(ip_script)
	add_child(_item_panel)
	_item_panel.init(item_hbox, self, bottom_panel)
	_item_panel.trial_tower_selected.connect(_on_trial_tower_selected)

	# ── TowerUpgradePanel ────────────────────────────────────────────
	var tup_script = load("res://scenes/battle/TowerUpgradePanel.gd")
	_tower_upgrade_panel = Node.new()
	_tower_upgrade_panel.name = "TowerUpgradePanel"
	_tower_upgrade_panel.set_script(tup_script)
	add_child(_tower_upgrade_panel)
	_tower_upgrade_panel.init(
		$HUD, _upgrade_panel, _upgrade_vbox,
		bottom_panel, tower_scroll, item_scroll,
		build_manager, PANEL_EXPANDED_TOP, PANEL_UPGRADE_TOP,
		func(): return _tutorial_guide if is_instance_valid(_tutorial_guide) else null
	)
	_tower_upgrade_panel.tower_sold.connect(_on_tower_sold)
	_tower_upgrade_panel.request_apply_upgrades.connect(_apply_upgrades_to_all_towers)
	_tower_upgrade_panel.request_hero_panel.connect(_on_hero_panel_requested)
	_tower_upgrade_panel.request_hide_hero_panel.connect(func(): _hero_system.hide_hero_panel())
	_tower_upgrade_panel.request_refresh_card_affordability.connect(_refresh_card_affordability)
	_tower_upgrade_panel.panel_hidden.connect(func(): _apply_tab_filter())


# ══════════════════════════════════════════════════════════════════════════
# _process：延迟刷新升级面板
# ══════════════════════════════════════════════════════════════════════════
func _process(_delta: float) -> void:
	if _upgrade_panel_dirty:
		_upgrade_panel_dirty = false
		var active_t = _tower_upgrade_panel.get_active_tower()
		if _upgrade_panel.visible and is_instance_valid(active_t):
			_tower_upgrade_panel.show_upgrade_panel(active_t)


# ══════════════════════════════════════════════════════════════════════════
# 播放 / 倍速 / 暂停
# ══════════════════════════════════════════════════════════════════════════
func _on_speed_btn_pressed() -> void:
	if not _game_started:
		_game_started = true
		var def_spd: int = clampi(SettingsManager.default_speed, 1, 3)
		Engine.time_scale = float(def_spd)
		wave_manager.start()
		speed_btn.text = "%d×" % def_spd
		pause_btn.disabled = false
		if is_instance_valid(_tutorial_guide):
			_tutorial_guide.notify_game_started()
	elif Engine.time_scale == 1.0:
		Engine.time_scale = 2.0
		speed_btn.text = "2×"
	elif Engine.time_scale == 2.0:
		Engine.time_scale = 3.0
		speed_btn.text = "3×"
	else:
		Engine.time_scale = 1.0
		speed_btn.text = "1×"


func _on_pause_btn_pressed() -> void:
	if not _game_started:
		return
	_is_paused = not _is_paused
	if _is_paused:
		_pre_pause_speed = Engine.time_scale
		Engine.time_scale = 0.0
		pause_btn.text = "▶"
		if _game_started and wave_manager.current_wave >= 1:
			_save_battle()
	else:
		Engine.time_scale = _pre_pause_speed if _pre_pause_speed > 0.0 else 1.0
		pause_btn.text = "⏸"


# ══════════════════════════════════════════════════════════════════════════
# 底部 Tab 切换
# ══════════════════════════════════════════════════════════════════════════
func _set_tab(tab: int) -> void:
	_active_tab = tab
	_apply_tab_filter()

func _apply_tab_filter() -> void:
	_panel_bg_tower.visible = (_active_tab == 0)
	_panel_bg_hero.visible  = (_active_tab == 1)
	_panel_bg_item.visible  = (_active_tab == 2)
	tower_scroll.visible = _active_tab != 2
	item_scroll.visible  = _active_tab == 2
	for entry in _tower_card_panel.get_entries():
		var d := entry.data as TowerCollectionData
		var is_hero_card: bool = d != null and d.is_hero
		match _active_tab:
			0: entry.card.visible = not is_hero_card
			1: entry.card.visible = is_hero_card
			2: entry.card.visible = false
	if _active_tab == 2:
		_item_panel.refresh_cards()

func _refresh_tab_state() -> void:
	var has_hero := false
	for entry in _tower_card_panel.get_entries():
		var d := entry.data as TowerCollectionData
		if d != null and d.is_hero:
			has_hero = true
			break
	_hero_tab_btn.disabled = not has_hero
	_hero_tab_btn.text = tr("UI_HERO_LABEL") if has_hero else tr("UI_HERO_LOCKED")
	_apply_tab_filter()


# ══════════════════════════════════════════════════════════════════════════
# HUD 更新
# ══════════════════════════════════════════════════════════════════════════
func _on_hp_changed(new_hp: int) -> void:
	hp_label.text = "%d" % new_hp
	if new_hp <= 0:
		if _game_end_flow.can_offer_revive() and not _game_ended:
			_game_end_flow.offer_revive()
		elif not _game_ended and not _game_end_flow.is_revive_pending():
			_game_end_flow.on_game_over()

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "%d" % new_gold
	_refresh_card_affordability()
	if _upgrade_panel.visible and is_instance_valid(_tower_upgrade_panel.get_active_tower()):
		_upgrade_panel_dirty = true

func _refresh_displays() -> void:
	hp_label.text   = "%d" % GameManager.player_life
	gold_label.text = "%d" % GameManager.gold
	gem_label.text  = "%d" % UserManager.gems


# ══════════════════════════════════════════════════════════════════════════
# 波次事件
# ══════════════════════════════════════════════════════════════════════════
func _on_wave_started(wave_num: int) -> void:
	var wave_name: String = wave_manager.get_wave_name(wave_num)
	if wave_manager.is_endless:
		wave_label.text = tr("UI_BATTLE_ENDLESS_WAVE") % wave_num
	else:
		wave_label.text = tr("UI_BATTLE_WAVE_FORMAT") % [wave_num, wave_manager.get_total_waves()]
	_show_wave_banner(wave_num)
	# 通知教学引导
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_wave_started(wave_num)
	# 全局升级面板
	var _is_tut: bool = is_instance_valid(_tutorial_guide) and not _tutorial_guide_done
	if not _is_tut and _global_upgrade_system.should_trigger_on_wave(wave_num):
		_global_upgrade_system.show_upgrade_panel(wave_num)
		if is_instance_valid(_tutorial_guide) and _tutorial_guide.has_method("notify_global_upgrade_shown"):
			_tutorial_guide.notify_global_upgrade_shown()
	# 英雄升级（非教学、非全局升级波次时直接弹出）
	if _hero_system.is_hero_placed() and not _is_tut:
		var hero_tier: int = _hero_system.get_hero_upgrade_tier(wave_num)
		if hero_tier > 0 and _hero_system.get_hero_chosen_upgrades().size() < hero_tier:
			if not _global_upgrade_system.should_trigger_on_wave(wave_num):
				_hero_system.show_hero_upgrade_panel(wave_num, hero_tier)

func _on_wave_cleared(wave_num: int) -> void:
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_wave_cleared(wave_num)

func _on_victory() -> void:
	_game_end_flow.on_victory()

func _show_wave_banner(wave_num: int) -> void:
	var banner := Label.new()
	var total: int = wave_manager.get_total_waves() if wave_manager else 40
	var w_name: String = wave_manager.get_wave_name(wave_num)
	if w_name != "":
		banner.text = tr("UI_WAVE_BANNER") % [wave_num, w_name]
	else:
		banner.text = tr("UI_WAVE_BANNER_SIMPLE") % wave_num
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("shadow_offset_x", 3)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.custom_minimum_size = Vector2(600, 120)
	banner.z_index = 50
	$HUD.add_child(banner)
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	banner.size = Vector2(600, 120)
	banner.position = Vector2((vp_size.x - 600) / 2.0, (vp_size.y - 120) / 2.0)
	banner.modulate.a = 0.0
	banner.position.y -= 60
	var tw := banner.create_tween()
	tw.tween_property(banner, "position:y", banner.position.y + 60, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.0)
	tw.tween_property(banner, "position:y", banner.position.y - 20, 0.4)
	tw.parallel().tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)


# ══════════════════════════════════════════════════════════════════════════
# 全局升级回调
# ══════════════════════════════════════════════════════════════════════════
func _on_global_upgrade_chosen(upg: GlobalUpgradeData) -> void:
	_apply_upgrades_to_all_towers()
	_tower_card_panel.refresh_costs(
		func(tid: String) -> float: return _global_upgrade_system.get_cost_discount_for(tid)
	)
	# 通知教学引导
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_upgrade_chosen()
	# 全局升级选完后，检查是否需要弹英雄升级
	var wn: int = wave_manager.current_wave
	if _hero_system.is_hero_placed():
		var hero_tier: int = _hero_system.get_hero_upgrade_tier(wn)
		if hero_tier > 0 and _hero_system.get_hero_chosen_upgrades().size() < hero_tier:
			_hero_system.show_hero_upgrade_panel(wn, hero_tier)
			return
	get_tree().paused = false


func _on_hero_upgrade_done() -> void:
	# 英雄升级完成后显示浮动文字
	var ht = _hero_system.get_hero_tower()
	if is_instance_valid(ht):
		_tower_upgrade_panel.show_float_text(
			tr("UI_HERO_UPGRADE_FLOAT") % ht.hero_level,
			ht.global_position
		)


func _apply_upgrades_to_all_towers() -> void:
	_global_upgrade_system._apply_upgrades_to_all_towers()


# ══════════════════════════════════════════════════════════════════════════
# 炮台放置回调（BuildManager → BattleScene）
# ══════════════════════════════════════════════════════════════════════════
func _on_tower_placed(tower: Area2D) -> void:
	_tower_card_panel.highlight_card(null)
	tower.tower_tapped.connect(_on_tower_tapped)
	tower.stat_wave_placed = wave_manager.current_wave if _game_started else 0
	tower.stat_total_spent = tower.tower_data.placement_cost if tower.tower_data else 0
	# 注入子弹对象池
	tower.bullet_pool = _bullet_pool
	# 英雄炮台记录
	var placed_td := tower.tower_data as TowerCollectionData
	if placed_td and placed_td.is_hero:
		_hero_system.register_hero(tower, wave_manager.current_wave)
		build_manager.set_hero_placed(true)
		_refresh_card_affordability()
	# 新塔应用全局升级
	_apply_upgrades_to_all_towers()
	# 通知教学引导
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_tower_placed(tower)


func _on_tower_tapped(tower: Area2D) -> void:
	_tower_upgrade_panel.on_tower_tapped(tower)


func _on_hero_panel_requested(tower: Area2D) -> void:
	_hero_system.show_hero_panel(tower, _tower_upgrade_panel.get_active_tower())


func _on_hero_sell_requested(tower: Area2D, refund: int, is_hero: bool) -> void:
	_tower_upgrade_panel._show_sell_confirm(tower, refund, is_hero)


## ── 试用炮台 ────────────────────────────────────────────────────────

func _on_trial_tower_selected(tower_data: Resource) -> void:
	var td := tower_data as TowerCollectionData
	if not td:
		return
	# 记录试用 ID
	if td.tower_id not in _trial_tower_ids:
		_trial_tower_ids.append(td.tower_id)
	# 临时添加到炮台栏（放置费用为 0）
	_add_trial_tower_card(td)


func _add_trial_tower_card(td: TowerCollectionData) -> void:
	# 在 tower_hbox 中添加一个带"试用"标记的炮台卡片
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	# 图片
	var img := Panel.new()
	img.custom_minimum_size = Vector2(100, 140)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if td.collection_texture:
		var tex := TextureRect.new()
		tex.texture = td.collection_texture
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(tex)
	else:
		var emoji := Label.new()
		emoji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		emoji.text = td.tower_emoji
		emoji.add_theme_font_size_override("font_size", 48)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(emoji)
	card.add_child(img)

	# 名称
	var name_lbl := Label.new()
	name_lbl.text = TowerResourceRegistry.tr_tower_name(td)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# "试用" 标记
	var badge := Label.new()
	badge.text = "🎟️ " + tr("UI_TRIAL_BADGE")
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	# 免费放置
	var cost_lbl := Label.new()
	cost_lbl.text = tr("UI_TRIAL_FREE_PLACE")
	cost_lbl.name = "CostLbl"
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cost_lbl)

	# 拖拽放置（免费，cost=0）
	var cap := td
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				build_manager.select_tower(cap)
				card.set_meta("press_pos", e.global_position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", 0)
			else:
				if card.get_meta("dragging", false):
					build_manager.release_drag()
				else:
					build_manager.cancel_selection()
				card.set_meta("dragging", false)
		elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pp: Vector2 = card.get_meta("press_pos", e.global_position)
			if not card.get_meta("dragging", false):
				if e.global_position.distance_to(pp) >= 40.0:
					card.set_meta("dragging", true)
					build_manager.start_drag_at(e.global_position, 0)
			else:
				build_manager.move_preview_to(e.global_position)
		elif e is InputEventScreenTouch:
			if e.pressed:
				build_manager.select_tower(cap)
				card.set_meta("press_pos", e.position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", 0)
			else:
				if card.get_meta("dragging", false):
					build_manager.release_drag()
				else:
					build_manager.cancel_selection()
				card.set_meta("dragging", false)
		elif e is InputEventScreenDrag:
			var pp: Vector2 = card.get_meta("press_pos", e.position)
			if not card.get_meta("dragging", false):
				if e.position.distance_to(pp) >= 40.0:
					card.set_meta("dragging", true)
					var vp_pos: Vector2 = get_viewport().get_mouse_position()
					build_manager.start_drag_at(vp_pos, 0)
			else:
				var vp_pos: Vector2 = get_viewport().get_mouse_position()
				build_manager.move_preview_to(vp_pos)
	)

	tower_hbox.add_child(card)


## ── 宝箱敌人掉落 ────────────────────────────────────────────────────

func _on_treasure_enemy_spawned(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.treasure_killed.connect(_on_treasure_killed)
	enemy.treasure_escaped.connect(_on_treasure_escaped)


func _on_treasure_killed() -> void:
	# 随机掉落奖励
	var roll: float = randf()
	if roll < 0.30:
		# 30% 试用券
		UserManager.add_item("trial_ticket", 1)
		_show_treasure_reward("🎟️ " + tr("ITEM_TRIAL_TICKET") + " ×1")
	elif roll < 0.60:
		# 30% 随机紫碎片 ×5
		var towers = TowerResourceRegistry.get_towers_by_rarity(3)
		if towers.size() > 0:
			var td = towers[randi() % towers.size()]
			CollectionManager.add_fragments(td.tower_id, 5)
			var tname: String = TowerResourceRegistry.get_tower_display_name(td.tower_id, td.display_name)
			_show_treasure_reward("🧩 " + tname + " ×5")
		else:
			UserManager.add_gems(30)
			_show_treasure_reward("💎 ×30")
	else:
		# 40% 钻石 15-30
		var gems: int = randi_range(15, 30)
		UserManager.add_gems(gems)
		_show_treasure_reward("💎 ×%d" % gems)
	SaveManager.save()


func _on_treasure_escaped() -> void:
	# 宝箱敌人逃走，什么都不给
	pass


func _show_treasure_reward(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "🎁 " + text
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.custom_minimum_size = Vector2(600, 60)
	lbl.z_index = 50
	$HUD.add_child(lbl)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	lbl.position = Vector2((vp_size.x - 600) / 2.0, vp_size.y * 0.35)
	# 动画：弹出 → 停留 → 淡出
	lbl.modulate.a = 0.0
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _show_trial_end_popup() -> void:
	if _trial_tower_ids.is_empty():
		return
	# 延迟显示（等胜利/失败弹窗关闭后再弹）
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("UI_TRIAL_END_TITLE")
	dlg.dialog_text = tr("UI_TRIAL_END_MSG")
	dlg.ok_button_text = tr("UI_TRIAL_GO_SHOP")
	dlg.cancel_button_text = tr("UI_TRIAL_LATER")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		GameManager.challenge_mode = false
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


func _on_tower_sold(tower: Area2D) -> void:
	var td := tower.tower_data as TowerCollectionData
	if td and td.is_hero:
		_hero_system.on_hero_sold()
	_tower_upgrade_panel.cleanup_free_owners_for(tower)


func _refresh_card_affordability() -> void:
	_tower_card_panel.refresh_affordability(
		func() -> bool: return _hero_system.is_hero_placed()
	)


# ══════════════════════════════════════════════════════════════════════════
# 无限模式
# ══════════════════════════════════════════════════════════════════════════
func _on_endless_entered() -> void:
	_game_ended = false

func _reconnect_signals() -> void:
	if not wave_manager.wave_started.is_connected(_on_wave_started):
		wave_manager.wave_started.connect(_on_wave_started)
	if not wave_manager.wave_cleared.is_connected(_on_wave_cleared):
		wave_manager.wave_cleared.connect(_on_wave_cleared)
	if not wave_manager.all_waves_cleared.is_connected(_on_victory):
		wave_manager.all_waves_cleared.connect(_on_victory)
	if not GameManager.hp_changed.is_connected(_on_hp_changed):
		GameManager.hp_changed.connect(_on_hp_changed)
	if not GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.connect(_on_gold_changed)


# ══════════════════════════════════════════════════════════════════════════
# 设置 / 退出
# ══════════════════════════════════════════════════════════════════════════
func _on_back() -> void:
	if _game_ended:
		return
	if is_instance_valid(_settings_panel_ref):
		return
	_open_settings_panel()


func _open_settings_panel() -> void:
	var sp: SettingsPanel = SETTINGS_PANEL_SCENE.instantiate()
	sp.save_game_requested.connect(_on_save_and_exit)
	sp.exit_requested.connect(_on_exit_no_save)
	get_tree().root.add_child(sp)
	sp.open(true)
	_settings_panel_ref = sp


func _on_save_and_exit() -> void:
	if SaveManager.has_battle_save():
		var info: Dictionary = SaveManager.load_battle()
		var day_num: int = info.get("day", GameManager.current_day)
		var mode_str: String = tr("UI_MODE_CHALLENGE_LABEL") if info.get("challenge_mode", false) else tr("UI_MODE_NORMAL_LABEL")
		var confirm := AcceptDialog.new()
		confirm.process_mode = Node.PROCESS_MODE_ALWAYS
		confirm.dialog_text = tr("UI_SAVE_OVERWRITE") % [day_num, mode_str]
		confirm.ok_button_text = tr("UI_SAVE_CONFIRM")
		confirm.add_cancel_button(tr("UI_DIALOG_CANCEL"))
		confirm.confirmed.connect(func(): confirm.queue_free(); _do_exit(true))
		confirm.canceled.connect(func(): confirm.queue_free())
		$HUD.add_child(confirm)
		confirm.popup_centered()
	else:
		_do_exit(true)


func _on_exit_no_save() -> void:
	var confirm := AcceptDialog.new()
	confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm.dialog_text = tr("UI_EXIT_NO_SAVE_MSG")
	confirm.ok_button_text = tr("UI_SAVE_CONFIRM")
	confirm.add_cancel_button(tr("UI_DIALOG_CANCEL"))
	confirm.confirmed.connect(func(): confirm.queue_free(); _do_exit_keep_save())
	confirm.canceled.connect(func(): confirm.queue_free())
	$HUD.add_child(confirm)
	confirm.popup_centered()


func _do_exit(save: bool) -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameManager.test_mode      = false
	GameManager.challenge_mode = false
	_disconnect_signals()
	UserManager.tutorial_completed = true
	if save and _game_started:
		_save_battle()
	else:
		SaveManager.clear_battle_save()
	SaveManager.save()
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")


func _do_exit_keep_save() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameManager.test_mode      = false
	GameManager.challenge_mode = false
	_disconnect_signals()
	UserManager.tutorial_completed = true
	SaveManager.save()
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")


func _disconnect_signals() -> void:
	if GameManager.hp_changed.is_connected(_on_hp_changed):
		GameManager.hp_changed.disconnect(_on_hp_changed)
	if GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.disconnect(_on_gold_changed)
	if is_instance_valid(wave_manager):
		if wave_manager.all_waves_cleared.is_connected(_on_victory):
			wave_manager.all_waves_cleared.disconnect(_on_victory)
		if wave_manager.wave_started.is_connected(_on_wave_started):
			wave_manager.wave_started.disconnect(_on_wave_started)
		if wave_manager.wave_cleared.is_connected(_on_wave_cleared):
			wave_manager.wave_cleared.disconnect(_on_wave_cleared)


# ══════════════════════════════════════════════════════════════════════════
# 新手教学引导
# ══════════════════════════════════════════════════════════════════════════
func _start_tutorial_guide() -> void:
	_tutorial_guide = TutorialGuide.new()
	_tutorial_guide.name = "TutorialGuideLayer"
	add_child(_tutorial_guide)
	_tutorial_guide.tutorial_finished.connect(_on_tutorial_finished)
	_tutorial_guide.request_upgrade_panel.connect(_on_tutorial_request_upgrade)
	_tutorial_guide.start_tutorial(self)

func _on_tutorial_finished() -> void:
	_tutorial_guide_done = true

func _on_tutorial_request_upgrade() -> void:
	_global_upgrade_system.show_upgrade_panel(0)


# ══════════════════════════════════════════════════════════════════════════
# 战局存档
# ══════════════════════════════════════════════════════════════════════════
func _save_battle() -> void:
	var upgrade_ids: Array = _global_upgrade_system.get_active_upgrade_ids()

	var towers_data: Array = []
	var hero_place_wave: int = _hero_system.get_hero_place_wave()
	var hero_tower = _hero_system.get_hero_tower()
	for t in get_tree().get_nodes_in_group("tower"):
		if not is_instance_valid(t):
			continue
		if t.is_preview:
			continue
		var td := t.tower_data as TowerCollectionData
		if not td:
			continue
		towers_data.append({
			"resource_path":    td.resource_path,
			"pos_x":            t.global_position.x,
			"pos_y":            t.global_position.y,
			"is_hero":          td.is_hero,
			"hero_level":       t.hero_level,
			"hero_place_wave":  (hero_place_wave if t == hero_tower else 0),
			"hero_chosen_upgrades": t.hero_chosen_upgrades.duplicate(),
			"upgrade_paths":    t._in_game_path_levels.duplicate(),
			"target_mode":      t.target_mode,
			"stat_wave_placed":   t.stat_wave_placed,
			"stat_total_spent":   t.stat_total_spent,
			"stat_damage_dealt":  t.stat_damage_dealt,
			"stat_kills":         t.stat_kills,
		})

	SaveManager.save_battle({
		"day":             GameManager.current_day,
		"wave":            wave_manager.current_wave,
		"total_waves":     wave_manager.get_total_waves(),
		"gold":            GameManager.gold,
		"life":            GameManager.player_life,
		"challenge_mode":  GameManager.challenge_mode,
		"revive_used":     _game_end_flow._revive_used,
		"active_upgrades": upgrade_ids,
		"towers":          towers_data,
	})


func _resume_from_save() -> void:
	var sd: Dictionary = SaveManager.load_battle()
	if sd.is_empty():
		return

	# 恢复资源
	GameManager.gold        = sd.get("gold", 100)
	GameManager.player_life = sd.get("life", 20)
	_game_end_flow._revive_used = sd.get("revive_used", false)
	_refresh_displays()

	# 恢复全局升级
	var saved_ids: Array = sd.get("active_upgrades", [])
	_global_upgrade_system.restore_upgrades(saved_ids)

	# 恢复炮台
	var tower_layer: Node = find_child("TowerLayer", true, false)
	const TOWER_SCENE_FALLBACK := preload("res://tower/Tower.tscn")

	for tdata in sd.get("towers", []):
		var res_path: String = tdata.get("resource_path", "")
		if res_path == "" or not ResourceLoader.exists(res_path):
			continue
		var td_res := load(res_path) as TowerCollectionData
		if td_res == null:
			continue
		var scene: PackedScene = td_res.tower_scene if td_res.tower_scene else TOWER_SCENE_FALLBACK
		var tower = scene.instantiate()
		tower.tower_data           = td_res
		tower.is_preview           = false
		tower.global_position      = Vector2(float(tdata["pos_x"]), float(tdata["pos_y"]))
		tower.hero_level           = tdata.get("hero_level", 1)
		var raw_paths: Array = tdata.get("upgrade_paths", [0, 0, 0, 0])
		var typed_paths: Array[int] = []
		for v in raw_paths:
			typed_paths.append(int(v))
		tower._in_game_path_levels = typed_paths
		tower.target_mode          = tdata.get("target_mode", 0)
		tower.stat_wave_placed     = tdata.get("stat_wave_placed", 0)
		tower.stat_total_spent     = tdata.get("stat_total_spent", 0)
		tower.stat_damage_dealt    = float(tdata.get("stat_damage_dealt", 0.0))
		tower.stat_kills           = int(tdata.get("stat_kills", 0))
		tower.bullet_pool          = _bullet_pool
		if tower_layer:
			tower_layer.add_child(tower)
		else:
			add_child(tower)

		if tdata.get("is_hero", false):
			_hero_system.register_hero(tower, tdata.get("hero_place_wave", 0))
			build_manager.set_hero_placed(true)
			# 恢复英雄升级选择
			var saved_choices: Array = tdata.get("hero_chosen_upgrades", [])
			_hero_system.restore_hero_upgrades(saved_choices)
		tower.tower_tapped.connect(_on_tower_tapped)

	# 重新计算全局升级加成
	_apply_upgrades_to_all_towers()

	# 启动战局（直接从存档波次开始）
	_game_started = true
	speed_btn.text = "1×"
	pause_btn.disabled = false
	wave_manager.start_from(sd.get("wave", 1))


# ══════════════════════════════════════════════════════════════════════════
# 地图视觉动效 + 可交互装饰品
# ══════════════════════════════════════════════════════════════════════════
func _setup_map_vfx() -> void:
	var map_node: Node = $TutorialMap
	if not map_node:
		return
	if SettingsManager.particles_enabled:
		var particles := GPUParticles2D.new()
		particles.name = "FallingLeaves"
		particles.z_index = -5
		particles.amount = 15
		particles.lifetime = 5.0
		particles.process_material = _create_leaf_particle_material()
		particles.visibility_rect = Rect2(-600, -200, 1800, 2200)
		particles.position = Vector2(540, 0)
		map_node.add_child(particles)


func _create_leaf_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(540, 10, 0)
	mat.direction = Vector3(0.3, 1.0, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(5, 20, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.7, 0.2, 0.8))
	gradient.set_color(1, Color(0.5, 0.6, 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = gradient
	mat.color_ramp = gt
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	mat.tangential_accel_min = -10.0
	mat.tangential_accel_max = 10.0
	return mat


func _connect_interactable_decors() -> void:
	for node in get_tree().get_nodes_in_group("interactable_decor"):
		if node is InteractableDecor:
			node.clicked.connect(_on_decor_clicked)


func _on_decor_clicked(decor: InteractableDecor) -> void:
	if not is_instance_valid(decor):
		return
	var cost: int = decor.remove_cost
	var dname: String = decor.display_name
	var dlg := ConfirmationDialog.new()
	dlg.title              = tr("UI_DECOR_REMOVE_TITLE")
	dlg.dialog_text        = tr("UI_DECOR_REMOVE_MSG") % [dname, cost]
	dlg.ok_button_text     = tr("UI_DECOR_REMOVE_CONFIRM")
	dlg.cancel_button_text = tr("UI_DIALOG_CANCEL")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if GameManager.spend_gold(cost):
			if is_instance_valid(decor):
				decor.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


func _on_interactable_clicked(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	var dlg := ConfirmationDialog.new()
	dlg.title              = tr("UI_DECOR_REMOVE_TITLE")
	dlg.dialog_text        = tr("UI_DECOR_REMOVE_GENERIC")
	dlg.ok_button_text     = tr("UI_DECOR_REMOVE_CONFIRM")
	dlg.cancel_button_text = tr("UI_DIALOG_CANCEL")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if GameManager.spend_gold(500):
			if is_instance_valid(area):
				area.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


# ══════════════════════════════════════════════════════════════════════════
# 自定义地图动态加载
# ══════════════════════════════════════════════════════════════════════════
func _replace_map_with_custom(path: String) -> void:
	GameManager.test_mode   = true
	GameManager.gold        = 999999
	GameManager.player_life = 999999
	GameManager.gold_changed.emit(GameManager.gold)
	GameManager.hp_changed.emit(GameManager.player_life)

	var saved_curve: Curve2D = null
	var old_map := get_node_or_null("TutorialMap")
	if old_map:
		var old_path := old_map.get_node_or_null("Path2D")
		if old_path and old_path is Path2D and old_path.curve:
			saved_curve = old_path.curve.duplicate()
		remove_child(old_map)
		old_map.queue_free()

	var md := MapData.load_from_file(path)
	if not md:
		push_error("BattleScene: 无法加载自定义地图 " + path)
		return

	var dyn := Node2D.new()
	dyn.name = "TutorialMap"
	add_child(dyn)
	move_child(dyn, 0)

	var _ground_colors: Dictionary = {
		"grass":    Color(0.25, 0.55, 0.18),
		"highland": Color(0.62, 0.56, 0.38),
		"farmland": Color(0.32, 0.50, 0.20),
		"dirt":     Color(0.55, 0.40, 0.25),
	}
	var bg := ColorRect.new()
	bg.size         = Vector2(1080, 1920)
	bg.color        = _ground_colors.get(md.background_type, Color(0.25, 0.55, 0.18))
	bg.z_index      = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.add_child(bg)

	var path2d        := Path2D.new()
	path2d.name       = "Path2D"
	if saved_curve:
		path2d.curve = saved_curve
	else:
		var curve         := Curve2D.new()
		curve.bake_interval = 5.0
		for wp: Vector2 in md.waypoints:
			curve.add_point(wp)
		path2d.curve = curve
	dyn.add_child(path2d)

	if saved_curve:
		var road := Line2D.new()
		road.name           = "RoadVisual"
		road.width          = 90.0
		road.default_color  = Color(0.60, 0.45, 0.20)
		road.joint_mode     = Line2D.LineJointMode.LINE_JOINT_ROUND
		road.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		road.end_cap_mode   = Line2D.LineCapMode.LINE_CAP_ROUND
		road.points         = saved_curve.get_baked_points()
		dyn.add_child(road)

	var tower_layer      := Node2D.new()
	tower_layer.name     = "TowerLayer"
	tower_layer.z_index  = 5
	dyn.add_child(tower_layer)

	var enemy_layer      := Node2D.new()
	enemy_layer.name     = "EnemyLayer"
	enemy_layer.z_index  = 3
	dyn.add_child(enemy_layer)

	var ui_layer         := CanvasLayer.new()
	ui_layer.name        = "UILayer"
	dyn.add_child(ui_layer)

	var PATH_W := 90.0
	var path_area              := Area2D.new()
	path_area.name             = "PathArea"
	path_area.add_to_group("path")
	path_area.collision_layer  = 1024
	path_area.collision_mask   = 2
	if saved_curve:
		var pts: PackedVector2Array = saved_curve.get_baked_points()
		var step := 3
		for si in range(0, pts.size() - step, step):
			var a: Vector2 = pts[si]
			var b: Vector2 = pts[si + step]
			var col := CollisionShape2D.new()
			var sh  := RectangleShape2D.new()
			sh.size      = Vector2(a.distance_to(b) + PATH_W, PATH_W)
			col.shape    = sh
			col.position = (a + b) / 2.0
			col.rotation = (b - a).angle()
			path_area.add_child(col)
	dyn.add_child(path_area)

	var block_area             := Area2D.new()
	block_area.name            = "BlockArea"
	block_area.add_to_group("block")
	block_area.collision_layer = 256
	block_area.collision_mask  = 2
	for d: Dictionary in md.objects:
		if d.get("group", "") == "block":
			var col   := CollisionShape2D.new()
			var sh    := RectangleShape2D.new()
			sh.size            = Vector2(d.get("w", 80.0), d.get("h", 80.0))
			col.shape          = sh
			col.position       = Vector2(d.get("x", 0.0), d.get("y", 0.0))
			col.rotation_degrees = d.get("rot", 0.0)
			block_area.add_child(col)
	dyn.add_child(block_area)

	var goal_area              := Area2D.new()
	goal_area.name             = "GoalArea"
	goal_area.position         = md.goal_pos
	var gcol                   := CollisionShape2D.new()
	var gsh                    := CircleShape2D.new()
	gsh.radius                 = 80.0
	gcol.shape                 = gsh
	goal_area.add_child(gcol)
	dyn.add_child(goal_area)

	for d: Dictionary in md.objects:
		var grp_i: String = d.get("group", "block")
		if grp_i == "path" or grp_i == "interactable":
			continue
		var rect              := ColorRect.new()
		rect.size              = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		rect.position          = Vector2(
			d.get("x", 0.0) - d.get("w", 80.0) / 2.0,
			d.get("y", 0.0) - d.get("h", 80.0) / 2.0)
		rect.rotation_degrees  = d.get("rot", 0.0)
		rect.color             = Color(0.20, 0.40, 0.15)
		rect.mouse_filter      = Control.MOUSE_FILTER_IGNORE
		dyn.add_child(rect)

	for d: Dictionary in md.objects:
		if d.get("group", "") != "interactable":
			continue
		var ia := Area2D.new()
		ia.add_to_group("block")
		ia.collision_layer = 256
		ia.collision_mask  = 2
		ia.input_pickable  = true
		ia.position        = Vector2(d.get("x", 0.0), d.get("y", 0.0))
		ia.rotation_degrees = d.get("rot", 0.0)
		var col_ia := CollisionShape2D.new()
		var sh_ia  := RectangleShape2D.new()
		sh_ia.size = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		col_ia.shape = sh_ia
		ia.add_child(col_ia)
		var rect_ia := ColorRect.new()
		rect_ia.size         = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		rect_ia.position     = Vector2(-d.get("w", 80.0) / 2.0, -d.get("h", 80.0) / 2.0)
		rect_ia.color        = Color(0.35, 0.58, 0.22)
		rect_ia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ia.add_child(rect_ia)
		ia.input_event.connect(func(_vp, event, _idx):
			if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
				_on_interactable_clicked(ia)
		)
		dyn.add_child(ia)

	# 测试模式：重建炮台列表
	while tower_hbox.get_child_count() > 0:
		var child = tower_hbox.get_child(0)
		tower_hbox.remove_child(child)
		child.free()
	_tower_card_panel.build_cards()
	_refresh_tab_state()
