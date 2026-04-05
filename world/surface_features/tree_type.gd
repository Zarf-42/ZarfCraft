class_name TreeType
extends Resource

# Handles settings for different tree species. 

@export var tree_name: String = ""
@export var log_block_name: String = ""
@export var leaves_block_name: String = ""
@export var trunk_min: int = 4
@export var trunk_max: int = 6
@export var leaf_radius: int = 2
@export var leaf_y_scale: float = 1.1   # >1 = taller than wide, <1 = flatter
@export var spawn_weight: int = 1       # relative frequency vs other species. Should be handled via
	# biomes later.
