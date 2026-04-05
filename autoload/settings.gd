extends Node

# Global settings to be loaded at runtime. Ideally, most of these shouldn't change without the user
# changing something in the Settings menu.


const chunk_size: int = 16
const chunk_height: int = 16
const world_height: int = 288 # Defines the world's height in Blocks, not chunks
const sea_level: int = 160 # This is Y-altitude, not chunks
const chunk_collision_radius: int = 1  # Chunks around the player that get collision meshes (XZ only, all vertical layers)

var mouse_mode = Input.MOUSE_MODE_CAPTURED # Prevents the mouse from exiting the window. Needs to be
	# user-configurable

var threads: Array = []

@export var chunk_render_distance: int = 4 # Currently, this is how far out we generate chunks, not
	# the render distance.
@export var mouse_sensitivity: float = 0.27 # This is used as a multiplier somewhere, I think.
@export var single_threaded: bool = false # Set this to true if you want to use only one thread.
@export var player_reach: Vector3 = Vector3(4, 4, 4) # How far the player can reach ingame. 
@onready var player_is_spawned = false # This gets set to true during gameplay. Maybe move this to EventBus?
@export var texture_size: int = 16 # The size of textures used in Atlases. Defaults to a square.
@export var default_block: String = "Stone" # This is so we can configure different default block types.

var pause_state: bool = false # When set to true, pauses the game. Another thing that should be moved to EventBus?

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Prevents menus from getting paused. Paused buttons don't work.
	threads = register_threads(get_threads())

# This gets the number of cores the OS can see. This does not always translate to the number of threads
# we can effectively use. When I was experimenting with 32x32x96 chunks, 6 threads seemed optimal.
# We need a way to dynamically assign how many threads to use based on how quickly chunks get generated
# and how much it affects FPS.
func get_threads() -> int:
	var availableThreads = OS.get_processor_count()
	if single_threaded == false:
	
		# Choosing the number of threads based on how many cores. Seems to top out at 6, as far as performance goes.
		if availableThreads == 2:
			availableThreads = 2
		elif availableThreads == 6:
			availableThreads = 3
		elif availableThreads > 6:
			availableThreads = 6
			
	return(availableThreads)

# It takes a bit of time to register threads, so we should grab them and keep them.
func register_threads(available_threads) -> Array:
	for i in available_threads:
		var new_thread: Thread = Thread.new()
		threads.append(new_thread)
	return(threads)
