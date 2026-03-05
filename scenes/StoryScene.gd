extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $SkipButton

func _ready():
	skip_button.pressed.connect(_skip)

	var story_path = "res://assets/sprites/video/story.ogv"
	if ResourceLoader.exists(story_path):
		video.stream = load(story_path)
		video.finished.connect(_on_video_finished)
		video.play()
	else:
		push_warning("StoryScene: story.ogv not found, skipping to login.")
		SceneManager.call_deferred("go_login")

func _on_video_finished():
	SceneManager.go_login()

func _skip():
	video.stop()
	SceneManager.go_login()
