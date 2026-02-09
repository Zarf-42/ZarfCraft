extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c

# This references a node that exists in the World scene; once we procedurally generate cubes, we should
# delete that node and this variable.
@onready var default_cube: CSGBox3D = $DefaultCube

# This is the primitive that we instance to create our terrain. I believe this supersedes the default_cube
# above, so we should be able to remove that soon.
#@onready var chunk: Chunk = $Chunk

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}

func _ready():
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode

func _unhandled_input(event: InputEvent):
	# If the user presses Esc, quit immediately.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
