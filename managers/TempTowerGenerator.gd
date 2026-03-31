class_name TempTowerGenerator
extends RefCounted

## 临时炮台随机生成器（纯工具类，无状态）
## 用法：var entry = TempTowerGenerator.generate_random()

# ── 稀有度概率表（白20 绿25 蓝30 紫15 橙10）──────────────────────────
const RARITY_WEIGHTS: Array[Array] = [
	[0, 20],  # 白
	[1, 25],  # 绿
	[2, 30],  # 蓝
	[3, 15],  # 紫
	[4, 10],  # 橙
]

# ── 橙色英雄概率 ─────────────────────────────────────────────────────
const ORANGE_HERO_CHANCE: float = 0.5

# ── 英雄等级概率表（Lv1~Lv8，总和100%）───────────────────────────────
const HERO_LEVEL_WEIGHTS: Array[Array] = [
	[1, 12],
	[2, 18],
	[3, 20],
	[4, 18],
	[5, 10],
	[6, 10],
	[7, 7],
	[8, 5],
]


## 按标准概率随机生成一个临时炮台
static func generate_random() -> Dictionary:
	var rarity: int = _weighted_pick(RARITY_WEIGHTS)
	return _generate_for_rarity(rarity)


## 生成指定稀有度的临时炮台
static func generate_of_rarity(rarity: int) -> Dictionary:
	return _generate_for_rarity(rarity)


## 内部：根据稀有度生成完整条目
static func _generate_for_rarity(rarity: int) -> Dictionary:
	var by_rarity: Dictionary = TowerResourceRegistry.get_towers_by_rarity()
	var is_hero: bool = false

	# 橙色：50% 概率为英雄
	if rarity == 4:
		is_hero = randf() < ORANGE_HERO_CHANCE

	# 筛选候选炮台
	var candidates: Array = []
	var pool: Array = by_rarity.get(rarity, [])
	for res in pool:
		var hero_flag: bool = res.get("is_hero") == true
		if rarity == 4:
			if is_hero and hero_flag:
				candidates.append(res)
			elif not is_hero and not hero_flag:
				candidates.append(res)
		else:
			if not hero_flag:
				candidates.append(res)

	# 安全回退：无候选时取该稀有度全部
	if candidates.is_empty():
		candidates = pool.duplicate()
	if candidates.is_empty():
		# 极端回退：取全部炮台
		candidates = TowerResourceRegistry.get_all_resources().duplicate()

	var tower_data: Resource = candidates[randi() % candidates.size()]
	var tower_id: String = tower_data.get("tower_id")

	var entry: Dictionary = {
		"tower_id": tower_id,
		"rarity": rarity,
		"is_hero": is_hero,
		"hero_level": 0,
		"hero_directions": [],
	}

	# 英雄：随机等级 + 方向
	if is_hero:
		var hero_level: int = _weighted_pick(HERO_LEVEL_WEIGHTS)
		entry["hero_level"] = hero_level
		var directions: Array[String] = []
		# 每层独立 50/50 随机 A 或 B
		for tier in range(1, hero_level):
			var choice: String = "A" if randf() < 0.5 else "B"
			directions.append("%d%s" % [tier, choice])
		entry["hero_directions"] = directions

	return entry


## 加权随机选择：weights = [[value, weight], ...]
static func _weighted_pick(weights: Array) -> int:
	var total: int = 0
	for w in weights:
		total += int(w[1])
	var roll: int = randi() % total
	var cumulative: int = 0
	for w in weights:
		cumulative += int(w[1])
		if roll < cumulative:
			return int(w[0])
	return int(weights[weights.size() - 1][0])
