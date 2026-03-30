extends CanvasLayer

# ── 常量 ─────────────────────────────────────────────────────────────
# 稀有度常量引用（集中定义于 TowerResourceRegistry Autoload）
## Attack type names resolved at runtime via tr()
static func _get_atk_type_names() -> Array[String]:
	return [tr("UI_ATK_GROUND"), tr("UI_ATK_AIR"), tr("UI_ATK_ALL")]

const COLOR_OWNED:     Color = Color(1.0,  0.75, 0.1,  1.0)   # 金色：已解锁
const COLOR_AVAILABLE: Color = Color(0.2,  0.9,  0.3,  1.0)   # 绿色：可升级（资源充足）
const COLOR_LOCKED_RES:Color = Color(1.0,  0.45, 0.15, 1.0)   # 橙红：资源不足
const COLOR_LOCKED:    Color = Color(0.35, 0.35, 0.35, 1.0)   # 灰色：未到达

## 升级方向碎片消耗表：TIER_FRAG_COSTS[rarity][tier_idx]
## 稀有度 0=白 1=绿 2=蓝 3=紫 4=橙，tier_idx 0~4 对应第1~5层
const TIER_FRAG_COSTS: Array = [
	[30, 45, 60, 75,  90],   # 白
	[35, 50, 65, 80,  95],   # 绿
	[40, 55, 70, 85, 100],   # 蓝
	[45, 60, 75, 90, 105],   # 紫
	[50, 65, 80, 95, 110],   # 橙
]

# ── 节点引用 ─────────────────────────────────────────────────────────
@onready var close_btn:      Button         = $MainCard/CloseBtn
@onready var icon_emoji:     Label          = $MainCard/ContentScroll/ContentVBox/TopRow/IconFrame/IconEmoji
@onready var icon_tex:       TextureRect    = $MainCard/ContentScroll/ContentVBox/TopRow/IconFrame/IconTex
@onready var tower_name_lbl: Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/TowerNameLabel
@onready var rarity_lbl:     Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/RarityLabel
@onready var dmg_val:        Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/DmgRow/DmgVal
@onready var spd_val:        Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/SpdRow/SpdVal
@onready var rng_val:        Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/RngRow/RngVal
@onready var frags_label:    Label          = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/FragsRow/FragsLabel
@onready var unlock_btn:     Button         = $MainCard/ContentScroll/ContentVBox/TopRow/StatsVBox/FragsRow/UnlockBtn
@onready var effect_label:   Label          = $MainCard/ContentScroll/ContentVBox/EffectLabel
@onready var paths_vbox:     VBoxContainer  = $MainCard/ContentScroll/ContentVBox/PathsVBox
@onready var hint_label:     Label          = $MainCard/ContentScroll/ContentVBox/HintLabel
@onready var tooltip_panel:  Panel          = $MainCard/TooltipPanel
@onready var tooltip_label:  Label          = $MainCard/TooltipPanel/TooltipLabel
@onready var dim_bg:         ColorRect      = $DimBg

# 确认弹窗节点
@onready var confirm_overlay:   Panel  = $MainCard/ConfirmOverlay
@onready var confirm_msg_label: Label  = $MainCard/ConfirmOverlay/ConfirmCard/ConfirmMsgLabel
@onready var confirm_yes_btn:   Button = $MainCard/ConfirmOverlay/ConfirmCard/BtnRow/ConfirmYesBtn
@onready var confirm_no_btn:    Button = $MainCard/ConfirmOverlay/ConfirmCard/BtnRow/ConfirmNoBtn

# ── 状态 ─────────────────────────────────────────────────────────────
var _data: TowerCollectionData = null
var _pending_confirm: Callable = Callable()

# ── 入口 ─────────────────────────────────────────────────────────────
func setup(data: TowerCollectionData) -> void:
	_data = data
	_populate()

# ── 初始化连接 ────────────────────────────────────────────────────────
func _ready() -> void:
	close_btn.pressed.connect(_close)
	unlock_btn.pressed.connect(_on_unlock_pressed)
	dim_bg.gui_input.connect(_on_dim_input)
	$MainCard.gui_input.connect(_on_main_card_input)
	confirm_yes_btn.pressed.connect(_on_confirm_yes)
	confirm_no_btn.pressed.connect(_on_confirm_no)
	# 监听碎片/解锁变化，自动刷新头部碎片数与解锁按钮状态
	CollectionManager.collection_changed.connect(_on_collection_changed)

func _on_collection_changed() -> void:
	if _data == null:
		return
	var status: int = CollectionManager.get_tower_status(_data.tower_id)
	_fill_header(status)
	_update_unlock_area(status)

# ── 确认弹窗系统 ──────────────────────────────────────────────────────
func _show_confirm(message: String, on_confirm: Callable) -> void:
	_pending_confirm = on_confirm
	confirm_msg_label.text = message
	tooltip_panel.hide()  # 隐藏 tooltip 避免层叠
	confirm_overlay.show()
	# 确保 ConfirmOverlay 在最上层
	$MainCard.move_child(confirm_overlay, $MainCard.get_child_count() - 1)

func _on_confirm_yes() -> void:
	confirm_overlay.hide()
	if _pending_confirm.is_valid():
		_pending_confirm.call()
	_pending_confirm = Callable()

func _on_confirm_no() -> void:
	confirm_overlay.hide()
	_pending_confirm = Callable()

# ── 填充界面 ──────────────────────────────────────────────────────────
func _populate() -> void:
	var status: int = CollectionManager.get_tower_status(_data.tower_id)
	_fill_header(status)
	effect_label.text = tr("UI_DETAIL_EFFECT") % (_data.effect_description if _data.effect_description != "" else tr("UI_DETAIL_EFFECT_TBD"))
	_build_paths(status)
	_update_unlock_area(status)
	tooltip_panel.hide()
	confirm_overlay.hide()

func _fill_header(status: int) -> void:
	icon_emoji.text = _data.tower_emoji
	if _data.collection_texture:
		icon_tex.texture = _data.collection_texture
	elif _data.icon_texture:
		icon_tex.texture = _data.icon_texture
	tower_name_lbl.text = TowerResourceRegistry.tr_tower_name(_data)
	rarity_lbl.text     = tr("UI_DETAIL_RARITY") % TowerResourceRegistry.RARITY_NAMES[_data.rarity]
	rarity_lbl.modulate = TowerResourceRegistry.RARITY_COLORS[_data.rarity]
	dmg_val.text = "%.0f" % _data.base_damage  if _data.base_damage  > 0.0 else "—"
	spd_val.text = "%.1f" % _data.attack_speed if _data.attack_speed > 0.0 else "—"
	rng_val.text = "%.0f" % _data.attack_range if _data.attack_range > 0.0 else "—"
	var owned: int = CollectionManager.get_fragments(_data.tower_id)
	frags_label.text = tr("UI_DETAIL_FRAGS") % [owned, _data.unlock_fragments]

func _update_unlock_area(status: int) -> void:
	match status:
		0:  # 等级不足（防御性处理，不应出现在此界面）
			unlock_btn.text     = tr("UI_DETAIL_LEVEL_INSUFFICIENT")
			unlock_btn.disabled = true
			hint_label.hide()
		1:  # 等级已到，未用碎片解锁
			var owned: int = CollectionManager.get_fragments(_data.tower_id)
			unlock_btn.text     = tr("UI_DETAIL_UNLOCK_BTN") % _data.unlock_fragments
			unlock_btn.disabled = (owned < _data.unlock_fragments)
			hint_label.text = tr("UI_DETAIL_UNLOCK_HINT")
			hint_label.show()
		2:  # 已解锁
			unlock_btn.text     = tr("UI_DETAIL_UNLOCKED")
			unlock_btn.disabled = true
			hint_label.hide()

# ── 升级路径构建 ──────────────────────────────────────────────────────
func _build_paths(status: int) -> void:
	for child in paths_vbox.get_children():
		child.queue_free()
	if _data.upgrade_paths.is_empty():
		var placeholder := Label.new()
		placeholder.text = tr("UI_DETAIL_PATHS_TBD")
		placeholder.add_theme_font_size_override("font_size", 24)
		placeholder.modulate = Color(1, 1, 1, 0.45)
		paths_vbox.add_child(placeholder)
		return
	for i: int in _data.upgrade_paths.size():
		paths_vbox.add_child(_make_path_row(i, _data.upgrade_paths[i], status))

func _make_path_row(path_idx: int, path_data: TowerUpgradePath, status: int) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "【%s】" % path_data.path_name
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var current_tier: int = CollectionManager.get_path_level(_data.tower_id, path_idx)
	for tier_idx: int in 5:
		hbox.add_child(_make_tier_btn(path_idx, tier_idx, path_data, current_tier, status))

	return vbox

func _make_tier_btn(path_idx: int, tier_idx: int, path_data: TowerUpgradePath,
		current_tier: int, status: int) -> Control:

	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(168, 0)
	container.alignment = BoxContainer.ALIGNMENT_BEGIN
	container.add_theme_constant_override("separation", 4)

	var btn := Panel.new()
	btn.custom_minimum_size = Vector2(168, 168)

	# ── 费用计算 ──────────────────────────────────────────────────────
	var rarity: int      = clampi(_data.rarity, 0, TIER_FRAG_COSTS.size() - 1)
	var frag_cost: int   = TIER_FRAG_COSTS[rarity][tier_idx]
	var gold_cost: int   = path_data.tier_costs[tier_idx] if tier_idx < path_data.tier_costs.size() else 0
	var owned_frags: int = CollectionManager.get_fragments(_data.tower_id)

	# ── 状态判断 ──────────────────────────────────────────────────────
	var is_owned:      bool = (tier_idx < current_tier)
	var is_next:       bool = (tier_idx == current_tier and status == 2)
	var is_affordable: bool = is_next and (owned_frags >= frag_cost) and (UserManager.gold >= gold_cost)
	# is_next 但资源不足
	var is_locked_res: bool = is_next and not is_affordable

	# ── 背景颜色 ──────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_owned:
		bg.color = Color(0.5, 0.4, 0.05, 0.85)
	elif is_affordable:
		bg.color = Color(0.05, 0.4, 0.1, 0.85)
	elif is_locked_res:
		bg.color = Color(0.45, 0.12, 0.02, 0.85)
	else:
		bg.color = Color(0.15, 0.15, 0.18, 0.85)
	btn.add_child(bg)

	# ── 层级序号角标 ──────────────────────────────────────────────────
	var tier_num := Label.new()
	tier_num.text = str(tier_idx + 1)
	tier_num.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tier_num.offset_right  = 30.0
	tier_num.offset_bottom = 30.0
	tier_num.add_theme_font_size_override("font_size", 20)
	tier_num.modulate = Color(1, 1, 1, 0.45)
	tier_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tier_num)

	# ── 中央图标 ──────────────────────────────────────────────────────
	var icon_lbl := Label.new()
	icon_lbl.text = "★" if is_owned else ("▶" if is_affordable else ("!" if is_locked_res else "◆"))
	icon_lbl.set_anchors_preset(Control.PRESET_CENTER)
	icon_lbl.offset_left   = -28.0
	icon_lbl.offset_top    = -28.0
	icon_lbl.offset_right  =  28.0
	icon_lbl.offset_bottom =  28.0
	icon_lbl.add_theme_font_size_override("font_size", 40)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	if is_owned:
		icon_lbl.modulate = COLOR_OWNED
	elif is_affordable:
		icon_lbl.modulate = COLOR_AVAILABLE
	elif is_locked_res:
		icon_lbl.modulate = COLOR_LOCKED_RES
	else:
		icon_lbl.modulate = Color(0.5, 0.5, 0.5)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon_lbl)

	container.add_child(btn)

	# ── 层级名称（按钮下方） ──────────────────────────────────────────
	var t_name: String = path_data.tier_names[tier_idx] if tier_idx < path_data.tier_names.size() else "—"
	var name_lbl := Label.new()
	name_lbl.text = t_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not is_owned and not is_next:
		name_lbl.modulate = Color(1, 1, 1, 0.4)
	container.add_child(name_lbl)

	# ── 费用标签（仅下一层显示） ─────────────────────────────────────
	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_owned:
		cost_lbl.text = "✓"
		cost_lbl.modulate = COLOR_OWNED
	elif is_next:
		cost_lbl.text = "%d💎  %d💰" % [frag_cost, gold_cost]
		cost_lbl.modulate = Color(0.4, 1.0, 0.5) if is_affordable else Color(1.0, 0.45, 0.3)
	else:
		cost_lbl.text = ""
	container.add_child(cost_lbl)

	# ── 点击回调 ──────────────────────────────────────────────────────
	var effect_text: String = path_data.tier_effects[tier_idx] if tier_idx < path_data.tier_effects.size() else tr("UI_DETAIL_EFFECT_TBD")
	# 提前捕获本次循环的不可变值（避免闭包捕获可变引用）
	var captured_t_name: String     = t_name
	var captured_effect: String     = effect_text
	var captured_frag: int          = frag_cost
	var captured_gold: int          = gold_cost
	var captured_path_name: String  = path_data.path_name
	var captured_affordable: bool   = is_affordable

	btn.gui_input.connect(
		func(event: InputEvent):
			if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				return
			# 任意状态都可以查看效果 tooltip
			_show_tooltip(btn, captured_t_name, captured_effect)
			# 只有资源充足时直接执行升级（实时校验防止重复点击）
			if captured_affordable:
				# 实时校验资源是否仍足够（防止快速双击重复扣费）
				if CollectionManager.get_fragments(_data.tower_id) < captured_frag:
					return
				if UserManager.gold < captured_gold:
					return
				# 通过 API 扣除碎片
				if not CollectionManager.spend_fragments(_data.tower_id, captured_frag):
					return
				# 扣除金币
				UserManager.spend_gold(captured_gold)
				# 执行升级
				if CollectionManager.unlock_path_tier(_data.tower_id, path_idx):
					var s: int = CollectionManager.get_tower_status(_data.tower_id)
					_build_paths(s)
					_fill_header(s)
					SaveManager.save()
	)

	return container

# ── Tooltip 系统 ──────────────────────────────────────────────────────
func _show_tooltip(anchor_node: Control, tier_name: String, effect_text: String) -> void:
	tooltip_label.text = "【%s】\n%s" % [tier_name, effect_text]
	var anchor_pos: Vector2 = anchor_node.get_global_position() - $MainCard.get_global_position()
	var tp_w: float = 640.0
	var tp_h: float = 160.0
	tooltip_panel.offset_left   = clampf(anchor_pos.x - 20.0, 0.0, 1020.0 - tp_w)
	tooltip_panel.offset_top    = maxf(anchor_pos.y - tp_h - 8.0, 10.0)
	tooltip_panel.offset_right  = tooltip_panel.offset_left + tp_w
	tooltip_panel.offset_bottom = tooltip_panel.offset_top  + tp_h
	tooltip_panel.show()
	$MainCard.move_child(tooltip_panel, $MainCard.get_child_count() - 1)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if confirm_overlay.visible:
			return  # 弹窗打开时暗色背景不关闭界面
		if tooltip_panel.visible:
			tooltip_panel.hide()
		else:
			_close()

func _on_main_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not confirm_overlay.visible and tooltip_panel.visible:
			tooltip_panel.hide()

# ── 解锁按钮（带确认弹窗） ────────────────────────────────────────────
func _on_unlock_pressed() -> void:
	var cost: int  = _data.unlock_fragments
	var owned: int = CollectionManager.get_fragments(_data.tower_id)
	if owned < cost:
		return  # 碎片不足（按钮理应已禁用）
	# 直接解锁，无需二次确认
	if CollectionManager.unlock_tower_with_fragments(_data.tower_id, cost):
		_populate()
		SaveManager.save()

# ── 关闭 ─────────────────────────────────────────────────────────────
func _close() -> void:
	queue_free()
