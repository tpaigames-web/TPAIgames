extends Node

## 新手教学战斗场景控制器
## 负责 HUD 显示（HP、金币）、底部炮台面板、返回逻辑

# ── 所有炮台集合数据路径 ──────────────────────────────────────────────
const COLLECTION_PATHS: Array[String] = [
	"res://data/towers/scarecrow_collection.tres",
	"res://data/towers/water_pipe_collection.tres",
	"res://data/towers/farmer_collection.tres",
	"res://data/towers/bear_trap_collection.tres",
	"res://data/towers/beehive_collection.tres",
	"res://data/towers/farm_cannon_collection.tres",
	"res://data/towers/barbed_wire_collection.tres",
	"res://data/towers/windmill_collection.tres",
	"res://data/towers/seed_shooter_collection.tres",
	"res://data/towers/mushroom_bomb_collection.tres",
	"res://data/towers/chili_flamer_collection.tres",
	"res://data/towers/watchtower_collection.tres",
	"res://data/towers/sunflower_collection.tres",
	"res://data/towers/hero_farmer_collection.tres",
]

# ── 节点引用 ──────────────────────────────────────────────────────────
@onready var build_manager:  Node           = $BuildManager
@onready var wave_manager:   Node           = $WaveManager
@onready var back_btn:       Button          = $HUD/TopBar/BackBtn
@onready var hp_label:       Label           = $HUD/TopBar/HPPanel/HPLabel
@onready var gold_label:     Label           = $HUD/TopBar/GoldPanel/GoldLabel
@onready var toggle_btn:     Button          = $HUD/BottomPanel/ToggleBtn
@onready var tower_scroll:   ScrollContainer = $HUD/BottomPanel/TowerScroll
@onready var tower_hbox:     HBoxContainer   = $HUD/BottomPanel/TowerScroll/TowerHBox
@onready var _upgrade_panel: ScrollContainer = $HUD/BottomPanel/UpgradePanel
@onready var _upgrade_vbox:  VBoxContainer   = $HUD/BottomPanel/UpgradePanel/UpgradeVBox

var _panel_expanded:   bool     = true
var _last_selected_card: VBoxContainer = null
var _active_tower:     Area2D   = null
var _game_ended:       bool     = false   # 防止胜利/失败逻辑重复触发

## （card, data）对列表，用于刷新金币可购买状态
var _tower_card_entries: Array = []

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	# 重置全局战斗状态（教学关：500 金币、100 HP）
	GameManager.player_life = 100
	GameManager.gold        = 500

	# 连接 GameManager autoload 信号 → HUD
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)

	# 连接胜利信号（WaveManager 所有波次清场后发出）
	wave_manager.all_waves_cleared.connect(_on_victory)

	# 连接按钮
	back_btn.pressed.connect(_on_back)
	toggle_btn.pressed.connect(_toggle_panel)

	# 监听炮台放置信号（取消选中 + 连接炮台点击）
	build_manager.tower_placed.connect(_on_tower_placed)

	# 构建炮台格子
	_build_tower_cards()

	# 初始 HUD 显示
	_refresh_displays()

# ── 面板展开 / 收缩 ──────────────────────────────────────────────────
func _toggle_panel() -> void:
	_panel_expanded = not _panel_expanded
	# 升级面板显示时不影响其可见性
	if not _upgrade_panel.visible:
		tower_scroll.visible = _panel_expanded
	toggle_btn.text = "▲" if _panel_expanded else "▼"

# ── 构建炮台格子（只显示已解锁的炮台）────────────────────────────────
func _build_tower_cards() -> void:
	_tower_card_entries.clear()
	for path in COLLECTION_PATHS:
		var data: Resource = load(path)
		if data == null:
			continue
		if CollectionManager.get_tower_status(data.tower_id) != 2:
			continue
		var card: VBoxContainer = _make_tower_card(data)
		tower_hbox.add_child(card)
		_tower_card_entries.append({card = card, data = data})
	_refresh_card_affordability()

## 生成单个炮台格子（VBoxContainer）
func _make_tower_card(data: Resource) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 图片区（5:7 比例 = 100×140）──
	var img := Panel.new()
	img.custom_minimum_size = Vector2(100, 140)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# ── 放置费用 ──
	var cost_lbl := Label.new()
	cost_lbl.text = "🪙 %d" % data.placement_cost
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cost_lbl)

	# ── 按下即拖拽，转发事件到 BuildManager ──
	var cap: Resource = data
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if GameManager.gold < cap.placement_cost:
					return   # 金币不足，不响应
				build_manager.select_tower(cap)
				_highlight_selected_card(card)
				build_manager.start_drag_at(e.global_position)
			else:
				build_manager.release_drag()
		elif e is InputEventMouseMotion:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				build_manager.move_preview_to(e.global_position)
		elif e is InputEventScreenTouch:
			if e.pressed:
				if GameManager.gold < cap.placement_cost:
					return
				build_manager.select_tower(cap)
				_highlight_selected_card(card)
				build_manager.start_drag_at(e.position)
			else:
				build_manager.release_drag()
		elif e is InputEventScreenDrag:
			build_manager.move_preview_to(e.position)
	)

	return card

# ── 高亮选中格子 ──────────────────────────────────────────────────────
func _highlight_selected_card(card: VBoxContainer) -> void:
	if _last_selected_card and is_instance_valid(_last_selected_card):
		_last_selected_card.modulate = Color(1, 1, 1, 1)
	_last_selected_card = card
	card.modulate = Color(0.5, 1.0, 0.5, 1.0)

# ── 金币可购买性刷新 ──────────────────────────────────────────────────
func _refresh_card_affordability() -> void:
	var gold: int = GameManager.gold
	for entry in _tower_card_entries:
		var ok: bool = gold >= entry.data.placement_cost
		entry.card.modulate = Color(1, 1, 1, 1) if ok else Color(0.5, 0.5, 0.5, 1)

# ── 炮台放置回调 ─────────────────────────────────────────────────────
func _on_tower_placed(tower: Area2D) -> void:
	# 取消卡片高亮
	if _last_selected_card and is_instance_valid(_last_selected_card):
		_last_selected_card.modulate = Color(1, 1, 1, 1)
	_last_selected_card = null
	# 连接炮台点击信号，支持升级面板
	tower.tower_tapped.connect(_on_tower_tapped)

# ── 升级面板 ─────────────────────────────────────────────────────────
func _on_tower_tapped(tower: Area2D) -> void:
	_show_upgrade_panel(tower)

func _show_upgrade_panel(tower: Area2D) -> void:
	_active_tower = tower
	tower_scroll.visible = false
	_populate_upgrade_panel(tower)
	_upgrade_panel.visible = true

func _hide_upgrade_panel() -> void:
	_active_tower = null
	_upgrade_panel.visible = false
	tower_scroll.visible = _panel_expanded

func _populate_upgrade_panel(tower: Area2D) -> void:
	for c in _upgrade_vbox.get_children():
		c.queue_free()
	var data: TowerCollectionData = tower.tower_data as TowerCollectionData
	if not data:
		return

	# 顶部：返回按钮 + 炮台名称
	var header := HBoxContainer.new()
	var back   := Button.new()
	back.text  = "← 返回"
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_hide_upgrade_panel)
	header.add_child(back)
	var title := Label.new()
	title.text = "%s %s" % [data.tower_emoji, data.display_name]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	_upgrade_vbox.add_child(header)

	# 攻击目标选择行
	var target_row := HBoxContainer.new()
	var _modes := [["第一个", 0], ["靠近", 1], ["强力", 2], ["最后", 3]]
	for md in _modes:
		var btn := Button.new()
		btn.text = md[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
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

func _make_upgrade_row(tower: Area2D, path_idx: int) -> HBoxContainer:
	var data         := tower.tower_data as TowerCollectionData
	var path         := data.upgrade_paths[path_idx] as TowerUpgradePath
	var cur_tier     : int  = tower._in_game_path_levels[path_idx]
	var arsenal_tier : int  = CollectionManager.get_path_level(data.tower_id, path_idx)
	var at_max       : bool = cur_tier >= 5

	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = path.path_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d/5" % cur_tier
	tier_lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(tier_lbl)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 22)
	if at_max:
		btn.text     = "MAX"
		btn.disabled = true
	else:
		var is_free : bool = (cur_tier + 1) <= arsenal_tier
		if is_free:
			btn.text = "升级 FREE"
		else:
			var cost : int = path.tier_costs[cur_tier] if cur_tier < path.tier_costs.size() else 0
			btn.text = "升级 🪙%d" % cost
			btn.disabled = (GameManager.gold < cost)
		var ci := path_idx
		btn.pressed.connect(func() -> void: _do_upgrade(tower, ci))
	row.add_child(btn)
	return row

func _do_upgrade(tower: Area2D, path_idx: int) -> void:
	var data         := tower.tower_data as TowerCollectionData
	var path         := data.upgrade_paths[path_idx] as TowerUpgradePath
	var cur_tier     : int  = tower._in_game_path_levels[path_idx]
	var arsenal_tier : int  = CollectionManager.get_path_level(data.tower_id, path_idx)
	if cur_tier >= 5:
		return
	var is_free : bool = (cur_tier + 1) <= arsenal_tier
	if not is_free:
		var cost : int = path.tier_costs[cur_tier] if cur_tier < path.tier_costs.size() else 0
		if not GameManager.spend_gold(cost):
			return
	tower._in_game_path_levels[path_idx] += 1
	tower.apply_stat_upgrades()
	_populate_upgrade_panel(tower)

# ── HUD 更新 ──────────────────────────────────────────────────────────
func _on_hp_changed(new_hp: int) -> void:
	hp_label.text = "❤️ %d" % new_hp
	if new_hp <= 0:
		_on_game_over()

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "🪙 %d" % new_gold
	_refresh_card_affordability()

func _refresh_displays() -> void:
	hp_label.text   = "❤️ %d" % GameManager.player_life
	gold_label.text = "🪙 %d" % GameManager.gold

# ── 返回主界面 ────────────────────────────────────────────────────────
func _on_back() -> void:
	if _game_ended:
		return
	_game_ended = true
	_disconnect_signals()
	# 退出时标记教学已完成，避免下次重复显示教学卡片
	UserManager.tutorial_completed = true
	UserManager.add_gold(GameManager.get_carry_out_gold())
	SaveManager.save()
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")

func _disconnect_signals() -> void:
	if GameManager.hp_changed.is_connected(_on_hp_changed):
		GameManager.hp_changed.disconnect(_on_hp_changed)
	if GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.disconnect(_on_gold_changed)

# ── 游戏结束（HP 归零）────────────────────────────────────────────────
func _on_game_over() -> void:
	if _game_ended:
		return
	_game_ended = true
	_disconnect_signals()
	UserManager.games_played += 1
	UserManager.tutorial_completed = true
	SaveManager.save()
	var dlg := AcceptDialog.new()
	dlg.title = "💀 游戏结束"
	dlg.dialog_text = "农场被攻破了！\n下次再接再厉～"
	dlg.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/HomeScene.tscn"))
	dlg.canceled.connect(func(): get_tree().change_scene_to_file("res://scenes/HomeScene.tscn"))
	add_child(dlg)
	dlg.popup_centered()

# ── 胜利（所有波次清场）──────────────────────────────────────────────
func _on_victory() -> void:
	if _game_ended:
		return
	_game_ended = true
	_disconnect_signals()
	UserManager.games_played += 1
	UserManager.games_won   += 1
	UserManager.tutorial_completed = true
	UserManager.add_xp(200)
	UserManager.add_gold(GameManager.get_carry_out_gold())
	SaveManager.save()
	var dlg := AcceptDialog.new()
	dlg.title = "🎉 教学完成！"
	dlg.dialog_text = "恭喜守护农场成功！\n获得 200 XP 奖励"
	dlg.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/HomeScene.tscn"))
	dlg.canceled.connect(func(): get_tree().change_scene_to_file("res://scenes/HomeScene.tscn"))
	add_child(dlg)
	dlg.popup_centered()
