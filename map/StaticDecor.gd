@tool
class_name StaticDecor extends Area2D

## 静态装饰品 — 拖入 DecorationLayer 使用
## 纯视觉 + 可选碰撞（阻挡塔放置）
## 图片通过子节点 Sprite2D 显示，可在编辑器中直接拖拉缩放

## 是否阻挡塔放置
@export var blocks_placement: bool = true

func _ready() -> void:
	z_index = -9
	z_as_relative = false
	if not Engine.is_editor_hint():
		if blocks_placement:
			add_to_group("block")
			collision_layer = 256
			collision_mask  = 2
		else:
			collision_layer = 0
			collision_mask  = 0
