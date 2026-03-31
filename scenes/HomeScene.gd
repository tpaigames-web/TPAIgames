extends Control

const PROFILE_PANEL  = preload("res://scenes/profile/ProfilePanel.tscn")
const LEVEL_UP_PANEL = preload("res://scenes/profile/LevelUpPanel.tscn")
const SETTINGS_PANEL = preload("res://scenes/settings/SettingsPanel.tscn")

# 标签索引常量
const TAB_SHOP     = 0
const TAB_ARSENAL  = 1
const TAB_BATTLE   = 2
const TAB_FACTORY  = 3
const TAB_CHESTS   = 4

# 各标签场景路径
const TAB_SCENES: Array[String] = [
	"res://scenes/tabs/ShopTab.tscn",
	"res://scenes/tabs/FragmentShopTab.tscn",
	"res://scenes/tabs/BattleTab.tscn",
	"res://scenes/tabs/TowersTab.tscn",
	"res://scenes/tabs/ChestsTab.tscn",
]

var current_tab: int = TAB_BATTLE
var tab_nodes: Array = [null, null, null, null, null]

@onready var player_name_label: Label  = $TopBar/ProfileArea/PlayerInfo/NameLabel
@onready var level_label: Label        = $TopBar/ProfileArea/PlayerInfo/LevelLabel
@onready var gold_label: Label         = $TopBar/CurrencyWrapper/CurrencyRow/GoldItem/GoldLabel
@onready var gems_label: Label         = $TopBar/CurrencyWrapper/CurrencyRow/GemItem/GemsLabel
@onready var vouchers_label: Label     = $TopBar/CurrencyWrapper/CurrencyRow/VoucherItem/VouchersLabel
var side_buttons: VBoxContainer = null
var left_side_buttons: VBoxContainer = null
var level_pass_side_btn: Button = null
@onready var tab_container: Control    = $TabContainer
@onready var coming_soon_dialog: AcceptDialog = $ComingSoonDialog

# ── 定时广告奖励（真实时钟，每30分钟一个周期）──────────────────────────
@onready var _ad_offer_btn: Control = $AdOfferBtn
@export var ad_slot_seconds: int = 1800   ## 广告周期（秒），1800=30分钟，测试可改60
var _ad_check_timer: float = 0.0          ## 检查间隔计时（每5秒检查一次，避免每帧检查）

# ── 开发工具（发布前删除）────────────────────────────────────────────
@onready var _dev_reset_btn:  Button = $DevResetBtn
@onready var _map_editor_btn: Button = $MapEditorBtn
var _dev_press_count: int = 0
var _dev_press_timer: float = 0.0

## 底部导航按钮（5个 TextureButton）
@onready var nav_buttons: Array = [
	$BottomNav/ButtonRow/ShopNavBtn,
	$BottomNav/ButtonRow/ArsenalNavBtn,
	$BottomNav/ButtonRow/BattleNavBtn,
	$BottomNav/ButtonRow/FactoryNavBtn,
	$BottomNav/ButtonRow/ChestNavBtn,
]

## 通知徽章
@onready var factory_badge: TextureRect = $BottomNav/ButtonRow/FactoryNavBtn/FactoryBadge
@onready var chest_badge: TextureRect = $BottomNav/ButtonRow/ChestNavBtn/ChestBadge

## 选中时按钮向上弹起的像素
@export var nav_raise_px: float = 30.0
## 通知检查计时
var _badge_timer: float = 0.0

func _ready() -> void:
	add_to_group("home_scene")
	_update_player_info()
	_connect_nav_buttons()
	_switch_tab(TAB_BATTLE)
	# 延迟一帧再刷新高亮，避免布局覆盖 position
	await get_tree().process_frame
	_update_nav_highlight()
	$TopBar/ProfileArea.gui_input.connect(_on_profile_area_input)
	# 左侧快捷按钮（签到 + 升级通行证）
	_setup_left_side_buttons()
	# 左上角设置按钮
	_setup_settings_button()
	# 金币/钻石/XP 变化时自动刷新顶栏显示
	UserManager.currency_changed.connect(_update_player_info)
	UserManager.level_changed.connect(_on_level_changed)
	# Lv. 标签点击 → 进入升级通行证
	level_label.mouse_filter = Control.MOUSE_FILTER_STOP
	level_label.gui_input.connect(_on_level_label_input)
	# 开发工具按钮（仅 debug 构建可见）
	_dev_reset_btn.visible = OS.is_debug_build()
	_dev_reset_btn.pressed.connect(_on_dev_reset_btn_pressed)
	_map_editor_btn.visible = OS.is_debug_build()
	_map_editor_btn.pressed.connect(_on_map_editor_btn_pressed)
	# 统一对话框字体大小
	coming_soon_dialog.get_label().add_theme_font_size_override("font_size", 28)
	coming_soon_dialog.get_ok_button().add_theme_font_size_override("font_size", 26)
	# 广告奖励按钮（真实时钟）
	$AdOfferBtn/HitArea.pressed.connect(_on_ad_offer_pressed)
	_check_ad_reward()   # 启动时立即检查
	_update_badges()     # 启动时立即检查通知
	# 月卡每日领取
	if UserManager.is_monthly_card_active():
		if UserManager.claim_monthly_card_daily():
			pass  # 静默领取（后续可加提示）
	# 每日签到弹窗
	call_deferred("_check_sign_in")
	# 后台预加载所有Tab（分帧加载，避免首次切换卡顿）
	_preload_all_tabs()


func _process(delta: float) -> void:
	# 开发工具连击计时
	if _dev_press_timer > 0.0:
		_dev_press_timer -= delta
		if _dev_press_timer <= 0.0:
			_dev_press_count = 0
	# 每5秒检查广告奖励（真实时钟）
	_ad_check_timer += delta
	if _ad_check_timer >= 5.0:
		_ad_check_timer = 0.0
		_check_ad_reward()
	# 每2秒检查通知徽章
	_badge_timer += delta
	if _badge_timer >= 2.0:
		_badge_timer = 0.0
		_update_badges()


## 检查是否有未领取的广告奖励（基于真实系统时间）
func _check_ad_reward() -> void:
	# 只在战斗标签显示广告奖励
	if current_tab != TAB_BATTLE:
		_ad_offer_btn.visible = false
		return
	var now: int = int(Time.get_unix_time_from_system())
	var current_slot: int = (now / ad_slot_seconds) * ad_slot_seconds
	var has_reward: bool = UserManager.last_ad_reward_time < current_slot
	if has_reward and not _ad_offer_btn.visible:
		_show_ad_offer()
	elif not has_reward and _ad_offer_btn.visible:
		_ad_offer_btn.visible = false


func _update_player_info() -> void:
	player_name_label.text = UserManager.player_name
	level_label.text = "Lv. %d" % UserManager.level
	gold_label.text = _abbrev_number(UserManager.gold)
	gems_label.text = _abbrev_number(UserManager.gems)
	vouchers_label.text = _abbrev_number(UserManager.vouchers)


## 数字缩写：5位数以上缩写
## 9999 以下原样，10000+ → 10K，1000000+ → 1.0M，10000000+ → 9999999+
static func _abbrev_number(value: int) -> String:
	if value < 10000:
		return str(value)
	elif value < 1000000:
		return "%dK" % (value / 1000)
	elif value < 10000000:
		return "%.1fM" % (value / 1000000.0)
	else:
		return "9999999+"

## 按需加载标签（首次切换到某标签时才实例化，避免首帧卡顿）
func _ensure_tab_loaded(index: int) -> void:
	if tab_nodes[index] != null:
		return
	if index < 0 or index >= TAB_SCENES.size():
		return
	var scene_path = TAB_SCENES[index]
	var scene_res = load(scene_path)
	if scene_res == null:
		push_error("HomeScene: 无法加载标签场景 " + scene_path)
		return
	var instance = scene_res.instantiate()
	instance.visible = false
	tab_container.add_child(instance)
	if instance is Control:
		instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_nodes[index] = instance

## ── 启动加载画面 + 预加载所有Tab ─────────────────────────────────────
const COVER_TEX = preload("res://assets/sprites/ui/Cover/cover.png")

var _loading_overlay: CanvasLayer = null
var _loading_bar: ProgressBar = null
var _loading_detail: Label = null

## 加载步骤定义：[tab_index 或负数(自定义), 显示文本]
const _LOAD_STEPS: Array = [
	[0, "加载商店..."],
	[1, "加载碎片商店..."],
	[-1, "加载炮台数据..."],
	[3, "加载兵工厂..."],
	[4, "加载宝箱..."],
	[-3, "加载设置与指南..."],
	[-2, "初始化完成"],
]

func _preload_all_tabs() -> void:
	_create_loading_overlay()
	await get_tree().process_frame  # 让遮罩先显示出来

	var total: int = _LOAD_STEPS.size()
	for step_idx in total:
		var step: Array = _LOAD_STEPS[step_idx]
		var tab_idx: int = step[0]
		var detail: String = step[1]

		# 更新进度
		if _loading_detail:
			_loading_detail.text = detail
		if _loading_bar:
			_loading_bar.value = float(step_idx) / float(total) * 100.0

		await get_tree().process_frame  # 让UI刷新一帧

		# 执行加载
		if tab_idx >= 0 and tab_nodes[tab_idx] == null:
			_ensure_tab_loaded(tab_idx)
			if tab_nodes[tab_idx] != null:
				tab_nodes[tab_idx].visible = false
				tab_nodes[tab_idx].process_mode = Node.PROCESS_MODE_DISABLED
		elif tab_idx == -1:
			# 预热炮台资源缓存
			TowerResourceRegistry.get_all_resources()
			TowerResourceRegistry.get_towers_by_rarity()
		elif tab_idx == -3:
			# 预加载设置面板的指南数据（敌人+升级+炮台，123+ .tres）
			SettingsPanel.preload_guide_data()

		await get_tree().process_frame

	# 加载完成 → 进度条满
	if _loading_bar:
		_loading_bar.value = 100.0
	if _loading_detail:
		_loading_detail.text = "加载完成！"
	await get_tree().process_frame

	# 淡出遮罩
	_fade_out_loading()


func _create_loading_overlay() -> void:
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 90  # 在大多数UI之上
	add_child(_loading_overlay)

	# 封面背景
	var bg := TextureRect.new()
	bg.texture = COVER_TEX
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_loading_overlay.add_child(bg)

	# 半透明黑色叠加（让文字更清晰）
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_overlay.add_child(dim)

	# 加载详情文字
	_loading_detail = Label.new()
	_loading_detail.text = "准备中..."
	_loading_detail.add_theme_font_size_override("font_size", 32)
	_loading_detail.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 0.9))
	_loading_detail.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_loading_detail.add_theme_constant_override("shadow_offset_x", 2)
	_loading_detail.add_theme_constant_override("shadow_offset_y", 2)
	_loading_detail.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_loading_detail.offset_top = -160.0
	_loading_detail.offset_bottom = -110.0
	_loading_detail.offset_left = 40.0
	_loading_detail.offset_right = -40.0
	_loading_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_overlay.add_child(_loading_detail)

	# 进度条
	_loading_bar = ProgressBar.new()
	_loading_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_loading_bar.offset_top = -100.0
	_loading_bar.offset_bottom = -60.0
	_loading_bar.offset_left = 60.0
	_loading_bar.offset_right = -60.0
	_loading_bar.min_value = 0
	_loading_bar.max_value = 100
	_loading_bar.value = 0
	_loading_bar.show_percentage = false
	_loading_overlay.add_child(_loading_bar)


func _fade_out_loading() -> void:
	if _loading_overlay == null:
		return
	# 创建一个覆盖全屏的 ColorRect 用于淡出
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_overlay.add_child(fade)

	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(_loading_overlay):
			_loading_overlay.queue_free()
			_loading_overlay = null
			_loading_bar = null
			_loading_detail = null
	)


func _connect_nav_buttons() -> void:
	for i in range(nav_buttons.size()):
		var btn: BaseButton = nav_buttons[i]
		btn.pressed.connect(_switch_tab.bind(i))



func _switch_tab(index: int) -> void:
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].visible = false
		tab_nodes[current_tab].process_mode = Node.PROCESS_MODE_DISABLED
	current_tab = index
	_ensure_tab_loaded(current_tab)
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].process_mode = Node.PROCESS_MODE_INHERIT
		tab_nodes[current_tab].visible = true

	# 战斗标签才显示个人信息、广告按钮、左侧快捷按钮（签到/月卡/升级）
	var is_battle := (index == TAB_BATTLE)
	$TopBar/ProfileArea.visible = is_battle
	if left_side_buttons and is_instance_valid(left_side_buttons):
		left_side_buttons.visible = is_battle
	if is_battle:
		_check_ad_reward()
	else:
		_ad_offer_btn.visible = false

	_update_nav_highlight()

func _update_nav_highlight() -> void:
	for i in range(nav_buttons.size()):
		var btn = nav_buttons[i]
		if i == current_tab:
			btn.position.y = -nav_raise_px  # 选中弹起
		else:
			btn.position.y = 0  # 复位

## 供各 Tab 子场景向上调用，弹出"功能开发中"对话框
func show_coming_soon() -> void:
	coming_soon_dialog.dialog_text = tr("UI_COMING_SOON")
	coming_soon_dialog.popup_centered()

## 显示指定解锁条件文字（BattleTab 关卡锁、TowersTab 等级锁等）
func show_locked(reason: String) -> void:
	coming_soon_dialog.dialog_text = reason
	coming_soon_dialog.popup_centered()

# ───── 个人资料面板 ─────

func _on_profile_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_profile_panel()

func _open_profile_panel() -> void:
	var panel = PROFILE_PANEL.instantiate()
	get_tree().root.add_child(panel)

## ProfilePanel 关闭时回调，刷新顶栏玩家信息
func refresh_player_info() -> void:
	_update_player_info()

## 升级时更新顶栏等级显示
func _on_level_changed(_new_level: int) -> void:
	_update_player_info()

## 点击顶栏 Lv. 标签 → 弹出升级通行证浮层
func _on_level_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_level_up_panel()

## 弹出升级通行证浮层（CanvasLayer，与 ProfilePanel 同款模式）
func _open_level_up_panel() -> void:
	var panel = LEVEL_UP_PANEL.instantiate()
	get_tree().root.add_child(panel)

func _open_level_pass() -> void:
	_open_level_up_panel()

# ── 开发重置（发布前删除）────────────────────────────────────────────

func _on_map_editor_btn_pressed() -> void:
	# 直接进入测试模式（教学关地图 + 全部炮台解锁 + 敌人召唤按钮）
	GameManager.test_mode = true
	SceneManager.go_with_loading("res://scenes/battle/BattleScene.tscn")

func _on_dev_reset_btn_pressed() -> void:
	_dev_press_count += 1
	_dev_press_timer = 0.0
	if _dev_press_count >= 5:
		_dev_press_count = 0
		UserManager.tutorial_completed = false
		UserManager.games_played = 0
		UserManager.games_won    = 0
		UserManager.gold         = 500
		UserManager.vouchers     = 0
		UserManager.xp           = 0
		SaveManager.save()
		get_tree().reload_current_scene()


# ═══════════════════════════════════════════════════════════════════════
# 定时广告奖励
# ═══════════════════════════════════════════════════════════════════════

func _show_ad_offer() -> void:
	_ad_offer_btn.visible = true
	# 入场动画
	_ad_offer_btn.modulate.a = 0.0
	var tw := _ad_offer_btn.create_tween()
	tw.tween_property(_ad_offer_btn, "modulate:a", 1.0, 0.3)


func _on_ad_offer_pressed() -> void:
	# 弹出奖励选择
	var dlg := ConfirmationDialog.new()
	dlg.title = tr("UI_FREE_REWARD_TITLE")
	dlg.dialog_text = tr("UI_FREE_REWARD_DESC")
	dlg.ok_button_text = tr("UI_FREE_REWARD_WATCH")
	dlg.cancel_button_text = tr("UI_DIALOG_CANCEL")
	dlg.get_label().add_theme_font_size_override("font_size", 26)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 24)
	dlg.get_cancel_button().add_theme_font_size_override("font_size", 24)

	dlg.confirmed.connect(func():
		dlg.queue_free()
		AdManager.show_rewarded_ad(_on_ad_reward_complete, _on_ad_reward_cancel)
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _on_ad_reward_complete() -> void:
	# 随机选择奖励类型
	var reward_type: int = randi() % 2   # 0=钻石, 1=碎片
	var msg: String = ""

	if reward_type == 0:
		# 30-50 钻石
		var amount: int = randi_range(30, 50)
		UserManager.gems += amount
		msg = tr("UI_REWARD_GEMS") % amount
	else:
		# 随机蓝/紫/橙品质炮台碎片
		var frag_amount: int = randi_range(3, 8)
		var tower_pools: Array = _get_fragment_tower_pool()
		if tower_pools.size() > 0:
			var tower_id: String = tower_pools[randi() % tower_pools.size()]
			var td = CollectionManager.get_tower_data(tower_id) if CollectionManager else null
			var tower_name: String = TowerResourceRegistry.tr_tower_name(td) if td else tower_id
			CollectionManager.add_fragments(tower_id, frag_amount)
			msg = tr("UI_REWARD_FRAGMENTS") % [tower_name, frag_amount]
		else:
			# fallback 给钻石
			var amount: int = randi_range(30, 50)
			UserManager.gems += amount
			msg = tr("UI_REWARD_GEMS") % amount

	SaveManager.save()
	_update_player_info()

	# 显示奖励结果
	var result_dlg := AcceptDialog.new()
	result_dlg.title = tr("UI_REWARD_TITLE")
	result_dlg.dialog_text = msg
	result_dlg.get_label().add_theme_font_size_override("font_size", 28)
	result_dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	get_tree().root.add_child(result_dlg)
	result_dlg.popup_centered()
	result_dlg.confirmed.connect(func(): result_dlg.queue_free())

	# 记录领取时间戳（真实时钟），按钮自动在下个周期再出现
	UserManager.last_ad_reward_time = int(Time.get_unix_time_from_system())
	_ad_offer_btn.visible = false


func _on_ad_reward_cancel() -> void:
	# 用户取消，按钮保留（不消失），下次点击可以再试
	pass


## 获取蓝/紫/橙品质的炮台ID池（用于碎片奖励）
func _get_fragment_tower_pool() -> Array:
	var pool: Array = []
	# 遍历所有炮台资源路径，筛选蓝(2)、紫(3)、橙(4) 品质
	for path in CollectionManager.TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			continue
		var tid = res.get("tower_id")
		var rar = res.get("rarity")
		var is_hero = res.get("is_hero")
		if tid and rar != null and int(rar) >= 2 and not is_hero:
			pool.append(str(tid))
	return pool


# ───── 通知徽章 ─────

func _update_badges() -> void:
	factory_badge.visible = _has_factory_notification()
	chest_badge.visible = _has_chest_notification()


## 兵工厂通知：有炮台可以用碎片解锁
func _has_factory_notification() -> bool:
	for res in TowerResourceRegistry.get_all_resources():
		var td := res as TowerCollectionData
		if td == null:
			continue
		var status: int = CollectionManager.get_tower_status(td.tower_id)
		var frags: int = CollectionManager.get_fragments(td.tower_id)
		# 可解锁
		if status == 1 and td.unlock_fragments > 0 and frags >= td.unlock_fragments:
			return true
		# 可升级（已解锁，碎片够下一级）
		if status == 2:
			var level: int = CollectionManager.get_tower_level(td.tower_id)
			if level < td.max_level and level >= 1:
				var idx: int = level - 1
				if idx < td.upgrade_fragments.size() and frags >= td.upgrade_fragments[idx]:
					return true
	return false


## 宝箱通知：有宝箱解锁完成 或 免费宝箱可领取
func _has_chest_notification() -> bool:
	if UserManager.is_free_wooden_chest_ready():
		return true
	for i in 4:
		if UserManager.is_chest_ready(i):
			return true
	return false


# ── 设置按钮 ─────────────────────────────────────────────────────────

func _setup_settings_button() -> void:
	var btn := TextureButton.new()
	btn.name = "SettingsBtn"
	btn.texture_normal = load("res://assets/sprites/ui/Setting.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = 0
	btn.position = Vector2(10, 10)
	btn.size = Vector2(80, 80)
	btn.pressed.connect(_open_settings)
	add_child(btn)


func _setup_left_side_buttons() -> void:
	const FLAG_SCENE = preload("res://scenes/components/UpgradeButton.tscn")

	left_side_buttons = VBoxContainer.new()
	left_side_buttons.position = Vector2(5, 420)
	left_side_buttons.add_theme_constant_override("separation", 5)
	add_child(left_side_buttons)

	# 签到按钮（Flag 样式）
	var sign_flag: Control = FLAG_SCENE.instantiate()
	var sign_label: Label = sign_flag.get_node("Label")
	sign_label.text = "📅 签到"
	if UserManager.can_sign_in_today():
		sign_flag.modulate = Color(1.0, 0.95, 0.7)
	else:
		sign_flag.modulate = Color(0.5, 0.5, 0.5)
	var sign_hit: Button = sign_flag.get_node("HitButton")
	sign_hit.pressed.connect(_show_sign_in_popup)
	left_side_buttons.add_child(sign_flag)

	# 月卡按钮（Flag 样式，仅激活时显示）
	if UserManager.is_monthly_card_active():
		var card_flag: Control = FLAG_SCENE.instantiate()
		var card_label: Label = card_flag.get_node("Label")
		var days_left: int = maxi(0, (UserManager.monthly_card_end_unix - int(Time.get_unix_time_from_system())) / 86400)
		card_label.text = "📅 %dd" % days_left
		card_label.add_theme_font_size_override("font_size", 26)
		if UserManager.last_monthly_claim_date != Time.get_date_string_from_system():
			card_flag.modulate = Color(1.0, 0.95, 0.7)  # 黄色高亮（可领取）
		else:
			card_flag.modulate = Color(0.4, 0.8, 0.4)  # 绿色（已领取）
		var card_hit: Button = card_flag.get_node("HitButton")
		card_hit.pressed.connect(_show_monthly_card_popup)
		left_side_buttons.add_child(card_flag)

	# 升级通行证按钮（Flag 样式）
	var pass_flag: Control = FLAG_SCENE.instantiate()
	var pass_label: Label = pass_flag.get_node("Label")
	pass_label.text = "⭐ 升级"
	var pass_hit: Button = pass_flag.get_node("HitButton")
	pass_hit.pressed.connect(_open_level_pass)
	left_side_buttons.add_child(pass_flag)


func _open_settings() -> void:
	var panel: SettingsPanel = SETTINGS_PANEL.instantiate()
	get_tree().root.add_child(panel)
	panel.open(false)


## ── 每日签到 ────────────────────────────────────────────────────────

func _check_sign_in() -> void:
	if not UserManager.can_sign_in_today():
		return
	_show_sign_in_popup()


func _show_sign_in_popup() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(800, 600)
	panel.position = Vector2(-400, -300)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "📅 每日签到"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# 连续签到天数
	var streak := Label.new()
	streak.text = "连续签到: %d 天" % UserManager.sign_in_streak
	streak.add_theme_font_size_override("font_size", 28)
	streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(streak)

	vbox.add_child(HSeparator.new())

	# 7天奖励网格
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	var reward_labels: Array[String] = [
		"Day 1\n🪙 200", "Day 2\n💎 10", "Day 3\n🧩 ×5",
		"Day 4\n🪙 300", "Day 5\n🎟️ ×1", "Day 6\n💎 20",
		"Day 7\n📦 铁宝箱",
	]

	for i in range(7):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(170, 80)
		var lbl := Label.new()
		lbl.text = reward_labels[i]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		if i < UserManager.sign_in_day:
			# 已领取
			lbl.modulate = Color(0.5, 0.5, 0.5)
			lbl.text += "\n✓"
		elif i == UserManager.sign_in_day:
			# 今日可领
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			lbl.modulate = Color(0.7, 0.7, 0.7)

		card.add_child(lbl)
		grid.add_child(card)

	# 签到按钮
	var sign_btn := Button.new()
	sign_btn.text = "✅ 签到领取"
	sign_btn.add_theme_font_size_override("font_size", 36)
	sign_btn.custom_minimum_size = Vector2(0, 70)
	sign_btn.pressed.connect(func():
		var reward: Dictionary = UserManager.do_sign_in()
		if not reward.is_empty():
			sign_btn.text = "✅ 已签到！"
			sign_btn.disabled = true
			_update_player_info()
			# 1.5 秒后关闭
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(overlay):
				overlay.queue_free()
	)
	vbox.add_child(sign_btn)

	# 关闭按钮
	var close := Button.new()
	close.text = "关闭"
	close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close)


## ── 月卡 ────────────────────────────────────────────────────────────

func _show_monthly_card_popup() -> void:
	var days_left: int = maxi(0, (UserManager.monthly_card_end_unix - int(Time.get_unix_time_from_system())) / 86400)
	var already_claimed: bool = UserManager.last_monthly_claim_date == Time.get_date_string_from_system()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 400)
	panel.position = Vector2(-350, -200)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "📅 月卡"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# 剩余天数
	var days_lbl := Label.new()
	days_lbl.text = "剩余 %d 天" % days_left
	days_lbl.add_theme_font_size_override("font_size", 32)
	days_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(days_lbl)

	# 每日奖励说明
	var desc := Label.new()
	desc.text = "每日领取 💎 30 钻石"
	desc.add_theme_font_size_override("font_size", 28)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# 领取按钮
	var claim_btn := Button.new()
	claim_btn.add_theme_font_size_override("font_size", 36)
	claim_btn.custom_minimum_size = Vector2(0, 70)
	if already_claimed:
		claim_btn.text = "✅ 今日已领取"
		claim_btn.disabled = true
		claim_btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		claim_btn.text = "💎 领取 30 钻石"
		claim_btn.modulate = Color(1.0, 0.9, 0.3)
		claim_btn.pressed.connect(func():
			if UserManager.claim_monthly_card_daily():
				claim_btn.text = "✅ 已领取！"
				claim_btn.disabled = true
				claim_btn.modulate = Color(0.6, 0.6, 0.6)
				_update_player_info()
				SaveManager.save()
		)
	vbox.add_child(claim_btn)

	# 关闭
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(close_btn)
