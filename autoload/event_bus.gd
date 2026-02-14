extends Node


# Intended to be an Event Bus that can be called from anywhere. For example, when the chunk that the
# player spawns on is complete, we will emit a signal defined here saying that it's safe to spawn.
# This may also be where the spawn function lives, I dunno yet.

#signal spawn_chunk_is_ready
#signal button_pressed(_PauseButton)

func _on_paused_button_pressed(_PauseButton):
	print("Pause Button was pressed.")
