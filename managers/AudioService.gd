extends Node

## 音效管理服务（Autoload）
## 功能：音效池化、并发上限、同类冷却、与 SettingsManager 集成
##
## 用法：
##   AudioService.play("tower_fire", stream, 0.0)
##   AudioService.play_2d("enemy_die", stream, position)

## 最大同时播放音效数
const MAX_CONCURRENT: int = 16

## 同类别冷却时间（秒）— 防止同类型音效密集播放
const CATEGORY_COOLDOWNS: Dictionary = {
	"tower_fire": 0.08,
	"bullet_hit": 0.05,
	"enemy_die":  0.10,
	"ui_click":   0.05,
}

## 默认冷却
const DEFAULT_COOLDOWN: float = 0.03

## 音效播放器池
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []

## 类别冷却计时器
var _category_timers: Dictionary = {}  # category -> float (remaining cooldown)

## 当前活跃播放数
var _active_count: int = 0


func _ready() -> void:
	# 预创建播放器池
	for i in MAX_CONCURRENT:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.finished.connect(_on_player_finished.bind(p))
		add_child(p)
		_players.append(p)

		var p2d := AudioStreamPlayer2D.new()
		p2d.bus = "SFX"
		p2d.finished.connect(_on_player_2d_finished.bind(p2d))
		add_child(p2d)
		_players_2d.append(p2d)


func _process(delta: float) -> void:
	# 更新类别冷却计时器
	var keys_to_remove: Array = []
	for cat in _category_timers:
		_category_timers[cat] -= delta
		if _category_timers[cat] <= 0.0:
			keys_to_remove.append(cat)
	for k in keys_to_remove:
		_category_timers.erase(k)


## ── 播放音效（非定位） ──────────────────────────────────────────────

func play(category: String, stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	if not _check_cooldown(category):
		return
	var player := _get_free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	_active_count += 1
	_set_cooldown(category)


## ── 播放 2D 定位音效 ────────────────────────────────────────────────

func play_2d(category: String, stream: AudioStream, pos: Vector2, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	if not _check_cooldown(category):
		return
	var player := _get_free_player_2d()
	if player == null:
		return
	player.stream = stream
	player.global_position = pos
	player.volume_db = volume_db
	player.play()
	_active_count += 1
	_set_cooldown(category)


## ── 停止所有音效 ────────────────────────────────────────────────────

func stop_all() -> void:
	for p in _players:
		if p.playing:
			p.stop()
	for p in _players_2d:
		if p.playing:
			p.stop()
	_active_count = 0


## ── 内部方法 ────────────────────────────────────────────────────────

func _check_cooldown(category: String) -> bool:
	if _active_count >= MAX_CONCURRENT:
		return false
	if _category_timers.has(category):
		return false  # 冷却中
	return true


func _set_cooldown(category: String) -> void:
	var cd: float = CATEGORY_COOLDOWNS.get(category, DEFAULT_COOLDOWN)
	if cd > 0.0:
		_category_timers[category] = cd


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return null


func _get_free_player_2d() -> AudioStreamPlayer2D:
	for p in _players_2d:
		if not p.playing:
			return p
	return null


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_active_count = maxi(_active_count - 1, 0)
	player.stream = null


func _on_player_2d_finished(player: AudioStreamPlayer2D) -> void:
	_active_count = maxi(_active_count - 1, 0)
	player.stream = null
