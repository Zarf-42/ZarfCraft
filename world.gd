extends Node3D

# Following this tutorial: https://www.youtube.com/watch?v=_uGtO7sk-_c
@onready var player: CharacterBody3D = $Player

# I think this initializes the array that will later contain the coordinate of every cube in our terrain.
var terrain_data: Dictionary[Vector3, Color] = {}

func _ready():
	# Get Mouse Mode from the Settings Singleton
	Input.mouse_mode = Settings.mouse_mode
	EventBus.spawn_chunk_is_ready.connect(self._spawn)

func _spawn():
	player.spawn()
