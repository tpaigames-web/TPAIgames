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

## 溅射半径/弹片飞行距离（像素，0 = 无溅射）
var splash_radius: float = 0.0

## 溅射伤害比例（0.0-1.0，相对于主目标伤害）
var splash_damage_ratio: float = 0.5

## 溅射锥形角度（度数，0 = 圆形溅射，>0 = 弹片模式）
var splash_cone_deg: float = 0.0

## 弹片附加燃烧时间（秒，0 = 无燃烧）
var splash_burn_duration: float = 0.0

## 弹片飞行结束时是否小范围爆炸
var splash_end_explode: bool = false

## 弹片数量（0 = 使用默认5个）
var splash_frag_count: int = 0

## 命中距离阈值（像素）
const HIT_RADIUS: float = 20.0

## 来源炮台（用于统计伤害/击杀，命中时闪烁）
var source_tower: Area2D = null

## 击退距离（像素，0 = 无击退）
var knockback_distance: float = 0.0

## 巨型穿透：使控制效果作用于巨型单位
var pierce_giant: bool = false

## 护甲穿透等级（降低目标的有效护甲等级，0 = 无穿透）
var armor_penetration: int = 0

## 无视闪避（必定命中，忽略敌人的 attack_immunity_chance）
var ignore_dodge: bool = false

## 弹丸穿透：命中后继续飞向下一个敌人（0=不穿透，N=可穿透N个额外目标）
var pierce_count: int = 0
var _pierced_enemies: Array = []

## 子弹飞行方向（归一化，命中时用于弹片方向）
var _last_direction: Vector2 = Vector2.RIGHT

## 目标死亡后继续飞行
var _target_last_pos: Vector2 = Vector2.ZERO
var _target_lost: bool = false


func _ready() -> void:
	# 初始化飞行方向
	if is_instance_valid(target):
		var init_dir: Vector2 = target.global_position - global_position
		if init_dir.length_squared() > 1.0:
			_last_direction = init_dir.normalized()

	# 优先使用 BulletSprite 贴图，无贴图时回退到 emoji
	if has_node("BulletSprite"):
		var spr: Sprite2D = $BulletSprite
		if spr.texture:
			spr.visible = true
			$EmojiLabel.visible = false
			return
	$EmojiLabel.text = bullet_emoji


func _process(delta: float) -> void:
	# 更新目标最后位置 / 检测目标失效
	if is_instance_valid(target):
		_target_last_pos = target.global_position
	elif _target_last_pos == Vector2.ZERO:
		queue_free()
		return
	else:
		_target_lost = true

	# 飞向目标（存活）或最后位置（死亡）
	var dest: Vector2 = target.global_position if is_instance_valid(target) else _target_last_pos
	var diff: Vector2 = dest - global_position
	var dist: float = diff.length()

	# 记录飞行方向
	if dist > HIT_RADIUS * 2.0:
		_last_direction = diff / dist

	# 命中
	if dist <= HIT_RADIUS:
		_on_hit()
		return

	# 移动
	global_position += diff * (move_speed * delta / dist)


func _on_hit() -> void:
	# 主目标伤害
	if is_instance_valid(target) and target.has_method("take_damage_from_bullet"):
		var was_alive: bool = target.hp > 0
		target.take_damage_from_bullet(damage, effects, pierce_giant, armor_penetration, ignore_dodge)
		if is_instance_valid(source_tower):
			source_tower.notify_damage(damage)
			if was_alive and (not is_instance_valid(target) or target.hp <= 0):
				source_tower.notify_kill()

	# 溅射
	if splash_radius > 0.0:
		if splash_cone_deg > 0.0:
			_spawn_fragments()
		else:
			_circular_splash()

	# 击退
	if knockback_distance > 0.0 and is_instance_valid(target) and target.has_method("apply_knockback"):
		target.apply_knockback(knockback_distance)

	_spawn_hit_vfx()

	# 穿透：命中后继续飞向下一个敌人（目标死亡也尝试穿透）
	if pierce_count > 0:
		if is_instance_valid(target):
			_pierced_enemies.append(target)
		pierce_count -= 1
		var next: Area2D = _find_pierce_target()
		if next != null:
			target = next
			_target_lost = false
			return   # 不销毁，继续飞行
	queue_free()


## 穿透：寻找沿飞行方向的下一个目标
func _find_pierce_target() -> Area2D:
	var best: Area2D = null
	var best_dist: float = INF
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy) or enemy in _pierced_enemies:
			continue
		if enemy == target:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		# 只找前方（沿飞行方向120°锥形内）且在合理距离内的
		if dist > 300.0 or dist < 1.0:
			continue
		var angle: float = absf(_last_direction.angle_to(to_enemy.normalized()))
		if angle < deg_to_rad(60.0) and dist < best_dist:
			best = enemy
			best_dist = dist
	return best


## 圆形溅射（向下兼容，splash_cone_deg == 0 时使用）
func _circular_splash() -> void:
	var splash_dmg: float = damage * splash_damage_ratio
	var sp_r2: float = splash_radius * splash_radius
	for enemy in GameManager.get_all_enemies():
		if enemy == target or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(global_position) <= sp_r2:
			if enemy.has_method("take_damage_from_bullet"):
				enemy.take_damage_from_bullet(splash_dmg, effects, pierce_giant, armor_penetration, ignore_dodge)
				if is_instance_valid(source_tower):
					source_tower.notify_damage(splash_dmg)


## 弹片模式（splash_cone_deg > 0 时使用）
func _spawn_fragments() -> void:
	var splash_dmg: float = damage * splash_damage_ratio
	var frag_count: int = splash_frag_count if splash_frag_count > 0 else 5
	var cone_half: float = deg_to_rad(splash_cone_deg / 2.0)

	# 构建弹片携带的燃烧效果
	var frag_effects: Array = effects.duplicate()
	if splash_burn_duration > 0.0:
		var burn := BulletEffect.new()
		burn.effect_type = BulletEffect.Type.BURN
		burn.damage_per_tick = 5.0
		burn.tick_interval = 1.0
		burn.duration = splash_burn_duration
		frag_effects.append(burn)

	for i in frag_count:
		var angle_offset: float = randf_range(-cone_half, cone_half)
		var dir: Vector2 = _last_direction.rotated(angle_offset)

		var frag := _SplashFragment.new()
		frag.direction = dir
		frag.speed = move_speed * 1.5
		frag.max_distance = splash_radius
		frag.frag_damage = splash_dmg
		frag.frag_effects = frag_effects
		frag.frag_pierce_giant = pierce_giant
		frag.frag_armor_pen = armor_penetration
		frag.frag_source_tower = source_tower if is_instance_valid(source_tower) else null
		frag.end_explode = splash_end_explode
		frag.global_position = global_position
		get_tree().current_scene.add_child(frag)


func _spawn_hit_vfx() -> void:
	var vfx := _HitVFX.new()
	vfx.global_position = global_position
	vfx.is_splash = splash_radius > 0.0
	vfx.splash_r = splash_radius if splash_cone_deg <= 0.0 else 20.0
	get_tree().current_scene.add_child(vfx)


## ═══════════════════════════════════════════════════════════════════════
## 弹片内部类
## ═══════════════════════════════════════════════════════════════════════
class _SplashFragment extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var speed: float = 600.0
	var max_distance: float = 50.0
	var frag_damage: float = 10.0
	var frag_effects: Array = []
	var frag_pierce_giant: bool = false
	var frag_armor_pen: int = 0
	var frag_source_tower: Area2D = null
	var end_explode: bool = false
	var _traveled: float = 0.0
	var _hit_enemies: Array = []
	const FRAG_HIT_RADIUS: float = 15.0
	const END_EXPLODE_RADIUS: float = 60.0

	func _ready() -> void:
		z_index = 10
		var lbl := Label.new()
		lbl.text = "💫"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.position = Vector2(-6, -6)
		add_child(lbl)

	func _process(delta: float) -> void:
		var move_dist: float = speed * delta
		global_position += direction * move_dist
		_traveled += move_dist

		# 碰撞检测
		for enemy in GameManager.get_all_enemies():
			if not is_instance_valid(enemy) or enemy in _hit_enemies:
				continue
			if enemy.global_position.distance_squared_to(global_position) <= FRAG_HIT_RADIUS * FRAG_HIT_RADIUS:
				if enemy.has_method("take_damage_from_bullet"):
					enemy.take_damage_from_bullet(frag_damage, frag_effects, frag_pierce_giant, frag_armor_pen)
					if is_instance_valid(frag_source_tower):
						frag_source_tower.notify_damage(frag_damage)
				_hit_enemies.append(enemy)

		# 飞行距离结束
		if _traveled >= max_distance:
			if end_explode:
				_do_end_explosion()
			queue_free()

	func _do_end_explosion() -> void:
		var explode_dmg: float = frag_damage * 0.5
		for enemy in GameManager.get_all_enemies():
			if not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_squared_to(global_position) <= END_EXPLODE_RADIUS * END_EXPLODE_RADIUS:
				if enemy.has_method("take_damage_from_bullet"):
					enemy.take_damage_from_bullet(explode_dmg, frag_effects, frag_pierce_giant, frag_armor_pen)
					if is_instance_valid(frag_source_tower):
						frag_source_tower.notify_damage(explode_dmg)
		# 爆炸视觉
		var lbl := Label.new()
		lbl.text = "💥"
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.global_position = global_position - Vector2(14, 14)
		lbl.z_index = 50
		get_tree().current_scene.add_child(lbl)
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "scale", Vector2(2.0, 2.0), 0.3).from(Vector2(0.5, 0.5))
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.1)
		tw.tween_callback(lbl.queue_free)


## ═══════════════════════════════════════════════════════════════════════
## 命中特效内部类
## ═══════════════════════════════════════════════════════════════════════
class _HitVFX extends Node2D:
	var is_splash: bool = false
	var splash_r: float = 0.0

	func _ready() -> void:
		z_index = 5
		var color := Color(1.0, 0.6, 0.2, 0.7) if is_splash else Color(1.0, 1.0, 0.8, 0.8)
		var start_scale := 0.5 if is_splash else 0.3
		scale = Vector2(start_scale, start_scale)
		modulate = color
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.2, 1.2) if is_splash else Vector2(0.8, 0.8), 0.15)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var r := splash_r if is_splash and splash_r > 0.0 else 20.0
		draw_circle(Vector2.ZERO, r, Color.WHITE)
