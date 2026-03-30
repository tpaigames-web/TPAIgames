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

func _connect_nav_buttons() -> void:
	for i in range(nav_buttons.size()):
		var btn: BaseButton = nav_buttons[i]
		btn.pressed.connect(_switch_tab.bind(i))



func _switch_tab(index: int) -> void:
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].visible = false
	current_tab = index
	_ensure_tab_loaded(current_tab)
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].visible = true

	# 战斗标签才显示个人信息和广告按钮
	var is_battle := (index == TAB_BATTLE)
	$TopBar/ProfileArea.visible = is_battle
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
	for path in CollectionManager.TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			continue
		var tid = res.get("tower_id")
		if tid == null:
			continue
		if CollectionManager.get_tower_status(str(tid)) == 1:
			var unlock_frags = res.get("unlock_fragments")
			if unlock_frags != null and CollectionManager.get_fragments(str(tid)) >= int(unlock_frags):
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
	left_side_buttons = VBoxContainer.new()
	left_side_buttons.position = Vector2(10, 350)
	left_side_buttons.add_theme_constant_override("separation", 10)
	add_child(left_side_buttons)

	# 签到按钮
	var sign_btn := Button.new()
	sign_btn.text = "📅\n签到"
	sign_btn.custom_minimum_size = Vector2(100, 90)
	sign_btn.add_theme_font_size_override("font_size", 24)
	if UserManager.can_sign_in_today():
		sign_btn.modulate = Color(1.0, 0.9, 0.3)  # 黄色高亮（可签到）
	else:
		sign_btn.modulate = Color(0.6, 0.6, 0.6)
	sign_btn.pressed.connect(_show_sign_in_popup)
	left_side_buttons.add_child(sign_btn)

	# 升级通行证按钮
	level_pass_side_btn = Button.new()
	level_pass_side_btn.text = "⭐\n升级"
	level_pass_side_btn.custom_minimum_size = Vector2(100, 90)
	level_pass_side_btn.add_theme_font_size_override("font_size", 24)
	level_pass_side_btn.pressed.connect(_open_level_pass)
	left_side_buttons.add_child(level_pass_side_btn)


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
