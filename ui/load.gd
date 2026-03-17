extends Control

@onready var back: Button = $VBoxContainer/VBoxContainer/Back
@onready var world_list: VBoxContainer = $VBoxContainer/HBoxContainer/ScrollContainer/WorldList

var came_from: String = "main_menu"  # This handles what to do when the user hits Back. If in the

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	back.pressed.connect(func(): _on_back_pressed())
	populate_world_list()

func _on_back_pressed() -> void:
	if came_from == "main_menu":
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		
	elif came_from == "pause_menu":
		var pause_menu = load("res://ui/pause_menu.tscn").instantiate()
		PauseManager.add_child(pause_menu)
		queue_free()

func populate_world_list() -> void:
	var dir = DirAccess.open(SaveManager.SAVE_DIR)
	if dir == null:
		# SaveManager tries to make a folder if it doesn't exist. 
		print("Unable to find a Saves directory. Tried to create one, but was unable to.")
		return
		
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			add_world_entry(folder_name)
		folder_name = dir.get_next()
	dir.list_dir_end()

func add_world_entry(world_name: String) -> void:
	var button = Button.new()
	button.text = world_name
	button.name = world_name
	button.pressed.connect(func(): _on_world_selected(world_name))
	world_list.add_child(button)

func _on_world_selected(world_name: String) -> void:
	SaveManager.pending_load = world_name
	SaveManager.is_loading = true
	Settings.player_is_spawned = false
	if came_from == "main_menu":
		get_tree().change_scene_to_file("res://world/world.tscn")
	elif came_from == "pause_menu":
		# A little more complicated; we need to unload our existing world first.
		get_tree().paused = false
		EventBus.chunk_manager.kill_thread = true
		for thread in Settings.threads:
			if thread.is_started():
				thread.wait_to_finish()
		EventBus.chunk_manager = null
		EventBus.player = null
		queue_free()
		Settings.player_is_spawned = false
		get_tree().change_scene_to_file("res://world/world.tscn")
