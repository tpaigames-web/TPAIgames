extends Control

const LEVEL_UP_PANEL      = preload("res://scenes/profile/LevelUpPanel.tscn")
const DAY_CARD_SCENE      = preload("res://scenes/components/DayCard.tscn")
const TUTORIAL_CARD_SCENE = preload("res://scenes/components/TutorialCard.tscn")
const UPGRADE_BTN_SCENE   = preload("res://scenes/components/UpgradeButton.tscn")
const MODE_SELECT_SCENE   = preload("res://scenes/components/ModeSelectDialog.tscn")
const SAVE_INDICATOR_SCENE = preload("res://scenes/components/SaveIndicator.tscn")

@onready var tutorial_card:     Panel          = $TutorialCard
@onready var tutorial_play_btn: Button         = $TutorialCard/PlayBtn
@onready var scroll_container:  ScrollContainer = $ScrollContainer
@onready var path_map:          PathMapControl = $ScrollContainer/PathMap

## 关卡总数
@export var total_days: int = 40

## ── 布局参数 ────────────────────────────────────────────────────────────────
@export var card_w: float = 320.0
@export var card_h: float = 110.0

## 运行时从 PathMap 场景获取的卡片位置
var card_positions: Array[Vector2] = []

## 每个区段的关卡数
@export var days_per_zone: int = 5

## 区段卡片颜色（已解锁）
const ZONE_CARD_COLORS: Array[Color] = [
	Color(0.22, 0.65, 0.22, 1.0),   # 春 — 绿
	Color(0.75, 0.55, 0.25, 1.0),   # 夏 — 金棕
	Color(0.65, 0.35, 0.15, 1.0),   # 秋 — 暗橙
]

## 存储每个关卡按钮引用（index 0 = Tutorial/Day 0）
var _day_buttons: Array[Button] = []

## 小老鼠动画帧
const RAT_FRAMES = preload("res://data/enemies/rat_small_frames.tres")


func _ready() -> void:
	# 隐藏旧的独立教学卡片（已整合到路径地图中）
	tutorial_card.visible = false
	_build_path_map()
	# 升级按钮已移至 HomeScene 左侧快捷栏，不再在 BattleTab 单独显示
	_show_save_indicator()
	# 检查是否有刚解锁的关卡需要播放动画
	if UserManager.newly_unlocked_day > 0:
		call_deferred("_play_unlock_animation", UserManager.newly_unlocked_day)


func _build_path_map() -> void:
	# 从 PathMap 场景的 Marker2D 节点获取位置
	card_positions = path_map.get_card_positions()

	# 清理旧的动态节点（保留 Marker2D 和背景图）
	for c in path_map.get_children():
		if c is Marker2D or c is TextureRect:
			continue
		c.queue_free()

	_day_buttons.clear()

	# 更新 PathMap 尺寸
	path_map.custom_minimum_size = Vector2(1080, path_map.get_total_height())

	# ── 第 0 张卡片：新手教学 ──
	_add_tutorial_button()

	# ── Day 1 ~ Day N 卡片 ──
	for i in range(total_days):
		var day_idx: int = i + 1
		var card_idx: int = i + 1
		_add_day_button(day_idx, card_idx)


## 新手教学卡片（路径地图 index 0）
func _add_tutorial_button() -> void:
	var card: Control = TUTORIAL_CARD_SCENE.instantiate()
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.position = card_positions[0] if card_positions.size() > 0 else Vector2(550, 80)

	# 设置状态文字
	var status_lbl: Label = card.get_node_or_null("StatusLabel")
	if status_lbl:
		if UserManager.tutorial_completed:
			status_lbl.text = tr("UI_TUTORIAL_COMPLETED")
			status_lbl.add_theme_color_override("font_color", Color(0.7, 1, 0.7, 1))
		else:
			status_lbl.text = tr("UI_TUTORIAL_TAP_START")
			status_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))

	# 连接点击事件
	var hit_btn: Button = card.get_node_or_null("HitButton")
	if hit_btn:
		hit_btn.pressed.connect(func():
			GameManager.current_day = 0
			SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")
		)

	path_map.add_child(card)
	_day_buttons.append(card)


func _add_day_button(day_idx: int, idx: int) -> void:
	var is_unlocked: bool
	if day_idx == 1:
		is_unlocked = UserManager.tutorial_completed
	else:
		is_unlocked = (day_idx <= UserManager.max_unlocked_day)

	var pos: Vector2 = card_positions[idx] if idx < card_positions.size() else Vector2(100, 200 + 240 * idx)

	var ns: int = UserManager.level_stars.get("day%d" % day_idx, 0)
	var n_claimed: bool = UserManager.level_chest_claimed.get("day%d_normal" % day_idx, false)
	var c_claimed: bool = UserManager.level_chest_claimed.get("day%d_challenge" % day_idx, false)

	# 实例化 DayCard 场景
	var card: DayCard = DAY_CARD_SCENE.instantiate()
	card.position = pos
	card.setup(day_idx, is_unlocked, ns, n_claimed, c_claimed)
	card.day_pressed.connect(_on_day_pressed)

	path_map.add_child(card)
	_day_buttons.append(card.hit_button)


func _on_day_pressed(day_idx: int) -> void:
	var can_play: bool
	if day_idx == 1:
		can_play = UserManager.tutorial_completed
	else:
		can_play = (day_idx <= UserManager.max_unlocked_day)

	if can_play:
		_show_mode_select(day_idx)
	else:
		var home = get_tree().get_first_node_in_group("home_scene")
		if home:
			home.show_locked(tr("UI_DAY_LOCKED") % day_idx)


## 关卡模式选择（支持所有解锁关卡）
func _show_mode_select(day_idx: int) -> void:
	var n_claimed: bool = UserManager.level_chest_claimed.get("day%d_normal" % day_idx, false)
	var c_claimed: bool = UserManager.level_chest_claimed.get("day%d_challenge" % day_idx, false)

	# 检查是否有此关卡的存档
	var has_save: bool = false
	var save_info: String = ""
	if SaveManager.has_battle_save():
		var saved: Dictionary = SaveManager.load_battle()
		var save_day: int = int(saved.get("day", -1))
		if save_day == day_idx:
			has_save = true
			var wave_num: int = saved.get("wave", 1)
			var mode_str: String = tr("UI_MODE_CHALLENGE_LABEL") if saved.get("challenge_mode", false) else tr("UI_MODE_NORMAL_LABEL")
			save_info = tr("UI_SAVE_FORMAT") % [mode_str, wave_num]

	var dialog: ModeSelectDialog = MODE_SELECT_SCENE.instantiate()
	dialog.setup(day_idx, n_claimed, c_claimed, has_save, save_info)

	dialog.mode_selected.connect(func(idx: int, mode: int):
		GameManager.current_day = idx
		GameManager.challenge_mode = (mode == ModeSelectDialog.MODE_CHALLENGE)
		SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")
	)
	dialog.continue_save.connect(func():
		GameManager.current_day = day_idx
		GameManager.resume_battle = true
		if has_save:
			var saved2: Dictionary = SaveManager.load_battle()
			GameManager.challenge_mode = saved2.get("challenge_mode", false)
		SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")
	)

	get_tree().root.add_child(dialog)


## ── 浮动升级图标 ─────────────────────────────────────────────────────────────
## 显示存档指示器（在对应关卡旁边显示存档框）
func _show_save_indicator() -> void:
	if not SaveManager.has_battle_save():
		return
	var info: Dictionary = SaveManager.load_battle()
	if info.is_empty():
		return

	var save_day: int = int(info.get("day", 0))
	var save_wave: int = int(info.get("wave", 0))
	var total_waves: int = int(info.get("total_waves", 40))
	var is_challenge: bool = bool(info.get("challenge_mode", false))

	# 找到对应关卡的 DayCard 节点获取地图坐标
	var target_card: Control = null
	for c in path_map.get_children():
		if c is DayCard and c.day_idx == save_day:
			target_card = c
			break
	if target_card == null:
		return

	var save_panel: SaveIndicator = SAVE_INDICATOR_SCENE.instantiate()
	save_panel.name = "SaveIndicator"
	save_panel.setup(save_day, save_wave, total_waves, is_challenge)
	save_panel.continue_pressed.connect(func():
		GameManager.current_day = save_day
		GameManager.resume_battle = true
		if is_challenge:
			GameManager.challenge_mode = true
		SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")
	)
	save_panel.position = Vector2(
		target_card.position.x,
		target_card.position.y - 90
	)
	save_panel.custom_minimum_size.x = card_w
	path_map.add_child(save_panel)


func _add_upgrade_icon() -> void:
	var upgrade_btn: Control = UPGRADE_BTN_SCENE.instantiate()
	upgrade_btn.name = "UpgradeFloatBtn"
	upgrade_btn.position = Vector2(10, 600)
	upgrade_btn.get_node("HitButton").pressed.connect(_on_upgrade_icon_pressed)
	add_child(upgrade_btn)


func _on_upgrade_icon_pressed() -> void:
	get_tree().root.add_child(LEVEL_UP_PANEL.instantiate())


## ── 关卡解锁动画 ─────────────────────────────────────────────────────────────
func _play_unlock_animation(new_day: int) -> void:
	# card_positions 索引：0=教学, 1=Day1, 2=Day2...
	var prev_idx: int = new_day - 1
	var next_idx: int = new_day
	if prev_idx < 0 or next_idx >= card_positions.size():
		UserManager.newly_unlocked_day = 0
		return

	# 自动滚动到让两个关卡可见
	var target_y: float = card_positions[next_idx].y - 400.0
	scroll_container.set_deferred("scroll_vertical", int(maxf(target_y, 0.0)))

	# 等一帧让滚动生效
	await get_tree().process_frame

	# ── 1. 创建小老鼠 AnimatedSprite2D ──
	var rat := AnimatedSprite2D.new()
	rat.sprite_frames = RAT_FRAMES
	rat.play("default")
	rat.scale = Vector2(0.5, 0.5)
	rat.z_index = 20
	rat.rotation_degrees = -90.0   # 贴图朝上，旋转后朝右

	var from_center: Vector2 = card_positions[prev_idx] + Vector2(card_w * 0.5, card_h * 0.5)
	rat.position = from_center
	path_map.add_child(rat)

	# ── 2. 计算 S 形路径点（与 _draw_road_segment 一致）──
	var to_center: Vector2 = card_positions[next_idx] + Vector2(card_w * 0.5, card_h * 0.5)
	var mid_y: float = (from_center.y + to_center.y) * 0.5
	var p1 := Vector2(from_center.x, from_center.y + card_h * 0.5)
	var p2 := Vector2(from_center.x, mid_y)
	var p3 := Vector2(to_center.x, mid_y)
	var p4 := Vector2(to_center.x, to_center.y - card_h * 0.5)

	# ── 3. 沿路径移动小老鼠（Tween 链）──
	var move_tween := create_tween()
	# 从卡片中心到底部
	move_tween.tween_property(rat, "position", p1, 0.2)
	# 向下到转折点
	move_tween.tween_property(rat, "position", p2, 0.4)
	# 到转折点时旋转朝向（水平移动）
	var going_right: bool = p3.x > p2.x
	move_tween.tween_property(rat, "rotation_degrees", 0.0 if going_right else 180.0, 0.1)
	# 水平移动
	move_tween.tween_property(rat, "position", p3, 0.4)
	# 旋转朝下（继续向下移动）
	move_tween.tween_property(rat, "rotation_degrees", -90.0, 0.1)
	# 向下到目标卡片
	move_tween.tween_property(rat, "position", p4, 0.3)
	# 到达卡片中心
	move_tween.tween_property(rat, "position", to_center, 0.15)

	await move_tween.finished
	rat.queue_free()

	# ── 4. 卡片抖动 ──
	var btn: Button = _day_buttons[next_idx]
	var orig_rot: float = btn.pivot_offset.x
	btn.pivot_offset = btn.size * 0.5   # 以中心为旋转轴
	var shake_tween := create_tween()
	for s in 3:
		shake_tween.tween_property(btn, "rotation", deg_to_rad(5.0), 0.06)
		shake_tween.tween_property(btn, "rotation", deg_to_rad(-5.0), 0.06)
	shake_tween.tween_property(btn, "rotation", 0.0, 0.06)
	await shake_tween.finished

	# ── 5. 解锁效果：变色 + scale bounce + 文字更新 ──
	var zone_idx: int = (next_idx - 1) / days_per_zone   # next_idx 1-based for days
	var safe_z: int = zone_idx % ZONE_CARD_COLORS.size()

	# 更新文字
	var ns: int = UserManager.level_stars.get("day%d" % new_day, 0)
	var star_map := ["☆☆☆", "★☆☆", "★★☆", "★★★"]
	btn.text = "Day %02d\n%s" % [new_day, star_map[ns]]
	btn.disabled = false

	# 更新样式颜色
	var style := StyleBoxFlat.new()
	style.bg_color = ZONE_CARD_COLORS[safe_z]
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.28, 0.18, 1.0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = style.bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Scale bounce
	btn.scale = Vector2(0.8, 0.8)
	var bounce := create_tween()
	bounce.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	bounce.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)

	await bounce.finished

	# 清除标记
	UserManager.newly_unlocked_day = 0
	SaveManager.save()
