extends Node

const PAUSE_MENU_SCENE = preload("res://ui/pause_menu.tscn")

var is_paused: bool = false
var pause_menu_instance: Control = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		is_paused = !is_paused
		get_tree().paused = is_paused

		if is_paused and pause_menu_instance == null:
			pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
			get_tree().root.add_child(pause_menu_instance)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif not is_paused and pause_menu_instance != null:
			pause_menu_instance.queue_free()
			pause_menu_instance = null
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
