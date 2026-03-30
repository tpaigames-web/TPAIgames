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
		"rewards":        {"gems": 500, "gold": 5000, "trial_tickets": 3},
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
		"rewards":        {"unlock_hero": "hero_farmer", "frags_fixed": {"hero_farmer": 60}, "trial_tickets": 2},
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
		"rewards":        {"gems": 680, "trial_tickets": 2},
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
		"rewards":        {"gems": 1800, "trial_tickets": 5, "frags_random": {"rarity": 3, "count": 50}},
		"badge":          "UI_SHOP_BADGE_VALUE",
	},
	# ─── 碎片礼包 ───────────────────────────────────────────────────
	{
		"id":             "starter_basic",
		"name":           "UI_SHOP_PKG_STARTER_BASIC",
		"emoji":          "🌾",
		"desc":           "UI_SHOP_DESC_STARTER_BASIC",
		"section":        "frags",
		"price_type":     "cash",
		"price_rm":       6.0,
		"price_gems":     0,
		"purchase_limit": 5,
		"rewards":        {"frags_fixed": {"scarecrow": 100}, "gold": 500, "gems": 100},
		"badge":          "",
	},
	{
		"id":             "starter_farmer",
		"name":           "UI_SHOP_PKG_STARTER_FARMER",
		"emoji":          "👨‍🌾",
		"desc":           "UI_SHOP_DESC_STARTER_FARMER",
		"section":        "frags",
		"price_type":     "cash",
		"price_rm":       28.8,
		"price_gems":     0,
		"purchase_limit": 3,
		"rewards":        {"frags_fixed": {"farmer": 150}, "gold": 1000, "gems": 500},
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
		"price_gems":     1000,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 3, "count": 150}, "gold": 300},
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
		"price_gems":     100,
		"purchase_limit": 0,
		"rewards":        {"frags_random": {"rarity": 0, "count": 100}},
		"badge":          "",
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
		"id":             "gems_small_repeat",
		"name":           "UI_SHOP_PKG_GEMS_SMALL_R",
		"emoji":          "💎",
		"desc":           "UI_SHOP_DESC_GEMS_220",
		"section":        "currency",
		"price_type":     "cash",
		"price_rm":       6.0,
		"price_gems":     0,
		"purchase_limit": 0,
		"rewards":        {"gems": 220},
		"badge":          "",
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
	_build_all_sections()
	confirm_btn.pressed.connect(_on_confirm_yes)
	cancel_btn.pressed.connect(_on_confirm_no)
	confirm_overlay.gui_input.connect(_on_overlay_input)
	confirm_overlay.hide()
	# 玩家升级时自动刷新商店，等级达标后显示英雄礼包
	UserManager.level_changed.connect(func(_lv: int): _rebuild())

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

	if section == "items":
		var empty_margin := MarginContainer.new()
		empty_margin.add_theme_constant_override("margin_left",   24)
		empty_margin.add_theme_constant_override("margin_top",    10)
		empty_margin.add_theme_constant_override("margin_bottom", 10)
		main_vbox.add_child(empty_margin)
		var empty_lbl := Label.new()
		empty_lbl.text = tr("UI_SHOP_NO_ITEMS")
		empty_lbl.add_theme_font_size_override("font_size", 26)
		empty_lbl.modulate = Color(1, 1, 1, 0.35)
		empty_margin.add_child(empty_lbl)
		return

	for pkg in PACKAGES:
		if pkg.get("section", "") != section:
			continue
		# ── 条件过滤：require_level 玩家等级必须达到指定值 ────────────────
		var req_level: int = pkg.get("require_level", 0)
		if req_level > 0 and UserManager.level < req_level:
			continue
		# ── 构建卡片 ─────────────────────────────────────────────────────
		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left",   16)
		card_margin.add_theme_constant_override("margin_right",  16)
		card_margin.add_theme_constant_override("margin_top",    4)
		card_margin.add_theme_constant_override("margin_bottom", 4)
		card_margin.add_child(_make_package_card(pkg))
		main_vbox.add_child(card_margin)

# ── 礼包卡片构建 ──────────────────────────────────────────────────────
func _make_package_card(pkg: Dictionary) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 190)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	card.add_child(hbox)

	# ── 左侧信息区 ────────────────────────────────────────────────
	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left",   24)
	left_margin.add_theme_constant_override("margin_top",    18)
	left_margin.add_theme_constant_override("margin_bottom", 18)
	hbox.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_vbox)

	# 名称行
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	left_vbox.add_child(name_row)

	var emoji_lbl := Label.new()
	emoji_lbl.text = pkg.get("emoji", "🎁")
	emoji_lbl.add_theme_font_size_override("font_size", 44)
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(emoji_lbl)

	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 4)
	name_row.add_child(title_col)

	var name_lbl := Label.new()
	name_lbl.text = tr(pkg.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 30)
	title_col.add_child(name_lbl)

	var badge: String = pkg.get("badge", "")
	if badge != "":
		var badge_lbl := Label.new()
		badge_lbl.text = tr(badge)
		badge_lbl.add_theme_font_size_override("font_size", 20)
		badge_lbl.modulate = Color(1.0, 0.3, 0.3)
		title_col.add_child(badge_lbl)

	# 内容描述
	var desc_lbl := Label.new()
	desc_lbl.text = tr(pkg.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.modulate = Color(1, 1, 1, 0.65)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(desc_lbl)

	# ── 右侧购买区 ────────────────────────────────────────────────
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_right",  20)
	right_margin.add_theme_constant_override("margin_top",    18)
	right_margin.add_theme_constant_override("margin_bottom", 18)
	hbox.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(220, 0)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(210, 72)
	buy_btn.add_theme_font_size_override("font_size", 26)

	var price_type: String = pkg.get("price_type", "gems")
	var buy_count: int     = UserManager.get_purchase_count(pkg["id"])
	var limit: int         = pkg.get("purchase_limit", 0)
	var sold_out: bool     = (limit > 0 and buy_count >= limit)

	if sold_out:
		buy_btn.text     = tr("UI_SHOP_PURCHASED") if limit == 1 else tr("UI_SHOP_SOLD_OUT")
		buy_btn.disabled = true
	elif price_type == "cash":
		buy_btn.text     = "RM %.2f" % pkg.get("price_rm", 0.0)
		buy_btn.modulate = Color(0.8, 1.0, 0.65)   # 浅绿
	else:
		buy_btn.text     = "💎 %d" % pkg.get("price_gems", 0)
		buy_btn.modulate = Color(0.65, 0.85, 1.0)  # 浅蓝

	right_vbox.add_child(buy_btn)

	var count_lbl := Label.new()
	count_lbl.add_theme_font_size_override("font_size", 20)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.modulate = Color(1, 1, 1, 0.5)
	_update_count_label(count_lbl, buy_count, limit)
	right_vbox.add_child(count_lbl)

	_card_states.append({"pkg": pkg, "buy_btn": buy_btn, "count_lbl": count_lbl})

	if not sold_out:
		var captured_pkg: Dictionary = pkg
		buy_btn.pressed.connect(func(): _on_buy_pressed(captured_pkg))

	return card

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
		tr("UI_SHOP_CONFIRM_BUY") % [pkg.get("desc", ""), price_label],
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
		tr("UI_SHOP_CONFIRM_GEMS") % [pkg.get("desc", ""), cost],
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
	# 试用券
	if r.get("trial_tickets", 0) > 0:
		UserManager.add_item("trial_ticket", r["trial_tickets"])
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
	var picked_tower: Resource = null
	if not rand_info.is_empty():
		picked_tower = _add_random_frags(rand_info.get("rarity", 0), rand_info.get("count", 1))
	UserManager.record_purchase(pkg["id"])
	SaveManager.save()
	_refresh_all_cards()
	# 随机礼包：展示获得的炮台卡片
	if picked_tower != null:
		_show_frag_reward(picked_tower, rand_info.get("count", 1))

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

## 随机发放碎片，返回被选中的炮台资源（失败时返回 null）
func _add_random_frags(rarity: int, count: int) -> Resource:
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
		return null
	var tower_res: Resource = _towers_by_rarity[r].pick_random()
	var tid: String = tower_res.tower_id   # 直接属性访问，Resource.get() 不支持第二参数
	if tid != "":
		CollectionManager.add_fragments(tid, count)
	return tower_res

## 随机碎片购买结果展示（带品质标签）
func _show_frag_reward(tower_res: Resource, count: int) -> void:
	var emoji: String  = str(tower_res.get("tower_emoji"))  if tower_res.get("tower_emoji")  else "🏆"
	var dname: String  = TowerResourceRegistry.tr_tower_name(tower_res) if tower_res else tr("UI_BATTLE_TAB_TOWER")
	var rarity: int    = int(tower_res.get("rarity")) if tower_res.get("rarity") != null else 0
	var rarity_labels: Array[String] = [tr("UI_RARITY_WHITE"), tr("UI_RARITY_GREEN"), tr("UI_RARITY_BLUE"), tr("UI_RARITY_PURPLE"), tr("UI_RARITY_ORANGE")]
	var rarity_str: String = rarity_labels[clampi(rarity, 0, 4)]
	_show_alert(tr("UI_SHOP_FRAG_REWARD") % [emoji, dname, rarity_str, count])

# ── 刷新所有卡片状态 ──────────────────────────────────────────────────
func _refresh_all_cards() -> void:
	for state in _card_states:
		var pkg: Dictionary  = state["pkg"]
		var buy_btn: Button  = state["buy_btn"]
		var count_lbl: Label = state["count_lbl"]
		var buy_count: int   = UserManager.get_purchase_count(pkg["id"])
		var limit: int       = pkg.get("purchase_limit", 0)
		var sold_out: bool   = (limit > 0 and buy_count >= limit)
		if sold_out:
			buy_btn.text     = tr("UI_SHOP_PURCHASED") if limit == 1 else tr("UI_SHOP_SOLD_OUT")
			buy_btn.disabled = true
			buy_btn.modulate = Color(1, 1, 1, 1)
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
