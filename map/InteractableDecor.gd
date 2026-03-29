class_name InteractableDecor extends Area2D

## 可交互装饰品 — 拖入地图中使用
## 战斗中阻挡塔放置，玩家花金币可拆除

## 点击时发出（由 BattleScene 监听处理弹窗）
signal clicked(decor: InteractableDecor)

@export var display_emoji: String = "🌿"
@export var display_name: String = "灌木丛"
@export var remove_cost: int = 500
@export var emoji_size: int = 64

## 装饰品贴图（设置后优先显示图片，忽略 emoji）
@export var decor_texture: Texture2D = null
## 贴图显示大小（像素），0 = 使用贴图原始尺寸
@export var texture_display_size: Vector2 = Vector2.ZERO

var _emoji_label: Label = null
var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("block")
	add_to_group("interactable_decor")
	collision_layer = 256   # block 层
	collision_mask  = 2     # 检测 tower 层
	input_pickable  = true

	if decor_texture:
		# 有贴图 → 用 Sprite2D 显示
		_sprite = Sprite2D.new()
		_sprite.texture = decor_texture
		if texture_display_size != Vector2.ZERO and decor_texture.get_size().x > 0:
			var tex_size: Vector2 = decor_texture.get_size()
			_sprite.scale = texture_display_size / tex_size
		add_child(_sprite)
	else:
		# 无贴图 → 用 emoji 显示
		_emoji_label = Label.new()
		_emoji_label.text = display_emoji
		_emoji_label.add_theme_font_size_override("font_size", emoji_size)
		_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_emoji_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		_emoji_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_emoji_label.offset_left   = -float(emoji_size)
		_emoji_label.offset_top    = -float(emoji_size)
		_emoji_label.offset_right  =  float(emoji_size)
		_emoji_label.offset_bottom =  float(emoji_size)
		_emoji_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		add_child(_emoji_label)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		clicked.emit(self)
