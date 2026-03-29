class_name SaveIndicator
extends TextureButton

## 存档指示器 — 显示在对应关卡卡片上方，点击继续游戏

signal continue_pressed()

@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	pressed.connect(func(): continue_pressed.emit())


func setup(save_day: int, save_wave: int, total_waves: int, is_challenge: bool) -> void:
	if not is_inside_tree():
		await ready
	var mode_str: String = "挑战" if is_challenge else "普通"
	info_label.text = "%s %d/%d ▶" % [mode_str, save_wave, total_waves]
