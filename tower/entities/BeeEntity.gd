class_name BeeEntity extends Node2D

## 持久蜜蜂召唤物
## 状态机：IDLE(围绕蜂巢) → FLYING(飞向目标) → ENGAGED(持续攻击) → RETURN(飞回蜂巢)

enum State { IDLE, FLYING, ENGAGED, RETURN }

# ── 基础属性 ────────────────────────────────────────────────────────────
@export var base_damage: float = 4.0
@export var attack_interval: float = 1.0
@export var fly_speed: float = 300.0
@export var orbit_radius: float = 30.0
@export var orbit_speed: float = 2.0
@export var arrive_threshold: float = 15.0

# ── 状态 ────────────────────────────────────────────────────────────────
var state: State = State.IDLE
var target: Area2D = null
var hive: Area2D = null          ## 所属蜂巢 Tower 引用
var ability: TowerAbility = null ## 所属能力脚本引用
var effects: Array = []          ## 当前携带的 BulletEffect 数组
var is_king: bool = false        ## 是否为蜂王

# ── 内部计时 ────────────────────────────────────────────────────────────
var _attack_timer: float = 0.0
var _orbit_angle: float = 0.0
var _damage_mult: float = 1.0    ## 外部伤害倍率（升级加成）

# ── 视觉 ────────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D = $BeeSprite if has_node("BeeSprite") else null
@onready var _emoji: Label = $EmojiLabel if has_node("EmojiLabel") else null


func _ready() -> void:
	# 随机初始轨道角度，避免所有蜜蜂重叠
	_orbit_angle = randf() * TAU
	# 优先显示图片，无图片时显示 emoji
	if _sprite and _sprite.texture:
		if _emoji:
			_emoji.visible = false
	elif _emoji:
		_emoji.visible = true
		_emoji.text = "👑🐝" if is_king else "🐝"


func _process(delta: float) -> void:
	match state:
		State.IDLE:
			_process_idle(delta)
		State.FLYING:
			_process_flying(delta)
		State.ENGAGED:
			_process_engaged(delta)
		State.RETURN:
			_process_return(delta)


# ═══════════════════════════════════════════════════════════════════════
# 状态处理
# ═══════════════════════════════════════════════════════════════════════

func _process_idle(delta: float) -> void:
	if not is_instance_valid(hive):
		return
	_orbit_angle += orbit_speed * delta
	var offset := Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	global_position = hive.global_position + offset


func _process_flying(delta: float) -> void:
	if not is_instance_valid(target) or target.finished:
		_lose_target()
		return
	var dir := (target.global_position - global_position)
	var dist := dir.length()
	if dist <= arrive_threshold:
		state = State.ENGAGED
		_attack_timer = 0.0
		_do_attack()
	else:
		global_position += dir.normalized() * fly_speed * delta
	# 面向目标
	if dir.x != 0:
		scale.x = -1.0 if dir.x < 0 else 1.0


func _process_engaged(delta: float) -> void:
	if not is_instance_valid(target) or target.finished or target.hp <= 0:
		_lose_target()
		return
	# 跟随目标
	var dir := target.global_position - global_position
	if dir.length() > arrive_threshold * 2.0:
		global_position += dir.normalized() * fly_speed * delta
	# 攻击计时
	_attack_timer += delta
	if _attack_timer >= _get_effective_interval():
		_attack_timer = 0.0
		_do_attack()


func _process_return(delta: float) -> void:
	if not is_instance_valid(hive):
		return
	var dir := hive.global_position - global_position
	if dir.length() <= arrive_threshold:
		state = State.IDLE
	else:
		global_position += dir.normalized() * fly_speed * delta


# ═══════════════════════════════════════════════════════════════════════
# 攻击
# ═══════════════════════════════════════════════════════════════════════

func _do_attack() -> void:
	if not is_instance_valid(target) or not is_instance_valid(ability):
		return
	var dmg: float = base_damage * _damage_mult
	ability.deal_damage(target, dmg, effects.duplicate(), _get_pierce_giant())

	# 蜂王 AOE（Path0 T4+）
	if is_king:
		_do_king_aoe(dmg)


## 蜂王 AOE 攻击
func _do_king_aoe(dmg: float) -> void:
	if not is_instance_valid(target):
		return
	var aoe_radius: float = 150.0
	var aoe_dmg: float = 8.0 * _damage_mult
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == target or not is_instance_valid(enemy) or enemy.finished:
			continue
		if enemy.global_position.distance_to(target.global_position) <= aoe_radius:
			ability.deal_damage(enemy, aoe_dmg, [], _get_pierce_giant())


func _get_pierce_giant() -> bool:
	return hive.buff_giant_pierce if is_instance_valid(hive) else false


func _get_effective_interval() -> float:
	return maxf(attack_interval, 0.05)


# ═══════════════════════════════════════════════════════════════════════
# 外部接口
# ═══════════════════════════════════════════════════════════════════════

## 分配攻击目标
func assign_target(enemy: Area2D) -> void:
	if not is_instance_valid(enemy) or enemy.finished:
		return
	target = enemy
	state = State.FLYING
	_attack_timer = 0.0


## 更新攻击效果
func set_effects(effs: Array) -> void:
	effects = effs


## 设置伤害倍率
func set_damage_mult(mult: float) -> void:
	_damage_mult = mult


## 设置攻击间隔
func set_attack_interval(interval: float) -> void:
	attack_interval = interval


## 命令返回蜂巢
func go_return() -> void:
	target = null
	state = State.RETURN


## 是否空闲
func is_idle() -> bool:
	return state == State.IDLE


## 是否正在攻击
func is_engaged() -> bool:
	return state == State.ENGAGED


## 是否正在飞行或战斗
func is_busy() -> bool:
	return state == State.FLYING or state == State.ENGAGED


## 目标丢失处理 — 优先寻找下一个目标，无目标才返回蜂巢
func _lose_target() -> void:
	target = null
	# 尝试从能力脚本获取下一个目标
	if is_instance_valid(ability) and ability.has_method("request_next_target"):
		var next: Area2D = ability.request_next_target(self)
		if is_instance_valid(next) and not next.finished:
			assign_target(next)
			return
	# 无可用目标，返回蜂巢
	state = State.RETURN
