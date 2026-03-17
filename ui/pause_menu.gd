extends Control

@onready var pause_button: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/PauseButton
@onready var save_button: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/SaveButton
@onready var load_button: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/QuitButton
@onready var button_container: VBoxContainer = $VBoxContainer/ButtonsCenter/VBoxContainer

func _ready() -> void:
	# Any time the screen changes size, run this function. This resizes UI elements.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	
	var world = get_tree().get_root().get_node_or_null("World")
	pause_button.pressed.connect(func(): PauseManager.unpause())
	save_button.pressed.connect(func(): SaveManager.save_world("my_world"))
	load_button.pressed.connect(func(): _on_load_pressed())
	if world:
		quit_button.pressed.connect(func(): world.quit_game())

func _on_load_pressed():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world_select = load("res://ui/load.tscn").instantiate()
	world_select.came_from = "pause_menu"
	get_tree().root.add_child(world_select)
	queue_free()

func _on_viewport_size_changed() -> void:
	UiManager.resize_button_container(button_container)
