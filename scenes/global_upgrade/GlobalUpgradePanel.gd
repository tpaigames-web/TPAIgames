## 波次全局升级选择面板（卡牌轮播版）
## 在特定波次暂停游戏后弹出，供玩家 3 选 1 选择永久强化升级
extends CanvasLayer

signal upgrade_chosen(upgrade: GlobalUpgradeData)

# ── 稀有度基础权重（波次加成前）──
const RARITY_WEIGHTS := [55, 32, 10, 3]   # 白/蓝/橙/红

# ── 稀有度卡框路径 ──
const RARITY_FRAMES: Array[String] = [
	"res://assets/sprites/Cards/Game Card_Upgrade_Grey.png",
	"res://assets/sprites/Cards/Game Card_Upgrade_Blue.png",
	"res://assets/sprites/Cards/Game Card_Upgrade_Orange.png",
	"res://assets/sprites/Cards/Game Card_Upgrade_Red.png",
]

# ── 稀有度颜色 ──
const RARITY_COLORS := [
	Color(0.70, 0.70, 0.72),
	Color(0.18, 0.42, 0.88),
	Color(0.88, 0.48, 0.08),
	Color(0.85, 0.15, 0.15),
]
const RARITY_TEXT_COLORS := [
	Color(0.85, 0.85, 0.85),
	Color(0.55, 0.82, 1.00),
	Color(1.00, 0.72, 0.30),
	Color(1.00, 0.30, 0.30),
]
## RARITY_NAMES built at runtime via _get_rarity_names() to support translation
func _get_rarity_names() -> Array[String]:
	return [tr("UI_GU_RARITY_COMMON"), tr("UI_GU_RARITY_RARE"), tr("UI_GU_RARITY_EPIC"), tr("UI_GU_RARITY_LEGENDARY")]

# ── 卡牌插图映射（upgrade_id → 图片路径）──
const CARD_ART: Dictionary = {
	"synergy_cannon_watch": "res://assets/sprites/Cards/CU_01.png",
	"synergy_hero_all":     "res://assets/sprites/Cards/CU_02.png",
	"syn_bow_mark":         "res://assets/sprites/Cards/CU_03.png",
}

# ── 第 0 波测试卡 ID ──
const WAVE0_TEST_IDS: Array[String] = [
	"synergy_cannon_watch",
	"synergy_hero_all",
	"syn_bow_mark",
]

# ── 保底计数 ──
var _no_epic_count: int = 0
const PITY_THRESHOLD: int = 3
var _wave_num: int = 0

# ── 炮台 ID → 显示名称（通过翻译系统）──
func _get_tower_name(tid: String) -> String:
	return TowerResourceRegistry.get_tower_display_name(tid, tid)

const ICON_COL_W := 110

# ── 刷新费用 ──
const REFRESH_COST_GOLD := 100
const REFRESH_COST_GEMS := 5
const REFRESH_GOLD_MIN  := 300

# ── 卡牌轮播参数 ──
const CARD_W := 780.0
const CARD_H := 1100.0
const SIDE_SCALE := 0.7
const SIDE_ROTATION := 12.0    # 度
const TWEEN_DURATION := 0.25

# 动态计算的中心点（在 _ready 中初始化）
var CARD_CENTER_X: float = 540.0
var CARD_CENTER_Y: float = 560.0
var SIDE_OFFSET_X: float = 400.0

# ── 节点引用 ──
@onready var _card_container: Control       = $Content/CardArea/CardContainer
@onready var _left_btn: TextureButton       = $Content/CardArea/LeftBtn
@onready var _right_btn: TextureButton      = $Content/CardArea/RightBtn
@onready var _confirm_btn: TextureButton    = $Content/ConfirmBtn
@onready var _refresh_btn: TextureButton    = $Content/RefreshRow/RefreshBtn
@onready var _cost_icon: TextureRect        = $Content/RefreshRow/CostIcon
@onready var _cost_label: Label             = $Content/RefreshRow/CostLabel

var _choices: Array[GlobalUpgradeData] = []
var _current_index: int = 1   # 默认选中中间卡
var _card_nodes: Array[Control] = []

# 保存 setup() 参数，供刷新时重新抽取
var _pool_ref:   Array = []
var _active_ref: Array = []
var _wave_ref:   int   = 0

# 预缓存纹理
var _frame_textures: Array[Texture2D] = []
var _art_textures: Dictionary = {}

# 滑动手势
var _swipe_start_x: float = 0.0
var _swiping: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	_left_btn.pressed.connect(_on_left)
	_right_btn.pressed.connect(_on_right)
	# 预加载卡框纹理
	for path in RARITY_FRAMES:
		var tex := load(path) as Texture2D
		_frame_textures.append(tex)
	# 预加载卡牌插图
	for uid in CARD_ART:
		var tex := load(CARD_ART[uid]) as Texture2D
		if tex:
			_art_textures[uid] = tex


func _update_center_from_viewport() -> void:
	# 卡牌位置相对于 CardArea，不是 viewport
	var area_size := _card_container.size
	if area_size.x <= 0 or area_size.y <= 0:
		# CardArea 还没布局完成，用默认值
		area_size = Vector2(1080, 1100)
	CARD_CENTER_X = area_size.x / 2.0
	CARD_CENTER_Y = area_size.y / 2.0 - CARD_H * 0.1  # 稍微偏上
	SIDE_OFFSET_X = area_size.x * 0.37


func setup(pool: Array, active: Array, wave_num: int) -> void:
	if not is_inside_tree():
		await ready
	# 等一帧让布局完成
	await get_tree().process_frame
	_update_center_from_viewport()
	_pool_ref   = pool
	_active_ref = active
	_wave_ref   = wave_num
	_wave_num   = wave_num

	# 第 0 波强制使用测试卡
	if wave_num == 0:
		_choices = _get_wave0_test_cards(pool)
	else:
		var filtered := _filter_pool(pool, active, wave_num)
		_choices = _roll_choices(filtered)

	if _choices.is_empty():
		push_warning("GlobalUpgradePanel: No upgrades for wave %d" % wave_num)
	else:
		print("GlobalUpgradePanel: %d choices for wave %d" % [_choices.size(), wave_num])

	_build_cards()
	_current_index = mini(1, _choices.size() - 1)
	_update_carousel_instant()
	_update_refresh_btn()


# ── 第 0 波测试卡 ────────────────────────────────────────────────────────────
func _get_wave0_test_cards(pool: Array) -> Array[GlobalUpgradeData]:
	var result: Array[GlobalUpgradeData] = []
	for test_id in WAVE0_TEST_IDS:
		for upg_raw in pool:
			var upg := upg_raw as GlobalUpgradeData
			if upg and upg.upgrade_id == test_id:
				result.append(upg)
				break
	return result


# ── 池过滤 ──────────────────────────────────────────────────────────────────
func _filter_pool(pool: Array, active: Array, wave_num: int) -> Array:
	var active_ids: Array[String] = []
	for upg in active:
		active_ids.append((upg as GlobalUpgradeData).upgrade_id)

	var result: Array = []
	for upg_raw in pool:
		var upg := upg_raw as GlobalUpgradeData
		if upg == null:
			continue
		if wave_num == 0 and upg.rarity > 0:
			continue
		if upg.upgrade_id in active_ids:
			continue
		if not _is_upgrade_unlocked(upg):
			continue
		result.append(upg)
	return result


func _is_upgrade_unlocked(upg: GlobalUpgradeData) -> bool:
	if upg.target_tower_id != "":
		if CollectionManager.get_tower_status(upg.target_tower_id) < 2:
			return false
	for tid in upg.target_tower_ids:
		if CollectionManager.get_tower_status(tid) < 2:
			return false
	for tid in upg.required_tower_ids:
		if CollectionManager.get_tower_status(tid) < 2:
			return false
	return true


# ── 计算动态权重 ────────────────────────────────────────────────────────────
func _get_adjusted_weights() -> Array[int]:
	var w: Array[int] = []
	for v in RARITY_WEIGHTS:
		w.append(v)
	var wave_tier: int = _wave_num / 10
	var orange_boost: int = wave_tier * 2
	var red_boost: int = wave_tier
	if w.size() > 2:
		w[2] += orange_boost
	if w.size() > 3:
		w[3] += red_boost
	w[0] = maxi(w[0] - orange_boost - red_boost, 10)
	if _no_epic_count >= PITY_THRESHOLD:
		if w.size() > 2:
			w[2] *= 3
		if w.size() > 3:
			w[3] *= 2
		w[0] = maxi(w[0] / 2, 5)
	return w


# ── 加权随机抽 3 张 ──────────────────────────────────────────────────────────
func _roll_choices(filtered: Array) -> Array[GlobalUpgradeData]:
	if filtered.is_empty():
		return []

	var adjusted_w: Array[int] = _get_adjusted_weights()
	var result: Array[GlobalUpgradeData] = []
	var remaining := filtered.duplicate()
	remaining.shuffle()

	var tries := 0
	while result.size() < 3 and not remaining.is_empty() and tries < 100:
		tries += 1
		var total_w := 0
		var weight_map: Array = []
		for upg in remaining:
			var rw: int = clampi((upg as GlobalUpgradeData).rarity, 0, adjusted_w.size() - 1)
			var w: int = adjusted_w[rw]
			total_w += w
			weight_map.append(w)

		if total_w <= 0:
			break

		var rand_val := randi() % total_w
		var cumulative := 0
		for i in weight_map.size():
			cumulative += weight_map[i]
			if rand_val < cumulative:
				result.append(remaining[i] as GlobalUpgradeData)
				remaining.remove_at(i)
				break

	var has_epic: bool = false
	for upg in result:
		if upg.rarity >= 2:
			has_epic = true
			break
	if has_epic:
		_no_epic_count = 0
	else:
		_no_epic_count += 1

	return result


# ── 数值示例 ────────────────────────────────────────────────────────────────
func _build_example_str(upg: GlobalUpgradeData) -> String:
	var bonus: float = upg.stat_bonus
	var tid: String  = upg.target_tower_id
	if tid == "" and upg.target_tower_ids.size() > 0:
		tid = upg.target_tower_ids[0]

	if tid != "":
		var td: TowerCollectionData = null
		for res in TowerResourceRegistry.get_all_resources():
			if res.tower_id == tid:
				td = res
				break
		if td:
			match upg.stat_type:
				GlobalUpgradeData.StatType.DAMAGE:
					if td.base_damage > 0:
						return tr("UI_GU_EX_DMG") % [td.base_damage, td.base_damage * (1.0 + bonus)]
				GlobalUpgradeData.StatType.SPEED:
					var ni := td.attack_speed / (1.0 + bonus)
					return tr("UI_GU_EX_SPD") % [td.attack_speed, ni]
				GlobalUpgradeData.StatType.RANGE:
					return tr("UI_GU_EX_RNG") % [td.attack_range, td.attack_range * (1.0 + bonus)]
				GlobalUpgradeData.StatType.COST:
					var nc := int(td.placement_cost * (1.0 - bonus))
					return tr("UI_GU_EX_COST") % [td.placement_cost, nc]

	match upg.stat_type:
		GlobalUpgradeData.StatType.DAMAGE:
			return tr("UI_GU_EX_DMG") % [100, 100.0 * (1.0 + bonus)]
		GlobalUpgradeData.StatType.SPEED:
			return tr("UI_GU_EX_SPD_PCT") % (bonus * 100.0)
		GlobalUpgradeData.StatType.RANGE:
			return tr("UI_GU_EX_RNG") % [100, 100.0 * (1.0 + bonus)]
		GlobalUpgradeData.StatType.COST:
			return tr("UI_GU_EX_COST_PCT") % (bonus * 100.0)
	return ""


# ══════════════════════════════════════════════════════════════════════════════
#  卡牌轮播
# ══════════════════════════════════════════════════════════════════════════════

func _build_cards() -> void:
	# 清除旧卡牌
	for child in _card_container.get_children():
		_card_container.remove_child(child)
		child.queue_free()
	_card_nodes.clear()

	if _choices.is_empty():
		return

	for i in _choices.size():
		var upg: GlobalUpgradeData = _choices[i]
		var card := _create_card(upg)
		card.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
		_card_container.add_child(card)
		_card_nodes.append(card)


func _create_card(upg: GlobalUpgradeData) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var r: int = clampi(upg.rarity, 0, RARITY_FRAMES.size() - 1)

	# ── 插图 ──
	var art_rect := TextureRect.new()
	art_rect.position = Vector2.ZERO
	art_rect.size = Vector2(CARD_W, CARD_H)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _art_textures.has(upg.upgrade_id):
		art_rect.texture = _art_textures[upg.upgrade_id]
	else:
		# 没有插图时用 emoji 占位
		var emoji_lbl := Label.new()
		emoji_lbl.text = upg.icon_emoji
		emoji_lbl.add_theme_font_size_override("font_size", 120)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.size = Vector2(CARD_W, CARD_H * 0.5)
		emoji_lbl.position = Vector2(0, CARD_H * 0.05)
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(emoji_lbl)

	card.add_child(art_rect)

	# ── 卡框（覆盖在插图上方）──
	var frame_rect := TextureRect.new()
	frame_rect.position = Vector2.ZERO
	frame_rect.size = Vector2(CARD_W, CARD_H)
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r < _frame_textures.size() and _frame_textures[r]:
		frame_rect.texture = _frame_textures[r]
	card.add_child(frame_rect)

	# ── 文字信息区（卡牌内部下半，调整 info_y 控制上下位置）──
	var info_y := CARD_H * 0.58   # ≈ 卡框内下半区域起点，可自行调整
	var info_w := 640.0           # ≈ 13 中文字宽度
	var info_x := (CARD_W - info_w) / 2.0  # 居中

	# 名称（56px, 暗色）
	var name_lbl := Label.new()
	name_lbl.text = upg.display_name
	name_lbl.position = Vector2(info_x, info_y)
	name_lbl.size = Vector2(info_w, 64)
	name_lbl.add_theme_font_size_override("font_size", 56)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.clip_text = true
	card.add_child(name_lbl)

	# 稀有度（38px）
	var rarity_lbl := Label.new()
	rarity_lbl.text = "【%s】" % _get_rarity_names()[r]
	rarity_lbl.position = Vector2(info_x, info_y + 68)
	rarity_lbl.size = Vector2(info_w, 44)
	rarity_lbl.add_theme_font_size_override("font_size", 38)
	rarity_lbl.add_theme_color_override("font_color", RARITY_TEXT_COLORS[r])
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rarity_lbl)

	# 效果描述（48px）
	var desc_text := upg.description
	if upg.upgrade_type == GlobalUpgradeData.UpgradeType.SYNERGY:
		var nl := desc_text.find("\n")
		if nl >= 0 and (desc_text.begins_with("需要：") or desc_text.begins_with("Requires:") or desc_text.begins_with("Memerlukan:")):
			desc_text = desc_text.substr(nl + 1)

	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.position = Vector2(info_x, info_y + 118)
	desc_lbl.size = Vector2(info_w, 160)
	desc_lbl.add_theme_font_size_override("font_size", 48)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	desc_lbl.add_theme_constant_override("shadow_offset_y", 2)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)

	# 羁绊条件（32px, 黄色, 放在卡牌下方避免超出卡框）
	if upg.required_tower_ids.size() > 0:
		var id_names: Array[String] = []
		for tid in upg.required_tower_ids:
			id_names.append(_get_tower_name(tid))
		var cond_lbl := Label.new()
		cond_lbl.text = tr("UI_GU_REQUIRES") % ", ".join(id_names)
		cond_lbl.position = Vector2(info_x, CARD_H + 10)
		cond_lbl.size = Vector2(info_w, 80)
		cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		cond_lbl.add_theme_font_size_override("font_size", 32)
		cond_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cond_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		cond_lbl.add_theme_constant_override("shadow_offset_y", 2)
		cond_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cond_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cond_lbl)

	return card


# ── 轮播位置更新（无动画）──
func _update_carousel_instant() -> void:
	if _card_nodes.is_empty():
		return
	for i in _card_nodes.size():
		var card := _card_nodes[i]
		var offset := i - _current_index
		_apply_carousel_transform(card, offset, false)
	_update_nav_buttons()


# ── 轮播位置更新（Tween 动画）──
func _update_carousel_animated() -> void:
	if _card_nodes.is_empty():
		return
	for i in _card_nodes.size():
		var card := _card_nodes[i]
		var offset := i - _current_index
		_apply_carousel_transform(card, offset, true)
	_update_nav_buttons()


func _apply_carousel_transform(card: Control, offset: int, animated: bool) -> void:
	var target_pos := Vector2.ZERO
	var target_scale := Vector2.ONE
	var target_rot := 0.0
	var target_mod := Color.WHITE
	var target_z := 0

	if offset == 0:
		# 中间卡
		target_pos = Vector2(CARD_CENTER_X - CARD_W / 2.0, CARD_CENTER_Y - CARD_H / 2.0)
		target_scale = Vector2(1.0, 1.0)
		target_rot = 0.0
		target_mod = Color.WHITE
		target_z = 1
	elif offset < 0:
		# 左卡
		target_pos = Vector2(CARD_CENTER_X - CARD_W / 2.0 - SIDE_OFFSET_X, CARD_CENTER_Y - CARD_H / 2.0 + 40)
		target_scale = Vector2(SIDE_SCALE, SIDE_SCALE)
		target_rot = deg_to_rad(-SIDE_ROTATION)
		target_mod = Color(0.5, 0.5, 0.5, 0.7)
		target_z = 0
	else:
		# 右卡
		target_pos = Vector2(CARD_CENTER_X - CARD_W / 2.0 + SIDE_OFFSET_X, CARD_CENTER_Y - CARD_H / 2.0 + 40)
		target_scale = Vector2(SIDE_SCALE, SIDE_SCALE)
		target_rot = deg_to_rad(SIDE_ROTATION)
		target_mod = Color(0.5, 0.5, 0.5, 0.7)
		target_z = 0

	card.z_index = target_z

	if animated:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target_pos, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "scale", target_scale, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "rotation", target_rot, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "modulate", target_mod, TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		card.position = target_pos
		card.scale = target_scale
		card.rotation = target_rot
		card.modulate = target_mod


func _update_nav_buttons() -> void:
	_left_btn.visible = _current_index > 0
	_right_btn.visible = _current_index < _card_nodes.size() - 1


func _on_left() -> void:
	if _current_index > 0:
		_current_index -= 1
		_update_carousel_animated()


func _on_right() -> void:
	if _current_index < _card_nodes.size() - 1:
		_current_index += 1
		_update_carousel_animated()


# ── 确认按钮 ─────────────────────────────────────────────────────────────────
# ── 触控滑动 ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_x = event.position.x
			_swiping = true
		else:
			if _swiping:
				var dx: float = event.position.x - _swipe_start_x
				if dx < -80.0:
					_on_right()
				elif dx > 80.0:
					_on_left()
				_swiping = false
	elif event is InputEventMouseButton:
		# 鼠标也支持左右拖拽
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_swipe_start_x = event.position.x
				_swiping = true
			else:
				if _swiping:
					var dx: float = event.position.x - _swipe_start_x
					if dx < -80.0:
						_on_right()
					elif dx > 80.0:
						_on_left()
					_swiping = false


func _on_confirm_pressed() -> void:
	if _current_index < 0 or _current_index >= _choices.size():
		return
	upgrade_chosen.emit(_choices[_current_index])
	queue_free()


# ── 刷新按钮 ─────────────────────────────────────────────────────────────────
func _on_refresh_pressed() -> void:
	if GameManager.gold > REFRESH_GOLD_MIN:
		GameManager.spend_gold(REFRESH_COST_GOLD)
	elif UserManager.gems >= REFRESH_COST_GEMS:
		UserManager.spend_gems(REFRESH_COST_GEMS)
	else:
		return

	var filtered := _filter_pool(_pool_ref, _active_ref, _wave_ref)
	_choices = _roll_choices(filtered)
	_build_cards()
	_current_index = mini(1, _choices.size() - 1)
	_update_carousel_instant()
	_update_refresh_btn()


## 根据当前余额更新刷新按钮费用显示
var _coin_tex: Texture2D = preload("res://assets/sprites/ui/Coin.png")
var _diamond_tex: Texture2D = preload("res://assets/sprites/ui/Diamond.png")

func _update_refresh_btn() -> void:
	var coin_tex := _coin_tex
	var diamond_tex := _diamond_tex

	if GameManager.gold > REFRESH_GOLD_MIN:
		_cost_icon.texture = coin_tex
		_cost_label.text = "%d" % REFRESH_COST_GOLD
		_refresh_btn.modulate = Color.WHITE
		_refresh_btn.disabled = false
	elif UserManager.gems >= REFRESH_COST_GEMS:
		_cost_icon.texture = diamond_tex
		_cost_label.text = "%d" % REFRESH_COST_GEMS
		_refresh_btn.modulate = Color(0.8, 0.9, 1.0)
		_refresh_btn.disabled = false
	else:
		_cost_icon.texture = coin_tex
		_cost_label.text = tr("UI_GU_INSUFFICIENT")
		_refresh_btn.modulate = Color(0.5, 0.5, 0.5)
		_refresh_btn.disabled = true
