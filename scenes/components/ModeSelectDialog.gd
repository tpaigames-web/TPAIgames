class_name ModeSelectDialog
extends CanvasLayer

## 难度选择弹窗 — 普通/困难/挑战 三模式

signal mode_selected(day_idx: int, mode: int)  # 0=普通, 1=困难, 2=挑战
signal continue_save()
signal canceled()

const MODE_NORMAL: int = 0
const MODE_HARD: int = 1
const MODE_CHALLENGE: int = 2

const MODE_DESCRIPTIONS: Array[String] = [
	"体验纯粹的塔防，能够使用兵工厂力量",
	"提供80波敌人，新敌人、新机制，即将推出",
	"1HP挑战40波敌人，不可以使用兵工厂力量",
]

const CHEST_CLOSED: Array[String] = [
	"res://assets/sprites/ui/Chest_Wood.png",
	"res://assets/sprites/ui/Chest_Silver.png",
	"res://assets/sprites/ui/Chest_Gold.png",
]
const CHEST_OPEN: Array[String] = [
	"res://assets/sprites/ui/Chest_Wood_Open.png",
	"res://assets/sprites/ui/Chest_Silver_Open.png",
	"res://assets/sprites/ui/Chest_Gold_Open.png",
]

@onready var dim_bg: ColorRect          = $DimBg
@onready var title_label: Label         = $Panel/DayPanel/TitleLabel
@onready var close_btn: TextureButton   = $Panel/CloseBtn
@onready var info_panel: TextureRect    = $Panel/InfoPanel
@onready var info_label: Label          = $Panel/InfoPanel/InfoLabel
@onready var start_btn: TextureButton   = $Panel/StartBtn

@onready var mode_buttons: Array[TextureButton] = [
	$Panel/NormalMode,
	$Panel/HardMode,
	$Panel/ChallengeMode,
]

var _day_idx: int = 1
var _selected_mode: int = -1
var _claimed: Array[bool] = [false, false, false]


func _ready() -> void:
	dim_bg.gui_input.connect(_on_dim_input)
	close_btn.pressed.connect(_cancel)
	start_btn.pressed.connect(_start)

	for i in range(mode_buttons.size()):
		mode_buttons[i].pressed.connect(_select_mode.bind(i))

	# 困难模式锁定
	mode_buttons[MODE_HARD].disabled = true
	mode_buttons[MODE_HARD].modulate = Color(0.6, 0.6, 0.6, 1.0)


func setup(day_idx: int, n_claimed: bool, c_claimed: bool, has_save: bool, save_info: String = "") -> void:
	_day_idx = day_idx
	_claimed = [n_claimed, false, c_claimed]  # 困难模式暂时 false

	if not is_inside_tree():
		await ready

	title_label.text = "Day %02d" % day_idx

	# 更新宝箱图标和 Tick
	for i in range(mode_buttons.size()):
		var btn: TextureButton = mode_buttons[i]
		var chest_icon: TextureRect = btn.get_node("ChestIcon")
		var tick_icon: TextureRect = btn.get_node("TickIcon")

		if _claimed[i]:
			chest_icon.texture = load(CHEST_OPEN[i])
			tick_icon.visible = true
		else:
			chest_icon.texture = load(CHEST_CLOSED[i])
			tick_icon.visible = false


func _select_mode(mode: int) -> void:
	if mode == MODE_HARD:
		return  # 锁定中

	_selected_mode = mode

	# 高亮选中，其他变暗
	for i in range(mode_buttons.size()):
		if i == MODE_HARD:
			continue  # 保持困难模式灰色
		if i == mode:
			mode_buttons[i].modulate = Color(1.2, 1.15, 1.0, 1.0)
		else:
			mode_buttons[i].modulate = Color(0.75, 0.75, 0.75, 1.0)

	# 显示信息面板和开始按钮
	info_panel.visible = true
	info_label.text = MODE_DESCRIPTIONS[mode]
	start_btn.visible = true


func _start() -> void:
	if _selected_mode < 0:
		return
	mode_selected.emit(_day_idx, _selected_mode)
	queue_free()


func _cancel() -> void:
	canceled.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cancel()
