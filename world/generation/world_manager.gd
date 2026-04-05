class_name WorldManager extends Node

# World Manager defines the order in which chunks are generated. It splits this task among the available threads.

# Chunk Size and Height are two seperate variables in case we want to use tall chunks (Like 16x16x32).
@onready var chunk_size: int = Settings.chunk_size
@onready var chunk_height: int = Settings.chunk_height
@onready var player_focus: BlockRay = $"../Player/Head/PlayerEyes/PlayerFocus" # Highlights the block 
	# the player is looking at, assuming it's within Settings.player_reach.
@onready var player: CharacterBody3D = $"../Player"
@export var block_types: Array[BlockType] = [] # Not sure this is the best way to handle this, but
	# this is an array that contains every block type in the game. Filled in the Godot Editor.

# For overhanging blocks from neighboring chunks, like leaves
#var blocks_from_adjacent_chunks: Dictionary = {}  # Vector3i world pos -> BlockType
#var adjacent_blocks_applied: bool = false

var render_distance = Settings.chunk_render_distance
var altitude_generator = FastNoiseLite.new() # Surface height noise
var big_cave_generator = FastNoiseLite.new() # For large, open caves
var long_cave_generator = FastNoiseLite.new() # For long, thin caves
var kill_thread: bool = false

# For benchmarking chunk gen times.
var is_benchmarking: bool = true
var stat_generation_start_time: int = 0
var total_visual_time: int = 0
var visual_commit_count: int = 0
var stop_timing_chunk_generation: bool = false
var stat_mutex: Mutex = Mutex.new()
var stat_generate_mesh_total: int = 0
var stat_generate_mesh_count: int = 0
var stat_add_face_total: int = 0
var stat_add_face_count: int = 0
var stat_chunks_expected: int = 0
var stat_chunks_reported: int = 0
var stat_generation_complete: bool = false
var stat_generate_data_total: int = 0
var stat_generate_data_count: int = 0
var stat_perface_mesh_total: int = 0
var stat_transparent_mesh_total: int = 0

var world_seed: int = 0
var surface_level = Settings.sea_level
var atlas_tiles: Vector2 = Vector2.ZERO

# For Cross-Chunk structures like trees and caves
var pending_structures: Dictionary = {}  # Vector3i chunk_key -> Array of {world_pos, block}
var pending_structures_mutex: Mutex = Mutex.new()

var loading_threads: Array = Settings.threads
var generation_thread: Thread = Thread.new()

# We've sped up chunk generation so much that the act of placing all available chunks in the scene
# is slowing things down to the point where it feels like the game is frozen when we first start.
# We need to make a commit queue that will divide that work into different frames, as it all needs
# to happen on one thread. Additionally, I've split this between Visuals and Collision commits, because
# collision is much more expensive. Users need to see generated chunks first, far before they need
# to be able to collide with them.
var chunk_visual_queue: Array = []

var chunk_class = preload("res://world/generation/chunk.tscn")
var chunks: Dictionary[Vector3i, Chunk] = {}

func _process(_delta: float) -> void:
	while not chunk_visual_queue.is_empty():
		var chunk = chunk_visual_queue.pop_front()
		var start_time = Time.get_ticks_msec()
		chunk.commit_visuals()
		total_visual_time += Time.get_ticks_msec() - start_time
		visual_commit_count += 1
		stop_timing_chunk_generation = false
		#TODO: Should I replace Settings.sea_level with surface_level in the If statement below?
		
		if chunk.global_position == Vector3(0.0, surface_level, 0.0) and Settings.player_is_spawned == false:
			EventBus.spawn_chunk_is_ready.emit()

	if not pending_structures.is_empty():# and chunk_visual_queue.is_empty():
		apply_late_ccs()
					
func _ready() -> void:
	print("Surface level: ", (Settings.world_height / Settings.chunk_height))
	BlockRegistry.register(block_types)
	
	var temp_chunk: Chunk = chunk_class.instantiate()  # just to access its precomp tables
	var atlas_texture: Texture2D = temp_chunk.material.get_shader_parameter("texture_albedo")
	if atlas_texture != null:
		atlas_tiles = Vector2(atlas_texture.get_size().x / Settings.texture_size, 1.0)
	temp_chunk.free()
	if SaveManager.is_loading:
		var world_data = SaveManager.load_world()
		if not world_data.is_empty():
			altitude_generator.seed = int(world_data["seed"])
	else:
		# Uncomment this to make the world gen random. It's not currently, which can be helpful in testing.
		# Leaving this commented means the map will be the same every time you run the game.
		#world_seed = randi()
		altitude_generator.seed = world_seed
	
	# This makes it so the Signal emission at the end of generate_chunks() doesn't fire until the
	# World script is loaded. If we don't have these lines, that signal emits before the connection
	# is made in World's script.
	await $"../".ready
	
	player.add_block.connect(self._on_add_block)
	player.remove_block.connect(self._on_remove_block)

	# This tells everybody when the Chunk Manager (I.E. this file) is ready
	EventBus.world_manager = self
	
	var chunks_to_generate: Array = generate_terrain_infinite()
	
	# Count the total chunks across all threads, plus all of the chunks in the spawn chunk's column
	var num_layers: int = Settings.world_height / Settings.chunk_height
	stat_chunks_expected = num_layers  # spawn column chunks
	for thread_batch in chunks_to_generate:
		stat_chunks_expected += thread_batch.size()
	
	stat_generation_start_time = Time.get_ticks_msec()
	generation_thread.start(func(): multithreaded_terrain_generation(chunks_to_generate, loading_threads))
	
	# Tell other scenes we're ready
	EventBus.blocks_ready.emit(block_types)

func generate_terrain_infinite() -> Array:
	altitude_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude_generator.frequency = 0.003
	big_cave_generator.noise_type = FastNoiseLite.TYPE_PERLIN
	big_cave_generator.frequency = 0.05
	big_cave_generator.seed = altitude_generator.seed + 1
	long_cave_generator.noise_type = FastNoiseLite.TYPE_PERLIN
	long_cave_generator.frequency = 0.08
	long_cave_generator.seed = altitude_generator.seed + 2

	var num_threads: int = loading_threads.size()
	var chunk_coordinates: Array = []
	for i in range(num_threads):
		chunk_coordinates.append([])

	var chunk_queue = get_chunk_queue()
	for i in range(chunk_queue.size()):
		chunk_coordinates[i % num_threads].append(chunk_queue[i])

	return chunk_coordinates

# 3/28.26: Re-wrote this method to be able to do an arbitrary number of layers. Used to be limited to
# 3 very tall layers.
func get_chunk_queue() -> Array:
	var chunk_queue: Array = []
	var num_layers: int = Settings.world_height / Settings.chunk_height
	
	for distance in range(1, render_distance + 1):
		for x in range(-distance, distance + 1):
			for z in range(-distance, distance + 1):
				if maxi(absi(x), absi(z)) == distance:
					for layer in range(num_layers):
						chunk_queue.append(Vector3i(x, layer, z))
	return chunk_queue

func generate_chunks(pos) -> void:
	for chunk in pos:
		if kill_thread == true:
			break
		if chunks.has(chunk):
			print(chunk, " is a duplicate")
			continue
		var new_chunk: Chunk = chunk_class.instantiate()
		new_chunk.number_of_textures_in_atlas = atlas_tiles
		new_chunk.world_origin = Vector3i(
			chunk.x * chunk_size,
			chunk.y * chunk_height,
			chunk.z * chunk_size)
		new_chunk.position = new_chunk.world_origin
		new_chunk.chunks_key = chunk
		new_chunk.world_seed = altitude_generator.seed
		new_chunk.generate_data(chunk_size, chunk_height, altitude_generator, big_cave_generator, long_cave_generator)
		if SaveManager.is_loading:
			SaveManager.apply_chunk_diffs(new_chunk)
		new_chunk.generate_mesh()
		report_stats.call_deferred(new_chunk.stat_generate_mesh_us, new_chunk.stat_add_face_us, new_chunk.stat_add_face_count, new_chunk.stat_generate_data_us, new_chunk.stat_perface_mesh_us, new_chunk.stat_transparent_mesh_us)
		
		new_chunk.was_generated_by_thread = true
		new_chunk.name = str(new_chunk.world_origin / Vector3i(chunk_size, chunk_height, chunk_size))
		chunks[chunk] = new_chunk
		call_deferred("add_child", new_chunk)
		call_deferred("add_to_commit_queue", new_chunk)


# CCSs are Cross-Chunk Structures, like trees.
func register_ccs(world_pos: Vector3i, block: BlockType) -> void:
	var chunk_x: int = int(floor(float(world_pos.x) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(world_pos.y) / Settings.chunk_height))
	var chunk_z: int = int(floor(float(world_pos.z) / Settings.chunk_size))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	##print("register_ccs: world_pos=", world_pos, " chunk_key=", chunk_key)

	pending_structures_mutex.lock()
	if not pending_structures.has(chunk_key):
		pending_structures[chunk_key] = []
	pending_structures[chunk_key].append({"world_pos": world_pos, "block": block})
	pending_structures_mutex.unlock()

func claim_ccs(chunk_key: Vector3i) -> Array:
	pending_structures_mutex.lock()
	var result: Array = pending_structures.get(chunk_key, [])
	pending_structures.erase(chunk_key)
	pending_structures_mutex.unlock()
	#if chunk_key == Vector3i(-2, -2, 10):
		#print("claim_ccs: key=", chunk_key, " found=", result.size(), " entries")
	return result

func add_to_commit_queue(chunk: Chunk) -> void:
	chunk_visual_queue.append(chunk)
	# When loading, apply and saved diffs to this chunk immediately.
	if SaveManager.is_loading:
		SaveManager.apply_chunk_diffs(chunk)

# We might be able to replace this with Settings.sea_level
func estimate_surface_layer(grid_x: int, grid_z: int) -> int:
	var world_x: float = grid_x * chunk_size + chunk_size * 0.5
	var world_z: float = grid_z * chunk_size + chunk_size * 0.5
	var rand: float = ((
		altitude_generator.get_noise_2d(world_x, world_z) + 0.6 *
		altitude_generator.get_noise_2d(world_x * 2, world_z * 2) + 0.25 *
		altitude_generator.get_noise_2d(world_x * 4, world_z * 4)
		) / 1.75)
	var surface_y: int = Settings.sea_level + int(rand * 24)
	return int(floor(float(surface_y) / chunk_height))

func get_priority_chunks(columns: Dictionary, priority: int) -> Array:
	var num_threads: int = loading_threads.size()
	var thread_batches: Array = []
	for i in range(num_threads):
		thread_batches.append([])

	var col_index: int = 0
	for col_key in columns:
		var grid_x: int = col_key.x
		var grid_z: int = col_key.y  # Vector2i so .y is grid Z
		var surface_layer: int = estimate_surface_layer(grid_x, grid_z)
		var thread_idx: int = col_index % num_threads

		for chunk in columns[col_key]:
			var chunk_priority: int
			if chunk.y == surface_layer:
				chunk_priority = 0
			elif chunk.y == surface_layer - 1:
				chunk_priority = 1
			elif chunk.y == surface_layer + 1 or chunk.y == surface_layer + 2:
				chunk_priority = 2  # placeholder, will be refined after P0 generates
			else:
				chunk_priority = 3

			if chunk_priority == priority:
				thread_batches[thread_idx].append(chunk)

		col_index += 1
	return thread_batches

func multithreaded_terrain_generation(chunks_by_thread, _number_of_threads) -> void:
	var num_layers: int = Settings.world_height / Settings.chunk_height
	# We need to generate the player's spawn position first. This must include all 3 vertical chunks
	# that exist at this XY coordinate; underground, surface, and sky.
	var spawn_point_chunks: Array = []
	for layer in range(num_layers):
		spawn_point_chunks.append(Vector3i(0, layer, 0))
	generate_chunks(spawn_point_chunks)  # Generate spawn chunk first
	
# Build column dictionary for priority system
	var columns: Dictionary = {}
	for thread_batch in chunks_by_thread:
		for chunk in thread_batch:
			var col_key: Vector2i = Vector2i(chunk.x, chunk.z)
			if not columns.has(col_key):
				columns[col_key] = []
			columns[col_key].append(chunk)

	# P0 and P1 — surface and directly below
	for priority in [0, 1]:
		var batches: Array = get_priority_chunks(columns, priority)
		for i in range(batches.size()):
			if not batches[i].is_empty():
				var batch = batches[i]  # capture by value
				loading_threads[i].start(func(): generate_chunks(batch))
		for thread in loading_threads:
			if thread.is_started():
				thread.wait_to_finish()

	# P2 — chunks targeted by CCS blocks
	var p2_chunks: Array = []
	pending_structures_mutex.lock()
	for chunk_key in pending_structures:
		if not chunks.has(chunk_key):
			p2_chunks.append(chunk_key)
	pending_structures_mutex.unlock()

	if not p2_chunks.is_empty():
		var num_threads: int = loading_threads.size()
		var p2_batches: Array = []
		for i in range(num_threads):
			p2_batches.append([])
		for i in range(p2_chunks.size()):
			p2_batches[i % num_threads].append(p2_chunks[i])
		for i in range(p2_batches.size()):
			if not p2_batches[i].is_empty():
				var batch = p2_batches[i]
				loading_threads[i].start(func(): generate_chunks(batch))
		for thread in loading_threads:
			if thread.is_started():
				thread.wait_to_finish()

	# P3 — everything else
	var p3_batches: Array = get_priority_chunks(columns, 3)
	for i in range(p3_batches.size()):
		if not p3_batches[i].is_empty():
			var batch = p3_batches[i]
			loading_threads[i].start(func(): generate_chunks(batch))
	for thread in loading_threads:
		if thread.is_started():
			thread.wait_to_finish()

func apply_late_ccs() -> void:
	pending_structures_mutex.lock()
	var leftover: Dictionary = pending_structures.duplicate()
	pending_structures.clear()
	pending_structures_mutex.unlock()
	
	var chunks_to_rebuild: Array = []
	for chunk_key in leftover:
		var target_chunk: Chunk = chunks.get(chunk_key, null)
		if target_chunk == null:
			# Chunk doesn't exist yet — put these entries back to retry next frame
			pending_structures_mutex.lock()
			if not pending_structures.has(chunk_key):
				pending_structures[chunk_key] = []
			pending_structures[chunk_key].append_array(leftover[chunk_key])
			pending_structures_mutex.unlock()
			continue
		for entry in leftover[chunk_key]:
			var local_pos: Vector3i = entry["world_pos"] - target_chunk.world_origin
			target_chunk.voxels[local_pos] = entry["block"]
		chunks_to_rebuild.append(target_chunk)
	
	for target_chunk in chunks_to_rebuild:
		target_chunk.threaded_rebuild()

# This ensures voxels get added to the correct chunk. If chunk size is 32x32 and player adds one at
# 33, it'll add the block to the neighboring chunk.
func get_target_chunk(world_position: Vector3i) -> Dictionary:	
	# Determine which chunk this voxel actually belongs to
	var chunk_x: int = int(floor(float(world_position.x) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(world_position.y) / Settings.chunk_height))
	var chunk_z: int = int(floor(float(world_position.z) / Settings.chunk_size))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	var chunk: Chunk = chunks.get(chunk_key, null)
	if chunk == null:
		return {} # This may help if we ever have constrained-sized worlds.
	return {"chunk": chunk, "local_pos": world_position - Vector3i(chunk.global_position)}

# Checks to see if a block the player is placing would collide with the player, which could cause the
# player to fall through geometry
func would_collide_with_player(world_position: Vector3i) -> bool:
	var player_center = player.global_position + Vector3(0.0, 0.5, 0.0)
	var block_center = Vector3(world_position) + Vector3(0.5, 0.5, 0.5)
	var horizontal_dist = Vector2(
		player_center.x - block_center.x, 
		player_center.z - block_center.z).length()
	var vertical_overlap = abs(player_center.y - block_center.y) < 1.2
	return horizontal_dist < 0.75 and vertical_overlap
	
func _on_add_block(_pos: Vector3i) -> void:
	var ray_hit = player_focus.get_ray_hit()
	if ray_hit == null:
		return

	var world_position = player_focus.get_ray_hit().add_position
	
	if would_collide_with_player(world_position):
		return
	
	var target = get_target_chunk(world_position)
	if target.is_empty():
		return
	
	# Check which chunk to add the block to
	var correct_chunk = target["chunk"]
	var correct_local_pos = target["local_pos"]
	var selected_block = player.selected_block_type

	correct_chunk.regen_mutex.lock()
	correct_chunk.voxels[correct_local_pos] = selected_block
	correct_chunk.dirty_voxels[correct_local_pos] = selected_block
	correct_chunk.regen_mutex.unlock()
	correct_chunk.request_rebuild()

func _on_remove_block(_pos: Vector3i) -> void:
	var ray_hit = player_focus.get_ray_hit()
	if ray_hit == null:
		return
		
	var world_position: Vector3i = player_focus.get_ray_hit().remove_position
	var target = get_target_chunk(world_position)
	if target.is_empty():
		#print("get_target_chunk returned empty")
		return
	
	var correct_chunk = target["chunk"]
	var correct_local_pos = target["local_pos"]
	
	if correct_chunk.voxels.has(correct_local_pos):
		correct_chunk.regen_mutex.lock()
		correct_chunk.voxels.erase(correct_local_pos)
		# Dirty voxels are used to creat diffs between what's naturally generated and what the player did.
		correct_chunk.dirty_voxels[correct_local_pos] = null
		correct_chunk.regen_mutex.unlock()
		correct_chunk.threaded_rebuild()

func remove_chunk(chunk_position: Vector3i) -> void:
	if !chunks.has(chunk_position): return
	var chunk = chunks[chunk_position]
	chunks.erase(chunk_position)
	chunk.queue_free()

# Helper Function that can return the Surface Height of any chunk.
# Call EventBus.world_manager.get_surface(x, z) from anywhere.
func get_surface_y(world_x: int, world_z: int) -> int:
	var chunk_x: int = int(floor(float(world_x) / Settings.chunk_size))
	var chunk_z: int = int(floor(float(world_z) / Settings.chunk_size))
	var local_x: int = world_x - chunk_x * Settings.chunk_size
	var local_z: int = world_z - chunk_z * Settings.chunk_size

	# Search from the top layer down for the first chunk with a real surface entry
	var num_layers: int = Settings.world_height / Settings.chunk_height
	for layer in range(num_layers - 1, -1, -1):
		var chunk: Chunk = chunks.get(Vector3i(chunk_x, layer, chunk_z), null)
		if chunk == null:
			continue
		var h: int = chunk.heightmap[local_x][local_z]
		if h != -1:
			return h

	return -1  # No surface found in this column

func report_stats(generate_mesh_us: int, add_face_us: int, add_face_calls: int, generate_data_us: int, greedy_mesh_us: int, transparent_mesh_us: int) -> void:
	stat_mutex.lock()
	stat_generate_mesh_total += generate_mesh_us
	stat_generate_mesh_count += 1
	stat_add_face_total += add_face_us
	stat_add_face_count += add_face_calls
	stat_generate_data_total += generate_data_us
	stat_generate_data_count += 1
	stat_perface_mesh_total += greedy_mesh_us
	stat_transparent_mesh_total += transparent_mesh_us
	stat_chunks_reported += 1
	var all_done: bool = stat_chunks_reported >= stat_chunks_expected and not stat_generation_complete
	if all_done:
		stat_generation_complete = true
	stat_mutex.unlock()

	if all_done:
		print_generation_stats.call_deferred()

func print_generation_stats() -> void:
	print("=== Generation Complete: %d chunks ===" % stat_chunks_reported)
	print("  total time:        %d ms" % (Time.get_ticks_msec() - stat_generation_start_time))
	if stat_generate_data_count > 0:
		print("  generate_data:     avg %.2f us over %d chunks" % [
			float(stat_generate_data_total) / stat_generate_data_count,
			stat_generate_data_count])
	if stat_generate_mesh_count > 0:
		print("  generate_mesh:     avg %.2f us over %d chunks" % [
			float(stat_generate_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_generate_mesh_count > 0:
		print("  per-face_mesh:       avg %.2f us over %d chunks" % [
			float(stat_perface_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_generate_mesh_count > 0:
		print("  transparent_mesh:  avg %.2f us over %d chunks" % [
			float(stat_transparent_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_add_face_count > 0:
		print("  add_face:          called %d times total, avg %.4f us each" % [
			stat_add_face_count,
			float(stat_add_face_total) / stat_add_face_count])
	if visual_commit_count > 0:
		print("  commit_visuals:    avg %.2f ms over %d chunks" % [
			float(total_visual_time) / visual_commit_count,
			visual_commit_count])

# This acts as a flag that should allow us to terminate threads almost instantly.
func thread_is_kill() -> bool:
	kill_thread = true
	return kill_thread

func _exit_tree() -> void:
	if generation_thread.is_started():
		generation_thread.wait_to_finish()
	for thread in loading_threads:
		if thread.is_started():
			thread.wait_to_finish()
