extends Node

# Global settings to be loaded at runtime.
const chunk_size: int = 32
const chunk_height: int = 96
var mouse_mode = Input.MOUSE_MODE_CAPTURED
# I changed this from Array[Thread] to try to fix errors when using threads. I think we can revert this,
# but until I've eliminated any other Typed Arrays relating to Nodes, this needs to stay as it is.
#var threads: Array[Thread]
var threads: Array = []
@export var chunk_render_distance: int = 2
@export var mouse_sensitivity: float = 0.27
@export var single_threaded: bool = false
@export var player_reach: Vector3 = Vector3(4, 4, 4)
@onready var player_is_spawned = false
var pause_state: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	threads = register_threads(get_threads())

func get_threads():
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

func register_threads(available_threads):
	for i in available_threads:
		var new_thread: Thread = Thread.new()
		threads.append(new_thread)
	return(threads)
