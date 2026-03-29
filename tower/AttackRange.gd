extends Area2D

enum TargetMode { FIRST, CLOSEST, STRONGEST, LAST }

## 由 Tower 显式写入，与 CollisionShape2D 的共享 shape 资源完全解耦。
## Godot 4 内联 sub_resource 默认跨实例共享：预览捕兽夹（attack_range=60）
## 调用 apply_tower_data() 时会把共享 CircleShape2D.radius 改为 60，
## 导致全场炮台读到的 col.shape.radius 都变成 60，敌人检测失效。
## 改用此字段后，每个 AttackRange 实例持有自己的半径值，互不干扰。
var attack_radius: float = 0.0


func _ready():
	monitoring = true
	monitorable = false


## 使用 distance_squared_to 避免每帧对每个敌人做开方运算。
## 通过 GameManager.get_all_enemies() 读取每帧缓存，避免多塔重复扫描场景树。
## attack_type: 0=地面, 1=空中, 2=全部
func get_enemies_in_range(attack_type: int = 2) -> Array:
	if attack_radius <= 0.0:
		return []
	var r2: float = attack_radius * attack_radius
	var my_pos: Vector2 = global_position
	var result: Array = []
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy):
			continue
		if my_pos.distance_squared_to(enemy.global_position) > r2:
			continue
		# 根据 attack_type 过滤飞行/地面敌人
		if attack_type != 2:
			var ed = enemy.get("enemy_data")
			var flying: bool = ed != null and ed.is_flying
			if attack_type == 0 and flying:
				continue
			if attack_type == 1 and not flying:
				continue
		result.append(enemy)
	return result


func get_target(mode: int = TargetMode.FIRST, attack_type: int = 2) -> Area2D:
	var enemies := get_enemies_in_range(attack_type)
	if enemies.is_empty():
		return null
	# 只有 1 个敌人时直接返回，跳过 reduce
	if enemies.size() == 1:
		return enemies[0]
	var my_pos: Vector2 = global_position
	match mode:
		TargetMode.FIRST:
			var best: Area2D = enemies[0]
			var best_prog: float = _prog(best)
			for i in range(1, enemies.size()):
				var p: float = _prog(enemies[i])
				if p > best_prog:
					best_prog = p
					best = enemies[i]
			return best
		TargetMode.CLOSEST:
			var best: Area2D = enemies[0]
			var best_d2: float = my_pos.distance_squared_to(best.global_position)
			for i in range(1, enemies.size()):
				var d2: float = my_pos.distance_squared_to(enemies[i].global_position)
				if d2 < best_d2:
					best_d2 = d2
					best = enemies[i]
			return best
		TargetMode.STRONGEST:
			var best: Area2D = enemies[0]
			var best_hp: float = best.hp
			for i in range(1, enemies.size()):
				if enemies[i].hp > best_hp:
					best_hp = enemies[i].hp
					best = enemies[i]
			return best
		TargetMode.LAST:
			var best: Area2D = enemies[0]
			var best_prog: float = _prog(best)
			for i in range(1, enemies.size()):
				var p: float = _prog(enemies[i])
				if p < best_prog:
					best_prog = p
					best = enemies[i]
			return best
	return enemies[0]


func _prog(e: Area2D) -> float:
	var p = e.get_parent()
	return p.progress_ratio if p is PathFollow2D else 0.0
