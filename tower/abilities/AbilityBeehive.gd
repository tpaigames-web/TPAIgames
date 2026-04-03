extends TowerAbility

## 蜂巢 — 持久召唤蜜蜂系统
##
## 放置后召唤4只BeeEntity常驻，独立寻敌→攻击→返回。
## Path 0 蜂王领域：伤害/攻速加成 + 毒针 + 蜂王(T4+)
## Path 1 无尽蜂涌：攻速加成 + 多目标
## Path 2 致命毒巢：毒素效果 + 毒爆
## Path 3 蜜露光环：光环buff周围炮台

const BEE_SCENE: PackedScene = preload("res://tower/entities/BeeEntity.tscn")

# ── 数值查表（下标 = 层级 0-5）────────────────────────────────────────
const P0_DMG: Array[float] = [0.0, 0.15, 0.30, 0.30, 0.30, 0.30]
const P0_SPD: Array[float] = [0.0, 0.15, 0.30, 0.30, 0.30, 0.30]
const P1_SPD: Array[float] = [0.0, 0.20, 0.40, 0.60, 0.80, 0.80]
const P1_TARGETS: Array[int] = [1, 1, 2, 3, 3, 4]

# Path 3 光环
const P3_AURA_RADIUS: Array[float] = [0.0, 150.0, 180.0, 230.0, 230.0, 230.0]
const P3_AURA_SPEED: Array[float] = [0.0, 0.08, 0.12, 0.12, 0.18, 0.25]
const P3_AURA_DMG: Array[float] = [0.0, 0.0, 0.0, 0.05, 0.05, 0.05]

# ── 蜜蜂管理 ──────────────────────────────────────────────────────────
@export var base_bee_count: int = 4

var _bees: Array = []           ## Array[BeeEntity]
var _bee_king: BeeEntity = null
var _target_timer: float = 0.0
var _aura_timer: float = 0.0
var _buffed_towers: Array = []

# ── 效果对象 ──────────────────────────────────────────────────────────
var _poison_effects: Array = []  ## 当前毒素效果列表
var _slow_fx: BulletEffect = null


func on_placed() -> void:
	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.potency = 0.25
	_slow_fx.duration = 2.0

	# 初始召唤4只蜜蜂
	_spawn_bees(base_bee_count)
	_refresh_bee_stats()


## 跳过 Tower 默认攻击（蜜蜂自主攻击）
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	return true


func ability_process(delta: float) -> void:
	# 每 0.2 秒分配目标
	_target_timer += delta
	if _target_timer >= 0.2:
		_target_timer = 0.0
		_assign_targets()

	# 每 1.0 秒刷新光环
	if _lv(3) >= 1:
		_aura_timer += delta
		if _aura_timer >= 1.0:
			_aura_timer = 0.0
			_refresh_aura()

	# 动态管理蜜蜂数量和蜂王
	_manage_bee_count()
	_refresh_bee_stats()


# ═══════════════════════════════════════════════════════════════════════
# 蜜蜂生成与管理
# ═══════════════════════════════════════════════════════════════════════

func _spawn_bees(count: int) -> void:
	for _i in count:
		_spawn_one_bee(false)


func _spawn_one_bee(king: bool) -> BeeEntity:
	var bee: BeeEntity = BEE_SCENE.instantiate() as BeeEntity
	bee.hive = tower
	bee.ability = self
	bee.is_king = king
	if king:
		bee.base_damage = 8.0
		# 蜂王emoji更大
		if bee.has_node("EmojiLabel"):
			bee.get_node("EmojiLabel").text = "👑🐝"
			bee.get_node("EmojiLabel").add_theme_font_size_override("font_size", 28)
	tower.add_child(bee)
	if king:
		_bee_king = bee
	else:
		_bees.append(bee)
	return bee


func _manage_bee_count() -> void:
	var desired: int = base_bee_count
	# Path0 T1: +1 蜜蜂
	if _lv(0) >= 1:
		desired = base_bee_count + 1

	# 添加缺少的蜜蜂
	var had_bees: int = _bees.size()
	while _bees.size() < desired:
		_spawn_one_bee(false)
	# 新蜜蜂出现时蜂巢抖动
	if _bees.size() > had_bees and tower.has_method("shake"):
		tower.shake(6.0, 0.25)

	# Path0 T4+: 蜂王
	var want_king: bool = _lv(0) >= 4
	if want_king and _bee_king == null:
		_spawn_one_bee(true)
		if tower.has_method("shake"):
			tower.shake(10.0, 0.4)  # 蜂王出现抖动更强
	elif not want_king and _bee_king != null:
		_bee_king.queue_free()
		_bee_king = null

	# 清理无效蜜蜂
	_bees = _bees.filter(func(b): return is_instance_valid(b))


# ═══════════════════════════════════════════════════════════════════════
# 蜜蜂数值刷新
# ═══════════════════════════════════════════════════════════════════════

func _refresh_bee_stats() -> void:
	var dmg_mult: float = 1.0 + P0_DMG[_lv(0)]
	var spd_bonus: float = P0_SPD[_lv(0)] + P1_SPD[_lv(1)]
	var base_interval: float = 1.0
	var interval: float = maxf(base_interval / (1.0 + spd_bonus), 0.05)
	var effects: Array = _build_effects()

	for bee in _bees:
		if is_instance_valid(bee):
			bee.set_damage_mult(dmg_mult)
			bee.set_attack_interval(interval)
			bee.set_effects(effects)

	if is_instance_valid(_bee_king):
		_bee_king.set_damage_mult(dmg_mult)
		_bee_king.set_attack_interval(interval)
		_bee_king.set_effects(effects)


## 构建当前效果数组
func _build_effects() -> Array:
	var effs: Array = []

	# ── Path 0 毒针（T2+）──
	if _lv(0) >= 2:
		var p := BulletEffect.new()
		p.effect_type = BulletEffect.Type.POISON
		p.tick_interval = 1.0
		if _lv(0) >= 3:
			p.damage_per_tick = 5.0
			p.duration = 4.0
		else:
			p.damage_per_tick = 3.0
			p.duration = 3.0
		effs.append(p)
		# T3+: 叠2层
		if _lv(0) >= 3:
			var p2 := BulletEffect.new()
			p2.effect_type = BulletEffect.Type.POISON
			p2.damage_per_tick = p.damage_per_tick
			p2.tick_interval = p.tick_interval
			p2.duration = p.duration
			effs.append(p2)
		# T5: 叠3层
		if _lv(0) >= 5:
			var p3 := BulletEffect.new()
			p3.effect_type = BulletEffect.Type.POISON
			p3.damage_per_tick = p.damage_per_tick
			p3.tick_interval = p.tick_interval
			p3.duration = p.duration
			effs.append(p3)

	# ── Path 2 致命毒巢 ──
	if _lv(2) >= 1:
		var poison := BulletEffect.new()
		poison.effect_type = BulletEffect.Type.POISON
		poison.tick_interval = 1.0
		if _lv(2) >= 2:
			poison.damage_per_tick = 35.0
			poison.duration = 5.0
		else:
			poison.damage_per_tick = 20.0
			poison.duration = 4.0
		effs.append(poison)

		# T3: 叠2层
		if _lv(2) >= 3:
			var p2 := BulletEffect.new()
			p2.effect_type = BulletEffect.Type.POISON
			p2.damage_per_tick = poison.damage_per_tick
			p2.tick_interval = poison.tick_interval
			p2.duration = poison.duration
			effs.append(p2)

		# T4: 叠3层 + 减速30%
		if _lv(2) >= 4:
			var p3 := BulletEffect.new()
			p3.effect_type = BulletEffect.Type.POISON
			p3.damage_per_tick = poison.damage_per_tick
			p3.tick_interval = poison.tick_interval
			p3.duration = poison.duration
			effs.append(p3)

			var slow := BulletEffect.new()
			slow.effect_type = BulletEffect.Type.SLOW
			slow.potency = 0.30
			slow.duration = 2.0
			effs.append(slow)

	# ── Path 1 T4: 25%减速 ──
	if _lv(1) >= 4:
		var slow := BulletEffect.new()
		slow.effect_type = BulletEffect.Type.SLOW
		slow.potency = 0.25
		slow.duration = 2.0
		effs.append(slow)

	return effs


# ═══════════════════════════════════════════════════════════════════════
# 目标分配
# ═══════════════════════════════════════════════════════════════════════

func _assign_targets() -> void:
	var enemies: Array = tower.get_enemies_in_range().duplicate()
	if enemies.is_empty():
		# 全部返回蜂巢
		for bee in _bees:
			if is_instance_valid(bee) and bee.is_busy():
				# 检查目标是否仍在范围内
				if is_instance_valid(bee.target):
					var dist: float = bee.target.global_position.distance_to(tower.global_position)
					if dist > tower._effective_range * 1.2:
						bee.go_return()
				else:
					bee.go_return()
		if is_instance_valid(_bee_king) and _bee_king.is_busy():
			if not is_instance_valid(_bee_king.target):
				_bee_king.go_return()
		return

	var max_targets: int = P1_TARGETS[_lv(1)]
	var target_idx: int = 0

	# 为空闲蜜蜂分配目标
	var all_bees: Array = _bees.duplicate()
	if is_instance_valid(_bee_king):
		all_bees.append(_bee_king)

	for bee in all_bees:
		if not is_instance_valid(bee):
			continue
		# 已在攻击的蜜蜂：检查目标是否仍有效
		if bee.is_busy():
			if not is_instance_valid(bee.target) or bee.target.finished or bee.target.hp <= 0:
				# 直接分配下一个目标，不飞回蜂巢
				var next: Area2D = request_next_target(bee)
				if is_instance_valid(next):
					bee.assign_target(next)
				else:
					bee.go_return()
			continue
		# 空闲蜜蜂：分配目标
		if bee.is_idle() and target_idx < enemies.size():
			var enemy: Area2D = enemies[target_idx]
			if is_instance_valid(enemy) and not enemy.finished:
				bee.assign_target(enemy)
			target_idx += 1
			if target_idx >= max_targets:
				target_idx = 0  # 循环分配


# ═══════════════════════════════════════════════════════════════════════
# 光环 Buff（Path 3）
# ═══════════════════════════════════════════════════════════════════════

func _refresh_aura() -> void:
	var lv3: int = _lv(3)
	if lv3 == 0:
		return

	var aura_radius: float = P3_AURA_RADIUS[lv3]
	var aura_speed: float = P3_AURA_SPEED[lv3]
	var aura_dmg: float = P3_AURA_DMG[lv3]

	# 移除旧 buff
	for t in _buffed_towers:
		if is_instance_valid(t):
			t.buff_speed_mult = maxf(t.buff_speed_mult - aura_speed, 1.0)
			t.buff_damage_mult = maxf(t.buff_damage_mult - aura_dmg, 1.0)
	_buffed_towers.clear()

	# 施加新 buff
	for t in tower.get_nearby_towers(aura_radius):
		t.buff_speed_mult += aura_speed
		t.buff_damage_mult += aura_dmg
		_buffed_towers.append(t)


# ═══════════════════════════════════════════════════════════════════════
# 工具方法
# ═══════════════════════════════════════════════════════════════════════

func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


## 蜜蜂请求下一个目标（目标死亡后直接转攻，不飞回蜂巢）
func request_next_target(bee: BeeEntity) -> Area2D:
	var enemies: Array = tower.get_enemies_in_range().duplicate()
	if enemies.is_empty():
		return null
	# 优先分配未被其他蜜蜂攻击的目标
	var assigned: Array = []
	for b in _bees:
		if is_instance_valid(b) and b != bee and b.is_busy() and is_instance_valid(b.target):
			assigned.append(b.target)
	if is_instance_valid(_bee_king) and _bee_king != bee and _bee_king.is_busy() and is_instance_valid(_bee_king.target):
		assigned.append(_bee_king.target)
	# 先找未被攻击的
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.finished and enemy.hp > 0:
			if enemy not in assigned:
				return enemy
	# 都被攻击了就分配最近的
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.finished and enemy.hp > 0:
			return enemy
	return null


## 售出时清理蜜蜂和 buff
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 清理光环 buff
		for t in _buffed_towers:
			if is_instance_valid(t):
				t.buff_speed_mult = maxf(t.buff_speed_mult - P3_AURA_SPEED[_lv(3)], 1.0)
				t.buff_damage_mult = maxf(t.buff_damage_mult - P3_AURA_DMG[_lv(3)], 1.0)
		_buffed_towers.clear()
		# 蜜蜂会随 tower 子节点自动释放
