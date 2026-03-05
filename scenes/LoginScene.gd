extends Control

@onready var guest_button: Button = $CenterContainer/VBox/GuestButton
@onready var google_button: Button = $CenterContainer/VBox/GoogleButton
@onready var facebook_button: Button = $CenterContainer/VBox/FacebookButton
@onready var wechat_button: Button = $CenterContainer/VBox/WechatButton
@onready var coming_soon_dialog: AcceptDialog = $ComingSoonDialog
@onready var guest_warning_dialog: ConfirmationDialog = $GuestWarningDialog

func _ready():
	guest_button.pressed.connect(_on_guest_pressed)
	google_button.pressed.connect(_on_social_pressed)
	facebook_button.pressed.connect(_on_social_pressed)
	wechat_button.pressed.connect(_on_social_pressed)
	guest_warning_dialog.confirmed.connect(_on_guest_confirmed)

func _on_guest_pressed():
	guest_warning_dialog.popup_centered()

func _on_guest_confirmed():
	UserManager.set_guest()
	SceneManager.go_home()

func _on_social_pressed():
	coming_soon_dialog.popup_centered()
