extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer

func _ready():
	print("Logo ready")
	video.finished.connect(_on_video_finished)
	video.play()

func _on_video_finished():
	print("Logo video finished")
	SceneManager.go_story()
