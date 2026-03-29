class_name ItemData extends Resource

## 消耗品道具数据

@export var item_id: String = ""
@export var display_name: String = ""
@export var emoji: String = "📦"
@export var description: String = ""

## 钻石购买单价（每次购买获得 1 个）
@export var gem_cost: int = 30

## 效果类型："gold_boost" / "landmine"
@export var effect_type: String = ""

## 效果数值（金币数量 / 伤害值）
@export var effect_value: float = 0.0

## 地雷类：爆炸范围（像素）
@export var blast_radius: float = 200.0

## 是否需要放置在路径上（地雷=true，金币袋=false）
@export var place_on_path: bool = false
