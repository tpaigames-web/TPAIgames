extends Node

## 存档管理器 Autoload
## 负责将 UserManager 和 CollectionManager 的数据序列化写入本地 JSON 文件，
## 并在游戏启动时读取恢复。
##
## 存档文件路径：user://save.json
## 关键操作（开宝箱、解锁炮台、购买、领取奖励、改名换头像）后请调用 SaveManager.save()。

const SAVE_PATH: String = "user://save.json"

func _ready() -> void:
	# Autoload 顺序：SaveManager 排在 UserManager / CollectionManager 之后
	# 此时两者的 _ready() 已完成（基础炮台已写入 unlocked_towers），可安全读档覆盖。
	load_game()

# ── 存档 ────────────────────────────────────────────────────────────────────

func save() -> void:
	var data: Dictionary = {
		"user":       UserManager.get_save_data(),
		"collection": CollectionManager.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档 " + SAVE_PATH
				   + "  error=" + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# ── 读档 ────────────────────────────────────────────────────────────────────

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_new_player_defaults()
		save()   # 立即生成存档文件
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: 无法读取存档 " + SAVE_PATH
				   + "  error=" + str(FileAccess.get_open_error()))
		_apply_new_player_defaults()
		return

	var text: String = file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		push_error("SaveManager: 存档格式损坏，使用默认值")
		_apply_new_player_defaults()
		return

	if result.has("user"):
		UserManager.load_save_data(result["user"])
	if result.has("collection"):
		CollectionManager.load_save_data(result["collection"])

# ── 新玩家默认值 ──────────────────────────────────────────────────────────────

## 首次启动时给予启动资源，让新玩家可以立即体验购买/开箱流程。
func _apply_new_player_defaults() -> void:
	UserManager.gold = 500
	UserManager.gems = 50
	# 新玩家：生成本地唯一 UUID（旧玩家在 load_save_data 内兼容处理）
	if UserManager.player_uuid.is_empty():
		UserManager.player_uuid = UserManager._generate_uuid()
	# BASE_TOWERS 由 CollectionManager._ready() 已默认解锁，此处无需重复处理。
