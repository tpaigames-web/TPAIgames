extends Node

## 金币或钻石发生变化时发出（UI 监听此信号自动刷新显示）
signal currency_changed

## 玩家等级提升时发出
signal level_changed(new_level: int)

var is_guest: bool = false
var player_name: String = "农场主"
var level: int = 1
var gold: int = 0
var gems: int = 0

## 经验值
var xp: int = 0
var xp_to_next_level: int = 1000   # 首级需 1000 XP；公式：1000 + (level-1)*500

## 付费通行证（RM 8.88 永久激活）
var has_paid_pass: bool = false

## 已领取奖励记录（存储等级编号，避免重复领取）
var claimed_free_rewards: Array[int] = []
var claimed_paid_rewards: Array[int] = []

## 头像索引（0=稻草人  1=老鼠  2=松鼠）
var selected_avatar: int = 0

## 战绩统计
var games_played: int = 0
var games_won: int = 0
var enemies_defeated: int = 0
var achievements_unlocked: int = 0

func set_guest() -> void:
	is_guest = true
	player_name = "游客"

func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed != "":
		player_name = trimmed

func set_avatar(index: int) -> void:
	selected_avatar = clampi(index, 0, 2)

## 消耗金币。返回 true = 成功（余额足够）
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	currency_changed.emit()
	return true

func add_gold(amount: int) -> void:
	gold += amount
	currency_changed.emit()

func add_gems(amount: int) -> void:
	gems += amount
	currency_changed.emit()

## 消耗钻石。返回 true = 成功（余额足够）
func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	currency_changed.emit()
	return true

## 获得经验值，自动处理连续多次升级
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		_level_up()
	currency_changed.emit()   # XP 条通过 currency_changed 一并刷新

## 内部升级处理（每次只升一级，循环调用）
func _level_up() -> void:
	level += 1
	xp_to_next_level = 1000 + (level - 1) * 500
	level_changed.emit(level)

## 记录已领取的免费奖励等级
func claim_free_reward(lv: int) -> void:
	if lv not in claimed_free_rewards:
		claimed_free_rewards.append(lv)

## 记录已领取的付费奖励等级
func claim_paid_reward(lv: int) -> void:
	if lv not in claimed_paid_rewards:
		claimed_paid_rewards.append(lv)

## 新手教学是否已完成（完成后 BattleTab 隐藏入口卡片）
var tutorial_completed: bool = false

## 商店购买次数追踪（product_id → count）
var shop_purchases: Dictionary = {}

func get_purchase_count(product_id: String) -> int:
	return shop_purchases.get(product_id, 0)

func record_purchase(product_id: String) -> void:
	shop_purchases[product_id] = shop_purchases.get(product_id, 0) + 1

## 碎片商店周期内购买记录（key = "{rng_seed}_{tower_id}"，防止重启后重复购买同周期商品）
var fragment_shop_purchases: Dictionary = {}

## 玩家本地唯一 ID（首次启动生成，持久化存档；日后可与 Google/Firebase ID 绑定）
var player_uuid: String = ""

## 生成标准格式 UUID（使用 Crypto 模块保证随机性）
func _generate_uuid() -> String:
	var crypto := Crypto.new()
	var h := crypto.generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

## ── 木宝箱限时免费（每 6 小时一次）─────────────────────────────────

## 冷却秒数：6 小时
const FREE_WOODEN_CHEST_COOLDOWN_SECS: int = 6 * 3600

## 上次成功领取的 Unix 时间戳（0 = 从未领取过，即立即可领）
var free_wooden_chest_last_unix: int = 0

## 返回是否可以领取（冷却已结束）
func is_free_wooden_chest_ready() -> bool:
	return get_free_wooden_chest_cooldown_remaining() <= 0

## 返回距离下次可领取剩余的秒数（0 表示立即可领）
func get_free_wooden_chest_cooldown_remaining() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(0, FREE_WOODEN_CHEST_COOLDOWN_SECS - (now - free_wooden_chest_last_unix))

## 记录本次领取时间戳
func claim_free_wooden_chest() -> void:
	free_wooden_chest_last_unix = int(Time.get_unix_time_from_system())

# ── 存档序列化 ────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"player_name":               player_name,
		"level":                     level,
		"xp":                        xp,
		"xp_to_next_level":          xp_to_next_level,
		"gold":                      gold,
		"gems":                      gems,
		"selected_avatar":           selected_avatar,
		"has_paid_pass":             has_paid_pass,
		"claimed_free_rewards":      claimed_free_rewards,
		"claimed_paid_rewards":      claimed_paid_rewards,
		"shop_purchases":            shop_purchases,
		"tutorial_completed":        tutorial_completed,
		"games_played":              games_played,
		"games_won":                 games_won,
		"enemies_defeated":          enemies_defeated,
		"achievements_unlocked":     achievements_unlocked,
		"free_wooden_chest_last_unix": free_wooden_chest_last_unix,
		"fragment_shop_purchases":    fragment_shop_purchases,
		"player_uuid":                player_uuid,
	}

func load_save_data(dict: Dictionary) -> void:
	player_name               = str(dict.get("player_name",           player_name))
	level                     = int(dict.get("level",                 level))
	xp                        = int(dict.get("xp",                    xp))
	xp_to_next_level          = int(dict.get("xp_to_next_level",      xp_to_next_level))
	gold                      = int(dict.get("gold",                   gold))
	gems                      = int(dict.get("gems",                   gems))
	selected_avatar           = int(dict.get("selected_avatar",        selected_avatar))
	has_paid_pass             = bool(dict.get("has_paid_pass",         has_paid_pass))
	tutorial_completed        = bool(dict.get("tutorial_completed",    tutorial_completed))
	games_played              = int(dict.get("games_played",           games_played))
	games_won                 = int(dict.get("games_won",              games_won))
	enemies_defeated          = int(dict.get("enemies_defeated",       enemies_defeated))
	achievements_unlocked     = int(dict.get("achievements_unlocked",  achievements_unlocked))
	free_wooden_chest_last_unix = int(dict.get("free_wooden_chest_last_unix", 0))

	# Array[int] 字段：JSON 解析后为普通 Array，需逐元素转换
	claimed_free_rewards.clear()
	for v in dict.get("claimed_free_rewards", []):
		claimed_free_rewards.append(int(v))

	claimed_paid_rewards.clear()
	for v in dict.get("claimed_paid_rewards", []):
		claimed_paid_rewards.append(int(v))

	# Dictionary：JSON 保留 key/value 类型，直接赋值
	var sp = dict.get("shop_purchases", {})
	if sp is Dictionary:
		shop_purchases = sp

	var fsp = dict.get("fragment_shop_purchases", {})
	if fsp is Dictionary:
		fragment_shop_purchases = fsp

	# UUID：兼容旧存档（字段缺失时自动生成）
	player_uuid = str(dict.get("player_uuid", ""))
	if player_uuid.is_empty():
		player_uuid = _generate_uuid()
