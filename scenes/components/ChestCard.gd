extends TextureButton

signal info_requested(data: ChestData)
signal purchase_requested(data: ChestData)

const CHEST_TEXTURES: Array[String] = [
	"res://assets/sprites/ui/Chest_Wood.png",
	"res://assets/sprites/ui/Chest_Silver.png",
	"res://assets/sprites/ui/Chest_Gold.png",
]

var chest_data: ChestData

@onready var title_label: Label       = $TitleLabel
@onready var price_label: Label       = $PriceLabel
@onready var info_line1:  Label       = $InfoLine1
@onready var info_line2:  Label       = $InfoLine2
@onready var info_btn:    TextureButton = $InfoBtn
@onready var chest_image: TextureRect = $WoodPanel/ChestImage


func _ready() -> void:
	info_btn.pressed.connect(_on_info_btn_pressed)
	pressed.connect(_on_card_pressed)


func setup(data: ChestData) -> void:
	chest_data = data
	title_label.text = data.chest_name
	if data.voucher_cost > 0:
		price_label.text = "🎫 %d" % data.voucher_cost
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		price_label.text = "免费"
		price_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	info_line1.text = data.info_line1
	info_line2.text = data.info_line2

	# 设置宝箱图片
	var chest_idx: int = 0  # 默认木
	if data.chest_name.find("铁") >= 0 or data.chest_name.find("银") >= 0:
		chest_idx = 1
	elif data.chest_name.find("金") >= 0:
		chest_idx = 2
	chest_image.texture = load(CHEST_TEXTURES[chest_idx])


func _on_info_btn_pressed() -> void:
	if chest_data:
		info_requested.emit(chest_data)


func _on_card_pressed() -> void:
	if chest_data:
		purchase_requested.emit(chest_data)
