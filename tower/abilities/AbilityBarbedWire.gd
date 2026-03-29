extends TowerAbility

## 带刺铁网 — 耐久型路面陷阱
##
## 三态循环：ACTIVE(正常) → BROKEN(损坏) → REPAIRING(维修中) → ACTIVE
## 敌人踩踏消耗耐久，耐久=0损坏失效，玩家点击维修
##
## Path 0 终极铁刺：伤害+出血+护甲忽视+精英眩晕
## Path 1 钢铁长城：超高耐久+自动修补+维修缩短
## Path 2 磁化铁网：电击眩晕+损坏爆炸+磁力拉近+维修冲击
## Path 3 极致缠绕：极强减速+减速增伤+取消冲锋

enum State { ACTIVE, BROKEN, REPAIRING }

# ── 耐久/维修基础值 ─────────────────────────────────────────────────────
const BASE_DURABILITY: int = 5
const BASE_REPAIR_TIME: float = 8.0

# ── 各路线耐久加成（累计）─────────────────────────────────────────────
const P0_DUR:  Array[int]   = [0, 0, 0, 2, 2, 2]       # Path0 T3+: +2
const P1_DUR:  Array[int]   = [0, 3, 6, 6, 10, 15]     # Path1: +3/+6/+6/+10/+15
const P3_DUR:  Array[int]   = [0, 0, 0, 0, 2, 2]       # Path3 T4+: +2

# ── Path 0 出血参数 ─────────────────────────────────────────────────────
const P0_BLEED_DPS:  Array[float] = [0.0, 3.0, 5.0, 5.0, 5.0, 5.0]
const P0_BLEED_DUR:  Array[float] = [0.0, 4.0, 5.0, 5.0, 5.0, 5.0]
const P0_DMG_MULT:   Array[float] = [1.0, 1.25, 1.25, 1.25, 1.25, 2.0]  # T5: ×2
const P0_ARMOR_PEN:  Array[int]   = [0, 0, 1, 1, 1, 1]  # T2+: 忽视1级护甲

# ── Path 1 维修时间 ─────────────────────────────────────────────────────
const P1_REPAIR: Array[float] = [8.0, 8.0, 6.0, 6.0, 6.0, 6.0]  # T2:6s, T5:6s(自动)

# ── Path 3 减速参数 ─────────────────────────────────────────────────────
const P3_SLOW:     Array[float] = [0.0, 0.25, 0.38, 0.50, 0.58, 0.65]
const P3_SLOW_DUR: Array[float] = [0.0, 1.5,  2.5,  2.5,  2.5,  10.0]  # T5: 残留10s

# ── 状态 ────────────────────────────────────────────────────────────────
var _state: int = State.ACTIVE
var _durability: int = BASE_DURABILITY
var _max_durability: int = BASE_DURABILITY
var _repair_time: float = BASE_REPAIR_TIME
var _repair_timer: float = 0.0
var _auto_repair_timer: float = 0.0
var _stepped_enemies: Dictionary = {}   # enemy_id → true（避免同一敌人重复消耗）

# ── 效果对象 ────────────────────────────────────────────────────────────
var _slow_fx: BulletEffect = null
var _bleed_fx: BulletEffect = null
var _stun_fx: BulletEffect = null

# ── 耐久条 UI ──────────────────────────────────────────────────────────
var _dur_bar: ProgressBar = null
var _broken_label: Label = null


func _lv(path: int) -> int:
	return tower._in_game_path_levels[path] if tower._in_game_path_levels.size() > path else 0


func on_placed() -> void:
	_slow_fx = BulletEffect.new()
	_slow_fx.effect_type = BulletEffect.Type.SLOW
	_slow_fx.duration = 1.5

	_bleed_fx = BulletEffect.new()
	_bleed_fx.effect_type = BulletEffect.Type.BLEED
	_bleed_fx.tick_interval = 1.0

	_stun_fx = BulletEffect.new()
	_stun_fx.effect_type = BulletEffect.Type.STUN
	_stun_fx.duration = 0.6

	_create_durability_bar()
	_recalc_stats()


# ═══════════════════════════════════════════════════════════════════════
# 主攻击（不使用 Tower 定时攻击，attack_speed=0）
# ═══════════════════════════════════════════════════════════════════════
func do_attack(_target: Area2D, _damage: float, _td: TowerCollectionData) -> bool:
	return true   # 跳过 Tower 默认攻击，由 ability_process 处理踩踏


## 踩踏伤害检测（每帧在 ability_process 中调用）
func _check_step_damage() -> void:
	if _state != State.ACTIVE:
		return

	var td := tower.tower_data as TowerCollectionData
	if not td:
		return

	var base_dmg: float = td.base_damage * P0_DMG_MULT[_lv(0)]
	var gp: bool = tower.buff_giant_pierce
	tower.armor_penetration = P0_ARMOR_PEN[_lv(0)]

	# 构建效果列表
	var effects: Array = []
	if _lv(3) >= 1:
		_slow_fx.potency = P3_SLOW[_lv(3)]
		_slow_fx.duration = P3_SLOW_DUR[_lv(3)]
		effects.append(_slow_fx)
	if _lv(0) >= 1:
		_bleed_fx.damage_per_tick = P0_BLEED_DPS[_lv(0)]
		_bleed_fx.duration = P0_BLEED_DUR[_lv(0)]
		effects.append(_bleed_fx)
	if _lv(1) >= 4 and _lv(3) == 0:
		_slow_fx.potency = 0.15
		_slow_fx.duration = 1.5
		effects.append(_slow_fx)

	var did_hit: bool = false
	for enemy in _get_enemies_on_trap():
		if not is_instance_valid(enemy):
			continue

		var ed = enemy.get("enemy_data")
		if ed and ed.get("can_bypass_traps"):
			continue

		var eid: int = enemy.get_instance_id()

		# 首次踩踏：消耗耐久 + 伤害 + 抖动
		if not _stepped_enemies.has(eid):
			_stepped_enemies[eid] = true
			var dur_cost: int = 2 if _lv(0) >= 5 else 1
			_durability = maxi(_durability - dur_cost, 0)
			_update_dur_bar()
			_shake()
			did_hit = true

			# Path 2 T1: 25%眩晕
			if _lv(2) >= 1 and randf() < 0.25:
				deal_damage(enemy, 0.0, [_stun_fx], gp)

			# 踩踏伤害 + 效果
			var hit_effects: Array = effects.duplicate()
			if _lv(0) >= 5 and ed and ed.get("is_elite"):
				var elite_stun := BulletEffect.new()
				elite_stun.effect_type = BulletEffect.Type.STUN
				elite_stun.duration = 1.5
				hit_effects.append(elite_stun)
			if _lv(3) >= 4 and enemy.get("_charge_timer") != null:
				enemy._charge_timer = 999.0
			deal_damage(enemy, base_dmg, hit_effects, gp)

	if did_hit:
		tower.flash_attack_range(Color(0.7, 0.7, 0.7))

	# 清理已离开范围的敌人
	var in_range_ids: Dictionary = {}
	for enemy in _get_enemies_on_trap():
		if is_instance_valid(enemy):
			in_range_ids[enemy.get_instance_id()] = true
	for eid in _stepped_enemies.keys():
		if not in_range_ids.has(eid):
			_stepped_enemies.erase(eid)

	if _durability <= 0:
		_set_broken()


# ═══════════════════════════════════════════════════════════════════════
# 被动处理
# ═══════════════════════════════════════════════════════════════════════
func ability_process(delta: float) -> void:
	_recalc_stats()

	# 耐久条/损坏标签反向旋转（保持水平，不随路径旋转）
	var neg_rot: float = -tower.global_rotation
	if is_instance_valid(_dur_bar):
		_dur_bar.rotation = neg_rot
		_dur_bar.position = Vector2(-30, -50).rotated(neg_rot)
	if is_instance_valid(_broken_label):
		_broken_label.rotation = neg_rot
		_broken_label.position = Vector2(-40, -70).rotated(neg_rot)

	match _state:
		State.REPAIRING:
			_repair_timer -= delta
			_update_dur_bar()
			# P1 T5: 维修中仍可施加50%减速
			if _lv(1) >= 5:
				_apply_repair_slow()
			if _repair_timer <= 0.0:
				_finish_repair()

		State.BROKEN:
			# P1 T5: 损坏后自动开始维修
			if _lv(1) >= 5:
				start_repair()

		State.ACTIVE:
			# 踩踏伤害检测
			_check_step_damage()
			# Path 1 T3+: 每10s自动恢复1耐久
			if _lv(1) >= 3 and _durability < _max_durability:
				_auto_repair_timer += delta
				if _auto_repair_timer >= 10.0:
					_auto_repair_timer = 0.0
					_durability = mini(_durability + 1, _max_durability)
					_update_dur_bar()


# ═══════════════════════════════════════════════════════════════════════
# 状态切换
# ═══════════════════════════════════════════════════════════════════════
func _set_broken() -> void:
	_state = State.BROKEN
	_durability = 0
	_update_dur_bar()
	# 显示损坏标签
	if not is_instance_valid(_broken_label):
		_broken_label = Label.new()
		_broken_label.text = "⚠已损坏"
		_broken_label.add_theme_font_size_override("font_size", 18)
		_broken_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_broken_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_broken_label.position = Vector2(-40, -70)
		_broken_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tower.add_child(_broken_label)
	_broken_label.visible = true
	# 灰化精灵
	tower.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# Path 2 T2: 损坏时自动爆炸
	if _lv(2) >= 2:
		_on_break_explode()


## 玩家点击开始维修（由 BattleScene 调用）
func start_repair() -> void:
	if _state != State.BROKEN:
		return
	_state = State.REPAIRING
	_repair_timer = _repair_time
	if is_instance_valid(_broken_label):
		_broken_label.text = "🔧维修中..."
		_broken_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))


func _finish_repair() -> void:
	_state = State.ACTIVE
	_durability = _max_durability
	_repair_timer = 0.0
	_stepped_enemies.clear()
	_update_dur_bar()
	tower.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if is_instance_valid(_broken_label):
		_broken_label.visible = false

	# Path 2 T5: 维修完成瞬间电磁脉冲
	if _lv(2) >= 5:
		_on_repair_pulse()


# ═══════════════════════════════════════════════════════════════════════
# 数值重算
# ═══════════════════════════════════════════════════════════════════════
func _recalc_stats() -> void:
	var old_max: int = _max_durability
	_max_durability = BASE_DURABILITY + P0_DUR[_lv(0)] + P1_DUR[_lv(1)] + P3_DUR[_lv(3)]
	_repair_time = P1_REPAIR[_lv(1)]
	# 升级增加耐久上限时，当前耐久同步增加
	if _max_durability > old_max and _state == State.ACTIVE:
		_durability += (_max_durability - old_max)
		_durability = mini(_durability, _max_durability)
	if _dur_bar:
		_dur_bar.max_value = _max_durability


# ═══════════════════════════════════════════════════════════════════════
# 特殊效果
# ═══════════════════════════════════════════════════════════════════════

## Path 2 T2: 损坏时爆炸
func _on_break_explode() -> void:
	var explode_dmg: float = 60.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(tower.global_position) <= 80.0:
			deal_damage(enemy, explode_dmg, [], tower.buff_giant_pierce)
	# 爆炸视觉
	var lbl := Label.new()
	lbl.text = "💥"
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.global_position = tower.global_position - Vector2(18, 18)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(2.0, 2.0), 0.2).from(Vector2(0.5, 0.5))
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


## Path 2 T5: 维修完成电磁脉冲
func _on_repair_pulse() -> void:
	var pulse_dmg: float = 120.0
	var pulse_r: float = 150.0
	var stun := BulletEffect.new()
	stun.effect_type = BulletEffect.Type.STUN
	stun.duration = 1.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(tower.global_position) <= pulse_r:
			deal_damage(enemy, pulse_dmg, [stun], tower.buff_giant_pierce)
	# 脉冲视觉
	var lbl := Label.new()
	lbl.text = "⚡"
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.global_position = tower.global_position - Vector2(24, 24)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(3.0, 3.0), 0.3).from(Vector2(0.5, 0.5))
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


# ═══════════════════════════════════════════════════════════════════════
# 耐久条 UI
# ═══════════════════════════════════════════════════════════════════════
## P1 T5: 维修中施加50%减速给范围内敌人
func _apply_repair_slow() -> void:
	_slow_fx.potency = 0.50
	_slow_fx.duration = 1.0
	for enemy in tower.get_enemies_in_range().duplicate():
		if is_instance_valid(enemy):
			var ed = enemy.get("enemy_data")
			if ed and ed.get("can_bypass_traps"):
				continue
			if enemy.has_method("apply_effect"):
				enemy.apply_effect(_slow_fx)


## 获取在陷阱区域内的敌人
## 使用 PlacementPolygon 矩形判定（考虑旋转），fallback 到圆形检测
func _get_enemies_on_trap() -> Array:
	var polygon: CollisionPolygon2D = tower.get_node_or_null("PlacementPolygon")
	if not polygon or polygon.polygon.is_empty():
		return tower.get_enemies_in_range()

	# 获取多边形顶点并放大1.5倍（原始太小，确保敌人能被检测到）
	var pts: PackedVector2Array = polygon.polygon
	var scaled_pts: PackedVector2Array = PackedVector2Array()
	for pt in pts:
		scaled_pts.append(pt * 1.5)

	var result: Array = []
	var tower_pos: Vector2 = tower.global_position
	var tower_rot: float = tower.global_rotation
	for enemy in GameManager.get_all_enemies():
		if not is_instance_valid(enemy) or enemy.finished:
			continue
		# 将敌人位置转换到陷阱本地坐标（只考虑位移+旋转，不含缩放）
		var rel: Vector2 = enemy.global_position - tower_pos
		var local_pos: Vector2 = rel.rotated(-tower_rot)
		if Geometry2D.is_point_in_polygon(local_pos, scaled_pts):
			result.append(enemy)
	return result


## 踩踏抖动（随机方向微位移）
func _shake() -> void:
	var spr: Sprite2D = tower.get_node_or_null("BaseSprite")
	if not spr:
		return
	var angle: float = randf() * TAU
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * 2.0
	var orig_pos: Vector2 = spr.position
	var tw := spr.create_tween()
	tw.tween_property(spr, "position", orig_pos + offset, 0.04)
	tw.tween_property(spr, "position", orig_pos, 0.1).set_ease(Tween.EASE_OUT)


func _create_durability_bar() -> void:
	_dur_bar = ProgressBar.new()
	_dur_bar.max_value = _max_durability
	_dur_bar.value = _durability
	_dur_bar.show_percentage = false
	_dur_bar.custom_minimum_size = Vector2(60, 8)
	_dur_bar.size = Vector2(60, 8)
	_dur_bar.position = Vector2(-30, -50)
	_dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	_dur_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.8, 0.2)   # 绿色
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	_dur_bar.add_theme_stylebox_override("fill", fill_style)

	tower.add_child(_dur_bar)


func _update_dur_bar() -> void:
	if not is_instance_valid(_dur_bar):
		return

	if _state == State.REPAIRING:
		# 维修中显示维修进度
		_dur_bar.max_value = _repair_time
		_dur_bar.value = _repair_time - _repair_timer
		var fill := _dur_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = Color(0.2, 0.5, 1.0)   # 蓝色 = 维修中
	else:
		_dur_bar.max_value = _max_durability
		_dur_bar.value = _durability
		var fill := _dur_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			var ratio: float = float(_durability) / float(maxi(_max_durability, 1))
			if ratio > 0.5:
				fill.bg_color = Color(0.2, 0.8, 0.2)   # 绿色
			elif ratio > 0.0:
				fill.bg_color = Color(1.0, 0.6, 0.1)   # 橙色
			else:
				fill.bg_color = Color(1.0, 0.2, 0.2)   # 红色
