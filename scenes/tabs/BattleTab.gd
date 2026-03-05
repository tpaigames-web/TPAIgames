extends Control

@onready var tutorial_card:     Panel  = $TutorialCard
@onready var tutorial_play_btn: Button = $TutorialCard/PlayBtn

func _ready() -> void:
	$SeasonPassBar.pressed.connect(_on_coming_soon)
	$Day1Button.pressed.connect(_on_tutorial_play)
	$Day2Button.pressed.connect(func(): _on_stage_locked("🔒 持续更新中\n通关 Day 1 即可解锁"))
	$Day3Button.pressed.connect(func(): _on_stage_locked("🔒 持续更新中\n通关 Day 2 即可解锁"))
	$LevelUpBtn.pressed.connect(_on_level_up)

	# 新手教学：完成后隐藏入口卡片
	tutorial_card.visible = not UserManager.tutorial_completed
	tutorial_play_btn.pressed.connect(_on_tutorial_play)

func _on_coming_soon() -> void:
	var home = get_tree().get_first_node_in_group("home_scene")
	if home:
		home.show_coming_soon()

func _on_stage_locked(message: String) -> void:
	var home = get_tree().get_first_node_in_group("home_scene")
	if home:
		home.show_locked(message)

func _on_level_up() -> void:
	var panel = load("res://scenes/profile/LevelUpPanel.tscn").instantiate()
	get_tree().root.add_child(panel)

func _on_tutorial_play() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/TutorialScene.tscn")
