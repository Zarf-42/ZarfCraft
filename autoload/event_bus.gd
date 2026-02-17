extends Node


# Intended to be an Event Bus that can be called from anywhere. For example, when the chunk that the
# player spawns on is complete, we will emit a signal defined here saying that it's safe to spawn.
# This may also be where the spawn function lives, I dunno yet.

@onready var chunk_manager = get_parent().get_node("World").get_node("ChunkManager")

signal spawn_chunk_is_ready
signal chunk_spawned
#signal button_pressed(_PauseButton)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_paused_button_pressed(_PauseButton):
	PauseManager.unpause()

func _on_quit_button_pressed(_QuitButton):
	# Here, we need to shut down all threads and close the program gracefully. This should either
	# eventually offer a Save option, or live alongside a Save option.
	# For each thread, we call a function to stop itself within the chunk_manager file.
	for threads in Settings.threads:
		chunk_manager.kill_thread = true
		get_tree().quit()
