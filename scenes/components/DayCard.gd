class_name DayCard
extends Control

## 关卡卡片 — 显示 Day 编号、星级、锁定状态、宝箱领取状态
## 在 Godot 编辑器中可视化编辑布局，运行时由 BattleTab 调用 setup() 填充数据

signal day_pressed(day_idx: int)

@export var day_idx: int = 1

@onready var panel_bg: TextureRect      = $PanelBg
@onready var hit_button: Button         = $HitButton
@onready var day_label: Label           = $DayLabel
@onready var star_label: Label          = $StarLabel
@onready var lock_area: Control         = $LockArea
@onready var chest_row: HBoxContainer   = $ChestRow
@onready var normal_tick: TextureRect   = $ChestRow/NormalChest/NormalTick
@onready var challenge_tick: TextureRect = $ChestRow/ChallengeChest/ChallengeTick

const STAR_MAP: Array[String] = ["☆☆☆", "★☆☆", "★★☆", "★★★"]

# 缓存 setup 数据（在 _ready 之前调用时暂存）
var _pending_setup: Dictionary = {}


func _ready() -> void:
	hit_button.pressed.connect(func(): day_pressed.emit(day_idx))
	# 如果 setup() 在 _ready() 之前被调用，现在应用缓存数据
	if _pending_setup.size() > 0:
		_apply_setup(_pending_setup)
		_pending_setup = {}


## 由 BattleTab 调用，设置卡片状态
func setup(idx: int, unlocked: bool, stars: int, n_claimed: bool, c_claimed: bool) -> void:
	var data := {
		"idx": idx,
		"unlocked": unlocked,
		"stars": stars,
		"n_claimed": n_claimed,
		"c_claimed": c_claimed,
	}
	# 如果节点还没 ready，先缓存
	if not is_inside_tree() or panel_bg == null:
		_pending_setup = data
		day_idx = idx
	else:
		_apply_setup(data)


func _apply_setup(data: Dictionary) -> void:
	var idx: int = data.get("idx", 1)
	var unlocked: bool = data.get("unlocked", false)
	var stars: int = data.get("stars", 0)
	var n_claimed: bool = data.get("n_claimed", false)
	var c_claimed: bool = data.get("c_claimed", false)

	day_idx = idx
	day_label.text = "Day %02d" % idx

	if unlocked:
		panel_bg.modulate = Color.WHITE
		hit_button.disabled = false
		star_label.visible = true
		star_label.text = STAR_MAP[clampi(stars, 0, 3)]
		lock_area.visible = false
		chest_row.visible = true
		normal_tick.visible = n_claimed
		challenge_tick.visible = c_claimed
		day_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		panel_bg.modulate = Color(0.6, 0.55, 0.5, 0.85)
		hit_button.disabled = true
		star_label.visible = false
		lock_area.visible = true
		chest_row.visible = false
		day_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7, 0.7))
