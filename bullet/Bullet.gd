extends Node2D

## 子弹节点
## 创建后设置 target / damage / move_speed / effects / bullet_emoji，自动飞向目标并命中结算。

## 追踪的目标敌人（Area2D，Enemy 节点）
var target: Area2D = null

## 基础伤害
var damage: float = 10.0

## 飞行速度（像素/秒）
var move_speed: float = 400.0

## 携带的效果列表（Array[BulletEffect]）
var effects: Array = []

## 攻击类型（继承自炮台：0=地面 1=空中 2=全部）预留，后续过滤用
var attack_type: int = 0

## 子弹显示 emoji（从 TowerCollectionData.bullet_emoji 传入）
var bullet_emoji: String = "⚫"

## 命中距离阈值（像素）
const HIT_RADIUS: float = 20.0


func _ready() -> void:
	$EmojiLabel.text = bullet_emoji


func _process(delta: float) -> void:
	# 目标失效（已死亡 / 离开场景）则销毁子弹
	if not is_instance_valid(target):
		queue_free()
		return

	var diff: Vector2 = target.global_position - global_position

	# 到达命中距离
	if diff.length() <= HIT_RADIUS:
		_on_hit()
		return

	# 向目标移动
	global_position += diff.normalized() * move_speed * delta


func _on_hit() -> void:
	if is_instance_valid(target) and target.has_method("take_damage_from_bullet"):
		target.take_damage_from_bullet(damage, effects)
	queue_free()
