extends Node

const SAVE_DIR = "user://saves/"
var pending_load: String = "" # world_name to try to load. Empty means "start a new world", essentially.
var is_loading: bool = false

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func save_world(world_name: String) -> void:
	# Set the folder for the world we're saving
	var world_dir = SAVE_DIR + world_name + "/"
	if not DirAccess.dir_exists_absolute(world_dir):
		DirAccess.make_dir_absolute(world_dir)
	
	# And the chunks within it
	var terrain_dir = world_dir + "terrain/"
	if not DirAccess.dir_exists_absolute(terrain_dir):
		DirAccess.make_dir_absolute(terrain_dir)
	
	# And the world's metadata, including player location and rotation
	var pos = EventBus.player.global_position
	var head = EventBus.player.get_node("Head")
	var eyes = EventBus.player.get_node("Head/PlayerEyes")
	var world_data = {
		"world_name": world_name,
		"seed": EventBus.chunk_manager.random_generator.seed,
		"player_position": {
				"x":pos.x,
				"y":pos.y,
				"z":pos.z
		},
		"player_rotation": {
			"head_y": head.rotation.y,
			"eyes_x": eyes.rotation.x
		}
	}
	
	var file = FileAccess.open(world_dir + "world.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(world_data, "\t"))
	file.close()
	save_chunks(world_name)

# Saving terrain data
func save_chunks(world_name: String) -> void:
	var chunks = EventBus.chunk_manager.chunks
	var block_types = EventBus.chunk_manager.block_types
	var terrain_dir = SAVE_DIR + world_name + "/terrain/"
	
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]
		var chunk_data = {}
		
		# Convert voxels to a saveable format
		chunk.regen_mutex.lock()
		for voxel_pos in chunk.voxels:
			var block_type = chunk.voxels[voxel_pos]
			var index = block_types.find(block_type)
			var key = "%d,%d,%d" % [voxel_pos.x, voxel_pos.y, voxel_pos.z]
			chunk_data[key] = index
		chunk.regen_mutex.unlock()
		
		# Write chunk to file
		var filename = "%d_%d_%d.json" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
		var file = FileAccess.open(terrain_dir + filename, FileAccess.WRITE)
		file.store_string(JSON.stringify(chunk_data))
		file.close()
	#print("Saved ", EventBus.chunk_manager.chunks.size(), " chunks")

#func load_world() -> Dictionary:
