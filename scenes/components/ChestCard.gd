extends Panel

signal info_requested(data: ChestData)
signal purchase_requested(data: ChestData)

var chest_data: ChestData

@onready var title_label: Label    = $CardVBox/TitleLabel
@onready var price_label: Label    = $CardVBox/PriceLabel
@onready var info_line1:  Label    = $CardVBox/InfoLine1
@onready var info_line2:  Label    = $CardVBox/InfoLine2
@onready var info_btn:    Button   = $InfoBtn
@onready var chest_rect:  ColorRect = $CardVBox/ChestImageRect

func _ready() -> void:
	info_btn.pressed.connect(_on_info_btn_pressed)
	chest_rect.gui_input.connect(_on_chest_rect_input)

func setup(data: ChestData) -> void:
	chest_data = data
	title_label.text = data.chest_name
	price_label.text = "免费" if data.gem_purchase_cost == 0 else "💎 %d" % data.gem_purchase_cost
	info_line1.text = data.info_line1
	info_line2.text = data.info_line2

func _on_info_btn_pressed() -> void:
	if chest_data:
		emit_signal("info_requested", chest_data)

func _on_chest_rect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if chest_data:
			emit_signal("purchase_requested", chest_data)
