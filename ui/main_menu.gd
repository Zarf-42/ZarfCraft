extends Control

@onready var new: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/New
@onready var load: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/Load
@onready var options: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/Options
@onready var exit: Button = $VBoxContainer/ButtonsCenter/VBoxContainer/Exit
@onready var button_container: VBoxContainer = $VBoxContainer/ButtonsCenter/VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Any time the screen changes size, run this function. This resizes UI elements.
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	new.pressed.connect(func(): _on_new_pressed())
	load.pressed.connect(func(): _on_load_pressed())
	options.pressed.connect(func(): _on_options_pressed())
	exit.pressed.connect(func(): get_tree().quit())

func _on_new_pressed() -> void:
	get_tree().change_scene_to_file("res://world.tscn")

func _on_load_pressed() -> void:
	var world_select = load("res://ui/load.tscn").instantiate()
	world_select.came_from = "main_menu"
	get_tree().root.add_child(world_select)
	get_tree().current_scene = world_select
	queue_free()

func _on_options_pressed() -> void:
	pass

func _on_viewport_size_changed() -> void:
	UiManager.resize_button_container(button_container)
