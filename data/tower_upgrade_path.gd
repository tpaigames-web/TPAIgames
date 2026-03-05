class_name TowerUpgradePath extends Resource
## 炮台升级方向（每个方向5层）
## 每个炮台有4个升级方向，每个方向最多5层。
## BTD风格限制（实战阶段实现）：
##   - 每台只能升级最多2个方向
##   - 若某方向达到第3层，其他方向上限降为第2层

@export var path_name: String = ""           # 方向名称，如"攻击提升"
@export var tier_names: Array[String] = []   # 5个层级的名称
@export var tier_effects: Array[String] = [] # 5个层级的效果说明
@export var tier_costs: Array[int] = []      # 5个层级的金币费用

# ── 每层提供的属性加成（累加式，0.0 = 此路径不加该属性）──────────
## 每升一层伤害提升比例（0.12 = 每层+12%，5层共+60%）
@export var damage_bonus_per_tier: float = 0.0
## 每升一层攻击速度提升比例（0.10 = 每层+10%，效果：interval ÷ (1 + 总加成)）
@export var speed_bonus_per_tier: float = 0.0
## 每升一层攻击范围扩大比例（0.15 = 每层+15%）
@export var range_bonus_per_tier: float = 0.0
