extends Control

## ── 炮台资源路径（集中定义于 TowerResourceRegistry Autoload）──────────

## ── 礼包数据 ─────────────────────────────────────────────────────────
## price_type: "cash" | "gems"
## purchase_limit: 0=无限
## rewards: { "gold":int, "gems":int,
##            "frags_fixed":{"tower_id":count},
##            "frags_random":{"rarity":int,"count":int} }
## badge: 空字符串=不显示，"首次特惠" 等显示红色角标
const PACKAGES: Array = [
	# ─── 特别优惠 ───────────────────────────────────────────────────
	{
		"id":             "newbie_pack",
		"name":           "UI_SHOP_PKG_NEWBIE",
		"emoji":          "🎁",
		"desc":           "UI_SHOP_DESC_NEWBIE",
		"section":        "special",
		"price_type":     "cash",
		"price_rm":       3.88,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"gems": 500, "gold": 5000, "temp_tower_random": 3},
		"badge":          "UI_SHOP_BADGE_NEWBIE",
	},
	{
		"id":             "monthly_card",
		"name":           "UI_SHOP_PKG_MONTHLY",
		"emoji":          "📅",
		"desc":           "UI_SHOP_DESC_MONTHLY_300",
		"section":        "special",
		"price_type":     "cash",
		"price_rm":       8.88,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"monthly_card": true, "gems": 300},
		"badge":          "",
	},
	{
		"id":             "monthly_card_voucher",
		"name":           "UI_SHOP_PKG_MONTHLY_V",
		"emoji":          "📅",
		"desc":           "UI_SHOP_DESC_MONTHLY_V_300",
		"section":        "special",
		"price_type":     "voucher",
		"price_rm":       0.0,
		"price_gems":     0,
		"price_vouchers": 100,
		"purchase_limit": 0,
		"rewards":        {"monthly_card": true, "gems": 300},
		"badge":          "",
	},
	{
		"id":             "ad_free",
		"name":           "UI_SHOP_PKG_AD_FREE",
		"emoji":          "🚫",
		"desc":           "UI_SHOP_DESC_AD_FREE",
		"section":        "special",
		"price_type":     "cash",
		"price_rm":       12.88,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"ad_free": true},
		"badge":          "",
	},
	{
		"id":             "hero_afu_pack",
		"name":           "UI_SHOP_PKG_HERO_AFU",
		"emoji":          "👴",
		"desc":           "UI_SHOP_DESC_HERO_AFU",
		"section":        "special",
		"price_type":     "cash",
		"price_rm":       18.88,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"unlock_hero": "hero_farmer", "frags_fixed": {"hero_farmer": 60}, "temp_tower_random": 2},
		"badge":          "UI_SHOP_BADGE_HERO",
	},
	{
		"id":             "gems_medium",
		"name":           "UI_SHOP_PKG_GEMS_MED",
		"emoji":          "💎",
		"desc":           "UI_SHOP_DESC_GEMS_680",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       15.88,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"gems": 680, "temp_tower_random": 2},
		"badge":          "",
	},
	{
		"id":             "gems_large",
		"name":           "UI_SHOP_PKG_GEMS_LARGE",
		"emoji":          "💎",
		"desc":           "UI_SHOP_DESC_GEMS_1800",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       38.80,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"gems": 1800, "temp_tower_random": 5, "frags_random": {"rarity": 3, "count": 50}},
		"badge":          "UI_SHOP_BADGE_VALUE",
	},
	# ─── 碎片礼包（橙→紫→蓝→绿→白 排列）────────────────────────────
	{
		"id":             "orange_bundle",
		"name":           "UI_SHOP_PKG_ORANGE_BUNDLE",
		"emoji":          "🧡",
		"desc":           "UI_SHOP_DESC_ORANGE_BUNDLE",
		"section":        "frags",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     2500,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 4, "count": 50}},
		"badge":          "",
	},
	{
		"id":             "purple_bundle",
		"name":           "UI_SHOP_PKG_PURPLE_BUNDLE",
		"emoji":          "💜",
		"desc":           "UI_SHOP_DESC_PURPLE_BUNDLE",
		"section":        "frags",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     1500,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 3, "count": 80}},
		"badge":          "",
	},
	{
		"id":             "blue_bundle",
		"name":           "UI_SHOP_PKG_BLUE_BUNDLE",
		"emoji":          "💙",
		"desc":           "UI_SHOP_DESC_BLUE_BUNDLE",
		"section":        "frags",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     600,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 2, "count": 50}},
		"badge":          "",
	},
	{
		"id":             "green_bundle",
		"name":           "UI_SHOP_PKG_GREEN_BUNDLE",
		"emoji":          "💚",
		"desc":           "UI_SHOP_DESC_GREEN_BUNDLE",
		"section":        "frags",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     200,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 1, "count": 36}},
		"badge":          "",
	},
	{
		"id":             "white_bundle",
		"name":           "UI_SHOP_PKG_WHITE_BUNDLE",
		"emoji":          "🤍",
		"desc":           "UI_SHOP_DESC_WHITE_BUNDLE",
		"section":        "frags",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     80,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 0, "count": 50}},
		"badge":          "",
	},
	{
		"id":                     "hero_frag_farm_guardian",
		"name":                   "UI_SHOP_PKG_HERO_GUARDIAN",
		"emoji":                  "🗿",
		"desc":                   "UI_SHOP_DESC_HERO_GUARDIAN",
		"section":                "frags",
		"price_type":             "gems",
		"price_rm":               0.0,
		"price_gems":             1000,
		"purchase_limit":         0,
		"rewards":                {"frags_fixed": {"farm_guardian": 30}},
		"badge":          "UI_SHOP_BADGE_HERO",
		"require_level":  10,
	},
	{
		"id":             "ultimate_bundle",
		"name":           "UI_SHOP_PKG_ULTIMATE",
		"emoji":          "👑",
		"desc":           "UI_SHOP_DESC_ULTIMATE",
		"section":        "frags",
		"price_type":     "cash",
		"price_rm":       88.8,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"max_level": true, "all_tower_frags": 30},
		"badge":          "UI_SHOP_BADGE_ULTIMATE",
	},
	# ─── 货币 ────────────────────────────────────────────────────────
	{
		"id":             "gold_cash_first",
		"name":           "UI_SHOP_PKG_GOLD_SMALL",
		"emoji":          "💰",
		"desc":           "UI_SHOP_DESC_GOLD_1500",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       6.0,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"gold": 1500},
		"badge":          "UI_SHOP_BADGE_FIRST_DEAL",
	},
	{
		"id":             "gold_gems_first",
		"name":           "UI_SHOP_PKG_GOLD_SMALL",
		"emoji":          "💰",
		"desc":           "UI_SHOP_DESC_GOLD_1500",
		"section":        "currency",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     100,
		"purchase_limit": 1,
		"rewards":        {"gold": 1500},
		"badge":          "UI_SHOP_BADGE_FIRST_DEAL",
	},
	{
		"id":             "gems_cash_first",
		"name":           "UI_SHOP_PKG_GEMS_SMALL",
		"emoji":          "💎",
		"desc":           "UI_SHOP_DESC_GEMS_300",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       6.0,
		"price_gems":     0,
		"purchase_limit": 1,
		"rewards":        {"gems": 300},
		"badge":          "UI_SHOP_BADGE_FIRST_DEAL",
	},
	{
		"id":             "gold_cash_888",
		"name":           "UI_SHOP_PKG_GOLD_SMALL",
		"emoji":          "💰",
		"desc":           "UI_SHOP_DESC_GOLD_1500",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       8.88,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"gold": 1500},
		"badge":          "",
	},
	{
		"id":             "gems_cash_888",
		"name":           "UI_SHOP_PKG_GEMS_SMALL",
		"emoji":          "💎",
		"desc":           "UI_SHOP_DESC_GEMS_300",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       8.88,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"gems": 300},
		"badge":          "",
	},
	{
		"id":             "xp_small",
		"name":           "UI_SHOP_PKG_XP_SMALL",
		"emoji":          "⭐",
		"desc":           "UI_SHOP_DESC_XP_200",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       3.0,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"xp": 200},
		"badge":          "",
	},
	{
		"id":             "xp_large",
		"name":           "UI_SHOP_PKG_XP_LARGE",
		"emoji":          "🌟",
		"desc":           "UI_SHOP_DESC_XP_1000",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       8.88,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"xp": 1000},
		"badge":          "",
	},
	{
		"id":             "voucher_small",
		"name":           "UI_SHOP_PKG_VOUCHER_SMALL",
		"emoji":          "🎫",
		"desc":           "UI_SHOP_DESC_VOUCHER_10",
		"section":        "currency",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     100,
		"purchase_limit": 0,
		"rewards":        {"vouchers": 10},
		"badge":          "",
	},
	{
		"id":             "voucher_large",
		"name":           "UI_SHOP_PKG_VOUCHER_LARGE",
		"emoji":          "🎫",
		"desc":           "UI_SHOP_DESC_VOUCHER_110",
		"section":        "currency",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     1000,
		"purchase_limit": 0,
		"rewards":        {"vouchers": 110},
		"badge":          "UI_SHOP_BADGE_VALUE",
	},
	# ─── 道具 ────────────────────────────────────────────────────────
	{
		"id":             "shop_temp_tower",
		"name":           "UI_SHOP_PKG_TEMP_TOWER",
		"emoji":          "🎲",
		"desc":           "UI_SHOP_DESC_TEMP_TOWER",
		"section":        "items",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     60,
		"purchase_limit": 0,
		"rewards":        {"temp_tower_random": 1},
		"badge":          "",
	},
	{
		"id":             "shop_landmine",
		"name":           "UI_SHOP_PKG_LANDMINE",
		"emoji":          "💣",
		"desc":           "UI_SHOP_DESC_LANDMINE",
		"section":        "items",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     50,
		"purchase_limit": 0,
		"rewards":        {"item_grant": {"item_id": "landmine", "count": 1}},
		"badge":          "",
	},
	{
		"id":             "shop_gold_bag",
		"name":           "UI_SHOP_PKG_GOLD_BAG",
		"emoji":          "💰",
		"desc":           "UI_SHOP_DESC_GOLD_BAG",
		"section":        "items",
		"price_type":     "gems",
		"price_rm":       0.0,
		"price_gems":     30,
		"purchase_limit": 0,
		"rewards":        {"item_grant": {"item_id": "gold_bag", "count": 1}},
		"badge":          "",
	},
]

## ── 节点引用 ─────────────────────────────────────────────────────────
@onready var main_vbox:       VBoxContainer = $MainScroll/MainVBox
@onready var confirm_overlay: ColorRect     = $ConfirmOverlay
@onready var confirm_msg:     Label         = $ConfirmOverlay/ConfirmCard/ContentVBox/ConfirmMsg
@onready var confirm_btn:     Button        = $ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/ConfirmBtn
@onready var cancel_btn:      Button        = $ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/CancelBtn

## ── 运行时状态 ───────────────────────────────────────────────────────
var _towers_by_rarity: Dictionary = {}
## 每张卡的动态引用：[{pkg, buy_btn, count_lbl}]
var _card_states: Array = []
var _pending_action: Callable = Callable()

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_tower_resources()
	_setup_bg_effects()
	_build_all_sections()
	confirm_btn.pressed.connect(_on_confirm_yes)
	cancel_btn.pressed.connect(_on_confirm_no)
	confirm_overlay.gui_input.connect(_on_overlay_input)
	confirm_overlay.hide()
	# 玩家升级时自动刷新商店，等级达标后显示英雄礼包
	UserManager.level_changed.connect(func(_lv: int): _rebuild())

func _setup_bg_effects() -> void:
	BgFxLayer.create_and_attach(self, $Background)


## 清空并重建商店内容（用于解锁英雄后动态刷新）
func _rebuild() -> void:
	_card_states.clear()
	for child in main_vbox.get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_all_sections()

# ── 炮台资源加载（委托给 TowerResourceRegistry）─────────────────────────
func _load_tower_resources() -> void:
	if not _towers_by_rarity.is_empty():
		return
	_towers_by_rarity = TowerResourceRegistry.get_towers_by_rarity()

# ── 构建全部区块 ──────────────────────────────────────────────────────
func _build_all_sections() -> void:
	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 12)
	main_vbox.add_child(top_pad)

	_build_section("special",  tr("UI_SHOP_SECTION_SPECIAL"))
	_add_section_gap()
	_build_section("frags",    tr("UI_SHOP_SECTION_FRAGS"))
	_add_section_gap()
	_build_section("items",    tr("UI_SHOP_SECTION_ITEMS"))
	_add_section_gap()
	_build_section("currency", tr("UI_SHOP_SECTION_CURRENCY"))

	var bot_pad := Control.new()
	bot_pad.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(bot_pad)

func _add_section_gap() -> void:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.12)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(sep)
	main_vbox.add_child(margin)

func _build_section(section: String, title: String) -> void:
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left",  24)
	header_margin.add_theme_constant_override("margin_right", 24)
	header_margin.add_theme_constant_override("margin_top",   8)
	main_vbox.add_child(header_margin)

	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 34)
	header.modulate = Color(1.0, 0.82, 0.3)
	header_margin.add_child(header)

	# 分离可购买 vs 已售罄（限定包下沉到底部）
	var available_pkgs: Array = []
	var soldout_pkgs: Array = []
	for pkg in PACKAGES:
		if pkg.get("section", "") != section:
			continue
		var req_level: int = pkg.get("require_level", 0)
		if req_level > 0 and UserManager.level < req_level:
			continue
		var limit: int = pkg.get("purchase_limit", 0)
		var buy_count: int = UserManager.get_purchase_count(pkg["id"])
		if limit > 0 and buy_count >= limit:
			soldout_pkgs.append(pkg)
		else:
			available_pkgs.append(pkg)

	# 3 列网格布局
	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left",   12)
	grid_margin.add_theme_constant_override("margin_right",  12)
	grid_margin.add_theme_constant_override("margin_top",    8)
	main_vbox.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid_margin.add_child(grid)

	for pkg in available_pkgs + soldout_pkgs:
		grid.add_child(_make_package_card(pkg))

const SHOP_PANEL_TEX  = preload("res://assets/sprites/ui/Shop_panel.png")
const DIAMOND_ICON    = preload("res://assets/sprites/ui/Diamond.png")
const COIN_ICON       = preload("res://assets/sprites/ui/Coin.png")
const CLICK_THRESHOLD: float = 20.0   # 拖拽阈值（px），低于此为点击

# ── 礼包卡片构建（卡牌样式）──────────────────────────────────────────
func _make_package_card(pkg: Dictionary) -> Control:
	var price_type: String = pkg.get("price_type", "gems")
	var buy_count: int     = UserManager.get_purchase_count(pkg["id"])
	var limit: int         = pkg.get("purchase_limit", 0)
	var sold_out: bool     = (limit > 0 and buy_count >= limit)
	var is_monthly_active: bool = (
		pkg.get("rewards", {}).get("monthly_card", false)
		and UserManager.is_monthly_card_active()
	)
	var is_disabled: bool = sold_out or is_monthly_active

	# ── 根容器 ────────────────────────────────────────────────────
	var card := Control.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 420)
	card.mouse_filter = Control.MOUSE_FILTER_PASS  # PASS：让 ScrollContainer 也能接收拖拽

	# ── 木板背景 ──────────────────────────────────────────────────
	var bg := TextureRect.new()
	bg.texture = SHOP_PANEL_TEX
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	# ── 内容 margin ──────────────────────────────────────────────
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left",   20)
	content_margin.add_theme_constant_override("margin_right",  20)
	content_margin.add_theme_constant_override("margin_top",    24)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content_margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_child(vbox)

	# ── 商品图片/emoji ────────────────────────────────────────────
	var icon_path: String = pkg.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_tex := TextureRect.new()
		icon_tex.texture = load(icon_path)
		icon_tex.custom_minimum_size = Vector2(120, 120)
		icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_tex)
	else:
		var emoji_lbl := Label.new()
		emoji_lbl.text = pkg.get("emoji", "🎁")
		emoji_lbl.add_theme_font_size_override("font_size", 72)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.custom_minimum_size = Vector2(0, 100)
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(emoji_lbl)

	# ── 标题 ──────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text = tr(pkg.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# ── 红色角标 ──────────────────────────────────────────────────
	var badge: String = pkg.get("badge", "")
	if badge != "":
		var badge_lbl := Label.new()
		badge_lbl.text = tr(badge)
		badge_lbl.add_theme_font_size_override("font_size", 16)
		badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge_lbl)

	# ── 描述 ──────────────────────────────────────────────────────
	var desc_lbl := Label.new()
	desc_lbl.text = tr(pkg.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.modulate = Color(1, 1, 1, 0.65)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# ── 弹性间距 ──────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# ── 价格行 ────────────────────────────────────────────────────
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 6)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_row)

	if sold_out:
		var sold_lbl := Label.new()
		sold_lbl.text = tr("UI_SHOP_PURCHASED") if limit == 1 else tr("UI_SHOP_SOLD_OUT")
		sold_lbl.add_theme_font_size_override("font_size", 22)
		sold_lbl.modulate = Color(1, 1, 1, 0.5)
		sold_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_row.add_child(sold_lbl)
	elif is_monthly_active:
		var active_lbl := Label.new()
		active_lbl.text = tr("UI_SHOP_MONTHLY_ACTIVE")
		active_lbl.add_theme_font_size_override("font_size", 22)
		active_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		active_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_row.add_child(active_lbl)
	else:
		# 货币图标
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if price_type == "cash":
			# 现金不显示图标，直接文字
			pass
		elif price_type == "voucher":
			icon.texture = null  # 券暂无图标
		else:
			icon.texture = DIAMOND_ICON
			price_row.add_child(icon)

		var price_lbl := Label.new()
		price_lbl.add_theme_font_size_override("font_size", 24)
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if price_type == "cash":
			price_lbl.text = "RM %.2f" % pkg.get("price_rm", 0.0)
			price_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.4))
		elif price_type == "voucher":
			price_lbl.text = "🎫 %d" % pkg.get("price_vouchers", 0)
		else:
			price_lbl.text = "%d" % pkg.get("price_gems", 0)
			price_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		price_row.add_child(price_lbl)

	# ── 购买次数标签 ──────────────────────────────────────────────
	var count_lbl := Label.new()
	count_lbl.add_theme_font_size_override("font_size", 16)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.modulate = Color(1, 1, 1, 0.45)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_count_label(count_lbl, buy_count, limit)
	vbox.add_child(count_lbl)

	# ── 已售罄视觉 ────────────────────────────────────────────────
	if is_disabled:
		card.modulate = Color(0.6, 0.6, 0.6, 0.7)

	# ── 记录卡片状态（用于 _refresh_all_cards）────────────────────
	# buy_btn 改为 price_row 的引用（不再有独立按钮）
	_card_states.append({"pkg": pkg, "buy_btn": null, "count_lbl": count_lbl, "card": card, "price_row": price_row})

	# ── 点击处理（松手触发，防拖拽误触）────────────────────────────
	if not is_disabled:
		var captured_pkg: Dictionary = pkg
		card.gui_input.connect(func(event: InputEvent) -> void:
			_on_card_input(event, card, captured_pkg)
		)

	return card


## 卡牌点击处理：按下记录位置，松手时判断是否为点击（非拖拽）
func _on_card_input(event: InputEvent, card: Control, pkg: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			card.set_meta("press_pos", event.global_position)
		else:
			var press_pos: Vector2 = card.get_meta("press_pos", event.global_position)
			if event.global_position.distance_to(press_pos) < CLICK_THRESHOLD:
				_on_buy_pressed(pkg)
	elif event is InputEventScreenTouch:
		if event.pressed:
			card.set_meta("press_pos", event.position)
		else:
			var press_pos: Vector2 = card.get_meta("press_pos", event.position)
			if event.position.distance_to(press_pos) < CLICK_THRESHOLD:
				_on_buy_pressed(pkg)

func _update_count_label(lbl: Label, bought: int, limit: int) -> void:
	if limit == 0:
		lbl.text = ""
	elif limit == 1:
		lbl.text = tr("UI_SHOP_PURCHASED") if bought >= 1 else tr("UI_SHOP_LIMIT_ONE")
	else:
		lbl.text = tr("UI_SHOP_BOUGHT_COUNT") % [bought, limit]

# ── 购买响应 ──────────────────────────────────────────────────────────
func _on_buy_pressed(pkg: Dictionary) -> void:
	if confirm_overlay.visible:
		return
	# 月卡激活中不允许重复购买
	if pkg.get("rewards", {}).get("monthly_card", false) and UserManager.is_monthly_card_active():
		_show_alert("月卡仍在有效期内，无需重复购买")
		return
	var price_type: String = pkg.get("price_type", "gems")
	if price_type == "cash":
		_buy_cash(pkg)
	elif price_type == "voucher":
		_buy_voucher(pkg)
	else:
		_buy_gems(pkg)

## 现金购买 —— 经由 PaymentManager 统一处理
## 开发阶段（is_real_payment_enabled=false）：确认后直接发奖励
## 上架后（is_real_payment_enabled=true） ：调起 Google Play Billing
func _buy_cash(pkg: Dictionary) -> void:
	var price_label: String = "RM %.2f" % pkg.get("price_rm", 0.0)
	_show_confirm(
		tr("UI_SHOP_CONFIRM_BUY") % [tr(pkg.get("desc", "")), price_label],
		func():
			PaymentManager.purchase(
				pkg["id"],
				pkg.get("price_rm", 0.0),
				func(): _apply_rewards(pkg),
				func(err: String): _show_alert(tr("UI_SHOP_PAYMENT_FAILED") + "\n" + err)
			)
	)

## 钻石购买
func _buy_gems(pkg: Dictionary) -> void:
	var cost: int = pkg.get("price_gems", 0)
	if UserManager.gems < cost:
		_show_alert(tr("UI_SHOP_GEMS_LOW") % [cost, UserManager.gems])
		return
	_show_confirm(
		tr("UI_SHOP_CONFIRM_GEMS") % [tr(pkg.get("desc", "")), cost, UserManager.gems],
		func():
			UserManager.spend_gems(cost)
			_apply_rewards(pkg)
	)

## 券购买
func _buy_voucher(pkg: Dictionary) -> void:
	var cost: int = pkg.get("price_vouchers", 0)
	if UserManager.vouchers < cost:
		_show_alert("券不足！\n需要 🎫 %d（当前 🎫 %d）" % [cost, UserManager.vouchers])
		return
	_show_confirm(
		"确认使用 🎫 %d 券购买？" % cost,
		func():
			UserManager.vouchers -= cost
			UserManager.currency_changed.emit()
			_apply_rewards(pkg)
	)

# ── 奖励发放 ──────────────────────────────────────────────────────────
func _apply_rewards(pkg: Dictionary) -> void:
	var r: Dictionary = pkg.get("rewards", {})
	if r.get("gold", 0) > 0:
		UserManager.add_gold(r["gold"])
	if r.get("gems", 0) > 0:
		UserManager.add_gems(r["gems"])
	if r.get("xp", 0) > 0:
		UserManager.add_xp(r["xp"])
	if r.get("vouchers", 0) > 0:
		UserManager.add_vouchers(r["vouchers"])
	if r.get("max_level", false):
		_grant_max_level()
	if r.get("all_tower_frags", 0) > 0:
		_grant_all_tower_frags(r["all_tower_frags"])
	# 临时炮台随机券
	if r.get("temp_tower_random", 0) > 0:
		for _i in r["temp_tower_random"]:
			UserManager.add_temp_tower(TempTowerGenerator.generate_random())
	# 道具直接赠送（地雷、金币袋等）
	var ig: Dictionary = r.get("item_grant", {})
	if not ig.is_empty():
		UserManager.add_item(ig.get("item_id", ""), int(ig.get("count", 1)))
	# 月卡（购买后通知 HomeScene 刷新左侧按钮）
	if r.get("monthly_card", false):
		UserManager.activate_monthly_card()
		# 通知 HomeScene 刷新（通过 scene tree 查找）
		var home = get_tree().get_first_node_in_group("home_scene")
		if home and home.has_method("_setup_left_side_buttons"):
			# 清除旧按钮重建
			if home.left_side_buttons and is_instance_valid(home.left_side_buttons):
				home.left_side_buttons.queue_free()
			home.call_deferred("_setup_left_side_buttons")
	# 免广告
	if r.get("ad_free", false):
		UserManager.ad_free = true
	# 英雄解锁
	if r.has("unlock_hero"):
		var hero_id: String = r["unlock_hero"]
		if hero_id not in CollectionManager.unlocked_towers:
			CollectionManager.unlocked_towers.append(hero_id)
	for tid: String in r.get("frags_fixed", {}).keys():
		CollectionManager.add_fragments(tid, r["frags_fixed"][tid])
	var rand_info: Dictionary = r.get("frags_random", {})
	var frag_result: Dictionary = {}
	if not rand_info.is_empty():
		frag_result = _add_random_frags(rand_info.get("rarity", 0), rand_info.get("count", 1))
	UserManager.record_purchase(pkg["id"])
	SaveManager.save()
	_refresh_all_cards()
	# 随机礼包：展示分配结果
	if not frag_result.is_empty():
		_show_frag_reward(frag_result, rand_info.get("rarity", 0))

## 将玩家等级直接提升至满级（Lv.100）
func _grant_max_level() -> void:
	if UserManager.level >= UserManager.MAX_LEVEL:
		return
	UserManager.level             = UserManager.MAX_LEVEL
	UserManager.xp                = 0
	UserManager.xp_to_next_level  = 1000 + (UserManager.MAX_LEVEL - 1) * 500
	UserManager.level_changed.emit(UserManager.MAX_LEVEL)
	UserManager.currency_changed.emit()

## 给予所有炮台各 count 份碎片
func _grant_all_tower_frags(count: int) -> void:
	for rarity_list: Array in _towers_by_rarity.values():
		for tower_res: Resource in rarity_list:
			var tid: String = tower_res.tower_id
			if tid != "":
				CollectionManager.add_fragments(tid, count)

## 随机发放碎片 — 逐片随机分配到该稀有度的所有炮台
## 返回分配详情 Dictionary {tower_id: count}（失败时返回空）
func _add_random_frags(rarity: int, total_count: int) -> Dictionary:
	var r: int = rarity
	if r not in _towers_by_rarity or _towers_by_rarity[r].is_empty():
		for delta: int in [1, 2, 3, 4]:
			for candidate: int in [r - delta, r + delta]:
				if candidate in _towers_by_rarity and not _towers_by_rarity[candidate].is_empty():
					r = candidate
					break
			if r != rarity:
				break
	if r not in _towers_by_rarity or _towers_by_rarity[r].is_empty():
		return {}
	var towers: Array = _towers_by_rarity[r]
	var result: Dictionary = {}  # {tower_id: count}
	for _i in total_count:
		var tower_res: Resource = towers[randi() % towers.size()]
		var tid: String = tower_res.tower_id
		result[tid] = result.get(tid, 0) + 1
	# 批量发放碎片
	for tid: String in result:
		CollectionManager.add_fragments(tid, result[tid])
	return result

## 随机碎片购买结果展示（显示每个炮台获得的碎片数量）
func _show_frag_reward(frag_result: Dictionary, rarity: int) -> void:
	if frag_result.is_empty():
		return
	var rarity_labels: Array[String] = [tr("UI_RARITY_WHITE"), tr("UI_RARITY_GREEN"), tr("UI_RARITY_BLUE"), tr("UI_RARITY_PURPLE"), tr("UI_RARITY_ORANGE")]
	var rarity_str: String = rarity_labels[clampi(rarity, 0, 4)]
	var lines: String = tr("UI_SHOP_FRAG_REWARD_TITLE") % rarity_str
	for tid: String in frag_result:
		var tname: String = TowerResourceRegistry.get_tower_display_name(tid, tid)
		lines += "\n🧩 %s ×%d" % [tname, frag_result[tid]]
	_show_alert(lines)

# ── 刷新所有卡片状态 ──────────────────────────────────────────────────
func _refresh_all_cards() -> void:
	for state in _card_states:
		var pkg: Dictionary  = state["pkg"]
		var count_lbl: Label = state["count_lbl"]
		var card: Control    = state.get("card")
		var buy_count: int   = UserManager.get_purchase_count(pkg["id"])
		var limit: int       = pkg.get("purchase_limit", 0)
		var sold_out: bool   = (limit > 0 and buy_count >= limit)
		var is_monthly_active: bool = (
			pkg.get("rewards", {}).get("monthly_card", false)
			and UserManager.is_monthly_card_active()
		)
		if (sold_out or is_monthly_active) and card and is_instance_valid(card):
			card.modulate = Color(0.6, 0.6, 0.6, 0.7)
		_update_count_label(count_lbl, buy_count, limit)

# ── 确认 / 提示弹窗 ───────────────────────────────────────────────────
func _show_confirm(message: String, on_confirm: Callable) -> void:
	_pending_action = on_confirm
	confirm_msg.text = message
	cancel_btn.show()
	confirm_btn.text = tr("UI_DIALOG_CONFIRM")
	confirm_overlay.show()

func _show_alert(message: String) -> void:
	_pending_action = Callable()
	confirm_msg.text = message
	cancel_btn.hide()
	confirm_btn.text = tr("UI_SHOP_OK")
	confirm_overlay.show()

func _on_confirm_yes() -> void:
	confirm_overlay.hide()
	cancel_btn.show()
	confirm_btn.text = tr("UI_DIALOG_CONFIRM")
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()

func _on_confirm_no() -> void:
	confirm_overlay.hide()
	cancel_btn.show()
	confirm_btn.text = tr("UI_DIALOG_CONFIRM")
	_pending_action = Callable()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_confirm_no()
