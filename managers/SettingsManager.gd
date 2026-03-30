extends Node

## 全局设置管理器（Autoload 单例）
## 保存到 user://settings.json，游戏启动时加载并应用

const SETTINGS_PATH: String = "user://settings.json"

# ── 音频 ────────────────────────────────────────────────────────────────
@export var music_volume: int = 70       ## 0-100
@export var sfx_volume: int = 80         ## 0-100

# ── 画面/性能 ───────────────────────────────────────────────────────────
## 0=低（流畅），1=中（均衡），2=高（高画质）
@export var quality: int = 1
@export var particles_enabled: bool = true  ## 粒子特效开关
@export var target_fps: int = 60           ## 目标帧率 30/60
@export var shadow_enabled: bool = true    ## 炮台阴影
@export var hit_vfx_enabled: bool = true   ## 命中特效

# ── 游戏辅助 ────────────────────────────────────────────────────────────
@export var damage_numbers: bool = true     ## 伤害数字显示
@export var range_display: int = 1          ## 0=关闭，1=仅选中，2=常驻
@export var default_speed: int = 1          ## 1=1x，2=2x

# ── 语言 ────────────────────────────────────────────────────────────────
@export var language: String = "zh"         ## 当前只支持 zh

# ── 通知 ────────────────────────────────────────────────────────────────
@export var push_notifications: bool = true


func _ready() -> void:
	load_settings()
	_apply_audio()
	apply_quality()
	TranslationServer.set_locale(language)


## 设置语言并立即应用（重载场景刷新所有 UI）
func set_language(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	save_settings()
	# 延迟一帧后重载当前场景，确保设置已保存
	get_tree().call_deferred("reload_current_scene")


## 保存设置到文件
func save_settings() -> void:
	var data: Dictionary = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"quality": quality,
		"particles_enabled": particles_enabled,
		"target_fps": target_fps,
		"shadow_enabled": shadow_enabled,
		"hit_vfx_enabled": hit_vfx_enabled,
		"damage_numbers": damage_numbers,
		"range_display": range_display,
		"default_speed": default_speed,
		"language": language,
		"push_notifications": push_notifications,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


## 从文件加载设置
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	music_volume = int(data.get("music_volume", music_volume))
	sfx_volume = int(data.get("sfx_volume", sfx_volume))
	quality = int(data.get("quality", quality))
	particles_enabled = bool(data.get("particles_enabled", particles_enabled))
	target_fps = int(data.get("target_fps", target_fps))
	shadow_enabled = bool(data.get("shadow_enabled", shadow_enabled))
	hit_vfx_enabled = bool(data.get("hit_vfx_enabled", hit_vfx_enabled))
	damage_numbers = bool(data.get("damage_numbers", damage_numbers))
	range_display = int(data.get("range_display", range_display))
	default_speed = int(data.get("default_speed", default_speed))
	language = str(data.get("language", language))
	push_notifications = bool(data.get("push_notifications", push_notifications))
	_apply_audio()


## 应用音量设置到 AudioServer
func _apply_audio() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, vol: int) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = 0   # fallback to Master
	if vol <= 0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol / 100.0))


## 设置音乐音量并立即应用
func set_music_volume(val: int) -> void:
	music_volume = clampi(val, 0, 100)
	_set_bus_volume("Music", music_volume)


## 设置音效音量并立即应用
func set_sfx_volume(val: int) -> void:
	sfx_volume = clampi(val, 0, 100)
	_set_bus_volume("SFX", sfx_volume)


## ── 画质预设 ─────────────────────────────────────────────────────────

## 设置画质等级并应用（0=低，1=中，2=高）
func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	match quality:
		0:  # 低（流畅）
			particles_enabled = false
			shadow_enabled    = false
			hit_vfx_enabled   = false
			target_fps        = 30
		1:  # 中（均衡）
			particles_enabled = true
			shadow_enabled    = true
			hit_vfx_enabled   = true
			target_fps        = 60
		2:  # 高（高画质）
			particles_enabled = true
			shadow_enabled    = true
			hit_vfx_enabled   = true
			target_fps        = 60
	apply_quality()


## 应用画质设置到引擎
func apply_quality() -> void:
	# 帧率限制
	Engine.max_fps = target_fps

	# 渲染质量（Godot 4 视口缩放）
	var vp := get_viewport()
	if vp:
		match quality:
			0:
				vp.scaling_3d_scale = 0.5
				vp.msaa_2d = Viewport.MSAA_DISABLED
			1:
				vp.scaling_3d_scale = 0.75
				vp.msaa_2d = Viewport.MSAA_DISABLED
			2:
				vp.scaling_3d_scale = 1.0
				vp.msaa_2d = Viewport.MSAA_2X
