extends TowerAbility

## 农场守卫者 — 禁锢领域（被动地形英雄）
##
## Lv1: 领域内敌人移速-20%，嘲讽（敌人优先朝守卫者移动）
## Lv2A: 铁壁嘲讽（嘲讽范围200px，停留+1.5s）  |  Lv2B: 重力领域（移速-35%，大型同效）
## Lv3A: 石刻地面（领域每秒8伤害）              |  Lv3B: 破甲领域（护甲-10%）
## Lv4A: 冲击余波（每20s地震100px眩晕1.2s）     |  Lv4B: 磁力核心（吸引域外100px敌人）
## Lv5A: 永恒禁锢（280px，嘲讽期间全场+25%伤）  |  Lv5B: 石之迫近（死亡留石化标记减速10s）

const TERRAIN_DATA_PATH := "res://data/heroes/guardian_terrain.tres"

## 域内效果刷新间隔
@export var effect_interval: float = 0.5

# ── 基础参数 ─────────────────────────────────────────────────────────
@export var base_slow: float = 0.20
@export var base_taunt_radius: float = 160.0

# ── 运行时状态 ─────────────────────────────────────────────────────────
var _terrain_data: HeroTerrainData = null
var _effect_timer: float = 0.0
var _affected_enemies: Array = []

## 当前减速比例
var _current_slow: float = 0.20
## 大型敌人是否也受减速
var _slow_affects_giant: bool = false
## 嘲讽范围
var _taunt_radius: float = 160.0
## 嘲讽停留时间加成
var _taunt_linger: float = 0.0
## 石刻地面：每秒伤害
var _terrain_dps: float = 0.0
var _dps_timer: float = 0.0
## 破甲领域：护甲减少比例
var _armor_reduction: float = 0.0
## 冲击余波：地震间隔和参数
var _quake_interval: float = 0.0
@export var quake_radius: float = 100.0
@export var quake_stun: float = 1.2
var _quake_timer: float = 0.0
## 磁力核心：吸引范围外敌人
var _magnet_enabled: bool = false
@export var magnet_range: float = 100.0
## 永恒禁锢：嘲讽期间全场加伤
var _global_damage_bonus: float = 0.0
## 石之迫近：死亡留石化标记
var _petrify_on_death: bool = false
@export var petrify_slow_duration: float = 10.0


func on_placed() -> void:
	_terrain_data = load(TERRAIN_DATA_PATH) as HeroTerrainData
	if _terrain_data:
		tower.terrain_radius = _terrain_data.base_radius
		tower.terrain_color  = _terrain_data.terrain_color
		tower.queue_redraw()
	_taunt_radius = tower.terrain_radius


## 英雄不攻击
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	return true


func ability_process(delta: float) -> void:
	# ── 域内效果刷新 ──
	_effect_timer += delta
	if _effect_timer >= effect_interval:
		_effect_timer = 0.0
		_apply_terrain_effects()

	# ── 石刻地面 DPS ──
	if _terrain_dps > 0.0:
		_dps_timer += delta
		if _dps_timer >= 1.0:
			_dps_timer = 0.0
			_apply_terrain_damage()

	# ── 冲击余波 ──
	if _quake_interval > 0.0:
		_quake_timer += delta
		if _quake_timer >= _quake_interval:
			_quake_timer = 0.0
			_trigger_earthquake()

	# ── 磁力核心 ──
	if _magnet_enabled:
		_apply_magnet_pull(delta)


## 应用升级选择
func apply_upgrade(tier: int, choice: String) -> void:
	match tier:
		1:  # 波次5
			if choice == "A":
				# 铁壁嘲讽：嘲讽范围200px，停留+1.5s
				_taunt_radius = 200.0
				_taunt_linger = 1.5
			else:
				# 重力领域：移速-35%，大型同效
				_current_slow = 0.35
				_slow_affects_giant = true
		2:  # 波次10
			if choice == "A":
				# 石刻地面：每秒8伤害
				_terrain_dps = 8.0
			else:
				# 破甲领域：护甲-10%
				_armor_reduction = 0.10
		3:  # 波次15
			if choice == "A":
				# 冲击余波：每20s地震
				_quake_interval = 20.0
			else:
				# 磁力核心：吸引域外100px敌人
				_magnet_enabled = true
		4:  # 波次20
			if choice == "A":
				# 永恒禁锢：280px，全场+25%伤
				tower.terrain_radius = 280.0
				_taunt_radius = 280.0
				_global_damage_bonus = 0.25
				tower.queue_redraw()
			else:
				# 石之迫近：域内死亡留石化标记
				_petrify_on_death = true


## 对域内敌人施加减速和嘲讽
func _apply_terrain_effects() -> void:
	if not is_instance_valid(tower):
		return
	var radius: float = tower.terrain_radius

	# 清除旧效果
	for e in _affected_enemies:
		if is_instance_valid(e):
			e.terrain_slow = 0.0
			e.taunt_target = null
			e.terrain_armor_reduction = 0.0
	_affected_enemies.clear()

	# 扫描域内敌人
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		var dist: float = enemy.global_position.distance_to(tower.global_position)
		if dist > radius:
			continue

		# 检查是否是大型且不受减速
		var ed = enemy.get("enemy_data")
		var is_giant: bool = ed != null and ed.get("is_giant") == true
		if is_giant and not _slow_affects_giant:
			# 大型不受减速，但仍受嘲讽
			pass
		else:
			enemy.terrain_slow = _current_slow

		# 嘲讽（域内 + 嘲讽范围内）
		if dist <= _taunt_radius:
			enemy.taunt_target = tower

		# 破甲
		if _armor_reduction > 0.0:
			enemy.terrain_armor_reduction = _armor_reduction

		_affected_enemies.append(enemy)


## 石刻地面：对域内敌人造成伤害
func _apply_terrain_damage() -> void:
	if not is_instance_valid(tower):
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(tower.global_position) > tower.terrain_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(_terrain_dps)


## 冲击余波：地震 AoE 眩晕
func _trigger_earthquake() -> void:
	if not is_instance_valid(tower):
		return
	var stun_fx := BulletEffect.new()
	stun_fx.effect_type = BulletEffect.Type.STUN
	stun_fx.duration    = quake_stun

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(tower.global_position) > quake_radius:
			continue
		if enemy.has_method("apply_effect"):
			enemy.apply_effect(stun_fx)

	# 视觉特效
	_show_quake_vfx()


## 磁力核心：对域外100px内敌人施加强减速（不移动敌人位置，保持在路径上）
func _apply_magnet_pull(_delta: float) -> void:
	if not is_instance_valid(tower):
		return
	var radius: float = tower.terrain_radius
	var pull_range: float = radius + magnet_range

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		var dist: float = enemy.global_position.distance_to(tower.global_position)
		# 域外 ~ pull_range 之间的敌人施加强减速
		if dist > radius and dist <= pull_range:
			enemy.terrain_slow = maxf(enemy.terrain_slow, 0.50)   # 50% 减速


## 域内敌人死亡时调用（由 BattleScene 转发）
func on_enemy_died_in_terrain(enemy: Area2D) -> void:
	if not _petrify_on_death:
		return
	if not is_instance_valid(tower) or not is_instance_valid(enemy):
		return
	if enemy.global_position.distance_to(tower.global_position) > tower.terrain_radius:
		return
	# 在死亡位置留下石化标记
	_place_petrify_mark(enemy.global_position)


## 放置石化标记（减速后续敌人10秒）
func _place_petrify_mark(pos: Vector2) -> void:
	var mark := Area2D.new()
	mark.collision_layer = 0
	mark.collision_mask  = 4   # 敌人碰撞层

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	col.shape = circle
	mark.add_child(col)

	var lbl := Label.new()
	lbl.text = "🪦"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.position = Vector2(-16, -20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(lbl)

	mark.global_position = pos
	get_tree().current_scene.add_child(mark)

	# 对进入标记的敌人施加减速
	mark.area_entered.connect(func(area: Area2D):
		if area.is_in_group("enemy") and is_instance_valid(area):
			var slow_fx := BulletEffect.new()
			slow_fx.effect_type = BulletEffect.Type.SLOW
			slow_fx.potency     = 0.30
			slow_fx.duration    = petrify_slow_duration
			if area.has_method("apply_effect"):
				area.apply_effect(slow_fx)
	)

	# 10秒后消失
	var life_timer := Timer.new()
	life_timer.wait_time = petrify_slow_duration
	life_timer.one_shot  = true
	life_timer.autostart = true
	mark.add_child(life_timer)
	life_timer.timeout.connect(func():
		if is_instance_valid(mark):
			mark.queue_free()
	)


## 从存档恢复升级状态
func restore_upgrades(choices: Array[String]) -> void:
	for i in choices.size():
		apply_upgrade(i + 1, choices[i])


## 返回全场伤害加成值（供 BattleScene 读取并应用到所有塔）
func get_global_damage_bonus() -> float:
	return _global_damage_bonus


## 地震视觉特效
func _show_quake_vfx() -> void:
	if not is_instance_valid(tower):
		return
	var lbl := Label.new()
	lbl.text = "💥 地震！"
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.modulate = Color(0.8, 0.4, 0.1)
	lbl.position = Vector2(-80, -120)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.add_child(lbl)
	var tw := tower.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)
