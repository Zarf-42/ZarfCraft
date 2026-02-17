extends Node
const PAUSE_MENU_SCENE = preload("res://ui/pause_menu.tscn")

var is_paused: bool = false
var pause_menu_instance: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	 
func _process(delta: float) -> void:
	# This is bad. We're assigning a value to "player" 60 times a second. We need the Player object
	# to emit a signal and THEN assign player in this manager. I think.
	var player = $"/root/World/Player"
	# Handle pause.
	if Input.is_action_just_pressed("pause"):
		#print(get_tree().paused)
		
		if get_tree().paused == false:
			pause()
		elif get_tree().paused == true:
			unpause()

func pause():
	# Pause the Scene Tree, show the mouse cursor, show the pause menu.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	self.add_child(pause_menu_instance)

func unpause():
	# Unpause the scene tree, hide the mouse cursor, check if there's a pause menu, and if there is,
	# get rid of it.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if get_tree().get_first_node_in_group("pause_menu") == null:
		return
	else:
		# We might be able to simplify the logic that detects the pause menu, but this is the first
		# stuff I was able to get to work.
		get_tree().get_first_node_in_group("pause_menu").queue_free()
