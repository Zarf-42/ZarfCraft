extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var pause_button = $CenterContainer/Control/PauseButton
	pause_button.pressed.connect(EventBus._on_paused_button_pressed.bind(name))

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		print("Pause menu works!")
