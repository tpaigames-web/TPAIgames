extends Control

## 稀有度名称和颜色（与 ChestOpening.gd 保持一致）
const RARITY_NAMES:  Array[String] = ["白", "绿", "蓝", "紫", "橙"]
const RARITY_COLORS: Array[Color]  = [
	Color(0.85, 0.85, 0.85),  # 白
	Color(0.2,  0.75, 0.2 ),  # 绿
	Color(0.2,  0.5,  0.95),  # 蓝
	Color(0.7,  0.2,  0.9 ),  # 紫
	Color(1.0,  0.55, 0.0 ),  # 橙
]

const CHEST_PATHS: Array[String] = [
	"res://data/chests/wooden_chest.tres",
	"res://data/chests/iron_chest.tres",
	"res://data/chests/golden_chest.tres",
]

var _pending_chest: ChestData = null

## 木宝箱限时免费
var _wooden_card  = null           # ChestCard 节点引用
var _wooden_data: ChestData = null # 木宝箱资源
var _ticker: Timer = null          # 每秒更新倒计时

@onready var buy_cards_row:   HBoxContainer    = $BuyCardsRow
@onready var info_panel:      PanelContainer   = $InfoPanel
@onready var info_title:      Label            = $InfoPanel/InfoVBox/InfoHeaderRow/InfoTitle
@onready var info_card_count: Label            = $InfoPanel/InfoVBox/InfoCardCount
@onready var info_rarity_grid: GridContainer   = $InfoPanel/InfoVBox/InfoRarityGrid
@onready var close_btn:       Button           = $InfoPanel/InfoVBox/InfoHeaderRow/CloseBtn
@onready var purchase_dialog: ConfirmationDialog = $PurchaseDialog

func _ready() -> void:
	_setup_chest_cards()
	info_panel.hide()
	close_btn.pressed.connect(func(): info_panel.hide())
	purchase_dialog.confirmed.connect(_on_purchase_confirmed)

	# 每秒更新木宝箱倒计时
	_ticker = Timer.new()
	_ticker.wait_time = 1.0
	_ticker.autostart = true
	_ticker.timeout.connect(_on_ticker_timeout)
	add_child(_ticker)
	_update_wooden_chest_ui()

func _setup_chest_cards() -> void:
	for i in CHEST_PATHS.size():
		var data: ChestData = load(CHEST_PATHS[i])
		if data == null:
			push_error("ChestsTab: 无法加载 " + CHEST_PATHS[i])
			continue
		var card = load("res://scenes/components/ChestCard.tscn").instantiate()
		buy_cards_row.add_child(card)
		card.setup(data)
		card.info_requested.connect(_show_info_panel)
		if i == 0:
			# 木宝箱：限时免费，单独处理购买信号
			_wooden_card = card
			_wooden_data = data
			card.purchase_requested.connect(_on_wooden_chest_requested)
		else:
			card.purchase_requested.connect(_show_purchase_dialog)

# ── 木宝箱限时免费逻辑 ────────────────────────────────────────────────

## 点击木宝箱时调用
func _on_wooden_chest_requested(_data: ChestData) -> void:
	if not UserManager.is_free_wooden_chest_ready():
		return   # 冷却中：沉默拒绝（price_label 已显示剩余时间）
	_pending_chest = _wooden_data
	purchase_dialog.dialog_text = "确认免费领取 木宝箱？"
	purchase_dialog.popup_centered()

## 每秒刷新木宝箱卡片的价格标签显示
func _update_wooden_chest_ui() -> void:
	if _wooden_card == null:
		return
	if UserManager.is_free_wooden_chest_ready():
		_wooden_card.price_label.text     = "✅ 免费领取"
		_wooden_card.price_label.modulate = Color(0.2, 1.0, 0.35)
	else:
		var secs: int = UserManager.get_free_wooden_chest_cooldown_remaining()
		var h: int    = secs / 3600
		var m: int    = (secs % 3600) / 60
		var s: int    = secs % 60
		_wooden_card.price_label.text     = "⏳ %02d:%02d:%02d" % [h, m, s]
		_wooden_card.price_label.modulate = Color(1.0, 0.75, 0.2)

func _on_ticker_timeout() -> void:
	_update_wooden_chest_ui()

## 切换到宝箱 Tab 时立即刷新（防止 ticker 未到时显示旧值）
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_wooden_chest_ui()

# ── 普通宝箱购买流程 ──────────────────────────────────────────────────

func _show_info_panel(data: ChestData) -> void:
	info_title.text = data.chest_name + " 内容"
	info_card_count.text = "开箱张数：%d 张" % data.card_count

	# 清除旧的概率行
	for child in info_rarity_grid.get_children():
		child.queue_free()

	# 计算各稀有度百分比
	var weights = [
		data.white_weight, data.green_weight, data.blue_weight,
		data.purple_weight, data.orange_weight
	]
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0:
		total = 1.0

	for i in weights.size():
		var pct: float = weights[i] / total * 100.0
		if pct <= 0.0:
			continue

		# 颜色方块 + 名称
		var name_label := Label.new()
		name_label.text = "● " + RARITY_NAMES[i]
		name_label.add_theme_color_override("font_color", RARITY_COLORS[i])
		name_label.add_theme_font_size_override("font_size", 26)
		info_rarity_grid.add_child(name_label)

		# 概率数值
		var pct_label := Label.new()
		pct_label.text = "%.1f %%" % pct
		pct_label.add_theme_font_size_override("font_size", 26)
		info_rarity_grid.add_child(pct_label)

	info_panel.show()

func _show_purchase_dialog(data: ChestData) -> void:
	_pending_chest = data
	if data.gem_purchase_cost == 0:
		purchase_dialog.dialog_text = "确认获取 %s（免费）？" % data.chest_name
	else:
		purchase_dialog.dialog_text = "确认购买 %s？\n花费 💎 %d 宝石" % [data.chest_name, data.gem_purchase_cost]
	purchase_dialog.popup_centered()

func _on_purchase_confirmed() -> void:
	if _pending_chest == null:
		return
	# 如果是木宝箱免费领取，记录时间戳并刷新 UI
	if _wooden_data != null and _pending_chest == _wooden_data:
		UserManager.claim_free_wooden_chest()
		_update_wooden_chest_ui()
		SaveManager.save()
	_launch_chest_opening(_pending_chest)
	_pending_chest = null

func _launch_chest_opening(data: ChestData) -> void:
	var opening_scene = load("res://scenes/chest_opening/ChestOpening.tscn")
	if opening_scene == null:
		push_error("ChestsTab: 无法加载 ChestOpening.tscn")
		return
	var opening = opening_scene.instantiate()
	opening.setup(data)
	# 添加到场景树根节点，作为 CanvasLayer 覆盖全屏
	get_tree().root.add_child(opening)
