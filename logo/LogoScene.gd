extends Control

const FRAME_COUNT: int = 150  # 5秒 × 30fps
const FRAME_PATH := "res://assets/sprites/logo/logo_frames/frame_%04d.png"

@onready var display: TextureRect = $Display
@onready var timer: Timer = $Timer

var _frame_idx: int = 1


func _ready() -> void:
	timer.timeout.connect(_next_frame)
	display.texture = load(FRAME_PATH % _frame_idx)
	timer.start()


func _next_frame() -> void:
	_frame_idx += 1
	if _frame_idx > FRAME_COUNT:
		timer.stop()
		_on_finished()
		return
	display.texture = load(FRAME_PATH % _frame_idx)


func _on_finished() -> void:
	if UserManager.story_watched:
		SceneManager.go_login()
	else:
		SceneManager.go_story()
