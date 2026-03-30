## 英雄地形升级面板 — 2 选 1
## 在波次 5/10/15/20 暂停游戏后弹出，供玩家选择英雄地形升级方向
extends CanvasLayer

signal upgrade_chosen(hero_id: String, tier: int, choice: String)

@onready var _title_lbl:   Label         = $Margin/Panel/VBox/TitleLbl
@onready var _sub_lbl:     Label         = $Margin/Panel/VBox/SubLbl
@onready var _choices_vbox: VBoxContainer = $Margin/Panel/VBox/ChoicesVBox
@onready var _confirm_btn: Button        = $Margin/Panel/VBox/ConfirmBtn

var _hero_id: String = ""
var _tier: int = 0
var _selected_choice: String = ""   # "A" or "B"
var _card_a: PanelContainer = null
var _card_b: PanelContainer = null
var _style_a: StyleBoxFlat = null
var _style_b: StyleBoxFlat = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_btn.pressed.connect(_on_confirm)


## 初始化面板
## hero_id: "hero_farmer" / "farm_guardian"
## tier: 1-4 (对应 Lv2-Lv5)
## current_level: 当前英雄等级 (1-4)
## upgrade_data: HeroUpgradeData 资源
func setup(hero_id: String, tier: int, current_level: int, upgrade_data: HeroUpgradeData, hero_name: String, hero_emoji: String) -> void:
	_hero_id = hero_id
	_tier = tier
	_selected_choice = ""
	_confirm_btn.disabled = true

	_title_lbl.text = tr("UI_HERO_UPGRADE_TITLE") % [hero_emoji, hero_name, upgrade_data.wave_trigger]
	_sub_lbl.text   = "Lv.%d → Lv.%d" % [current_level, current_level + 1]

	_build_cards(upgrade_data)


func _build_cards(upg: HeroUpgradeData) -> void:
	for child in _choices_vbox.get_children():
		_choices_vbox.remove_child(child)
		child.queue_free()

	_card_a = _create_card(upg.option_a_icon, upg.option_a_name, upg.option_a_desc, "A")
	_card_b = _create_card(upg.option_b_icon, upg.option_b_name, upg.option_b_desc, "B")
	_choices_vbox.add_child(_card_a)
	_choices_vbox.add_child(_card_b)
	_choices_vbox.queue_sort()


func _create_card(icon: String, title: String, desc: String, choice: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size   = Vector2(0, 180)
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.96)
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.border_width_bottom = 3
	style.border_width_top    = 3
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_color = Color(0.30, 0.30, 0.34, 0.85)
	row.add_theme_stylebox_override("panel", style)

	if choice == "A":
		_style_a = style
	else:
		_style_b = style

	# 内部横向布局
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 0)
	row.add_child(hbox)

	# 左：图标区
	var icon_bg_color: Color = Color(0.88, 0.72, 0.18) if choice == "A" else Color(0.35, 0.55, 0.90)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(130, 0)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_bg_color
	icon_style.corner_radius_top_left     = 16
	icon_style.corner_radius_bottom_left  = 16
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_vbox := VBoxContainer.new()
	icon_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.add_child(icon_vbox)

	var emoji_lbl := Label.new()
	emoji_lbl.text = icon
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 64)
	emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_vbox.add_child(emoji_lbl)

	var choice_lbl := Label.new()
	choice_lbl.text = choice
	choice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_lbl.add_theme_font_size_override("font_size", 30)
	choice_lbl.add_theme_color_override("font_color", Color.WHITE)
	choice_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_vbox.add_child(choice_lbl)

	hbox.add_child(icon_panel)

	# 右：文字区
	var text_margin := MarginContainer.new()
	text_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left",   20)
	text_margin.add_theme_constant_override("margin_right",  16)
	text_margin.add_theme_constant_override("margin_top",    16)
	text_margin.add_theme_constant_override("margin_bottom", 16)
	hbox.add_child(text_margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	text_margin.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# 点击处理
	row.gui_input.connect(func(event: InputEvent): _on_card_input(event, choice))

	return row


func _on_card_input(event: InputEvent, choice: String) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed = true
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			pressed = true
	if pressed:
		_select_choice(choice)


func _select_choice(choice: String) -> void:
	_selected_choice = choice
	_confirm_btn.disabled = false

	# A 金色高亮 / B 取消高亮
	var gold := Color(1.0, 0.88, 0.0, 1.0)
	var normal := Color(0.30, 0.30, 0.34, 0.85)

	if choice == "A":
		_style_a.border_color = gold
		_style_a.border_width_bottom = 5
		_style_a.border_width_top    = 5
		_style_a.border_width_left   = 5
		_style_a.border_width_right  = 5
		_style_b.border_color = normal
		_style_b.border_width_bottom = 3
		_style_b.border_width_top    = 3
		_style_b.border_width_left   = 3
		_style_b.border_width_right  = 3
	else:
		_style_b.border_color = gold
		_style_b.border_width_bottom = 5
		_style_b.border_width_top    = 5
		_style_b.border_width_left   = 5
		_style_b.border_width_right  = 5
		_style_a.border_color = normal
		_style_a.border_width_bottom = 3
		_style_a.border_width_top    = 3
		_style_a.border_width_left   = 3
		_style_a.border_width_right  = 3

	_card_a.add_theme_stylebox_override("panel", _style_a)
	_card_b.add_theme_stylebox_override("panel", _style_b)


func _on_confirm() -> void:
	if _selected_choice == "":
		return
	upgrade_chosen.emit(_hero_id, _tier, _selected_choice)
	queue_free()
