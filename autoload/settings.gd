extends Node

# Global settings to be loaded at runtime.
const chunk_size: int = 32
const chunk_height: int = 64
var mouse_mode = Input.MOUSE_MODE_CAPTURED
# I changed this from Array[Thread] to try to fix errors when using threads. I think we can revert this,
# but until I've eliminated any other Typed Arrays relating to Nodes, this needs to stay as it is.
#var threads: Array[Thread]
var threads: Array = []
@export var chunk_render_distance: int = 8
@export var mouse_sensitivity: float = 0.27
@export var single_threaded: bool = true
var pause_state: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	threads = register_threads(get_threads())
	# Testing on 2 threads
	#threads = register_threads(2)
	#print("Now we have %s threads." %[threads.size()])

func get_threads():
	var availableThreads = OS.get_processor_count()
	if single_threaded == false:
	
		# If we're running on a quad-core or better, set the number of threads to
		# the core count minus 2. Otherwise, just establish 2 threads.
		if availableThreads > 2:
			#availableThreads -=2 # We appear to have better performance when using fewer threads.
			# 2/21/2024: Sweet spot seems to be 6 threads on my CPU. Total time spent generating
			# chunks is lowest on that setting. Using 8, the chunks take longer to generate and the
			# total worldgen time is higher. Using fewer, the chunks generate faster, but not as
			# many at a time, so worldgen still is higher. 6: 2.6-3 seconds. 4: 4 seconds.
			# 8: 4 seconds.
			availableThreads = 6
		else:
			availableThreads = 2
	else:
		availableThreads = 1
	return(availableThreads)

func register_threads(available_threads):
	#print("We have %s threads available." % available_threads)
	for i in available_threads:
		var new_thread: Thread = Thread.new()
		threads.append(new_thread)
	return(threads)
