extends Control

@onready var pause_button: Button = $CenterContainer/Control/PauseButton
@onready var quit_button: Button = $CenterContainer/Control/QuitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#var pause_button = $CenterContainer/Control/PauseButton
	#var quit_button = $CenterContainer/Control/QuitButton
	pause_button.pressed.connect(EventBus._on_paused_button_pressed.bind(name))
	quit_button.pressed.connect(EventBus._on_quit_button_pressed.bind(name))
