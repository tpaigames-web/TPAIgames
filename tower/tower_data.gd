extends Resource
class_name TowerData

@export var tower_name: String
@export var tower_scene: PackedScene
@export var damage: float
@export var attack_speed: float
@export var attack_range: float
@export var projectile_scene: PackedScene
@export var target_types: Array[String]
@export var cost: int
@export var upgrade_to: TowerData

# ⭐ 新增：放置碰撞大小
@export var collision_radius: float = 40.0

# 攻击类型
@export var can_attack_ground: bool = true
@export var can_attack_air: bool = false
@export var can_attack_water: bool = false

# 功能类型（未来扩展）
@export var tower_type: String

# 升级
@export var upgrade_paths: Array[Resource]
