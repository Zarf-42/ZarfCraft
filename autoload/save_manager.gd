extends Node

const SAVE_DIR = "user://saves/"
var pending_load: String = "" # world_name to try to load. Empty means "start a new world", essentially.
var is_loading: bool = false

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func save_world(world_name: String) -> void:
	var start = Time.get_ticks_msec()
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
		"seed": EventBus.chunk_manager.altitude_generator.seed,
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
	print("Save completed in ", Time.get_ticks_msec() - start, "ms")

# Saving terrain data
func save_chunks(world_name: String) -> void:
	var chunks = EventBus.chunk_manager.chunks
	var block_types = EventBus.chunk_manager.block_types
	var terrain_dir = SAVE_DIR + world_name + "/terrain/"
	var saved_count = 0
	
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]

		# Skip loading unmodified chunks
		if chunk.dirty_voxels.is_empty():
			continue
		
		saved_count += 1

		var chunk_data = {}

		# Convert voxels to a saveable format
		chunk.regen_mutex.lock()
		for voxel_pos in chunk.dirty_voxels:
			var block_type = chunk.dirty_voxels[voxel_pos]
			var key = "%d,%d,%d" % [voxel_pos.x, voxel_pos.y, voxel_pos.z]
			if block_type == null:
				chunk_data[key] = -1 # This means it's been removed
			else:
				chunk_data[key] = block_types.find(block_type)
		chunk.regen_mutex.unlock()
		
		# Write chunk to file
		var filename = "%d_%d_%d.json" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
		var file = FileAccess.open(terrain_dir + filename, FileAccess.WRITE)
		file.store_string(JSON.stringify(chunk_data))
		file.close()
	print("Saved %s chunks" % [saved_count])

func load_world() -> Dictionary:
	var world_dir = SAVE_DIR + pending_load + "/"
	var file = FileAccess.open(world_dir + "world.json", FileAccess.READ)
	if file == null:
		print("Couldn't load ", pending_load)
		return {}
	var world_data = JSON.parse_string(file.get_as_text())
	file.close()
	return world_data

func load_chunks() -> void:
	var terrain_dir = SAVE_DIR + pending_load + "/terrain/"
	var dir = DirAccess.open(terrain_dir)
	if dir == null:
		print("Couldn't load ", pending_load, ", no terrain directory found.")
		return
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	while filename != "":
		if filename.ends_with(".json"):
			load_chunk(terrain_dir + filename, filename)
		filename = dir.get_next()
	dir.list_dir_end()

func load_chunk(filepath: String, filename: String) -> void:
	# Get chunk position from filename. 0_0_0.json > Vector3i(0, 0, 0)
	var chunk_coords = filename.replace(".json", "").split("_")
	var chunk_pos = Vector3i(int(chunk_coords[0]), int(chunk_coords[1]), int(chunk_coords[2]))
	
	# Skip chunks beyond current render distance
	if abs(chunk_pos.x) > Settings.chunk_render_distance or \
		abs(chunk_pos.y) > Settings.chunk_render_distance:
			return
	
	# Now, read the chunk file
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return
	var chunk_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	# Find the chunk in the chunk manager
	var chunk = EventBus.chunk_manager.chunks.get(chunk_pos, null)
	if chunk == null:
		print("Chunk at ", chunk_pos, " not found.")
		return
	
	# Overwrite with saved data
	chunk.regen_mutex.lock()
	#chunk.voxels.clear()
	for key in chunk_data:
		var coords = key.split(",")
		var voxel_pos = Vector3i(int(coords[0]), int(coords[1]), int(coords[2]))
		var block_index = int(chunk_data[key])
		if block_index == -1:
			chunk.voxels.erase(voxel_pos) # Block removed
		else:
			chunk.voxels[voxel_pos] = EventBus.chunk_manager.block_types[block_index]
		# Restore dirty voxels, so further saves are correct
		if block_index == -1:
			chunk.dirty_voxels[voxel_pos] = null
		else:
			chunk.dirty_voxels[voxel_pos] = EventBus.chunk_manager.block_types[block_index]
	chunk.regen_mutex.unlock()
	
	# Rebuild mesh with loaded voxel data
	chunk.request_rebuild()
	pass

# This gathers the differences between naturally generated terrain and what the player has done in
# a chunk (I.E. added or removed blocks, or if liquid has flowed, etc), then loads just those differences.
func apply_chunk_diffs(chunk: Chunk, block_types: Array[BlockType]) -> void:
	var chunk_pos = chunk.chunks_key
	var filename = "%d_%d_%d.json" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	var filepath = SAVE_DIR + pending_load + "/terrain/" + filename

	if not FileAccess.file_exists(filepath):
		return  # no diffs for this chunk

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return
	var chunk_data = JSON.parse_string(file.get_as_text())
	file.close()

	chunk.regen_mutex.lock()
	for key in chunk_data:
		var coords = key.split(",")
		var voxel_pos = Vector3i(int(coords[0]), int(coords[1]), int(coords[2]))
		var block_index = int(chunk_data[key])
		if block_index == -1:
			chunk.voxels.erase(voxel_pos)
			chunk.dirty_voxels[voxel_pos] = null
		else:
			chunk.voxels[voxel_pos] = block_types[block_index]
			chunk.dirty_voxels[voxel_pos] = block_types[block_index]
	chunk.regen_mutex.unlock()
