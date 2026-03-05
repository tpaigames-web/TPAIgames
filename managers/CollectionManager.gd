extends Node

## 炮台收藏状态管理 Autoload
## 负责追踪玩家拥有的碎片数量、炮台等级和解锁状态。
## 存档读写由 SaveManager 统一协调（get_save_data / load_save_data）。

## 碎片或解锁状态发生变化时发出（UI 监听此信号来刷新显示）
signal collection_changed

## 基础炮台（玩家初始解锁，无需碎片）
const BASE_TOWERS: Array[String] = ["scarecrow", "water_pipe", "farmer"]

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
]

## 拥有的碎片数量：tower_id → count
var owned_fragments: Dictionary = {}

## 炮台当前等级：tower_id → level（0表示未解锁）
var tower_levels: Dictionary = {}

## 已解锁的炮台 ID 列表
var unlocked_towers: Array[String] = []

## 升级路径进度：tower_id → [tier0, tier1, tier2, tier3]（每条路径已解锁层数 0~5）
var path_levels: Dictionary = {}

## 延迟加载的等级要求缓存：tower_id → level_required
var _tower_level_reqs: Dictionary = {}

func _ready() -> void:
	# 基础炮台默认解锁
	for tower_id in BASE_TOWERS:
		if tower_id not in unlocked_towers:
			unlocked_towers.append(tower_id)

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
	if tower_id not in path_levels:
		path_levels[tower_id] = [0, 0, 0, 0]
	var levels: Array = path_levels[tower_id]
	var current: int = levels[path_idx] if path_idx < levels.size() else 0
	if current >= 5:
		return false
	levels[path_idx] = current + 1
	path_levels[tower_id] = levels
	return true

# ── 存档序列化 ────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	# path_levels 值为普通 Array，JSON 可直接序列化
	return {
		"owned_fragments": owned_fragments,
		"tower_levels":    tower_levels,
		"unlocked_towers": unlocked_towers,
		"path_levels":     path_levels,
	}

func load_save_data(dict: Dictionary) -> void:
	# owned_fragments / tower_levels：key=String, value=int
	var of_ = dict.get("owned_fragments", {})
	if of_ is Dictionary:
		owned_fragments = of_

	var tl_ = dict.get("tower_levels", {})
	if tl_ is Dictionary:
		tower_levels = tl_

	# unlocked_towers：JSON 解析为普通 Array，转为 Array[String]
	unlocked_towers.clear()
	for id in dict.get("unlocked_towers", []):
		unlocked_towers.append(str(id))
	# 确保基础炮台始终解锁（兼容旧存档）
	for base_id in BASE_TOWERS:
		if base_id not in unlocked_towers:
			unlocked_towers.append(base_id)

	# path_levels：key=tower_id (String), value=Array of int
	var pl_ = dict.get("path_levels", {})
	if pl_ is Dictionary:
		path_levels = pl_

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
