extends Node

## 新手教学战斗场景控制器
## 负责 HUD 显示（HP、金币）、底部炮台面板、返回逻辑

# ── 所有炮台集合数据路径 ──────────────────────────────────────────────
## 拖拽放置阈值（像素）：按下卡片后须移动此距离才创建预览，防止误触放置
const DRAG_THRESHOLD: float = 40.0

# 炮台资源路径（集中定义于 TowerResourceRegistry Autoload）

# ── 节点引用 ──────────────────────────────────────────────────────────
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

## 底部面板 offset_top（负值，表示距底部的距离）
const PANEL_EXPANDED_TOP  = -490.0
## 升级面板展开时面板顶部位置（更高，留出更多升级内容空间）
const PANEL_UPGRADE_TOP   = -870.0

var _active_tab:         int      = 0   # 0=炮台  1=英雄  2=道具
var _last_selected_card: VBoxContainer = null
var _active_tower:       Area2D   = null
var _game_ended:         bool     = false   # 防止胜利/失败逻辑重复触发
var _game_started:       bool     = false   # 玩家点击播放后置 true
var _upgrade_panel_dirty: bool    = false   # 升级面板脏标记，延迟到下帧刷新
var _revive_used:        bool     = false   # 本局复活已用，限 1 次
var _revive_pending:     bool     = false   # 复活弹窗展示中，防止同帧多次弹出
var _revive_dlg: ConfirmationDialog = null  # 复活对话框引用（场景退出时清理）
var _pre_pause_speed:    float    = 1.0     # 升级面板打开前的游戏速度
var _is_paused:          bool     = false

## ── 新手教学引导 ────────────────────────────────────────────────────────────
var _tutorial_guide: TutorialGuide = null
var _tutorial_guide_done: bool = false

## ── 英雄炮台追踪 ────────────────────────────────────────────────────────────
var _hero_tower: Area2D = null   # 当前局英雄塔引用（null = 未放置）
var _hero_place_wave: int = -1   # 英雄放置时的波数（-1 = 未放置）
## 英雄面板节点引用（打开时有效，关闭时为 null）
var _hero_panel: Control = null
## 英雄地形数据
var _hero_terrain_data: HeroTerrainData = null
## 英雄升级面板引用
var _hero_upgrade_panel: Node = null
## 英雄升级完成信号（用于 await）
signal _hero_upgrade_done
## 英雄每隔多少波升级一次
const HERO_UPGRADE_INTERVAL: int = 5
## 英雄最大升级次数（Lv1→Lv5，共4次升级）
const HERO_MAX_UPGRADES: int = 4

## 计算英雄第 N 次升级的触发波次（基于放置波次）
func _get_hero_upgrade_wave(upgrade_index: int) -> int:
	return _hero_place_wave + HERO_UPGRADE_INTERVAL * (upgrade_index + 1)

## 判断当前波次是否触发英雄升级，返回升级次序（1-4），0=不触发
func _get_hero_upgrade_tier(wave_num: int) -> int:
	if _hero_place_wave < 0:
		return 0
	var waves_since: int = wave_num - _hero_place_wave
	if waves_since <= 0 or waves_since % HERO_UPGRADE_INTERVAL != 0:
		return 0
	var tier: int = waves_since / HERO_UPGRADE_INTERVAL
	if tier < 1 or tier > HERO_MAX_UPGRADES:
		return 0
	return tier

## 免费升级路径占用表
## key: "tower_id:path_idx"  →  占用该免费配额的炮台实例（Area2D）
## 若对应实例已失效（被售出），视为未占用
var _free_upgrade_owners: Dictionary = {}

## （card, data）对列表，用于刷新金币可购买状态
var _tower_card_entries: Array = []

## ── 消耗品道具 ───────────────────────────────────────────────────────
const ITEM_PATHS: Array[String] = [
	"res://data/items/gold_bag.tres",
	"res://data/items/landmine.tres",
]
var _item_card_entries: Array = []   # [{card, data, count_label}]

# ── 全局升级（波次强化）────────────────────────────────────────────────
## 升级池：从 data/global_upgrades/ 目录加载的所有 GlobalUpgradeData
var _upgrade_pool:    Array[GlobalUpgradeData] = []
## 本局已选中的升级列表（最多 8 条）
var _active_upgrades: Array[GlobalUpgradeData] = []
## 左上角已选升级图标容器（动态创建）
var _upgrade_icon_container: VBoxContainer = null
## 升级详情弹窗（点击图标后显示）
var _upgrade_popup: PanelContainer = null
var _upgrade_popup_overlay: ColorRect = null
## 当前活跃的全局升级选择面板（防止重复实例化）
var _global_upgrade_panel: Node = null
## 升级触发波次（波次开始时检查）
const UPGRADE_WAVE_TRIGGERS: Array[int] = [5, 10, 15, 20, 25, 30, 35]
## 升级数据目录路径
const UPGRADE_POOL_DIR := "res://data/global_upgrades/"

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	# 重置全局战斗状态
	if GameManager.test_mode:
		# 测试模式（从地图编辑器或开发入口进入）：充足金币和 HP
		GameManager.player_life = 999999
		GameManager.gold        = 999999
	else:
		GameManager.player_life = 100
		if GameManager.current_day == 0:
			# 教学关：1500 金币
			GameManager.gold = 1500
			wave_manager.use_tutorial_waves()
		else:
			# 按关卡日数设置难度和起始金币
			wave_manager.apply_day_difficulty(GameManager.current_day)
			if GameManager.current_day <= 3:
				GameManager.gold = 600
			elif GameManager.current_day <= 9:
				GameManager.gold = 500
			elif GameManager.current_day <= 12:
				GameManager.gold = 450
			else:
				GameManager.gold = 400

	# 连接 GameManager autoload 信号 → HUD
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)

	# 连接胜利信号（WaveManager 所有波次清场后发出）
	wave_manager.all_waves_cleared.connect(_on_victory)
	# 连接波次开始信号 → HUD 波次显示
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)

	# 连接按钮
	back_btn.pressed.connect(_on_back)
	speed_btn.pressed.connect(_on_speed_btn_pressed)
	pause_btn.pressed.connect(_on_pause_btn_pressed)
	pause_btn.disabled = true   # 游戏未开始时禁用暂停按钮

	# 监听炮台放置信号（取消选中 + 连接炮台点击）
	build_manager.tower_placed.connect(_on_tower_placed)

	# 连接底部 TabBar 按钮
	_tower_tab_btn.pressed.connect(func(): _set_tab(0))
	_hero_tab_btn.pressed.connect(func():  _set_tab(1))
	_item_tab_btn.pressed.connect(func():  _set_tab(2))

	# 构建炮台格子 + 道具卡片
	_build_tower_cards()
	_build_item_cards()
	_refresh_tab_state()

	# 初始 HUD 显示
	_refresh_displays()

	# ── 全局升级初始化 ──────────────────────────────────────────────────
	# 确保每局开始时升级状态干净（场景复用或热重载时防止残留）
	_active_upgrades.clear()
	_free_upgrade_owners.clear()
	_load_upgrade_pool()
	_build_upgrade_icons_hud()
	# 第 0 波：场景就绪后延迟一帧弹出升级面板
	# 教学模式下跳过 Wave 0 升级面板（由教学引导控制节奏）
	var _is_tutorial_mode: bool = GameManager.current_day == 0 and not UserManager.tutorial_completed and not GameManager.test_mode and not GameManager.resume_battle
	if not GameManager.resume_battle and not _is_tutorial_mode:
		call_deferred("_show_global_upgrade_panel", 0)

	# 自定义地图测试模式：若 GameManager.custom_map_path 非空则替换默认地图
	if GameManager.custom_map_path != "":
		_replace_map_with_custom(GameManager.custom_map_path)
		GameManager.custom_map_path = ""   # 用完即清空，避免下次重用

	# 战局恢复：存档存在时延迟一帧恢复（确保 TowerLayer 等节点已就绪）
	if GameManager.resume_battle:
		GameManager.resume_battle = false
		call_deferred("_resume_from_save")

	# ── 地图视觉动效 ──────────────────────────────────────────────────────
	_setup_map_vfx()

	# ── 连接地图中的可交互装饰品 ──────────────────────────────────────────
	_connect_interactable_decors()

	# ── 新手教学引导（首次进入教学关时启动）────────────────────────────────
	if _is_tutorial_mode:
		call_deferred("_start_tutorial_guide")

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
	# 教学 Step 6：弹出第 0 波的全局升级面板
	if _upgrade_pool.is_empty():
		push_warning("Tutorial: upgrade pool empty, reloading...")
		_load_upgrade_pool()
	call_deferred("_show_global_upgrade_panel", 0)

func _process(_delta: float) -> void:
	# 升级面板脏标记：延迟到本帧末尾统一刷新（避免高频 gold_changed 时每次都重建）
	if _upgrade_panel_dirty:
		_upgrade_panel_dirty = false
		if _upgrade_panel.visible and is_instance_valid(_active_tower):
			_populate_upgrade_panel(_active_tower)
	# （英雄面板无需每帧刷新，内容在 _show_hero_panel 中一次性设置）

# ── 自定义地图动态加载 ────────────────────────────────────────────────
func _replace_map_with_custom(path: String) -> void:
	# 测试模式：解锁所有炮台 + 充足金币/HP（999999）
	GameManager.test_mode   = true
	GameManager.gold        = 999999
	GameManager.player_life = 999999
	GameManager.gold_changed.emit(GameManager.gold)
	GameManager.hp_changed.emit(GameManager.player_life)

	# 0. 在移除旧地图前，先复制其 Path2D 曲线（教学关路线）
	var saved_curve: Curve2D = null
	var old_map := get_node_or_null("TutorialMap")
	if old_map:
		var old_path := old_map.get_node_or_null("Path2D")
		if old_path and old_path is Path2D and old_path.curve:
			saved_curve = old_path.curve.duplicate()
		# 必须先 remove_child 把节点从树中移除（立即释放名称），再 queue_free 延迟销毁
		# 若只调用 queue_free()，旧节点在当帧仍占用 "TutorialMap" 名称；
		# 之后 add_child(dyn) 时 Godot 会自动重命名为 "TutorialMap2"，
		# 导致 BuildManager 的 NodePath("../TutorialMap/TowerLayer") 解析失败
		remove_child(old_map)
		old_map.queue_free()

	# 2. 从 JSON 加载 MapData
	var md := MapData.load_from_file(path)
	if not md:
		push_error("BattleScene: 无法加载自定义地图 " + path)
		return

	# 3. 创建动态地图节点，命名为 "TutorialMap"
	#    BuildManager.tower_layer_path = "../TutorialMap/TowerLayer"
	#    WaveManager.map_path_node     = "../TutorialMap/Path2D"
	#    → 与现有 NodePath 导出值完全一致，无需修改两个 Manager
	var dyn := Node2D.new()
	dyn.name = "TutorialMap"
	add_child(dyn)
	move_child(dyn, 0)   # 放到最底层

	# 3a. 背景（地面颜色与编辑器一致）
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

	# 3b. Path2D — 敌人行进路线（WaveManager 通过 NodePath 取此节点）
	# 优先使用从教学关复制的曲线；无 saved_curve 时退回 md.waypoints
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

	# 3b-2. 路线视觉带（Line2D 宽线，90px 棕色，圆角接头）
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

	# 3c. TowerLayer — BuildManager 把炮台加到这里
	# z_index = 5：确保炮台渲染在地图路线/装饰物（z=0）上方，可被玩家看见
	var tower_layer      := Node2D.new()
	tower_layer.name     = "TowerLayer"
	tower_layer.z_index  = 5
	dyn.add_child(tower_layer)

	# 3d. EnemyLayer — z_index = 3，在装饰物之上、炮台之下
	var enemy_layer      := Node2D.new()
	enemy_layer.name     = "EnemyLayer"
	enemy_layer.z_index  = 3
	dyn.add_child(enemy_layer)

	# 3e. UILayer（炮台攻击范围圆圈等）
	var ui_layer         := CanvasLayer.new()
	ui_layer.name        = "UILayer"
	dyn.add_child(ui_layer)

	# 3f. PathArea — 标记路径区（阻止在路上放塔）
	# collision_layer = 1024：Tower.collision_mask(1282) 包含此位，可检测到
	# collision_mask  = 2   ：检测 Tower(collision_layer=2)，使 Tower 也能检测到本区域
	# add_to_group("path")  ：Tower._update_can_place() 通过 is_in_group("path") 判断不可放置
	# 从教学关曲线烘焙点自动生成矩形碰撞段（替代旧 path 对象方块）
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

	# 3g. BlockArea — 装饰物碰撞区（阻止在装饰上放塔；仅 block 组，interactable 由独立 Area2D 处理）
	# collision_layer = 256：Tower.collision_mask(1282) 包含此位，可检测到
	# collision_mask  = 2  ：检测 Tower(collision_layer=2)
	# add_to_group("block")：Tower._update_can_place() 通过 is_in_group("block") 判断不可放置
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

	# 3h. GoalArea — 终点区域
	var goal_area              := Area2D.new()
	goal_area.name             = "GoalArea"
	goal_area.position         = md.goal_pos
	var gcol                   := CollisionShape2D.new()
	var gsh                    := CircleShape2D.new()
	gsh.radius                 = 80.0
	gcol.shape                 = gsh
	goal_area.add_child(gcol)
	dyn.add_child(goal_area)

	# 3i. 对象视觉占位（彩色方块，同编辑器风格；path 组由 Line2D 替代，interactable 由独立 Area2D 处理）
	for d: Dictionary in md.objects:
		var grp_i: String = d.get("group", "block")
		if grp_i == "path" or grp_i == "interactable":
			continue   # path → 已有 Line2D；interactable → 下方单独处理
		var rect              := ColorRect.new()
		rect.size              = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		rect.position          = Vector2(
			d.get("x", 0.0) - d.get("w", 80.0) / 2.0,
			d.get("y", 0.0) - d.get("h", 80.0) / 2.0)
		rect.rotation_degrees  = d.get("rot", 0.0)
		rect.color             = Color(0.20, 0.40, 0.15)
		rect.mouse_filter      = Control.MOUSE_FILTER_IGNORE
		dyn.add_child(rect)

	# 3j. 可拆卸装饰品 — 每个单独 Area2D（保留塔楼阻挡 + 支持点击拆除）
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
		# 碰撞形状
		var col_ia := CollisionShape2D.new()
		var sh_ia  := RectangleShape2D.new()
		sh_ia.size = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		col_ia.shape = sh_ia
		ia.add_child(col_ia)
		# 视觉（黄绿色矩形）
		var rect_ia := ColorRect.new()
		rect_ia.size         = Vector2(d.get("w", 80.0), d.get("h", 80.0))
		rect_ia.position     = Vector2(-d.get("w", 80.0) / 2.0, -d.get("h", 80.0) / 2.0)
		rect_ia.color        = Color(0.35, 0.58, 0.22)
		rect_ia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ia.add_child(rect_ia)
		# 点击弹窗
		ia.input_event.connect(func(_vp, event, _idx):
			if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
				_on_interactable_clicked(ia)
		)
		dyn.add_child(ia)

	# 测试模式：重建炮台列表（显示全部炮台 + 敌人刷新按钮）；立即释放避免重复卡片
	while tower_hbox.get_child_count() > 0:
		var child = tower_hbox.get_child(0)
		tower_hbox.remove_child(child)
		child.free()
	_tower_card_entries.clear()
	_build_tower_cards()
	_refresh_tab_state()

## 扫描地图中所有 InteractableDecor 节点并连接点击信号
func _setup_map_vfx() -> void:
	var map_node: Node = $TutorialMap
	if not map_node:
		return

	# ── 飘落粒子（树叶/花瓣）──
	if SettingsManager.particles_enabled:
		var particles := GPUParticles2D.new()
		particles.name = "FallingLeaves"
		particles.z_index = -5
		particles.amount = 15
		particles.lifetime = 5.0
		particles.process_material = _create_leaf_particle_material()
		# 发射区域覆盖地图上方
		particles.visibility_rect = Rect2(-600, -200, 1800, 2200)
		particles.position = Vector2(540, 0)   # 地图中间上方
		map_node.add_child(particles)


func _create_leaf_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	# 发射区域：水平长条（地图宽度）
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(540, 10, 0)   # 1080px 宽
	# 方向：向下 + 微向右（模拟风）
	mat.direction = Vector3(0.3, 1.0, 0)
	mat.spread = 15.0
	# 速度
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	# 重力
	mat.gravity = Vector3(5, 20, 0)
	# 大小
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	# 颜色：绿色叶子渐变
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0.7, 0.2, 0.8))
	gradient.set_color(1, Color(0.5, 0.6, 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = gradient
	mat.color_ramp = gt
	# 旋转（叶子翻转）
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	# 水平偏移（风吹摆动）
	mat.tangential_accel_min = -10.0
	mat.tangential_accel_max = 10.0
	return mat


func _connect_interactable_decors() -> void:
	for node in get_tree().get_nodes_in_group("interactable_decor"):
		if node is InteractableDecor:
			node.clicked.connect(_on_decor_clicked)

## InteractableDecor 点击处理（读取每个装饰品的价格和名称）
func _on_decor_clicked(decor: InteractableDecor) -> void:
	if not is_instance_valid(decor):
		return
	var cost: int = decor.remove_cost
	var dname: String = decor.display_name
	var dlg := ConfirmationDialog.new()
	dlg.title              = "拆除装饰"
	dlg.dialog_text        = "拆除 %s？\n花费 %d 🪙" % [dname, cost]
	dlg.ok_button_text     = "确认拆除"
	dlg.cancel_button_text = "取消"
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

## 旧系统：可拆卸装饰品点击拆除弹窗（花费 500 金币，兼容 MapData JSON）
func _on_interactable_clicked(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	var dlg := ConfirmationDialog.new()
	dlg.title              = "拆除装饰"
	dlg.dialog_text        = "花费 500 🪙 拆除此装饰物？"
	dlg.ok_button_text     = "确认拆除"
	dlg.cancel_button_text = "取消"
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

# ── 消耗品道具 ────────────────────────────────────────────────────────

func _build_item_cards() -> void:
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

		item_hbox.add_child(card)
		_item_card_entries.append({"card": card, "data": data, "count_label": count_lbl, "use_btn": use_btn})
	_refresh_item_cards()

func _refresh_item_cards() -> void:
	for entry in _item_card_entries:
		var data: ItemData = entry.data
		var count_lbl: Label = entry.count_label
		var use_btn: Button = entry.use_btn
		var count: int = UserManager.get_item_count(data.item_id)
		if count > 0:
			count_lbl.text = "库存: %d" % count
			use_btn.text = "使用"
			use_btn.disabled = false
		elif UserManager.gems >= data.gem_cost:
			count_lbl.text = "无库存"
			use_btn.text = "💎 %d 购买" % data.gem_cost
			use_btn.disabled = false
		else:
			count_lbl.text = "无库存"
			use_btn.text = "📺 看广告"
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
				_refresh_item_cards(),
			func(): pass
		)

func _show_item_purchase_confirm(data: ItemData) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "购买道具"
	dlg.dialog_text = "购买 %s %s？\n花费 💎 %d（当前 💎 %d）" % [
		data.emoji, data.display_name, data.gem_cost, UserManager.gems]
	dlg.ok_button_text = "确认购买"
	dlg.cancel_button_text = "取消"
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if UserManager.spend_gems(data.gem_cost):
			SaveManager.save()
			_start_item_drag(data)
		else:
			_refresh_item_cards()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

## ── 道具拖拽放置（通用） ──────────────────────────────────────────────
var _item_preview: Node2D = null
var _item_drag_data: ItemData = null
var _item_dragging: bool = false

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

	var map_node := get_node_or_null("TutorialMap")
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

	var map_node := get_node_or_null("TutorialMap")
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
	var panel_top: float = get_viewport().get_visible_rect().size.y + bottom_panel.offset_top
	if screen_pos.y >= panel_top:
		# 放回库存
		UserManager.add_item(_item_drag_data.item_id, 1)
		SaveManager.save()
		_refresh_item_cards()
		return

	# 在地图区域 → 使用道具
	match _item_drag_data.effect_type:
		"gold_boost":
			GameManager.add_gold(int(_item_drag_data.effect_value))
			_refresh_item_cards()
		"landmine":
			var map_node := get_node_or_null("TutorialMap")
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
					_refresh_item_cards()
					return
				_spawn_active_mine(snap_pos, _item_drag_data)
			else:
				UserManager.add_item(_item_drag_data.item_id, 1)
				SaveManager.save()
			_refresh_item_cards()

func _spawn_active_mine(mine_pos: Vector2, data: ItemData) -> void:
	var map_node := get_node_or_null("TutorialMap")
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


# ── 播放 / 倍速按钮 ───────────────────────────────────────────────────
func _on_speed_btn_pressed() -> void:
	if not _game_started:
		# 第一次点击：启动游戏，使用设置中的默认速度
		_game_started = true
		var def_spd: int = clampi(SettingsManager.default_speed, 1, 3)
		Engine.time_scale = float(def_spd)
		wave_manager.start()
		speed_btn.text = "%d×" % def_spd
		pause_btn.disabled = false
		# 通知教学引导
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
		# 暂停时自动存档（游戏已开始且至少到达第1波）
		if _game_started and wave_manager.current_wave >= 1:
			_save_battle()
	else:
		Engine.time_scale = _pre_pause_speed if _pre_pause_speed > 0.0 else 1.0
		pause_btn.text = "⏸"

# ── 构建炮台格子（测试模式：显示全部；正常模式：只显示已解锁）───────
## 教学关可用炮台（仅这 4 个）
const TUTORIAL_TOWERS: Array[String] = ["scarecrow", "water_pipe", "beehive", "farmer"]

func _build_tower_cards() -> void:
	_tower_card_entries.clear()
	for path in TowerResourceRegistry.TOWER_RESOURCE_PATHS:
		var data: Resource = load(path)
		if data == null:
			continue
		# 教学关只显示指定的 4 个炮台
		if GameManager.current_day == 0 and not GameManager.test_mode:
			if data.tower_id not in TUTORIAL_TOWERS:
				continue
		# 测试模式下显示所有炮台，否则只显示已解锁（status=2）的
		elif not GameManager.test_mode and CollectionManager.get_tower_status(data.tower_id) != 2:
			continue
		var card: VBoxContainer = _make_tower_card(data)
		tower_hbox.add_child(card)
		_tower_card_entries.append({card = card, data = data})
	_refresh_card_affordability()
	# 测试模式：在炮台列表末尾追加敌人刷新按钮
	if GameManager.test_mode:
		_append_enemy_spawn_buttons()

## 生成单个炮台格子（VBoxContainer）
func _make_tower_card(data: Resource) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(100, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 图片区（5:7 比例 = 100×140）──
	var img := Panel.new()
	img.custom_minimum_size = Vector2(100, 140)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_tex: Texture2D = data.icon_texture if data.icon_texture else data.collection_texture if data.collection_texture else null
	if card_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = card_tex
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.add_child(tex_rect)
	else:
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
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# ── 攻击类型 ──
	var atk_lbl := Label.new()
	var atk_names: Array[String] = ["地面", "空中", "全部"]
	var atk_colors: Array[Color] = [Color(0.6, 0.4, 0.2), Color(0.3, 0.7, 1.0), Color(0.2, 1.0, 0.4)]
	var atk_idx: int = clampi(data.attack_type, 0, 2)
	atk_lbl.text = atk_names[atk_idx]
	atk_lbl.add_theme_font_size_override("font_size", 18)
	atk_lbl.add_theme_color_override("font_color", atk_colors[atk_idx])
	atk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(atk_lbl)

	# ── 放置费用 ──
	var cost_lbl := Label.new()
	cost_lbl.text = "🪙 %d" % data.placement_cost
	cost_lbl.add_theme_font_size_override("font_size", 22)
	cost_lbl.name = "CostLbl"
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cost_lbl)

	# ── 拖拽放置（须移动超过阈值才创建预览，防止误触）──────────────
	var cap: Resource = data
	card.gui_input.connect(func(e: InputEvent) -> void:
		# ── 鼠标 ──────────────────────────────────────────────────────
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var _disc := _get_cost_discount_for(cap.tower_id)
				var _cost := int(cap.placement_cost * (1.0 - _disc))
				if GameManager.gold < _cost:
					return   # 金币不足，不响应
				build_manager.select_tower(cap)
				_highlight_selected_card(card)
				card.set_meta("press_pos", e.global_position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", _cost)   # 锁定费用，拖拽触发时传给 BuildManager
			else:
				if card.get_meta("dragging", false):
					build_manager.release_drag()
				else:
					build_manager.cancel_selection()
					_highlight_selected_card(null)
				card.set_meta("dragging", false)

		elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pp: Vector2 = card.get_meta("press_pos", e.global_position)
			if not card.get_meta("dragging", false):
				if e.global_position.distance_to(pp) >= DRAG_THRESHOLD:
					card.set_meta("dragging", true)
					build_manager.start_drag_at(e.global_position, card.get_meta("locked_cost", -1))
			else:
				build_manager.move_preview_to(e.global_position)

		# ── 触屏 ──────────────────────────────────────────────────────
		elif e is InputEventScreenTouch:
			if e.pressed:
				var _disc := _get_cost_discount_for(cap.tower_id)
				var _cost := int(cap.placement_cost * (1.0 - _disc))
				if GameManager.gold < _cost:
					return
				build_manager.select_tower(cap)
				_highlight_selected_card(card)
				card.set_meta("press_pos", e.position)
				card.set_meta("dragging", false)
				card.set_meta("locked_cost", _cost)
			else:
				if card.get_meta("dragging", false):
					build_manager.release_drag()
				else:
					build_manager.cancel_selection()
					_highlight_selected_card(null)
				card.set_meta("dragging", false)

		elif e is InputEventScreenDrag:
			var pp: Vector2 = card.get_meta("press_pos", e.position)
			if not card.get_meta("dragging", false):
				if e.position.distance_to(pp) >= DRAG_THRESHOLD:
					card.set_meta("dragging", true)
					# 用 get_mouse_position 获取正确的视口坐标（e.position 可能是物理坐标）
					var vp_pos: Vector2 = get_viewport().get_mouse_position()
					build_manager.start_drag_at(vp_pos, card.get_meta("locked_cost", -1))
			else:
				var vp_pos: Vector2 = get_viewport().get_mouse_position()
				build_manager.move_preview_to(vp_pos)
	)

	return card

# ── 高亮选中格子 ──────────────────────────────────────────────────────
func _highlight_selected_card(card: VBoxContainer) -> void:
	if _last_selected_card and is_instance_valid(_last_selected_card):
		_last_selected_card.modulate = Color(1, 1, 1, 1)
	_last_selected_card = card
	if is_instance_valid(card):
		card.modulate = Color(0.5, 1.0, 0.5, 1.0)

# ── 金币可购买性刷新 ──────────────────────────────────────────────────
func _refresh_card_affordability() -> void:
	var gold: int = GameManager.gold
	for entry in _tower_card_entries:
		var disc := _get_cost_discount_for(entry.data.tower_id)
		var cost := int(entry.data.placement_cost * (1.0 - disc))
		var ok: bool = gold >= cost
		# 英雄已在场时锁住英雄卡片
		var entry_td := entry.data as TowerCollectionData
		if entry_td and entry_td.is_hero and is_instance_valid(_hero_tower):
			ok = false
		entry.card.modulate = Color(1, 1, 1, 1) if ok else Color(0.5, 0.5, 0.5, 1)

## 计算指定炮台当前费用折扣（汇总所有已激活的 COST_REDUCTION 升级）
func _get_cost_discount_for(tower_id: String) -> float:
	var disc := 0.0
	for upg_raw in _active_upgrades:
		var upg := upg_raw as GlobalUpgradeData
		if upg == null: continue
		if upg.upgrade_type != GlobalUpgradeData.UpgradeType.COST_REDUCTION: continue
		if upg.stat_type != GlobalUpgradeData.StatType.COST: continue
		if upg.target_tower_id == "" or upg.target_tower_id == tower_id:
			disc += upg.stat_bonus
	return clamp(disc, 0.0, 0.9)


## 刷新所有炮台卡片上的费用文字（激活费用折扣升级后调用）
func _refresh_card_costs() -> void:
	for entry in _tower_card_entries:
		var cost_lbl := entry.card.get_node_or_null("CostLbl") as Label
		if cost_lbl == null: continue
		var disc := _get_cost_discount_for(entry.data.tower_id)
		var orig: int = entry.data.placement_cost
		if disc > 0.001:
			var final_cost: int = int(orig * (1.0 - disc))
			cost_lbl.text = "🪙 %d→%d" % [orig, final_cost]
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			cost_lbl.text = "🪙 %d" % orig
			cost_lbl.remove_theme_color_override("font_color")
	_refresh_card_affordability()


# ── 底部 Tab 切换（炮台 / 英雄 / 道具）──────────────────────────────
func _set_tab(tab: int) -> void:
	_active_tab = tab
	_apply_tab_filter()

func _apply_tab_filter() -> void:
	# 切换底部面板背景（美术已含高亮标签）
	_panel_bg_tower.visible = (_active_tab == 0)
	_panel_bg_hero.visible  = (_active_tab == 1)
	_panel_bg_item.visible  = (_active_tab == 2)
	# 切换 TowerScroll / ItemScroll 可见性
	tower_scroll.visible = _active_tab != 2
	item_scroll.visible  = _active_tab == 2
	for entry in _tower_card_entries:
		var d := entry.data as TowerCollectionData
		var is_hero_card: bool = d != null and d.is_hero
		match _active_tab:
			0: entry.card.visible = not is_hero_card   # 炮台：仅非英雄
			1: entry.card.visible = is_hero_card       # 英雄：仅英雄
			2: entry.card.visible = false              # 道具
	# 道具标签页：刷新库存显示
	if _active_tab == 2:
		_refresh_item_cards()

## 根据英雄卡片是否存在来启用/禁用英雄 Tab，并更新锁标志文字
func _refresh_tab_state() -> void:
	var has_hero := false
	for entry in _tower_card_entries:
		var d := entry.data as TowerCollectionData
		if d != null and d.is_hero:
			has_hero = true
			break
	_hero_tab_btn.disabled = not has_hero
	_hero_tab_btn.text = "英雄" if has_hero else "英雄 🔒"
	_apply_tab_filter()


# ── 炮台放置回调 ─────────────────────────────────────────────────────
func _on_tower_placed(tower: Area2D) -> void:
	# 取消卡片高亮
	if _last_selected_card and is_instance_valid(_last_selected_card):
		_last_selected_card.modulate = Color(1, 1, 1, 1)
	_last_selected_card = null
	# 连接炮台点击信号，支持升级面板
	tower.tower_tapped.connect(_on_tower_tapped)
	tower.stat_wave_placed = wave_manager.current_wave if _game_started else 0
	tower.stat_total_spent = tower.tower_data.placement_cost if tower.tower_data else 0
	# 英雄炮台记录
	var placed_td := tower.tower_data as TowerCollectionData
	if placed_td and placed_td.is_hero:
		_hero_tower = tower
		_hero_place_wave = wave_manager.current_wave
		build_manager.set_hero_placed(true)
		# 加载英雄地形数据
		var terrain_path: String = "res://data/heroes/%s_terrain.tres" % ("afu" if placed_td.tower_id == "hero_farmer" else "guardian")
		_hero_terrain_data = load(terrain_path) as HeroTerrainData
		_refresh_card_affordability()   # 灰掉英雄卡片
	# 新塔放置后应用已选中的全局升级（新塔可能触发羁绊条件，需刷新全场）
	_apply_upgrades_to_all_towers()
	# 通知教学引导
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_tower_placed(tower)

# ── 升级面板 ─────────────────────────────────────────────────────────
func _on_tower_tapped(tower: Area2D) -> void:
	# 通知教学引导
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_tower_tapped()
	var td := tower.tower_data as TowerCollectionData
	if td and td.is_hero:
		_show_hero_panel(tower)
	else:
		# 铁网损坏时点击触发维修
		if tower.get("_ability") and tower._ability.has_method("start_repair"):
			if tower._ability.get("_state") == 1:   # State.BROKEN = 1
				tower._ability.start_repair()
		_show_upgrade_panel(tower)

func _show_upgrade_panel(tower: Area2D) -> void:
	# 关闭旧炮台的范围显示
	if is_instance_valid(_active_tower) and _active_tower != tower:
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = tower
	tower_scroll.visible = false
	item_scroll.visible  = false
	_populate_upgrade_panel(tower)
	_upgrade_panel.visible = true
	# 面板上移，为升级内容提供更大空间
	bottom_panel.offset_top = PANEL_UPGRADE_TOP
	_upgrade_panel.offset_bottom = -PANEL_UPGRADE_TOP
	# 显示炮台攻击范围圆（点击后高亮）
	tower.show_range = true
	tower.queue_redraw()

## 售出确认弹窗
func _show_sell_confirm(tower: Area2D, sell_val: int, is_hero: bool) -> void:
	if not is_instance_valid(tower):
		return
	# 半透明遮罩 + 居中弹窗
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(overlay)

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
			_hero_tower = null
			_hero_terrain_data = null
			build_manager.set_hero_placed(false)
			_refresh_card_affordability()
			_hide_hero_panel()
		else:
			_hide_upgrade_panel()
			if tower.tower_data and (tower.tower_data as TowerCollectionData).is_hero:
				_hero_tower = null
				build_manager.set_hero_placed(false)
				_refresh_card_affordability()
		for key in _free_upgrade_owners.keys():
			if _free_upgrade_owners[key] == tower:
				_free_upgrade_owners.erase(key)
		tower.queue_free()
	)
	btn_row.add_child(confirm_btn)


func _hide_upgrade_panel() -> void:
	if is_instance_valid(_active_tower):
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = null
	_upgrade_panel.visible = false
	# 恢复面板位置和内容区高度
	bottom_panel.offset_top = PANEL_EXPANDED_TOP
	_upgrade_panel.offset_bottom = 360.0
	_apply_tab_filter()

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
	back.pressed.connect(_hide_upgrade_panel)
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

## 浮动升级文字提示（英雄升级时显示）
func _show_float_text(msg: String, pos: Vector2) -> void:
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

# ─── 英雄炮台面板（BTD6 风格）─────────────────────────────────────────────

func _show_hero_panel(tower: Area2D) -> void:
	_hide_hero_panel()   # 先关闭旧面板
	# 关闭旧炮台的范围显示
	if is_instance_valid(_active_tower) and _active_tower != tower:
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = tower

	tower_scroll.visible = false
	item_scroll.visible  = false
	tower.show_range = true
	tower.queue_redraw()

	# 确保地形数据已加载
	var data := tower.tower_data as TowerCollectionData
	if _hero_terrain_data == null and data:
		var terrain_file: String = "afu" if data.tower_id == "hero_farmer" else "guardian"
		_hero_terrain_data = load("res://data/heroes/%s_terrain.tres" % terrain_file) as HeroTerrainData

	# 复用普通炮台升级面板区域（立即移除旧子节点，避免 find_child 命中旧节点）
	for c in _upgrade_vbox.get_children():
		_upgrade_vbox.remove_child(c)
		c.queue_free()
	_upgrade_panel.visible = true
	bottom_panel.offset_top = PANEL_UPGRADE_TOP
	_upgrade_panel.offset_bottom = -PANEL_UPGRADE_TOP
	_hero_panel = _upgrade_panel   # 标记英雄面板已打开

	var vbox := _upgrade_vbox

	# ── 标题行（返回 + 名称 + 售出）────────────────────────────────────────
	var header := HBoxContainer.new()

	var back_b := Button.new()
	back_b.text = "← 返回"
	back_b.add_theme_font_size_override("font_size", 28)
	back_b.pressed.connect(_hide_hero_panel)
	header.add_child(back_b)

	var title := Label.new()
	title.text = "%s %s  英雄" % [data.tower_emoji if data else "🗿", data.display_name if data else "英雄"]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	header.add_child(title)

	var sell_b := Button.new()
	sell_b.text = "🔥 售出"
	sell_b.add_theme_font_size_override("font_size", 24)
	sell_b.pressed.connect(func():
		_show_sell_confirm(tower, 0, true)
	)
	header.add_child(sell_b)
	vbox.add_child(header)

	# ── 分隔线 ────────────────────────────────────────────────────────
	vbox.add_child(HSeparator.new())

	# ── 读取硬编码数据 ────────────────────────────────────────────────
	var tid: String = data.tower_id if data else ""
	var info: Dictionary = HERO_TERRAIN_INFO.get(tid, {})
	var lv: int = tower.hero_chosen_upgrades.size() + 1
	var t_name: String = info.get("terrain_name", "地形") as String
	var base_effect: String = info.get("base_desc", "") as String
	var upgrades_arr: Array = info.get("upgrades", []) as Array

	# ── 地形信息 + 等级 ────────────────────────────────────────────────
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

	# ── 初始技能（Lv1 基础效果）────────────────────────────────────────
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

	# ── 已选升级技能 ────────────────────────────────────────────────
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
	var first_upg_wave: int = _get_hero_upgrade_wave(0)
	upgrade_list.text = "\n".join(lines) if lines.size() > 0 else "（第 %d 波解锁）" % first_upg_wave
	upgrade_list.add_theme_font_size_override("font_size", 24)
	upgrade_list.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	upgrade_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(upgrade_list)

	vbox.add_child(HSeparator.new())

	# ── 下次升级提示 ────────────────────────────────────────────────
	var next_lbl := Label.new()
	var upgrades_done: int = tower.hero_chosen_upgrades.size()
	if upgrades_done >= HERO_MAX_UPGRADES:
		next_lbl.text = "✨ 满级"
	else:
		var next_wave: int = _get_hero_upgrade_wave(upgrades_done)
		var current_wave: int = wave_manager.current_wave if wave_manager else 0
		var waves_left: int = maxi(next_wave - current_wave, 0)
		next_lbl.text = "⏳ 下次升级: 第 %d 波（还需 %d 波）" % [next_wave, waves_left]
	next_lbl.add_theme_font_size_override("font_size", 24)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	vbox.add_child(next_lbl)

func _hide_hero_panel() -> void:
	if is_instance_valid(_active_tower):
		_active_tower.show_range = false
		_active_tower.queue_redraw()
	_active_tower = null
	# 清空 _upgrade_vbox 内容（不删除 _upgrade_panel 本身）
	for c in _upgrade_vbox.get_children():
		c.queue_free()
	_hero_panel = null
	_upgrade_panel.visible = false
	bottom_panel.offset_top = PANEL_EXPANDED_TOP
	_upgrade_panel.offset_bottom = 360.0
	_apply_tab_filter()

## 英雄地形名称/基础效果/升级数据（硬编码，避免 .tres 加载失败）
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

## BTD6 风格升级路线战局锁定规则：
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
	_apply_upgrades_to_all_towers()
	_populate_upgrade_panel(tower)
	# 通知教学引导单塔升级完成
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_single_upgrade_chosen()

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

# ── HUD 更新 ──────────────────────────────────────────────────────────
func _on_hp_changed(new_hp: int) -> void:
	hp_label.text = "%d" % new_hp
	if new_hp <= 0:
		if not _revive_used and not _game_ended and not _revive_pending:
			_revive_pending = true
			_offer_revive()      # 弹出复活广告提示（首次 HP 归零）
		elif not _game_ended and not _revive_pending:
			_on_game_over()      # 已复活过 → 直接游戏结束

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "%d" % new_gold
	_refresh_card_affordability()
	# 升级面板已打开时，标记脏位，延迟到 _process 统一刷新（避免高频重建）
	if _upgrade_panel.visible and is_instance_valid(_active_tower):
		_upgrade_panel_dirty = true

func _on_wave_started(wave_num: int) -> void:
	var wave_name: String = wave_manager.get_wave_name(wave_num)
	if wave_manager.is_endless:
		wave_label.text = "♾️ 波次 %d" % wave_num
	else:
		wave_label.text = "波次 %d/%d" % [wave_num, wave_manager.wave_data.size()]
	# 波次开始视觉提示
	_show_wave_banner(wave_num)
	# 通知教学引导波次事件
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_wave_started(wave_num)
	# 指定波次开始前弹出全局升级选择（教学模式下由教学引导控制，跳过自动触发）
	var _is_tut: bool = is_instance_valid(_tutorial_guide) and not _tutorial_guide_done
	if not _is_tut and wave_num in UPGRADE_WAVE_TRIGGERS:
		_show_global_upgrade_panel(wave_num)
		# 通知教学引导全局升级面板弹出
		if is_instance_valid(_tutorial_guide) and _tutorial_guide.has_method("notify_global_upgrade_shown"):
			_tutorial_guide.notify_global_upgrade_shown()
	# 英雄地形升级：放置后每5波触发（若该波没有全局升级，则直接弹出）
	if is_instance_valid(_hero_tower) and not _is_tut:
		var hero_tier: int = _get_hero_upgrade_tier(wave_num)
		if hero_tier > 0 and _hero_tower.hero_chosen_upgrades.size() < hero_tier:
			if not (wave_num in UPGRADE_WAVE_TRIGGERS):
				# 该波没有全局升级面板，直接弹英雄升级
				_show_hero_upgrade_panel(wave_num, hero_tier)
			# 若有全局升级，英雄升级会在 _on_global_upgrade_chosen 中链式弹出

func _on_wave_cleared(wave_num: int) -> void:
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_wave_cleared(wave_num)

func _refresh_displays() -> void:
	hp_label.text   = "%d" % GameManager.player_life
	gold_label.text = "%d" % GameManager.gold
	gem_label.text  = "%d" % UserManager.gems

# ── 返回主界面 ────────────────────────────────────────────────────────
var _settings_panel_ref: SettingsPanel = null
var _info_dialog: AcceptDialog = null

func _on_back() -> void:
	if _game_ended:
		return
	if is_instance_valid(_settings_panel_ref):
		return
	_open_settings_panel()


func _do_exit(save: bool) -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	if is_instance_valid(_revive_dlg):
		_revive_dlg.queue_free()
		_revive_dlg = null
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


# ═══════════════════════════════════════════════════════════════════════
# 设置面板（使用统一 SettingsPanel 场景）
# ═══════════════════════════════════════════════════════════════════════
const SETTINGS_PANEL_SCENE = preload("res://scenes/settings/SettingsPanel.tscn")

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
		var mode_str: String = "挑战模式" if info.get("challenge_mode", false) else "普通模式"
		var confirm := AcceptDialog.new()
		confirm.process_mode = Node.PROCESS_MODE_ALWAYS
		confirm.dialog_text = "将覆盖 Day%d %s 的保存记录，确定？" % [day_num, mode_str]
		confirm.ok_button_text = "确定"
		confirm.add_cancel_button("取消")
		confirm.confirmed.connect(func(): confirm.queue_free(); _do_exit(true))
		confirm.canceled.connect(func(): confirm.queue_free())
		$HUD.add_child(confirm)
		confirm.popup_centered()
	else:
		_do_exit(true)


func _on_exit_no_save() -> void:
	var confirm := AcceptDialog.new()
	confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm.dialog_text = "退出当前游戏？\n当前游戏进度不会被保留"
	confirm.ok_button_text = "确定"
	confirm.add_cancel_button("取消")
	confirm.confirmed.connect(func(): confirm.queue_free(); _do_exit_keep_save())
	confirm.canceled.connect(func(): confirm.queue_free())
	$HUD.add_child(confirm)
	confirm.popup_centered()


## 退出但保留之前的存档（不保存当前进度，也不清除旧存档）
func _do_exit_keep_save() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	if is_instance_valid(_revive_dlg):
		_revive_dlg.queue_free()
		_revive_dlg = null
	GameManager.test_mode      = false
	GameManager.challenge_mode = false
	_disconnect_signals()
	UserManager.tutorial_completed = true
	# 不清除存档，也不保存当前进度 — 保留之前的存档记录
	SaveManager.save()
	SettingsManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")



# ── 测试模式：敌人刷新按钮 ────────────────────────────────────────────
func _append_enemy_spawn_buttons() -> void:
	# 分隔标签
	var sep := Label.new()
	sep.text = "──🐾──"
	sep.add_theme_font_size_override("font_size", 22)
	sep.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.custom_minimum_size  = Vector2(60, 100)
	tower_hbox.add_child(sep)

	# 遍历 enemy_data_map，为每种敌人生成刷新按钮
	for etype: String in wave_manager.enemy_data_map.keys():
		var edata: Resource = wave_manager.enemy_data_map[etype]
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(80, 100)

		var btn := Button.new()
		var emoji: String = edata.display_emoji if edata.display_emoji != "" else "👾"
		btn.text = emoji
		btn.custom_minimum_size = Vector2(70, 60)
		btn.add_theme_font_size_override("font_size", 32)
		var cap := etype
		btn.pressed.connect(func():
			wave_manager.spawn_enemy(cap)
		)
		vbox.add_child(btn)

		var lbl := Label.new()
		lbl.text = edata.enemy_id if edata.enemy_id != "" else etype
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(80, 0)
		vbox.add_child(lbl)

		tower_hbox.add_child(vbox)

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

# ── 复活广告流程 ─────────────────────────────────────────────────────
## 第一次 HP 归零时调用：冻结游戏，弹出复活广告选项
func _offer_revive() -> void:
	Engine.time_scale = 0.0        # 冻结游戏（UI 仍可响应）
	var dlg := ConfirmationDialog.new()
	_revive_dlg = dlg
	dlg.title = "💔 农场快撑不住了！"
	dlg.dialog_text = "农场 HP 归零！\n观看广告可获得一次免费复活机会\n复活后恢复 50% 生命值"
	dlg.ok_button_text = "📺 观看广告复活"
	dlg.cancel_button_text = "放弃"
	dlg.confirmed.connect(func():
		_revive_dlg = null
		dlg.queue_free()
		AdManager.show_rewarded_ad(
			func(): _do_revive(),        # 广告完成 → 复活
			func(): _on_game_over()      # 广告跳过 → 正常结束
		)
	)
	dlg.canceled.connect(func():
		_revive_dlg = null
		dlg.queue_free()
		_on_game_over()
	)
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

## 执行复活：恢复 50 HP，重置速度，更新 HUD
func _do_revive() -> void:
	_revive_pending = false   # 复活成功，解除挂起标志，允许后续 HP 归零正常触发
	_revive_used = true
	GameManager.player_life = 50
	GameManager.hp_changed.emit(50)    # 更新 HUD 血量显示
	Engine.time_scale = 1.0             # 恢复 1× 速度
	speed_btn.text = "1×"              # 按钮状态与 1× 速度一致

# ── 游戏结束（HP 归零）────────────────────────────────────────────────
func _on_game_over() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	GameManager.challenge_mode = false
	_disconnect_signals()
	UserManager.games_played += 1
	UserManager.tutorial_completed = true
	# 无限模式记录最高波数
	var endless_line := ""
	if wave_manager.is_endless:
		var day_key := "day%d" % GameManager.current_day
		var best: int = UserManager.best_endless_wave.get(day_key, 0)
		var reached: int = wave_manager.current_wave
		if reached > best:
			UserManager.best_endless_wave[day_key] = reached
		endless_line = "\n🏆 无限模式到达: 第 %d 波（最高: %d）" % [reached, max(reached, best)]
	# 失败不发金币：玩家看到带出金币数量但不实际获得
	SaveManager.clear_battle_save()   # 游戏结束，清除战局存档
	SaveManager.save()
	var carry_gold := GameManager.get_carry_out_gold()
	var dlg := AcceptDialog.new()
	dlg.title = "💀 游戏结束"
	dlg.dialog_text = "农场被攻破了！\n带出金币: %d 🪙\n下次再接再厉～" % carry_gold + endless_line
	dlg.confirmed.connect(func():
		GameManager.challenge_mode = false
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
	)
	dlg.canceled.connect(func():
		GameManager.challenge_mode = false
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
	)
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

# ── 胜利（所有波次清场）──────────────────────────────────────────────
func _on_victory() -> void:
	if _game_ended:
		return
	_game_ended = true
	Engine.time_scale = 1.0
	_disconnect_signals()
	UserManager.games_played += 1
	UserManager.games_won   += 1
	# 首次通过教学 → 标记解锁 Day 1 动画
	if not UserManager.tutorial_completed:
		UserManager.newly_unlocked_day = 1
	UserManager.tutorial_completed = true
	SaveManager.clear_battle_save()   # 胜利，清除战局存档
	# 金币和 XP 在广告选择后才发放（_finish_victory 中）
	# challenge_mode 不在此处清除——_finish_victory 需要读取此值写星级/宝箱 key
	# 清除由 _show_victory_result_dialog 的弹窗回调统一完成
	_offer_double_reward()

# ── 双倍奖励广告流程 ─────────────────────────────────────────────────
## 胜利后弹出双倍奖励广告选项
func _offer_double_reward() -> void:
	var carry_gold := GameManager.get_carry_out_gold()
	var dlg := ConfirmationDialog.new()
	dlg.title = "🎉 教学完成！"
	dlg.dialog_text = (
		"恭喜守护农场成功！\n\n"
		+ "普通奖励: %d 🪙 + 200 XP\n" % carry_gold
		+ "双倍奖励: %d 🪙 + 400 XP（看广告获得）" % min(carry_gold * 2, GameManager.MAX_CARRY_OUT_GOLD * 2)
	)
	dlg.ok_button_text = "📺 双倍奖励"
	dlg.cancel_button_text = "领取普通奖励"
	dlg.confirmed.connect(func():
		dlg.queue_free()
		AdManager.show_rewarded_ad(
			func(): _finish_victory(true),    # 广告完成 → 双倍
			func(): _finish_victory(false)    # 广告跳过 → 普通
		)
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
		_finish_victory(false)
	)
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

## 发放胜利奖励并显示结算界面
func _finish_victory(double_reward: bool) -> void:
	var carry_gold := GameManager.get_carry_out_gold()
	var xp_reward  := 200
	if double_reward:
		carry_gold = min(carry_gold * 2, GameManager.MAX_CARRY_OUT_GOLD * 2)
		xp_reward  = 400
	UserManager.add_xp(xp_reward)
	UserManager.add_gold(carry_gold)
	SaveManager.save()
	# 星级评价
	var hp := GameManager.player_life
	var stars: String
	var star_desc: String
	var star_count: int
	if hp >= 99:
		star_count = 3
		stars = "★★★"
		star_desc = "完美防守！"
	elif hp >= 50:
		star_count = 2
		stars = "★★☆"
		star_desc = "表现良好！"
	else:
		star_count = 1
		stars = "★☆☆"
		star_desc = "险险通关！"
	# 存储星级（按模式区分 key，只保留历史最高）
	var day_num: int = GameManager.current_day
	var star_key := "day%d_challenge" % day_num if GameManager.challenge_mode else "day%d" % day_num
	var prev_stars: int = UserManager.level_stars.get(star_key, 0)
	UserManager.level_stars[star_key] = max(prev_stars, star_count)

	# 普通模式通关后解锁下一关
	if not GameManager.challenge_mode and day_num == UserManager.max_unlocked_day and day_num < 15:
		UserManager.max_unlocked_day = day_num + 1
		UserManager.newly_unlocked_day = day_num + 1

	# 首胜宝箱奖励（每个模式仅首次触发，随机宝箱类型放入槽位）
	var chest_key := "day%d_challenge" % day_num if GameManager.challenge_mode else "day%d_normal" % day_num
	var chest_line := ""
	if not UserManager.level_chest_claimed.get(chest_key, false):
		UserManager.level_chest_claimed[chest_key] = true
		# 随机宝箱类型：木 70% / 铁 20% / 金 10%
		var rand := randf()
		var chest_type: int = 0 if rand < 0.70 else (1 if rand < 0.90 else 2)
		var chest_name: String = ["木宝箱", "铁宝箱", "金宝箱"][chest_type]
		var added := UserManager.add_chest_to_slot(chest_type)
		SaveManager.save()
		if added:
			chest_line = "\n🎁 获得 %s！前往宝箱标签解锁" % chest_name
			_show_victory_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, chest_line)
		else:
			# 槽位已满 → 询问是否看广告保留宝箱（广告回调中显示胜利弹窗）
			_offer_full_slots_ad(stars, star_desc, carry_gold, xp_reward, double_reward)
		return
	# 无宝箱奖励时直接显示胜利结算弹窗
	_show_victory_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, chest_line)

## 显示胜利结算弹窗
func _show_victory_result_dialog(stars: String, star_desc: String,
		carry_gold: int, xp_reward: int,
		double_reward: bool, chest_line: String) -> void:
	var bonus_text := " 🎊×2" if double_reward else ""
	var can_endless: bool = GameManager.current_day > 0 and not wave_manager.is_endless

	# 使用 ConfirmationDialog 提供无限模式选项
	var dlg: AcceptDialog
	if can_endless:
		var cdlg := ConfirmationDialog.new()
		cdlg.ok_button_text = "♾️ 继续无限模式"
		cdlg.cancel_button_text = "返回主界面"
		cdlg.confirmed.connect(func():
			cdlg.queue_free()
			_enter_endless_mode()
		)
		cdlg.canceled.connect(func():
			GameManager.challenge_mode = false
			get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
		)
		dlg = cdlg
	else:
		dlg = AcceptDialog.new()
		dlg.confirmed.connect(func():
			GameManager.challenge_mode = false
			get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
		)

	dlg.title = "🎉 胜利！"
	var endless_line := ""
	if wave_manager.is_endless:
		endless_line = "\n🏆 无限模式最高波数: %d" % wave_manager.current_wave
	dlg.dialog_text = (
		"恭喜守护农场成功！\n"
		+ "评分: %s %s\n" % [stars, star_desc]
		+ "带出金币: %d 🪙%s\n" % [carry_gold, bonus_text]
		+ "获得 %d XP 奖励%s" % [xp_reward, bonus_text]
		+ chest_line
		+ endless_line
	)
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	if dlg is ConfirmationDialog:
		dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()

## 进入无限模式
func _enter_endless_mode() -> void:
	_game_ended = false
	# 重新连接信号
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
	wave_manager.enter_endless()
	wave_label.text = "♾️ 波次 %d" % wave_manager.current_wave

## 槽位满时询问是否看广告保留宝箱（胜利弹窗通过回调显示）
func _offer_full_slots_ad(stars: String, star_desc: String,
		carry_gold: int, xp_reward: int, double_reward: bool) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "🎁 宝箱槽位已满"
	dlg.dialog_text = "4 个槽位都占满了！\n看广告可以保留这个宝箱\n等有空槽位时再领取"
	dlg.ok_button_text = "📺 看广告保留"
	dlg.cancel_button_text = "放弃"
	# 预定义两个回调，避免 GDScript 解析多行 lambda 逗号时产生缩进错误
	var on_ad_complete := func():
		var r := randf()
		UserManager.pending_chest_type = 0 if r < 0.70 else (1 if r < 0.90 else 2)
		SaveManager.save()
		_show_victory_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n✅ 宝箱已保留！下次有空槽位时前往宝箱标签领取")
	var on_ad_cancel := func():
		_show_victory_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n❌ 已丢失一个金宝箱！（清空槽位后可正常获得）")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		AdManager.show_rewarded_ad(on_ad_complete, on_ad_cancel)
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
		_show_victory_result_dialog(stars, star_desc, carry_gold, xp_reward, double_reward, "\n❌ 已丢失一个金宝箱！（清空槽位后可正常获得）")
	)
	add_child(dlg)
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 26)
	dlg.popup_centered()


# ============================================================
# 全局升级（波次强化）系统
# ============================================================

## 显式文件列表（DirAccess 在导出后无法遍历 res:// 打包目录）
const _UPGRADE_FILES: Array[String] = [
	"beehive_dmg_b.tres", "beehive_spd_o.tres", "beehive_spd_w.tres",
	"cannon_dmg_b.tres", "cannon_dmg_o.tres", "cannon_dmg_w.tres",
	"chili_dmg_b.tres", "chili_dmg_o.tres", "chili_dmg_w.tres",
	"cost_b.tres", "cost_w.tres",
	"farmer_dmg_b.tres", "farmer_dmg_o.tres", "farmer_dmg_w.tres", "farmer_spd_w.tres",
	"global_dmg_b.tres", "global_dmg_o.tres", "global_dmg_w.tres",
	"global_spd_b.tres", "global_spd_w.tres",
	"hero_dmg_b.tres", "hero_dmg_o.tres", "hero_dmg_w.tres",
	"mushroom_dmg_o.tres", "mushroom_dmg_w.tres", "mushroom_rng_w.tres",
	"scarecrow_rng_b.tres", "scarecrow_rng_w.tres",
	"seed_dmg_b.tres", "seed_rng_o.tres", "seed_rng_w.tres",
	"sun_rng_b.tres", "sun_spd_w.tres",
	"synergy_bloom.tres", "synergy_cannon_watch.tres", "synergy_chili_beehive.tres",
	"synergy_farm_core.tres", "synergy_farm_full.tres", "synergy_fire_wind.tres",
	"synergy_full_defense.tres", "synergy_hero_all.tres", "synergy_hive_farmer.tres",
	"synergy_nature.tres", "synergy_poison_net.tres", "synergy_scarecrow_wire.tres",
	"synergy_seed_mushroom.tres", "synergy_sun_farmer.tres", "synergy_trap_wire.tres",
	"synergy_triple_atk.tres", "synergy_watch_seed.tres", "synergy_water_gun.tres",
	"synergy_water_seed.tres", "synergy_wind_cannon.tres",
	"watch_dmg_b.tres", "watch_rng_o.tres", "watch_rng_w.tres",
	"water_dmg_w.tres", "water_spd_b.tres",
	"wind_dmg_b.tres", "wind_spd_w.tres",
]

## 加载所有 GlobalUpgradeData .tres 文件（自动扫描目录）
func _load_upgrade_pool() -> void:
	_upgrade_pool.clear()
	# 优先使用目录扫描，兼容硬编码列表
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
		# 回退到硬编码列表
		for fname2 in _UPGRADE_FILES:
			var res := load(UPGRADE_POOL_DIR + fname2) as GlobalUpgradeData
			if res:
				_upgrade_pool.append(res)
			else:
				push_warning("GlobalUpgrade: 无法加载 " + UPGRADE_POOL_DIR + fname2)
	if _upgrade_pool.is_empty():
		push_warning("GlobalUpgrade: 升级池为空！检查 data/global_upgrades/ 目录")


## 在 HUD CanvasLayer 上动态创建左上角升级图标容器
func _build_upgrade_icons_hud() -> void:
	_upgrade_icon_container = VBoxContainer.new()
	_upgrade_icon_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_upgrade_icon_container.position = Vector2(6, 110)
	_upgrade_icon_container.visible  = false
	$HUD.add_child(_upgrade_icon_container)

	# ── 点击空白处关闭弹窗的全屏透明遮罩 ──
	_upgrade_popup_overlay = ColorRect.new()
	_upgrade_popup_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upgrade_popup_overlay.color       = Color(0, 0, 0, 0)
	_upgrade_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_popup_overlay.visible     = false
	_upgrade_popup_overlay.gui_input.connect(_on_upgrade_popup_overlay_input)
	$HUD.add_child(_upgrade_popup_overlay)

	# ── 弹窗面板 ──
	_upgrade_popup = PanelContainer.new()
	_upgrade_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_upgrade_popup.custom_minimum_size = Vector2(320, 0)
	_upgrade_popup.visible = false
	$HUD.add_child(_upgrade_popup)

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
	close_btn.pressed.connect(_hide_upgrade_popup)
	vbox.add_child(close_btn)


## 弹出全局升级选择面板（暂停游戏）
func _show_global_upgrade_panel(wave_num: int) -> void:
	if not is_inside_tree():
		return   # 场景已退出（如点击返回），忽略延迟触发的升级弹窗
	# 关闭详情弹窗（防止阻塞升级面板交互）
	if is_instance_valid(_info_dialog):
		_info_dialog.queue_free()
		_info_dialog = null
	if _active_upgrades.size() >= 8:
		return
	if is_instance_valid(_global_upgrade_panel):
		return   # 面板已打开，防止重复实例化
	get_tree().paused = true
	var panel_scene := preload("res://scenes/global_upgrade/GlobalUpgradePanel.tscn")
	var panel := panel_scene.instantiate()
	_global_upgrade_panel = panel
	$HUD.add_child(panel)
	panel.upgrade_chosen.connect(_on_global_upgrade_chosen)
	panel.setup(_upgrade_pool, _active_upgrades, wave_num)


## 玩家确认选择某升级后回调
func _on_global_upgrade_chosen(upg: GlobalUpgradeData) -> void:
	_global_upgrade_panel = null
	_active_upgrades.append(upg)
	_apply_upgrades_to_all_towers()
	_update_upgrade_icons_hud()
	_refresh_card_costs()   # 更新炮台卡片的费用显示（若有费用折扣升级则实时更新）
	# 通知教学引导升级已选择
	if is_instance_valid(_tutorial_guide):
		_tutorial_guide.notify_upgrade_chosen()
	# 全局升级选完后，检查是否需要弹英雄地形升级（放置后每5波）
	var wn: int = wave_manager.current_wave
	var hero_tier: int = _get_hero_upgrade_tier(wn) if is_instance_valid(_hero_tower) else 0
	if hero_tier > 0 and _hero_tower.hero_chosen_upgrades.size() < hero_tier:
			# 保持暂停，弹出英雄升级面板
			_show_hero_upgrade_panel(wn, hero_tier)
			return
	get_tree().paused = false


## ── 英雄地形升级面板 ─────────────────────────────────────────────────────────

## 弹出英雄 2 选 1 升级面板
func _show_hero_upgrade_panel(wave_num: int, tier: int) -> void:
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

	# 构建 HeroUpgradeData
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
	$HUD.add_child(panel)
	panel.upgrade_chosen.connect(_on_hero_upgrade_chosen)
	panel.setup(td.tower_id, tier, current_lv, upg_data, td.display_name, td.tower_emoji)


## 英雄升级选择完成回调
func _on_hero_upgrade_chosen(hero_id: String, tier: int, choice: String) -> void:
	_hero_upgrade_panel = null
	if is_instance_valid(_hero_tower):
		_hero_tower.hero_chosen_upgrades.append(choice)
		_hero_tower.hero_level = _hero_tower.hero_chosen_upgrades.size() + 1
		# 通知能力脚本应用升级
		var ab = _hero_tower.get("_ability")
		if ab and ab.has_method("apply_upgrade"):
			ab.apply_upgrade(tier, choice)
		_hero_tower.queue_redraw()
		_show_float_text("🏰 英雄升级 Lv.%d！" % _hero_tower.hero_level, _hero_tower.global_position)
	get_tree().paused = false
	_hero_upgrade_done.emit()


## 将所有已选中升级应用到场上全部炮台（含预览塔，确保费用折扣/射程预览正确）
func _apply_upgrades_to_all_towers() -> void:
	var synergy := _check_synergies()
	for t in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(t):
			t.apply_global_buffs(_active_upgrades, synergy)


## 检查哪些羁绊升级的条件已满足（required_tower_ids 全部已放置）
func _check_synergies() -> Dictionary:
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


## 刷新左上角升级图标列表
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
		btn.pressed.connect(func(): _show_upgrade_popup(upg, btn))
		_upgrade_icon_container.add_child(btn)


## 显示升级详情弹窗（定位在图标右侧）
func _show_upgrade_popup(upg: GlobalUpgradeData, anchor: Control) -> void:
	if _upgrade_popup == null:
		return
	var vbox := _upgrade_popup.get_child(0) as VBoxContainer
	(vbox.get_node("EmojiLbl")  as Label).text = upg.icon_emoji
	(vbox.get_node("NameLbl")   as Label).text = upg.display_name
	(vbox.get_node("DescLbl")   as Label).text = upg.description

	# 稀有度颜色
	const COLORS := [Color(0.75,0.75,0.75), Color(0.20,0.45,0.90), Color(0.90,0.50,0.10), Color(0.85,0.15,0.15)]
	const NAMES  := ["普通", "稀有", "史诗", "传说"]
	var r: int = clampi(upg.rarity, 0, 2)
	var rarity_lbl := vbox.get_node("RarityLbl") as Label
	rarity_lbl.text = "【%s】" % NAMES[r]
	rarity_lbl.add_theme_color_override("font_color", COLORS[r])

	# 羁绊条件
	var cond_lbl := vbox.get_node("CondLbl") as Label
	if upg.required_tower_ids.size() > 0:
		cond_lbl.text    = "⚠ 需要：" + "、".join(upg.required_tower_ids)
		cond_lbl.visible = true
	else:
		cond_lbl.visible = false

	# 定位：图标右侧，防止超出屏幕右边
	var icon_pos: Vector2 = anchor.get_global_rect().position
	var popup_x: float = icon_pos.x + anchor.size.x + 4
	var popup_y: float = icon_pos.y
	# 等一帧让面板先算好尺寸再限制边界（此处先设初始位置）
	_upgrade_popup.position = Vector2(popup_x, popup_y)
	_upgrade_popup_overlay.visible = true
	_upgrade_popup.visible = true


## 隐藏升级详情弹窗
func _hide_upgrade_popup() -> void:
	if _upgrade_popup != null:
		_upgrade_popup.visible = false
	if _upgrade_popup_overlay != null:
		_upgrade_popup_overlay.visible = false


## 点击遮罩空白处关闭弹窗
func _on_upgrade_popup_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_upgrade_popup()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_hide_upgrade_popup()


# ─── 战局存档系统 ─────────────────────────────────────────────────────────────

## 保存当前战局状态（暂停时调用）
func _save_battle() -> void:
	# 收集已选的全局升级 ID
	var upgrade_ids: Array = []
	for upg_raw in _active_upgrades:
		var upg := upg_raw as GlobalUpgradeData
		if upg:
			upgrade_ids.append(upg.upgrade_id)

	# 收集炮台数据
	var towers_data: Array = []
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
			"hero_place_wave":  (_hero_place_wave if t == _hero_tower else 0),
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
		"total_waves":     wave_manager.wave_data.size() if wave_manager.wave_data else 40,
		"gold":            GameManager.gold,
		"life":            GameManager.player_life,
		"challenge_mode":  GameManager.challenge_mode,
		"revive_used":     _revive_used,
		"active_upgrades": upgrade_ids,
		"towers":          towers_data,
	})


## 从战局存档恢复（在 _ready() 末尾通过 call_deferred 调用）
func _resume_from_save() -> void:
	var sd: Dictionary = SaveManager.load_battle()
	if sd.is_empty():
		return

	# ── 恢复资源 ────────────────────────────────────────────────────────
	GameManager.gold        = sd.get("gold", 100)
	GameManager.player_life = sd.get("life", 20)
	_revive_used            = sd.get("revive_used", false)
	_refresh_displays()

	# ── 恢复全局升级（_upgrade_pool 已在 _ready() 中加载完毕）─────────
	var saved_ids: Array = sd.get("active_upgrades", [])
	_active_upgrades.clear()
	for upg_raw in _upgrade_pool:
		var upg := upg_raw as GlobalUpgradeData
		if upg and upg.upgrade_id in saved_ids:
			_active_upgrades.append(upg)

	# ── 恢复炮台 ────────────────────────────────────────────────────────
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
		if tower_layer:
			tower_layer.add_child(tower)
		else:
			add_child(tower)

		if tdata.get("is_hero", false):
			_hero_tower      = tower
			_hero_place_wave = tdata.get("hero_place_wave", 0)
			build_manager.set_hero_placed(true)
			# 恢复英雄升级选择
			var saved_choices: Array = tdata.get("hero_chosen_upgrades", [])
			for c in saved_choices:
				tower.hero_chosen_upgrades.append(str(c))
			tower.hero_level = tower.hero_chosen_upgrades.size() + 1
			# 加载地形数据并恢复升级效果（deferred 确保 ability 已初始化）
			var terrain_path: String = "res://data/heroes/%s_terrain.tres" % ("afu" if td_res.tower_id == "hero_farmer" else "guardian")
			_hero_terrain_data = load(terrain_path) as HeroTerrainData
			call_deferred("_restore_hero_upgrades", tower)
		tower.tower_tapped.connect(_on_tower_tapped)

	# ── 重新计算全局升级加成并刷新 HUD 图标 ──────────────────────────
	_apply_upgrades_to_all_towers()
	_update_upgrade_icons_hud()

	# ── 启动战局（直接从存档波次开始，跳过"开始"按钮）───────────────
	_game_started = true
	speed_btn.text = "1×"
	pause_btn.disabled = false
	wave_manager.start_from(sd.get("wave", 1))

## 恢复英雄地形升级效果（deferred 调用，确保 ability 已初始化）
func _restore_hero_upgrades(tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	var ab = tower.get("_ability")
	if ab and ab.has_method("restore_upgrades"):
		ab.restore_upgrades(tower.hero_chosen_upgrades)


# ── 波次切换视觉提示 ──────────────────────────────────────────────────
func _show_wave_banner(wave_num: int) -> void:
	var banner := Label.new()
	var total: int = wave_manager.wave_data.size() if wave_manager and wave_manager.wave_data else 40
	var w_name: String = wave_manager.get_wave_name(wave_num)
	if w_name != "":
		banner.text = "⚔ 第 %d 波 ⚔\n%s" % [wave_num, w_name]
	else:
		banner.text = "⚔ 第 %d 波 ⚔" % wave_num
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
	# 放到 HUD 上层
	$HUD.add_child(banner)
	# 用视口尺寸手动居中
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	banner.size = Vector2(600, 120)
	banner.position = Vector2((vp_size.x - 600) / 2.0, (vp_size.y - 120) / 2.0)
	# 动画：从上方滑入 → 停留 → 淡出上滑
	banner.modulate.a = 0.0
	banner.position.y -= 60
	var tw := banner.create_tween()
	tw.tween_property(banner, "position:y", banner.position.y + 60, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.0)  # 停留1秒
	tw.tween_property(banner, "position:y", banner.position.y - 20, 0.4)
	tw.parallel().tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(banner.queue_free)
