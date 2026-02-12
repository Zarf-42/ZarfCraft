extends Node

# Global settings to be loaded at runtime.
var chunk_size: int = 32
var mouse_mode = Input.MOUSE_MODE_CAPTURED
# I changed this from Array[Thread] to try to fix errors when using threads. I think we can revert this,
# but until I've eliminated any other Typed Arrays relating to Nodes, this needs to stay as it is.
#var threads: Array[Thread]
var threads: Array = []
@export var chunk_render_distance: int = 8
@export var mouse_sensitivity: float = 0.3

func _ready():
	threads = register_threads(get_threads())

func get_threads():
	var availableThreads = OS.get_processor_count()
	
	# If we're running on a quad-core or better, set the number of threads to
	# the core count minus 2. Otherwise, just establish 2 threads.
	if availableThreads > 2:
		availableThreads -=2
	else:
		availableThreads = 2
	return(availableThreads)

func register_threads(available_threads):
	print("We have %s threads available." % available_threads)
	for i in available_threads:
		var new_thread: Thread = Thread.new()
		threads.append(new_thread)
	return(threads)
