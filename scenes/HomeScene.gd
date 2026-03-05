extends Control

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
@onready var gold_label: Label         = $TopBar/CurrencyBar/GoldLabel
@onready var gems_label: Label         = $TopBar/CurrencyBar/GemsLabel
@onready var side_buttons: VBoxContainer       = $SideButtons
@onready var left_side_buttons: VBoxContainer  = $LeftSideButtons
@onready var level_pass_side_btn: Button       = $LeftSideButtons/LevelPassBtn
@onready var tab_container: Control    = $TabContainer
@onready var coming_soon_dialog: AcceptDialog = $ComingSoonDialog

## 底部导航按钮（5个，不含升级）
@onready var nav_buttons: Array = [
	$BottomNav/ButtonRow/ShopNavBtn,
	$BottomNav/ButtonRow/ArsenalNavBtn,
	$BottomNav/ButtonRow/BattleNavBtn,
	$BottomNav/ButtonRow/FactoryNavBtn,
	$BottomNav/ButtonRow/ChestNavBtn,
]

func _ready() -> void:
	add_to_group("home_scene")
	_update_player_info()
	_load_all_tabs()
	_connect_nav_buttons()
	_connect_side_buttons()
	_switch_tab(TAB_BATTLE)
	$TopBar/ProfileArea.gui_input.connect(_on_profile_area_input)
	# 金币/钻石/XP 变化时自动刷新顶栏显示
	UserManager.currency_changed.connect(_update_player_info)
	UserManager.level_changed.connect(_on_level_changed)
	# Lv. 标签点击 → 进入升级通行证
	level_label.mouse_filter = Control.MOUSE_FILTER_STOP
	level_label.gui_input.connect(_on_level_label_input)

func _update_player_info() -> void:
	player_name_label.text = UserManager.player_name
	level_label.text = "Lv. %d" % UserManager.level
	gold_label.text = str(UserManager.gold)
	gems_label.text = str(UserManager.gems)

func _load_all_tabs() -> void:
	for i in range(TAB_SCENES.size()):
		var scene_path = TAB_SCENES[i]
		var scene_res = load(scene_path)
		if scene_res == null:
			push_error("HomeScene: 无法加载标签场景 " + scene_path)
			continue
		var instance = scene_res.instantiate()
		instance.visible = false
		tab_container.add_child(instance)
		# 标签需要撑满 TabContainer 区域
		if instance is Control:
			instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tab_nodes[i] = instance

func _connect_nav_buttons() -> void:
	for i in range(nav_buttons.size()):
		var btn: Button = nav_buttons[i]
		btn.pressed.connect(_switch_tab.bind(i))

func _connect_side_buttons() -> void:
	$SideButtons/QuestButton.pressed.connect(show_coming_soon)
	$SideButtons/OfferButton.pressed.connect(show_coming_soon)
	$SideButtons/AdsButton.pressed.connect(show_coming_soon)
	level_pass_side_btn.pressed.connect(_open_level_up_panel)

func _switch_tab(index: int) -> void:
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].visible = false
	current_tab = index
	if tab_nodes[current_tab] != null:
		tab_nodes[current_tab].visible = true
	# 战斗标签才显示左右侧快捷按钮
	side_buttons.visible      = (current_tab == TAB_BATTLE)
	left_side_buttons.visible = (current_tab == TAB_BATTLE)
	_update_nav_highlight()

func _update_nav_highlight() -> void:
	for i in range(nav_buttons.size()):
		var btn: Button = nav_buttons[i]
		if i == current_tab:
			btn.modulate = Color(1.0, 0.85, 0.2, 1.0)  # 金色高亮
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

## 供各 Tab 子场景向上调用，弹出"功能开发中"对话框
func show_coming_soon() -> void:
	coming_soon_dialog.dialog_text = "功能开发中，敬请期待 🚧"
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
	var panel = load("res://scenes/profile/ProfilePanel.tscn").instantiate()
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
	var panel = load("res://scenes/profile/LevelUpPanel.tscn").instantiate()
	get_tree().root.add_child(panel)
