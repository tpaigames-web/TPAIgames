extends CanvasLayer

## 升级通行证 ── 竖向 Battle Pass 进度系统（CanvasLayer 浮层）
## 玩家击败敌人/商店购买获取经验，升级获得免费/付费双轨奖励。

# ── 常量 ──────────────────────────────────────────────────────────────
const MAX_LEVEL: int            = 100
const PAID_PASS_PRICE_RM: float = 8.88

## 稀有度颜色（集中定义于 TowerResourceRegistry Autoload）

## 进度条颜色
const BAR_FILLED_COLOR:   Color = Color(0.20, 0.70, 0.30)   # 绿色（已完成）
const BAR_CURRENT_COLOR:  Color = Color(0.20, 0.60, 1.00)   # 蓝色（当前级）
const BAR_EMPTY_COLOR:    Color = Color(0.25, 0.25, 0.30)   # 深灰（未到达）

## 里程碑徽章颜色
const BADGE_SUPER_COLOR:  Color = Color(1.00, 0.43, 0.00)   # 橙（×25）
const BADGE_MAJOR_COLOR:  Color = Color(0.61, 0.15, 0.69)   # 紫（×10）
const BADGE_MINOR_COLOR:  Color = Color(0.13, 0.59, 0.95)   # 蓝（×5）

# ── 炮台资源（集中定义于 TowerResourceRegistry Autoload）──────────────

# ── 节点引用（路径前缀 $Card/）────────────────────────────────────────
@onready var close_btn:        Button          = $Card/CloseBtn
@onready var levels_vbox:      VBoxContainer   = $Card/ScrollContainer/LevelsVBox
@onready var scroll_container: ScrollContainer = $Card/ScrollContainer
@onready var buy_pass_btn:     Button          = $Card/BottomBar/BottomBarContent/BuyPassBtn
@onready var confirm_overlay:  ColorRect       = $Card/ConfirmOverlay
@onready var confirm_msg:      Label           = $Card/ConfirmOverlay/ConfirmCard/ContentVBox/ConfirmMsg
@onready var confirm_btn:      Button          = $Card/ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/ConfirmBtn
@onready var cancel_btn:       Button          = $Card/ConfirmOverlay/ConfirmCard/ContentVBox/BtnRow/CancelBtn

# ── 运行时状态 ───────────────────────────────────────────────────────
var _towers_by_rarity: Dictionary = {}
var _pending_action:   Callable   = Callable()
## 每行的 claim 按钮引用：lv → {free_btn, paid_btn}
var _row_btns: Dictionary = {}
## 延迟构建：下一个待构建等级（从当前等级往下递减到 1）
var _deferred_build_lv: int = 0

# ── 初始化 ────────────────────────────────────────────────────────────
func _ready() -> void:
	# Translate .tscn hardcoded text
	$Card/TitleLabel.text = tr("UI_LEVEL_PASS_TITLE")
	$Card/BottomBar/BottomBarContent/FreeLbl.text = tr("UI_LEVEL_PASS_FREE")
	_load_tower_resources()
	_build_rows()
	_update_buy_pass_btn()
	close_btn.pressed.connect(queue_free)
	confirm_btn.pressed.connect(_on_confirm_yes)
	cancel_btn.pressed.connect(_on_confirm_no)
	confirm_overlay.gui_input.connect(_on_overlay_input)
	confirm_overlay.hide()
	buy_pass_btn.pressed.connect(_on_buy_pass)
	UserManager.currency_changed.connect(_refresh_xp_bars)
	UserManager.level_changed.connect(_on_level_changed)
	# 等布局稳定后滚动到当前等级
	call_deferred("_scroll_to_current")
	# 浮动一键领取按钮
	call_deferred("_add_claim_all_btn")

# ── 炮台资源加载（委托给 TowerResourceRegistry）──────────────────────
func _load_tower_resources() -> void:
	if not _towers_by_rarity.is_empty():
		return
	_towers_by_rarity = TowerResourceRegistry.get_towers_by_rarity()

# ── 构建所有等级行（倒序：高级在上，低级在下，与 Battle Pass 惯例一致）──
## 优先同步构建当前等级及以上的行（可见区域），其余行延迟分帧追加，避免首帧卡顿
const _BUILD_CHUNK: int = 15
func _build_rows() -> void:
	var cur: int = UserManager.level
	# 同步构建：MAX_LEVEL 到 max(1, cur-5)，覆盖打开面板时的可见区域
	var sync_end: int = maxi(1, cur - 5)
	for lv: int in range(MAX_LEVEL, sync_end - 1, -1):
		levels_vbox.add_child(_make_level_row(lv))
	# 余下等级（cur-6 到 1）延迟分批添加
	_deferred_build_lv = sync_end - 1
	if _deferred_build_lv >= 1:
		call_deferred("_build_rows_deferred")

## 每帧追加 _BUILD_CHUNK 行，直到全部构建完成
func _build_rows_deferred() -> void:
	var chunk_end: int = maxi(1, _deferred_build_lv - _BUILD_CHUNK + 1)
	for lv: int in range(_deferred_build_lv, chunk_end - 1, -1):
		levels_vbox.add_child(_make_level_row(lv))
	_deferred_build_lv = chunk_end - 1
	if _deferred_build_lv >= 1:
		call_deferred("_build_rows_deferred")

# ── 构建单行 ──────────────────────────────────────────────────────────
func _make_level_row(lv: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 0)

	row.add_child(_make_reward_slot(lv, false))
	row.add_child(_make_center_bar(lv))
	row.add_child(_make_reward_slot(lv, true))

	return row

# ── 中央进度条段 ──────────────────────────────────────────────────────
func _make_center_bar(lv: int) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(140, 0)
	vbox.add_theme_constant_override("separation", 0)

	var top_fill := ColorRect.new()
	top_fill.custom_minimum_size = Vector2(0, 40)
	top_fill.name = "TopFill_%d" % lv
	vbox.add_child(top_fill)

	# 等级徽章（里程碑用特殊颜色）
	var badge_panel := Panel.new()
	badge_panel.custom_minimum_size = Vector2(140, 40)
	var badge_lbl := Label.new()
	badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_lbl.text = str(lv)
	badge_lbl.add_theme_font_size_override("font_size", 28)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(badge_lbl)
	vbox.add_child(badge_panel)

	var bot_fill := ColorRect.new()
	bot_fill.custom_minimum_size = Vector2(0, 40)
	bot_fill.name = "BotFill_%d" % lv
	vbox.add_child(bot_fill)

	# 着色
	_apply_bar_colors(lv, top_fill, bot_fill, badge_panel, badge_lbl)

	return vbox

## 根据当前等级 & XP 为进度条着色
func _apply_bar_colors(lv: int, top_fill: ColorRect, bot_fill: ColorRect,
		badge_panel: Panel, badge_lbl: Label) -> void:
	var cur_lv: int = UserManager.level
	var xp_ratio: float = float(UserManager.xp) / float(UserManager.xp_to_next_level)

	if lv < cur_lv:
		# 完全已过 → 全绿
		top_fill.color = BAR_FILLED_COLOR
		bot_fill.color = BAR_FILLED_COLOR
	elif lv == cur_lv:
		# 当前级 → 下段按 XP 进度分割（用 modulate 模拟，简单起见全蓝）
		top_fill.color = BAR_FILLED_COLOR
		bot_fill.color = BAR_CURRENT_COLOR
		bot_fill.modulate = Color(1, 1, 1, 0.3 + xp_ratio * 0.7)
	else:
		top_fill.color = BAR_EMPTY_COLOR
		bot_fill.color = BAR_EMPTY_COLOR

	# 徽章颜色
	var badge_color: Color = _get_badge_color(lv)
	badge_lbl.modulate = badge_color if lv <= cur_lv else Color(1, 1, 1, 0.5)

## 返回等级徽章颜色（里程碑分级）
func _get_badge_color(lv: int) -> Color:
	if lv % 25 == 0:
		return BADGE_SUPER_COLOR
	elif lv % 10 == 0:
		return BADGE_MAJOR_COLOR
	elif lv % 5 == 0:
		return BADGE_MINOR_COLOR
	return Color(0.85, 0.85, 0.85)

# ── 奖励槽位 ──────────────────────────────────────────────────────────
func _make_reward_slot(lv: int, is_paid: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size   = Vector2(0, 120)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left",   8)
	inner.add_theme_constant_override("margin_right",  8)
	inner.add_theme_constant_override("margin_top",    6)
	inner.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	inner.add_child(vbox)

	# 奖励信息
	var reward: Dictionary = _get_reward(lv, is_paid)

	var emoji_lbl := Label.new()
	emoji_lbl.text = _reward_emoji(reward)
	emoji_lbl.add_theme_font_size_override("font_size", 36)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _reward_desc(reward)
	desc_lbl.add_theme_font_size_override("font_size", 19)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(0, 36)
	claim_btn.add_theme_font_size_override("font_size", 20)
	vbox.add_child(claim_btn)

	# 存储按钮引用以便刷新
	if lv not in _row_btns:
		_row_btns[lv] = {}
	if is_paid:
		_row_btns[lv]["paid_btn"]  = claim_btn
		_row_btns[lv]["paid_desc"] = desc_lbl
	else:
		_row_btns[lv]["free_btn"]  = claim_btn
		_row_btns[lv]["free_desc"] = desc_lbl

	_update_claim_btn(claim_btn, lv, is_paid)

	var cap_lv: int    = lv
	var cap_paid: bool = is_paid
	claim_btn.pressed.connect(func(): _on_claim(cap_lv, cap_paid))

	return panel

## 更新领取按钮状态
func _update_claim_btn(btn: Button, lv: int, is_paid: bool) -> void:
	var cur_lv: int = UserManager.level
	if is_paid and not UserManager.has_paid_pass:
		btn.text     = "🔒"
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.5)
		return
	var claimed_list: Array = UserManager.claimed_paid_rewards if is_paid else UserManager.claimed_free_rewards
	if lv in claimed_list:
		btn.text     = "✓"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
	elif lv <= cur_lv:
		btn.text     = tr("UI_LEVEL_CLAIM")
		btn.disabled = false
		btn.modulate = Color(0.4, 1.0, 0.5)  # 绿色高亮
	else:
		btn.text     = "—"
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.35)

# ── 程序化奖励生成 ────────────────────────────────────────────────────
func _get_reward(lv: int, is_paid: bool) -> Dictionary:
	var r: Dictionary = {}

	# ── 特殊里程碑（按设计文档）──────────────────────────────────────
	# 临时炮台里程碑：Lv.3, 8, 15, 25, 50
	if lv in [3, 8]:
		r["temp_tower_random"] = 2 if is_paid else 1
	elif lv == 15:
		r["temp_tower_random"] = 3 if is_paid else 2
		r["frags_tower"] = "farmer"
		r["frags_count"] = 50 if is_paid else 30
	elif lv == 25:
		r["temp_tower_random"] = 3 if is_paid else 2
		r["frags_rarity"] = 3
		r["frags_count"] = 50 if is_paid else 30
	elif lv == 50:
		r["temp_tower_random"] = 5 if is_paid else 3
		r["frags_tower"] = "watchtower"
		r["frags_count"] = 120 if is_paid else 60
	elif lv == 75:
		r["frags_tower"] = "hero_farmer"
		r["frags_count"] = 120 if is_paid else 60
	elif lv == 100:
		r["gold"] = 8000 if is_paid else 5000
		r["gems"] = 800 if is_paid else 500
		r["frags_rarity"] = 3 if is_paid else 2
		r["frags_count"] = 50

	# ── 常规里程碑 ──────────────────────────────────────────────────
	if r.is_empty():
		if lv % 25 == 0:        # 超级里程碑
			r["gold"] = lv * 50
			r["gems"] = lv * 10
			if lv >= 50:
				r["frags_rarity"] = 3
				r["frags_count"]  = 3
		elif lv % 10 == 0:      # 主要里程碑
			r["gold"] = lv * 35
			r["gems"] = lv * 7
			if lv >= 30:
				r["frags_rarity"] = 2
				r["frags_count"]  = 2
		elif lv % 5 == 0:       # 次里程碑
			r["gold"] = lv * 20
			r["gems"] = lv * 4
		elif lv % 2 == 0:       # 偶数普通
			r["gems"] = 20 + lv * 2
		else:                   # 奇数普通
			r["gold"] = 100 + lv * 8

	# ── 付费加成 ×1.8 ──────────────────────────────────────────────
	if is_paid:
		if "gold" in r:
			r["gold"] = int(r["gold"] * 1.8)
		if "gems" in r:
			r["gems"] = int(r["gems"] * 1.8)

	return r

## 奖励 emoji（用最主要的那项）
func _reward_emoji(reward: Dictionary) -> String:
	if "frags_rarity" in reward:
		return ["⬜", "🟩", "🟦", "🟪", "🟧"][reward["frags_rarity"]]
	if "gold" in reward and "gems" in reward:
		return "🪙💎"
	if "gold" in reward:
		return "🪙"
	if "gems" in reward:
		return "💎"
	return "🎁"

## 奖励描述文字
func _reward_desc(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if "gold" in reward:
		parts.append("🪙%d" % reward["gold"])
	if "gems" in reward:
		parts.append("💎%d" % reward["gems"])
	if "frags_rarity" in reward:
		var rarity_name: String = [tr("UI_RARITY_WHITE"), tr("UI_RARITY_GREEN"), tr("UI_RARITY_BLUE"), tr("UI_RARITY_PURPLE"), tr("UI_RARITY_ORANGE")][reward["frags_rarity"]]
		parts.append(tr("UI_LEVEL_FRAG_FORMAT") % [rarity_name, reward.get("frags_count", 1)])
	return "\n".join(parts)

# ── 领取奖励 ──────────────────────────────────────────────────────────
func _on_claim(lv: int, is_paid: bool) -> void:
	var cur_lv: int = UserManager.level
	if lv > cur_lv:
		return
	if is_paid and not UserManager.has_paid_pass:
		return
	var claimed_list: Array = UserManager.claimed_paid_rewards if is_paid else UserManager.claimed_free_rewards
	if lv in claimed_list:
		return
	var reward: Dictionary = _get_reward(lv, is_paid)
	_apply_reward(reward)
	if is_paid:
		UserManager.claim_paid_reward(lv)
	else:
		UserManager.claim_free_reward(lv)
	# 刷新该行按钮状态
	if lv in _row_btns:
		var btns: Dictionary = _row_btns[lv]
		if is_paid and "paid_btn" in btns:
			_update_claim_btn(btns["paid_btn"], lv, true)
		elif not is_paid and "free_btn" in btns:
			_update_claim_btn(btns["free_btn"], lv, false)

## 发放奖励
func _apply_reward(reward: Dictionary) -> void:
	if reward.get("gold", 0) > 0:
		UserManager.add_gold(reward["gold"])
	if reward.get("gems", 0) > 0:
		UserManager.add_gems(reward["gems"])
	# 临时炮台
	if reward.get("temp_tower_random", 0) > 0:
		for _i in reward["temp_tower_random"]:
			UserManager.add_temp_tower(TempTowerGenerator.generate_random())
	# 指定炮台碎片
	if "frags_tower" in reward:
		var tid: String = reward["frags_tower"]
		var count: int = reward.get("frags_count", 1)
		CollectionManager.add_fragments(tid, count)
	# 随机稀有度碎片
	elif "frags_rarity" in reward:
		var rarity: int = reward["frags_rarity"]
		var count: int  = reward.get("frags_count", 1)
		_add_random_frags(rarity, count)

## 随机发放碎片（与 ShopTab 同款逻辑）
func _add_random_frags(rarity: int, count: int) -> void:
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
		return
	var tower_res: Resource = _towers_by_rarity[r].pick_random()
	var tid: String = tower_res.tower_id
	if tid != "":
		CollectionManager.add_fragments(tid, count)

# ── 购买通行证 ────────────────────────────────────────────────────────
func _on_buy_pass() -> void:
	if UserManager.has_paid_pass:
		return
	_show_confirm(
		tr("UI_LEVEL_BUY_PASS") % PAID_PASS_PRICE_RM,
		func():
			PaymentManager.purchase(
				"level_pass",
				PAID_PASS_PRICE_RM,
				func():
					UserManager.has_paid_pass = true
					_update_buy_pass_btn()
					_refresh_all_claim_btns(),
				func(err: String): _show_alert(tr("UI_LEVEL_BUY_FAILED") + "\n" + err)
			)
	)

func _update_buy_pass_btn() -> void:
	if UserManager.has_paid_pass:
		buy_pass_btn.text     = tr("UI_LEVEL_PASS_ACTIVE")
		buy_pass_btn.disabled = true
		buy_pass_btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		buy_pass_btn.text     = "RM %.2f" % PAID_PASS_PRICE_RM
		buy_pass_btn.disabled = false
		buy_pass_btn.modulate = Color(0.8, 1.0, 0.65)

# ── 刷新所有行的按钮状态 ─────────────────────────────────────────────
func _refresh_all_claim_btns() -> void:
	for lv: int in _row_btns:
		var btns: Dictionary = _row_btns[lv]
		if "free_btn" in btns:
			_update_claim_btn(btns["free_btn"], lv, false)
		if "paid_btn" in btns:
			_update_claim_btn(btns["paid_btn"], lv, true)

## 刷新进度条着色（XP 变化时调用）
func _refresh_xp_bars() -> void:
	# 重新遍历 LevelsVBox，找到 TopFill/BotFill 并重新着色
	# LevelsVBox children 倒序对应 MAX_LEVEL→1
	for i: int in levels_vbox.get_child_count():
		var lv: int = MAX_LEVEL - i
		var row: HBoxContainer = levels_vbox.get_child(i)
		# center_bar 是中间那个子节点（索引 1）
		if row.get_child_count() < 2:
			continue
		var center_bar: VBoxContainer = row.get_child(1)
		if center_bar.get_child_count() < 3:
			continue
		var top_fill: ColorRect  = center_bar.get_child(0)
		var badge_panel: Panel   = center_bar.get_child(1)
		var bot_fill: ColorRect  = center_bar.get_child(2)
		var badge_lbl: Label     = badge_panel.get_child(0) if badge_panel.get_child_count() > 0 else null
		if badge_lbl != null:
			_apply_bar_colors(lv, top_fill, bot_fill, badge_panel, badge_lbl)

## 升级时刷新所有行（按钮 + 进度条）
func _on_level_changed(_new_level: int) -> void:
	_refresh_xp_bars()
	_refresh_all_claim_btns()

# ── 滚动到当前等级行 ─────────────────────────────────────────────────
func _scroll_to_current() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var cur_lv: int = UserManager.level
	# 在倒序列表中，等级 lv 的行索引 = MAX_LEVEL - lv
	var row_idx: int = MAX_LEVEL - cur_lv
	if row_idx < 0 or row_idx >= levels_vbox.get_child_count():
		return
	# 计算 Y 位置：每行 120px
	var target_y: float = row_idx * 120.0
	# 居中显示
	var visible_h: float = scroll_container.size.y
	scroll_container.scroll_vertical = int(max(0.0, target_y - visible_h / 2.0 + 60.0))

# ── 确认 / 提示弹窗 ───────────────────────────────────────────────────
func _show_confirm(message: String, on_confirm: Callable) -> void:
	_pending_action  = on_confirm
	confirm_msg.text = message
	cancel_btn.show()
	confirm_btn.text = tr("UI_DIALOG_CONFIRM")
	confirm_overlay.show()

func _show_alert(message: String) -> void:
	_pending_action  = Callable()
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

# ── 浮动一键领取按钮 ──────────────────────────────────────────────────────
var _claim_all_btn: Button = null

func _get_unclaimed_count() -> int:
	var cur_lv: int = UserManager.level
	var count: int = 0
	for lv: int in range(1, cur_lv + 1):
		if lv not in UserManager.claimed_free_rewards:
			count += 1
		if UserManager.has_paid_pass and lv not in UserManager.claimed_paid_rewards:
			count += 1
	return count

func _add_claim_all_btn() -> void:
	var unclaimed: int = _get_unclaimed_count()
	if unclaimed == 0:
		return

	var btn := Button.new()
	btn.name = "ClaimAllFloatBtn"
	btn.text = tr("UI_LEVEL_CLAIM_ALL") % unclaimed
	btn.custom_minimum_size = Vector2(260, 70)
	btn.size = Vector2(260, 70)
	btn.position = Vector2(20, 800)
	btn.add_theme_font_size_override("font_size", 28)
	btn.z_index = 10

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.45, 0.1, 0.95)
	style.corner_radius_top_left = 35
	style.corner_radius_top_right = 35
	style.corner_radius_bottom_left = 35
	style.corner_radius_bottom_right = 35
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.3, 1.0)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = style.bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.pressed.connect(_on_claim_all)
	$Card.add_child(btn)
	_claim_all_btn = btn

	# 浮动动画
	var tween := create_tween().set_loops()
	tween.tween_property(btn, "position:y", 788.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "position:y", 812.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_claim_all() -> void:
	var cur_lv: int = UserManager.level
	var claimed_count: int = 0
	for lv: int in range(1, cur_lv + 1):
		# 免费奖励
		if lv not in UserManager.claimed_free_rewards:
			var reward: Dictionary = _get_reward(lv, false)
			_apply_reward(reward)
			UserManager.claim_free_reward(lv)
			claimed_count += 1
		# 付费奖励
		if UserManager.has_paid_pass and lv not in UserManager.claimed_paid_rewards:
			var reward: Dictionary = _get_reward(lv, true)
			_apply_reward(reward)
			UserManager.claim_paid_reward(lv)
			claimed_count += 1
	# 刷新所有按钮状态
	_refresh_all_claim_btns()
	# 隐藏按钮
	if _claim_all_btn:
		_claim_all_btn.queue_free()
		_claim_all_btn = null
