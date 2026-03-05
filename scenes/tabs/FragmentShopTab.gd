extends Control

## 军火库 ── 三段刷新碎片商店
## 6h / 每日 / 每周，各 3 张卡，gold 购买，倒计时自动刷新

# ── 炮台资源路径 ──────────────────────────────────────────────────────
const TOWER_RESOURCE_PATHS: Array[String] = [
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

# ── 稀有度颜色（index = rarity：0白 1绿 2蓝 3紫 4橙）─────────────────
const RARITY_COLORS: Array[Color] = [
	Color(0.88, 0.88, 0.88),
	Color(0.27, 0.68, 0.31),
	Color(0.13, 0.59, 0.95),
	Color(0.61, 0.15, 0.69),
	Color(1.00, 0.43, 0.00),
]

# ── 金币单片价格（按 rarity 索引）────────────────────────────────────
const FRAG_PRICE_GOLD: Array[int] = [50, 80, 200, 500, 1200]

# ── 区段常量 & 刷新间隔 ───────────────────────────────────────────────
const SEC_6H:   int = 0
const SEC_DAY:  int = 1
const SEC_WEEK: int = 2

const INTERVALS: Array[int] = [
	6 * 3600,
	24 * 3600,
	7 * 24 * 3600,
]

## 稀有度池 [[rarity, weight], ...]
const POOLS: Array = [
	# 6h：白 60%，绿 40%
	[[0, 60], [1, 40]],
	# 每日：白 45%，绿 30%，蓝 20%，紫 5%（极低）
	[[0, 45], [1, 30], [2, 20], [3, 5]],
	# 每周：蓝 50%，紫 35%，橙 15%（低）
	[[2, 50], [3, 35], [4, 15]],
]

# ── 节点引用 ──────────────────────────────────────────────────────────
@onready var cards_6h:    HBoxContainer = $ScrollContainer/MainVBox/Section6h/CardsMargin6h/Cards6h
@onready var cards_daily: HBoxContainer = $ScrollContainer/MainVBox/SectionDaily/CardsMarginD/CardsDaily
@onready var cards_weekly: HBoxContainer = $ScrollContainer/MainVBox/SectionWeekly/CardsMarginW/CardsWeekly

@onready var timer_6h:    Label = $ScrollContainer/MainVBox/Section6h/HeaderMargin6h/Section6hHeader/Section6hTimer
@onready var timer_daily: Label = $ScrollContainer/MainVBox/SectionDaily/HeaderMarginD/SectionDailyHeader/SectionDailyTimer
@onready var timer_weekly: Label = $ScrollContainer/MainVBox/SectionWeekly/HeaderMarginW/SectionWeeklyHeader/SectionWeeklyTimer

@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_msg:     Label     = $ConfirmOverlay/ConfirmCard/ContentVBox/ConfirmMsg
@onready var confirm_btn:     Button    = $ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/ConfirmBtn
@onready var cancel_btn:      Button    = $ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/CancelBtn

# ── 运行时状态 ───────────────────────────────────────────────────────
var _towers_by_rarity: Dictionary = {}
var _pending_action:   Callable   = Callable()
var _timer_tick:       float      = 0.0
var _last_period:      Array[int] = [-1, -1, -1]

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_tower_resources()
	_populate_all_sections()
	confirm_btn.pressed.connect(_on_confirm_yes)
	cancel_btn.pressed.connect(_on_confirm_no)
	confirm_overlay.gui_input.connect(_on_overlay_input)
	confirm_overlay.hide()
	_update_timers()

# ── 每帧：倒计时 + 自动刷新检测 ──────────────────────────────────────
func _process(delta: float) -> void:
	_timer_tick += delta
	if _timer_tick >= 1.0:
		_timer_tick -= 1.0
		_update_timers()
		_check_refresh()

# ── 炮台资源加载（幂等）──────────────────────────────────────────────
func _load_tower_resources() -> void:
	if not _towers_by_rarity.is_empty():
		return
	for path in TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			continue
		var rval = res.get("rarity")
		if rval == null:
			continue
		var r: int = int(rval)
		if r not in _towers_by_rarity:
			_towers_by_rarity[r] = []
		_towers_by_rarity[r].append(res)

# ── Period 计算（同 period 内出相同卡片）─────────────────────────────
func _get_period(section: int) -> int:
	return int(Time.get_unix_time_from_system()) / INTERVALS[section]

func _seconds_until_next(section: int) -> int:
	var now: int = int(Time.get_unix_time_from_system())
	return INTERVALS[section] - (now % INTERVALS[section])

# ── 填充全部区段 ──────────────────────────────────────────────────────
func _populate_all_sections() -> void:
	var containers: Array = [cards_6h, cards_daily, cards_weekly]
	for s: int in 3:
		var period: int = _get_period(s)
		_last_period[s] = period
		_populate_section(containers[s], s, period)

# ── 自动刷新检测 ──────────────────────────────────────────────────────
func _check_refresh() -> void:
	var containers: Array = [cards_6h, cards_daily, cards_weekly]
	for s: int in 3:
		var period: int = _get_period(s)
		if period != _last_period[s]:
			_last_period[s] = period
			for child in containers[s].get_children():
				child.queue_free()
			_populate_section(containers[s], s, period)

# ── 填充单个区段（period 作种子保证同周期内卡片一致）─────────────────
func _populate_section(hbox: HBoxContainer, section: int, period: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = period * 10 + section
	for _i: int in 3:
		var rarity: int    = _roll_rarity(section, rng)
		var tower: Resource = _pick_tower(rarity, rng)
		var qty: int        = rng.randi_range(1, 5)
		if tower != null:
			hbox.add_child(_make_frag_card(tower, qty, rarity, period * 10 + section))

# ── 加权抽取稀有度 ────────────────────────────────────────────────────
func _roll_rarity(section: int, rng: RandomNumberGenerator) -> int:
	var pool: Array = POOLS[section]
	var total: int = 0
	for pair in pool:
		total += pair[1]
	var roll: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	for pair in pool:
		acc += pair[1]
		if roll < acc:
			return pair[0]
	return pool[0][0]

# ── 随机选取该稀有度的炮台 ────────────────────────────────────────────
func _pick_tower(rarity: int, rng: RandomNumberGenerator) -> Resource:
	if rarity not in _towers_by_rarity or _towers_by_rarity[rarity].is_empty():
		return null
	var arr: Array = _towers_by_rarity[rarity]
	return arr[rng.randi() % arr.size()]

# ── 构建单张碎片卡（5:7 比例 ≈ 341×470）─────────────────────────────
func _make_frag_card(tower_res: Resource, qty: int, rarity: int, seed: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(0, 470)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   8)
	outer.add_theme_constant_override("margin_right",  8)
	outer.add_theme_constant_override("margin_top",    8)
	outer.add_theme_constant_override("margin_bottom", 8)
	card.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	outer.add_child(vbox)

	# 顶部稀有度彩条
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.color = RARITY_COLORS[rarity]
	vbox.add_child(bar)

	# 炮台 emoji（撑满剩余空间，居中）
	var emoji_lbl := Label.new()
	emoji_lbl.text = tower_res.tower_emoji
	emoji_lbl.add_theme_font_size_override("font_size", 80)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	vbox.add_child(emoji_lbl)

	# 炮台名称
	var name_lbl := Label.new()
	name_lbl.text = tower_res.display_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# 碎片数量（金色）
	var qty_lbl := Label.new()
	qty_lbl.text = "×%d 碎片" % qty
	qty_lbl.add_theme_font_size_override("font_size", 26)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(qty_lbl)

	# 购买按钮（金币总价）
	var price: int = FRAG_PRICE_GOLD[rarity] * qty
	var key: String = "%d_%s" % [seed, tower_res.tower_id]  # 唯一键：周期种子 + 炮台ID
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 26)
	vbox.add_child(btn)

	# 已购买（跨会话持久化检查）
	if UserManager.fragment_shop_purchases.has(key):
		btn.text     = "✓ 已购买"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		btn.text = "🪙 %d" % price

	var cap_tower := tower_res
	var cap_qty   := qty
	var cap_price := price
	var cap_key   := key
	btn.pressed.connect(func(): _on_buy_pressed(cap_tower, cap_qty, cap_price, btn, cap_key))

	return card

# ── 购买响应 ──────────────────────────────────────────────────────────
func _on_buy_pressed(tower_res: Resource, qty: int, price: int, btn: Button, key: String) -> void:
	if UserManager.gold < price:
		_show_alert(
			"金币不足\n\n需要 🪙%d\n当前 🪙%d" % [price, UserManager.gold]
		)
		return
	_show_confirm(
		"确认购买？\n\n%s  %s\n×%d 碎片\n\n🪙 %d 金币" % [
			tower_res.tower_emoji, tower_res.display_name, qty, price
		],
		func():
			if UserManager.spend_gold(price):
				CollectionManager.add_fragments(tower_res.tower_id, qty)
				UserManager.fragment_shop_purchases[key] = true
				SaveManager.save()
				btn.disabled = true
				btn.text     = "✓ 已购买"
				btn.modulate = Color(0.6, 0.6, 0.6)
	)

# ── 倒计时格式化 ──────────────────────────────────────────────────────
func _update_timers() -> void:
	timer_6h.text     = _format_countdown(_seconds_until_next(SEC_6H))
	timer_daily.text  = _format_countdown(_seconds_until_next(SEC_DAY))
	timer_weekly.text = _format_countdown(_seconds_until_next(SEC_WEEK))

func _format_countdown(seconds: int) -> String:
	if seconds >= 86400:
		var d: int = seconds / 86400
		var h: int = (seconds % 86400) / 3600
		var m: int = (seconds % 3600) / 60
		return "%dd %02d:%02d" % [d, h, m]
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	var s: int = seconds % 60
	return "%02d:%02d:%02d" % [h, m, s]

# ── 确认 / 提示弹窗（与 ShopTab 模式相同）───────────────────────────
func _show_confirm(message: String, on_confirm: Callable) -> void:
	_pending_action  = on_confirm
	confirm_msg.text = message
	cancel_btn.show()
	confirm_btn.text = "确认"
	confirm_overlay.show()

func _show_alert(message: String) -> void:
	_pending_action  = Callable()
	confirm_msg.text = message
	cancel_btn.hide()
	confirm_btn.text = "确定"
	confirm_overlay.show()

func _on_confirm_yes() -> void:
	confirm_overlay.hide()
	cancel_btn.show()
	confirm_btn.text = "确认"
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()

func _on_confirm_no() -> void:
	confirm_overlay.hide()
	cancel_btn.show()
	confirm_btn.text = "确认"
	_pending_action = Callable()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_confirm_no()
