extends CanvasLayer

## 稀有度常量（白→绿→蓝→紫→橙，从最常见到最稀有）
const RARITY_WHITE  = 0
const RARITY_GREEN  = 1
const RARITY_BLUE   = 2
const RARITY_PURPLE = 3
const RARITY_ORANGE = 4

# 稀有度常量引用（集中定义于 TowerResourceRegistry Autoload）

## 翻牌动画参数
const FLIP_HALF_DURATION = 0.15   # 半程翻牌时间（秒）
const FLIP_PAUSE = 0.08           # 翻完一张后的停顿（秒）

## 卡片布局参数（5:8 比例）
const CARDS_PER_ROW := 3
const CARD_W := 180
const CARD_H := 288               # 5:8 = 180×288
const ROW_SEP := 20

## 10 连开箱用缩小布局
const BULK_CARDS_PER_ROW := 5
const BULK_CARD_W := 140
const BULK_CARD_H := 224           # 5:8 = 140×224
const BULK_ROW_SEP := 12

## 炮台资源路径（集中定义于 TowerResourceRegistry Autoload）

## 每个结果：{rarity:int, tower:TowerCollectionData, fragments:int}
var _results: Array[Dictionary] = []
var _reveal_cards: Array[Control] = []
var _is_animating: bool = false
var _active_tween: Tween = null

## 按稀有度分组的炮台资源：{rarity → [TowerCollectionData, ...]}
var _towers_by_rarity: Dictionary = {}

@onready var chest_stage:      Control       = $ChestStage
@onready var chest_rect:       ColorRect     = $ChestStage/ChestRect
@onready var cards_stage:      Control       = $CardsStage
@onready var cards_container:  VBoxContainer = $CardsStage/CardsContainer
@onready var skip_button:      Button        = $SkipButton
@onready var continue_button:  Button        = $ContinueButton

func setup(data: ChestData, count: int = 1) -> void:
	# 先确保资源已加载（防止 setup 在 _ready 之前被调用时 _towers_by_rarity 为空）
	_load_tower_resources()
	# 结果在点击前就已决定，保证公平
	# count > 1 时为 10 连开箱，重复 roll count 次合并结果
	_results.clear()
	for _i in count:
		_results.append_array(_roll_results(data))

func _ready() -> void:
	# 加载炮台资源（若 setup 已经调用过则直接跳过）
	_load_tower_resources()
	chest_rect.gui_input.connect(_on_chest_tapped)
	skip_button.pressed.connect(_skip_all)
	continue_button.pressed.connect(_on_continue)

## 加载炮台资源并按稀有度分组（委托给 TowerResourceRegistry）
func _load_tower_resources() -> void:
	if not _towers_by_rarity.is_empty():
		return
	_towers_by_rarity = TowerResourceRegistry.get_towers_by_rarity()

# ───── 结果计算 ─────

func _roll_results(data: ChestData) -> Array[Dictionary]:
	var weights: Array[int] = [
		data.white_weight,
		data.green_weight,
		data.blue_weight,
		data.purple_weight,
		data.orange_weight,
	]
	var total: int = 0
	for w in weights:
		total += w
	if total <= 0:
		total = 1

	var results: Array[Dictionary] = []
	for _i in data.card_count:
		# 决定稀有度
		var roll: int = randi() % total
		var cumulative: int = 0
		var rarity: int = 0
		for j in weights.size():
			cumulative += weights[j]
			if roll < cumulative:
				rarity = j
				break
		# 挑选对应炮台
		var tower: TowerCollectionData = _pick_tower(rarity)
		# 每张卡固定给1碎片
		results.append({"rarity": rarity, "tower": tower, "fragments": 1})
	return results

func _pick_tower(rarity: int) -> TowerCollectionData:
	## 优先同稀有度，退而求其次选最近稀有度，最终兜底任意
	if rarity in _towers_by_rarity and _towers_by_rarity[rarity].size() > 0:
		return _towers_by_rarity[rarity].pick_random()
	for delta in [1, 2, 3, 4]:
		for r in [rarity - delta, rarity + delta]:
			if r in _towers_by_rarity and _towers_by_rarity[r].size() > 0:
				return _towers_by_rarity[r].pick_random()
	for key in _towers_by_rarity:
		if _towers_by_rarity[key].size() > 0:
			return _towers_by_rarity[key][0]
	push_error("ChestOpening._pick_tower: no available tower, reward card will be empty")
	return null

# ───── 阶段1：点击宝箱 ─────

func _on_chest_tapped(event: InputEvent) -> void:
	if _is_animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_reveal()

func _begin_reveal() -> void:
	_is_animating = true
	chest_stage.hide()
	cards_stage.show()
	_spawn_cards()
	_animate_reveal_sequential()

# ───── 阶段2：翻牌 ─────

func _spawn_cards() -> void:
	_reveal_cards.clear()
	for child in cards_container.get_children():
		child.free()

	var n := _results.size()
	if n == 0:
		return

	# 10 连开箱用缩小卡片 + 更多每行
	var is_bulk: bool = n > 10
	var per_row: int = BULK_CARDS_PER_ROW if is_bulk else mini(n, CARDS_PER_ROW)
	var card_w: int = BULK_CARD_W if is_bulk else CARD_W
	var card_h: int = BULK_CARD_H if is_bulk else CARD_H
	var sep: int = BULK_ROW_SEP if is_bulk else ROW_SEP

	# 10 连时用 ScrollContainer 包裹，避免超出屏幕
	var target_container: VBoxContainer = cards_container
	if is_bulk:
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cards_container.add_child(scroll)
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", sep)
		scroll.add_child(inner)
		target_container = inner

	var idx := 0
	while idx < n:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", sep)
		target_container.add_child(row)

		var in_this_row := mini(per_row, n - idx)
		for _c in in_this_row:
			var card := _create_reveal_card(_results[idx], card_w, card_h)
			row.add_child(card)
			_reveal_cards.append(card)
			idx += 1

func _create_reveal_card(result: Dictionary, w: int, h: int) -> Control:
	var tower: TowerCollectionData = result.get("tower")
	var rarity: int = result.get("rarity", 0)
	var frags: int  = result.get("fragments", 0)
	var is_small: bool = w < CARD_W   # 10 连用缩小版

	var card := Control.new()
	card.custom_minimum_size = Vector2(w, h)

	# ── 卡背（翻牌前显示）──────────────────────────────────────────
	var back := Control.new()
	back.name = "CardBack"
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(back)

	# 卡背底色
	var back_bg := ColorRect.new()
	back_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_bg.color = Color(0.12, 0.12, 0.18)
	back_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(back_bg)

	# 卡背图片占位（用户提供图片后在此处启用）
	var back_tex := TextureRect.new()
	back_tex.name = "CardBackTex"
	back_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# back_tex.texture = preload("res://assets/card_back.png")  # 后续启用
	back.add_child(back_tex)

	# 卡背装饰问号
	var back_q := Label.new()
	back_q.text = "?"
	back_q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_q.add_theme_font_size_override("font_size", 56 if is_small else 80)
	back_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_q.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	back_q.modulate = Color(1, 1, 1, 0.12)
	back_q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(back_q)

	# ── 卡面（翻牌后显示）──────────────────────────────────────────
	var front := Control.new()
	front.name = "CardFront"
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.visible = false
	card.add_child(front)

	# 卡面背景（稀有度色，低透明）
	var front_bg := ColorRect.new()
	front_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_bg.color = Color(TowerResourceRegistry.RARITY_COLORS[rarity].r, TowerResourceRegistry.RARITY_COLORS[rarity].g,
						   TowerResourceRegistry.RARITY_COLORS[rarity].b, 0.25)
	front_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(front_bg)

	# 卡面图片占位（用户提供图片后在此处启用）
	var front_tex := TextureRect.new()
	front_tex.name = "CardFrontTex"
	front_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	front_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# front_tex.texture = preload("res://assets/card_front.png")  # 后续启用
	front.add_child(front_tex)

	# 顶部稀有度色条
	var stripe := ColorRect.new()
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_bottom = 12.0
	stripe.color = TowerResourceRegistry.RARITY_COLORS[rarity]
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(stripe)

	# 炮台图片 / emoji（居中）
	if tower and tower.collection_texture:
		var tex_rect := TextureRect.new()
		tex_rect.texture     = tower.collection_texture
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_CENTER)
		tex_rect.offset_left   = -60.0
		tex_rect.offset_top    = -80.0
		tex_rect.offset_right  =  60.0
		tex_rect.offset_bottom =  40.0
		tex_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		front.add_child(tex_rect)
	else:
		var emoji_lbl := Label.new()
		emoji_lbl.text = tower.tower_emoji if tower else "?"
		emoji_lbl.set_anchors_preset(Control.PRESET_CENTER)
		emoji_lbl.offset_left   = -48.0
		emoji_lbl.offset_top    = -60.0
		emoji_lbl.offset_right  =  48.0
		emoji_lbl.offset_bottom =  28.0
		emoji_lbl.add_theme_font_size_override("font_size", 56 if is_small else 80)
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(emoji_lbl)

	# 炮台名称（底部偏上）
	var name_lbl := Label.new()
	name_lbl.text = tower.display_name if tower else "—"
	name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top    = -76.0 if is_small else -96.0
	name_lbl.offset_bottom = -34.0 if is_small else -44.0
	name_lbl.add_theme_font_size_override("font_size", 32 if is_small else 32)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(name_lbl)

	# "碎片 ×1"（最底部，小字）
	var frag_lbl := Label.new()
	frag_lbl.text = tr("UI_CHEST_FRAG_X1")
	frag_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	frag_lbl.offset_top    = -32.0 if is_small else -40.0
	frag_lbl.offset_bottom =  -4.0 if is_small else -6.0
	frag_lbl.add_theme_font_size_override("font_size", 32 if is_small else 32)
	frag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frag_lbl.modulate = Color(1.0, 1.0, 1.0, 0.7)
	frag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(frag_lbl)

	card.set_meta("result", result)
	return card

func _animate_reveal_sequential() -> void:
	_flip_card_index(0)

func _flip_card_index(index: int) -> void:
	if index >= _reveal_cards.size():
		_is_animating = false
		continue_button.show()
		return

	var card = _reveal_cards[index]
	var tween = create_tween()
	_active_tween = tween

	# 10连时加速翻卡（0.06s 半程，几乎无停顿）
	var is_bulk: bool = _results.size() > 10
	var half_dur: float = 0.06 if is_bulk else FLIP_HALF_DURATION
	var pause: float = 0.02 if is_bulk else FLIP_PAUSE

	# 上半程：scaleX 1 → 0
	tween.tween_property(card, "scale:x", 0.0, half_dur).set_ease(Tween.EASE_IN)

	# 翻转中点：切换正反面
	tween.tween_callback(func():
		card.get_node("CardBack").hide()
		card.get_node("CardFront").show()
	)

	# 下半程：scaleX 0 → 1
	tween.tween_property(card, "scale:x", 1.0, half_dur).set_ease(Tween.EASE_OUT)

	# 停顿后翻下一张
	tween.tween_interval(pause)
	tween.tween_callback(func():
		_flip_card_index(index + 1)
	)

# ───── 跳过 ─────

func _skip_all() -> void:
	_is_animating = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

	if chest_stage.visible:
		chest_stage.hide()
		cards_stage.show()
		_spawn_cards()

	for card in _reveal_cards:
		if is_instance_valid(card):
			var back = card.get_node_or_null("CardBack")
			var front = card.get_node_or_null("CardFront")
			if back:
				back.hide()
			if front:
				front.show()
			card.scale = Vector2(1, 1)

	continue_button.show()

# ───── 继续（提交碎片奖励） ─────

func _on_continue() -> void:
	# 每张卡固定给1碎片，写入 CollectionManager
	for result in _results:
		var tower: TowerCollectionData = result.get("tower")
		if tower != null:
			CollectionManager.add_fragments(tower.tower_id, 1)
		else:
			# 无可用炮台时以金币补偿，避免奖励静默丢失
			UserManager.add_gold(5)
			push_warning("ChestOpening: 空炮台卡片已转换为 5 金币补偿")
	SaveManager.save()
	queue_free()
