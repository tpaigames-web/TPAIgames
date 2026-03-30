extends Node

## 炮台收藏状态管理 Autoload
## 负责追踪玩家拥有的碎片数量、炮台等级和解锁状态。
## 存档读写由 SaveManager 统一协调（get_save_data / load_save_data）。

## 碎片或解锁状态发生变化时发出（UI 监听此信号来刷新显示）
signal collection_changed

## 基础炮台（玩家初始解锁，无需碎片）
## 白色(0)+绿色(1)+蓝色(2)品质炮台默认解锁
const BASE_TOWERS: Array[String] = [
	"scarecrow", "beehive",                                  # 白色(0)
	"barbed_wire", "bear_trap", "farm_cannon", "water_pipe", # 绿色(1)
	"mushroom_bomb", "seed_shooter", "windmill",             # 蓝色(2)
	"farm_guardian",                                          # 橙色(4) 英雄·免费赠送
]

## 炮台资源路径（用于延迟加载 level_required）
const TOWER_RESOURCE_PATHS: Array[String] = [
	"res://data/towers/scarecrow_collection.tres",
	"res://data/towers/water_pipe_collection.tres",
	"res://data/towers/farmer_collection.tres",
	"res://data/towers/bear_trap_collection.tres",
	"res://data/towers/beehive_collection.tres",
	"res://data/towers/farm_cannon_collection.tres",
	"res://data/towers/barbed_wire_collection.tres",
	"res://data/towers/windmill_collection.tres",
	"res://data/towers/seed_shooter_collection.tres",
	"res://data/towers/mushroom_bomb_collection.tres",
	"res://data/towers/chili_flamer_collection.tres",
	"res://data/towers/watchtower_collection.tres",
	"res://data/towers/sunflower_collection.tres",
	"res://data/towers/hero_farmer_collection.tres",
	"res://data/towers/farm_guardian_collection.tres",
]

## 拥有的碎片数量：tower_id → count
var owned_fragments: Dictionary = {}

## 炮台当前等级：tower_id → level（0表示未解锁）
var tower_levels: Dictionary = {}

## 已解锁的炮台 ID 列表
var unlocked_towers: Array[String] = []

## 升级路径进度：tower_id → [tier0, tier1, tier2, tier3]（每条路径已解锁层数 0~5）
var path_levels: Dictionary = {}

## 英雄局外升级：hero_id → Array of unlocked option keys
## 格式：["1A", "1B", "2A", "3B", ...] 表示已解锁的方向
## 4方向×2选项 = 8个可能，1A=方向1选项A，2B=方向2选项B
## 英雄等级 = 已解锁数量 + 1（最高 Lv.9 = 8个全解锁+初始）
var hero_upgrades: Dictionary = {}

## 英雄升级碎片花费表（Lv.2→Lv.8 共7级）
const HERO_UPGRADE_FRAG_COSTS: Array[int] = [15, 25, 35, 45, 55, 70, 90]
const HERO_UPGRADE_GOLD_COSTS: Array[int] = [500, 1000, 1500, 2000, 3000, 4000, 5000]

## 延迟加载的等级要求缓存：tower_id → level_required
var _tower_level_reqs: Dictionary = {}

## 延迟加载的炮台数据缓存：tower_id → TowerCollectionData
var _tower_data_cache: Dictionary = {}

func _ready() -> void:
	# 基础炮台默认解锁
	for tower_id in BASE_TOWERS:
		if tower_id not in unlocked_towers:
			unlocked_towers.append(tower_id)
	# 农场守卫者免费送第一个升级方向（1A=铁壁嘲讽）
	if "farm_guardian" not in hero_upgrades:
		hero_upgrades["farm_guardian"] = ["1A"]
	elif "1A" not in hero_upgrades["farm_guardian"]:
		hero_upgrades["farm_guardian"].append("1A")

## 懒加载所有炮台的 level_required（首次调用时读取资源，之后幂等）
func _ensure_reqs_loaded() -> void:
	if not _tower_level_reqs.is_empty():
		return
	for path in TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			continue
		var tid = res.get("tower_id")
		var req = res.get("level_required")
		if tid != null:
			_tower_level_reqs[str(tid)] = int(req) if req != null else 1

## 根据 tower_id 获取 TowerCollectionData 资源（懒加载并缓存）
func get_tower_data(tower_id: String) -> TowerCollectionData:
	if _tower_data_cache.has(tower_id):
		return _tower_data_cache[tower_id]
	for path in TOWER_RESOURCE_PATHS:
		var res = load(path)
		if res == null:
			continue
		var tid = res.get("tower_id")
		if tid != null:
			_tower_data_cache[str(tid)] = res
	return _tower_data_cache.get(tower_id, null)


## 获取炮台状态
## 返回值：0 = 等级不足无法解锁  1 = 未解锁（等级足够，可用碎片解锁）  2 = 已解锁
func get_tower_status(tower_id: String) -> int:
	if tower_id in unlocked_towers:
		return 2
	_ensure_reqs_loaded()
	if UserManager.level < _tower_level_reqs.get(tower_id, 1):
		return 0   # 等级不足
	return 1

## 获取指定炮台的 level_required（用于 UI 显示"Lv.X 解锁"）
func get_level_required(tower_id: String) -> int:
	_ensure_reqs_loaded()
	return _tower_level_reqs.get(tower_id, 1)

## 获取指定炮台拥有的碎片数量
func get_fragments(tower_id: String) -> int:
	return owned_fragments.get(tower_id, 0)

## 获取指定炮台的当前等级（0 = 未解锁）
func get_tower_level(tower_id: String) -> int:
	return tower_levels.get(tower_id, 0)

## 添加碎片（存档由 SaveManager 在调用方统一处理）
func add_fragments(tower_id: String, count: int) -> void:
	owned_fragments[tower_id] = owned_fragments.get(tower_id, 0) + count
	collection_changed.emit()

## 消耗碎片（返回 true = 扣除成功，碎片不足时返回 false 且不修改）
func spend_fragments(tower_id: String, count: int) -> bool:
	var current: int = owned_fragments.get(tower_id, 0)
	if current < count:
		return false
	owned_fragments[tower_id] = current - count
	collection_changed.emit()
	return true

## 消耗碎片解锁炮台（实际逻辑）。碎片可溢出，消耗固定 fragment_cost 数量。
## 返回 true = 解锁成功
func unlock_tower_with_fragments(tower_id: String, fragment_cost: int) -> bool:
	if tower_id in unlocked_towers:
		return false  # 已解锁
	var current: int = owned_fragments.get(tower_id, 0)
	if current < fragment_cost:
		return false  # 碎片不足
	owned_fragments[tower_id] = current - fragment_cost
	unlocked_towers.append(tower_id)
	collection_changed.emit()
	return true

## 获取某条升级路径当前已解锁的层数（0=未升级，5=已满级）
func get_path_level(tower_id: String, path_idx: int) -> int:
	if tower_id not in path_levels:
		return 0
	var levels: Array = path_levels[tower_id]
	if path_idx >= levels.size():
		return 0
	return levels[path_idx]

## 局外（兵工厂）免费解锁某条路径的下一层。
## 序列约束：必须从第1层开始逐层解锁，但无路径数量限制（BTD规则只在游戏内生效）。
## 返回 true = 升级成功
func unlock_path_tier(tower_id: String, path_idx: int) -> bool:
	if tower_id not in unlocked_towers:
		return false
	if path_idx < 0 or path_idx >= 4:
		push_error("CollectionManager.unlock_path_tier: 非法 path_idx=%d（应为 0-3）" % path_idx)
		return false
	if tower_id not in path_levels:
		path_levels[tower_id] = [0, 0, 0, 0]
	var levels: Array = path_levels[tower_id]
	var current: int = levels[path_idx] if path_idx < levels.size() else 0
	if current >= 5:
		return false
	levels[path_idx] = current + 1
	path_levels[tower_id] = levels
	return true


# ── 英雄局外升级 ──────────────────────────────────────────────────────────────

## 获取英雄当前等级（1 + 已解锁选项数）
func get_hero_level(hero_id: String) -> int:
	var unlocked: Array = hero_upgrades.get(hero_id, [])
	return unlocked.size() + 1

## 获取英雄已解锁的选项列表
func get_hero_unlocked_options(hero_id: String) -> Array:
	return hero_upgrades.get(hero_id, [])

## 检查某个选项是否已解锁（如 "1A", "2B"）
func is_hero_option_unlocked(hero_id: String, option_key: String) -> bool:
	return option_key in hero_upgrades.get(hero_id, [])

## 解锁英雄升级选项（消耗碎片+金币）
func unlock_hero_option(hero_id: String, option_key: String) -> bool:
	if hero_id not in unlocked_towers:
		return false
	if is_hero_option_unlocked(hero_id, option_key):
		return false
	var current_lv: int = get_hero_level(hero_id)
	if current_lv > 8:
		return false  # 已满级
	var cost_idx: int = current_lv - 1  # Lv.1→Lv.2 = index 0
	if cost_idx < 0 or cost_idx >= HERO_UPGRADE_FRAG_COSTS.size():
		return false
	var frag_cost: int = HERO_UPGRADE_FRAG_COSTS[cost_idx]
	var gold_cost: int = HERO_UPGRADE_GOLD_COSTS[cost_idx]
	# 检查资源
	if get_fragments(hero_id) < frag_cost:
		return false
	if UserManager.gold < gold_cost:
		return false
	# 扣除资源
	spend_fragments(hero_id, frag_cost)
	UserManager.spend_gold(gold_cost)
	# 记录解锁
	if hero_id not in hero_upgrades:
		hero_upgrades[hero_id] = []
	hero_upgrades[hero_id].append(option_key)
	collection_changed.emit()
	SaveManager.save()
	return true

## 获取下一级升级所需碎片和金币
func get_hero_upgrade_cost(hero_id: String) -> Dictionary:
	var current_lv: int = get_hero_level(hero_id)
	var cost_idx: int = current_lv - 1
	if cost_idx < 0 or cost_idx >= HERO_UPGRADE_FRAG_COSTS.size():
		return {"frags": 0, "gold": 0}
	return {
		"frags": HERO_UPGRADE_FRAG_COSTS[cost_idx],
		"gold": HERO_UPGRADE_GOLD_COSTS[cost_idx],
	}


# ── 存档序列化 ────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	# path_levels 值为普通 Array，JSON 可直接序列化
	return {
		"owned_fragments": owned_fragments,
		"tower_levels":    tower_levels,
		"unlocked_towers": unlocked_towers,
		"path_levels":     path_levels,
		"hero_upgrades":   hero_upgrades,
	}

func load_save_data(dict: Dictionary) -> void:
	# owned_fragments / tower_levels：key=String, value=int
	# JSON round-trip 会把 int 变 float，需显式转回 int
	var of_ = dict.get("owned_fragments", {})
	if of_ is Dictionary:
		owned_fragments = {}
		for k in of_:
			owned_fragments[str(k)] = int(of_[k])

	var tl_ = dict.get("tower_levels", {})
	if tl_ is Dictionary:
		tower_levels = {}
		for k in tl_:
			tower_levels[str(k)] = int(tl_[k])

	# unlocked_towers：JSON 解析为普通 Array，转为 Array[String]
	unlocked_towers.clear()
	for id in dict.get("unlocked_towers", []):
		unlocked_towers.append(str(id))
	# 确保基础炮台始终解锁（兼容旧存档）
	for base_id in BASE_TOWERS:
		if base_id not in unlocked_towers:
			unlocked_towers.append(base_id)

	# path_levels：key=tower_id (String), value=Array of int（逐项验证，过滤损坏数据）
	var pl_ = dict.get("path_levels", {})
	if pl_ is Dictionary:
		path_levels = {}
		for tid in pl_.keys():
			var val = pl_[tid]
			if val is Array:
				var int_arr: Array[int] = []
				for v in val:
					int_arr.append(int(v))
				path_levels[str(tid)] = int_arr
			else:
				push_warning("CollectionManager: path_levels[%s] 不是 Array，已跳过" % tid)

	# hero_upgrades：key=hero_id, value=Array of String（如 ["1A","2B"]）
	var hu_ = dict.get("hero_upgrades", {})
	if hu_ is Dictionary:
		hero_upgrades = {}
		for hid in hu_.keys():
			var val = hu_[hid]
			if val is Array:
				var str_arr: Array = []
				for v in val:
					str_arr.append(str(v))
				hero_upgrades[str(hid)] = str_arr

## 游戏内判断：某条路径在当前 BTD 规则下是否还允许继续升级
## BTD 规则：若其他任意路径已到 3 层，本路径上限为 2 层；最多同时升级 2 条路径
func can_upgrade_path_ingame(tower_id: String, path_idx: int) -> bool:
	if tower_id not in path_levels:
		return true
	var levels: Array = path_levels[tower_id]
	var current: int = levels[path_idx] if path_idx < levels.size() else 0
	if current >= 5:
		return false
	# 若其他路径已到 3 层 → 本路径上限 2
	for i in levels.size():
		if i != path_idx and levels[i] >= 3 and current >= 2:
			return false
	return true
