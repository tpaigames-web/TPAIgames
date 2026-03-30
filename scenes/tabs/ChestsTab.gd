extends Control

const CHEST_OPENING_SCENE = preload("res://scenes/chest_opening/ChestOpening.tscn")

const CHEST_PATHS: Array[String] = [
	"res://data/chests/wooden_chest.tres",
	"res://data/chests/iron_chest.tres",
	"res://data/chests/golden_chest.tres",
]

var CHEST_NAMES: Array[String]:
	get: return [tr("UI_CHEST_WOODEN"), tr("UI_CHEST_IRON"), tr("UI_CHEST_GOLD")]
const CHEST_ICONS: Array[String] = ["🪵", "⚙️", "🏆"]

const CHEST_TEXTURES: Array[String] = [
	"res://assets/sprites/ui/Chest_Wood.png",
	"res://assets/sprites/ui/Chest_Silver.png",
	"res://assets/sprites/ui/Chest_Gold.png",
]

const BULK_COSTS: Array[int] = [50, 100, 150]
const BULK_COUNT: int = 10

var _pending_chest: ChestData = null
var _pending_bulk_cost: int = 0
var _pending_bulk_count: int = 0

var _chest_datas: Array[ChestData] = []
var _ticker: Timer = null

## 静态节点引用
@onready var chest_slots_row:  HBoxContainer    = $ChestSlotsRow
@onready var pending_chest_row: HBoxContainer   = $PendingChestRow
@onready var pending_label:    Label            = $PendingChestRow/PendingLabel
@onready var claim_pending_btn: Button          = $PendingChestRow/ClaimPendingBtn
@onready var buy_cards_row:    HBoxContainer    = $BuyCardsRow
@onready var bulk_buy_row:     HBoxContainer    = $BulkBuyRow
@onready var info_panel:       PanelContainer   = $InfoPanel
@onready var info_title:       Label            = $InfoPanel/InfoVBox/InfoHeaderRow/InfoTitle
@onready var info_card_count:  Label            = $InfoPanel/InfoVBox/InfoCardCount
@onready var info_rarity_grid: GridContainer    = $InfoPanel/InfoVBox/InfoRarityGrid
@onready var close_btn:        Button           = $InfoPanel/InfoVBox/InfoHeaderRow/CloseBtn
@onready var purchase_dialog:  ConfirmationDialog = $PurchaseDialog

## 槽位引用（直接从场景获取）
@onready var _slot_nodes: Array[Control] = [
	$ChestSlotsRow/Slot0,
	$ChestSlotsRow/Slot1,
	$ChestSlotsRow/Slot2,
	$ChestSlotsRow/Slot3,
]

## 购买卡牌引用
@onready var _buy_cards: Array[TextureButton] = [
	$BuyCardsRow/WoodCard,
	$BuyCardsRow/IronCard,
	$BuyCardsRow/GoldCard,
]

## 10连卡牌引用
@onready var _bulk_cards: Array[TextureButton] = [
	$BulkBuyRow/BulkWood,
	$BulkBuyRow/BulkIron,
	$BulkBuyRow/BulkGold,
]


func _ready() -> void:
	# 加载宝箱数据
	for path in CHEST_PATHS:
		var data: ChestData = load(path)
		_chest_datas.append(data)

	# 槽位按钮连接
	for i in 4:
		var btn: Button = _slot_nodes[i].get_node("HitButton")
		var idx := i
		btn.pressed.connect(func(): _on_slot_pressed(idx))

	# 购买卡牌按钮连接
	for i in 3:
		var card: TextureButton = _buy_cards[i]
		var info_btn: TextureButton = card.get_node("InfoBtn")
		var data := _chest_datas[i]
		var idx := i
		info_btn.pressed.connect(func(): _show_info_panel(data))
		if i == 0:
			card.pressed.connect(func(): _on_wooden_chest_requested(data))
		else:
			card.pressed.connect(func(): _show_purchase_dialog(data))

	# 10连卡牌按钮连接
	for i in 3:
		var data := _chest_datas[i]
		var idx := i
		_bulk_cards[i].pressed.connect(func(): _on_bulk_buy_pressed(idx, data))

	info_panel.hide()
	close_btn.pressed.connect(func(): info_panel.hide())
	purchase_dialog.confirmed.connect(_on_purchase_confirmed)
	purchase_dialog.get_label().add_theme_font_size_override("font_size", 28)
	purchase_dialog.get_ok_button().add_theme_font_size_override("font_size", 26)
	purchase_dialog.get_cancel_button().add_theme_font_size_override("font_size", 26)
	claim_pending_btn.pressed.connect(_on_claim_pending_pressed)

	_ticker = Timer.new()
	_ticker.wait_time = 1.0
	_ticker.autostart = true
	_ticker.timeout.connect(_on_ticker_timeout)
	add_child(_ticker)

	_update_wooden_chest_ui()
	_update_chest_slots()
	_update_pending_chest_ui()


# ── 宝箱槽位 UI ───────────────────────────────────────────────────────

func _update_chest_slots() -> void:
	for i in 4:
		var slot: Dictionary = UserManager.chest_slots[i]
		var chest_type: int  = slot.get("chest_type", -1)
		var c: Control       = _slot_nodes[i]

		var chest_tex: TextureRect = c.get_node("ChestTexture")
		var dim: ColorRect         = c.get_node("DimOverlay")
		var lock: TextureRect      = c.get_node("LockIcon")
		var time_lbl: Label        = c.get_node("TimeLabel")
		var hint_lbl: Label        = c.get_node("HintLabel")

		if chest_type == -1:
			chest_tex.visible = false
			dim.visible = false
			lock.visible = false
			time_lbl.visible = false
			hint_lbl.visible = false
		elif slot.get("unlock_start_unix", -1) == -1:
			chest_tex.texture = load(CHEST_TEXTURES[chest_type])
			chest_tex.visible = true
			dim.visible = true
			lock.visible = true
			time_lbl.visible = false
			hint_lbl.text = tr("UI_CHEST_TAP_UNLOCK")
			hint_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
			hint_lbl.visible = true
		elif UserManager.is_chest_ready(i):
			chest_tex.texture = load(CHEST_TEXTURES[chest_type])
			chest_tex.visible = true
			dim.visible = false
			lock.visible = false
			time_lbl.visible = false
			hint_lbl.text = tr("UI_CHEST_TAP_OPEN")
			hint_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			hint_lbl.visible = true
			_play_shake(chest_tex)
		else:
			chest_tex.texture = load(CHEST_TEXTURES[chest_type])
			chest_tex.visible = true
			dim.visible = true
			lock.visible = true
			var secs: int = UserManager.get_chest_remaining_secs(i)
			var h: int    = secs / 3600
			var m: int    = (secs % 3600) / 60
			var s: int    = secs % 60
			time_lbl.text = "%02d:%02d:%02d" % [h, m, s]
			time_lbl.visible = true
			hint_lbl.visible = false


func _play_shake(node: Control) -> void:
	if node.has_meta("shaking"):
		return
	node.set_meta("shaking", true)
	var tw := node.create_tween()
	tw.set_loops(3)
	tw.tween_property(node, "rotation", deg_to_rad(5.0), 0.08)
	tw.tween_property(node, "rotation", deg_to_rad(-5.0), 0.08)
	tw.tween_property(node, "rotation", 0.0, 0.08)
	tw.finished.connect(func(): node.remove_meta("shaking"))


func _on_slot_pressed(idx: int) -> void:
	var slot: Dictionary = UserManager.chest_slots[idx]
	var chest_type: int  = slot.get("chest_type", -1)
	if chest_type == -1:
		return

	var unlock_start: int = slot.get("unlock_start_unix", -1)
	if unlock_start == -1:
		if not UserManager.start_chest_unlock(idx):
			_show_simple_dialog(tr("UI_CHEST_UNLOCKING"), tr("UI_CHEST_UNLOCKING_MSG"))
			return
		SaveManager.save()
		_update_chest_slots()
	elif UserManager.is_chest_ready(idx):
		var chest_data := UserManager.claim_chest(idx)
		SaveManager.save()
		_update_chest_slots()
		if chest_data:
			_launch_chest_opening(chest_data)
	else:
		_show_unlock_options(idx)


func _show_unlock_options(idx: int) -> void:
	var slot: Dictionary = UserManager.chest_slots[idx]
	var chest_type: int  = slot["chest_type"]
	var secs: int        = UserManager.get_chest_remaining_secs(idx)
	var h: int = secs / 3600
	var m: int = (secs % 3600) / 60
	var s: int = secs % 60
	var gem_cost: int = int(ceil(float(secs) / 1800.0)) * 5

	var overlay := CanvasLayer.new()
	overlay.layer = 10
	get_tree().root.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(800, 520)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left   = -400
	card.offset_right  =  400
	card.offset_top    = -260
	card.offset_bottom =  260
	overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 30
	vbox.offset_right  = -30
	vbox.offset_top    = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	var title := Label.new()
	title.text = tr("UI_CHEST_UNLOCK_TITLE") % CHEST_NAMES[chest_type]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	var time_label := Label.new()
	time_label.text = tr("UI_CHEST_TIME_REMAINING") % [h, m, s]
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(time_label)

	var gem_btn := Button.new()
	gem_btn.text = tr("UI_CHEST_INSTANT_UNLOCK") % [gem_cost, UserManager.gems]
	gem_btn.custom_minimum_size = Vector2(0, 110)
	gem_btn.add_theme_font_size_override("font_size", 28)
	gem_btn.disabled = UserManager.gems < gem_cost
	vbox.add_child(gem_btn)

	var ad_btn := Button.new()
	ad_btn.text = tr("UI_CHEST_AD_SPEED_UP")
	ad_btn.custom_minimum_size = Vector2(0, 110)
	ad_btn.add_theme_font_size_override("font_size", 28)
	vbox.add_child(ad_btn)

	var close := Button.new()
	close.text = tr("UI_CHEST_CLOSE")
	close.custom_minimum_size = Vector2(0, 70)
	close.add_theme_font_size_override("font_size", 28)
	vbox.add_child(close)

	gem_btn.pressed.connect(func():
		if UserManager.spend_gems(gem_cost):
			UserManager.instant_unlock_chest(idx)
			SaveManager.save()
			overlay.queue_free()
			_update_chest_slots()
	)
	var on_ad_complete := func():
		UserManager.speed_up_chest(idx, 1800)
		SaveManager.save()
		_update_chest_slots()
	var on_ad_cancel := func(): pass
	ad_btn.pressed.connect(func():
		overlay.queue_free()
		AdManager.show_rewarded_ad(on_ad_complete, on_ad_cancel)
	)
	close.pressed.connect(func(): overlay.queue_free())
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)


func _update_pending_chest_ui() -> void:
	var ptype: int = UserManager.pending_chest_type
	if ptype == -1:
		pending_chest_row.hide()
		return
	pending_chest_row.show()
	pending_label.text = tr("UI_CHEST_PENDING") + "：%s %s" % [CHEST_ICONS[ptype], CHEST_NAMES[ptype]]
	var has_free := false
	for slot in UserManager.chest_slots:
		if slot["chest_type"] == -1:
			has_free = true
			break
	claim_pending_btn.disabled = not has_free


func _on_claim_pending_pressed() -> void:
	var ptype: int = UserManager.pending_chest_type
	if ptype == -1:
		return
	if UserManager.add_chest_to_slot(ptype):
		UserManager.pending_chest_type = -1
		SaveManager.save()
		_update_chest_slots()
		_update_pending_chest_ui()
	else:
		_show_simple_dialog(tr("UI_CHEST_SLOTS_FULL"), tr("UI_CHEST_SLOTS_FULL_MSG"))


func _show_simple_dialog(title_text: String, body_text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title_text
	dlg.dialog_text = body_text
	dlg.get_label().add_theme_font_size_override("font_size", 28)
	dlg.get_ok_button().add_theme_font_size_override("font_size", 26)
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())


# ── 木宝箱限时免费 ───────────────────────────────────────────────────

func _on_wooden_chest_requested(_data: ChestData) -> void:
	if not UserManager.is_free_wooden_chest_ready():
		return
	_pending_chest = _chest_datas[0]
	_pending_bulk_cost = 0
	_pending_bulk_count = 0
	purchase_dialog.dialog_text = tr("UI_CHEST_CONFIRM_FREE_WOODEN")
	purchase_dialog.popup_centered()


func _update_wooden_chest_ui() -> void:
	var price_lbl: Label = _buy_cards[0].get_node("PriceLabel")
	if UserManager.is_free_wooden_chest_ready():
		price_lbl.text = tr("UI_CHEST_FREE_CLAIM")
		price_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35))
	else:
		var secs: int = UserManager.get_free_wooden_chest_cooldown_remaining()
		var h: int    = secs / 3600
		var m: int    = (secs % 3600) / 60
		var s: int    = secs % 60
		price_lbl.text = "⏳ %02d:%02d:%02d" % [h, m, s]
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))


func _on_ticker_timeout() -> void:
	_update_wooden_chest_ui()
	_update_chest_slots()
	_update_pending_chest_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_wooden_chest_ui()
		_update_chest_slots()
		_update_pending_chest_ui()


# ── 购买流程 ─────────────────────────────────────────────────────────

func _show_info_panel(data: ChestData) -> void:
	info_title.text = tr("UI_CHEST_INFO_TITLE") % data.chest_name
	info_card_count.text = tr("UI_CHEST_CARD_COUNT") % data.card_count

	for child in info_rarity_grid.get_children():
		child.queue_free()

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
		var name_label := Label.new()
		name_label.text = "● " + TowerResourceRegistry.RARITY_NAMES[i]
		name_label.add_theme_color_override("font_color", TowerResourceRegistry.RARITY_COLORS[i])
		name_label.add_theme_font_size_override("font_size", 32)
		info_rarity_grid.add_child(name_label)

		var pct_label := Label.new()
		pct_label.text = "%.1f %%" % pct
		pct_label.add_theme_font_size_override("font_size", 32)
		info_rarity_grid.add_child(pct_label)

	info_panel.show()


func _show_purchase_dialog(data: ChestData) -> void:
	_pending_chest = data
	_pending_bulk_cost = 0
	_pending_bulk_count = 0
	if data.voucher_cost == 0:
		purchase_dialog.dialog_text = tr("UI_CHEST_CONFIRM_FREE") % data.chest_name
	else:
		purchase_dialog.dialog_text = tr("UI_CHEST_CONFIRM_BUY") % [
			data.chest_name, data.voucher_cost, UserManager.vouchers]
	purchase_dialog.popup_centered()


func _on_purchase_confirmed() -> void:
	if _pending_chest == null:
		return

	if _pending_bulk_count > 0:
		if not UserManager.spend_vouchers(_pending_bulk_cost):
			_show_simple_dialog(tr("UI_CHEST_VOUCHER_LOW"),
				tr("UI_CHEST_VOUCHER_LOW_MSG") % [
					_pending_bulk_cost, UserManager.vouchers])
			_pending_chest = null
			_pending_bulk_cost = 0
			_pending_bulk_count = 0
			return
		SaveManager.save()
		_launch_chest_opening(_pending_chest, _pending_bulk_count)
		_pending_chest = null
		_pending_bulk_cost = 0
		_pending_bulk_count = 0
		return

	if _chest_datas.size() > 0 and _pending_chest == _chest_datas[0]:
		UserManager.claim_free_wooden_chest()
		_update_wooden_chest_ui()
		SaveManager.save()
		_launch_chest_opening(_pending_chest)
		_pending_chest = null
		return

	if _pending_chest.voucher_cost > 0:
		if not UserManager.spend_vouchers(_pending_chest.voucher_cost):
			_show_simple_dialog(tr("UI_CHEST_VOUCHER_LOW"),
				tr("UI_CHEST_VOUCHER_LOW_MSG") % [
					_pending_chest.voucher_cost, UserManager.vouchers])
			_pending_chest = null
			return
	SaveManager.save()
	_launch_chest_opening(_pending_chest)
	_pending_chest = null


func _launch_chest_opening(data: ChestData, count: int = 1) -> void:
	var opening = CHEST_OPENING_SCENE.instantiate()
	opening.setup(data, count)
	get_tree().root.add_child(opening)


# ── 10连开箱 ─────────────────────────────────────────────────────────

func _on_bulk_buy_pressed(chest_idx: int, data: ChestData) -> void:
	var cost: int = BULK_COSTS[chest_idx]
	_pending_chest = data
	_pending_bulk_cost = cost
	_pending_bulk_count = BULK_COUNT
	purchase_dialog.dialog_text = tr("UI_CHEST_BULK_CONFIRM") % [
		CHEST_NAMES[chest_idx], BULK_COUNT, cost, UserManager.vouchers]
	purchase_dialog.popup_centered()
