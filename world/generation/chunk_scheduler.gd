# world/generation/chunk_scheduler.gd
class_name ChunkScheduler
extends Node

const COMMITS_PER_FRAME: int = 16
const UNLOADS_PER_FRAME: int = 32
const NEIGHBOR_MODE: int = 8 # For checking neighbors for CCSs like trees

@onready var world_manager: WorldManager = $".."
@onready var noise_settings: NoiseSettings = $"../NoiseSettings"
@onready var chunk_gen_profiler: ChunkGenProfiler = $"../ChunkGenProfiler"

# Thread Pool for organizing chunks to be generated
var thread_pool: Array = []
var kill_threads: bool = false

# Shared priority queue — threads pull from the front
# Contains Vector3i chunk keys, sorted by distance from player
var work_queue: Array = []
var work_queue_mutex: Mutex = Mutex.new()
var work_semaphore: Semaphore = Semaphore.new()
var mesh_semaphore: Semaphore = Semaphore.new()
var MAX_CONCURRENT_MESHES: int = 16  # Leave cores free for main thread

var s2_queue: Array = []
var s2_queue_mutex: Mutex = Mutex.new()
#var s2_semaphore: Semaphore = Semaphore.new()

# Stage tracking
var chunk_stages: Dictionary = {}  # Vector3i -> int (0-3)
var chunk_stages_mutex: Mutex = Mutex.new()

# Stage 1 complete chunks waiting for Stage 2 prerequisites
# Vector3i -> Chunk (not yet in scene tree)
var s1_chunks: Dictionary = {}
var s1_mutex: Mutex = Mutex.new()

# Per-chunk write mutex for Stage 2 — prevents two threads writing
# into the same neighbor simultaneously
var chunk_write_mutexes: Dictionary = {}  # Vector3i -> Mutex
var chunk_write_mutex_mutex: Mutex = Mutex.new()  # Guards the dictionary itself

# Visual commit queue — drained on main thread
var s3_queue: Array = []

# Chunk Node queue to be added to the world
var add_child_queue: Array = []

# Unload queue — drained on main thread
var chunk_unload_queue: Array = []

# Player position for priority sorting
var current_player_chunk: Vector2i = Vector2i(0, 0)

var chunk_class = preload("res://world/generation/chunk.tscn")


func _ready() -> void:
	EventBus.chunk_changed.connect(_on_chunk_changed)
	for thread in Settings.threads:
		thread_pool.append(thread)
	# Initialize mesh semaphore slots
	for i in range(MAX_CONCURRENT_MESHES):
		mesh_semaphore.post()

func _process(_delta: float) -> void:
	# Process one add_child per frame to avoid scene tree spikes
	if not add_child_queue.is_empty():
		var entry = add_child_queue.pop_front()
		var key: Vector3i = entry["key"]
		var chunk: Chunk = entry["chunk"]
		if is_instance_valid(chunk):
			world_manager.add_child(chunk)
			world_manager.chunks_mutex.lock()
			world_manager.chunks[key] = chunk
			world_manager.chunks_mutex.unlock()
			s1_mutex.lock()
			s1_chunks.erase(key)
			s1_mutex.unlock()
			chunk_stages_mutex.lock()
			chunk_stages[key] = 3
			chunk_stages_mutex.unlock()
			s3_queue.append(chunk)
			if not Settings.player_is_spawned:
				if key.x == 0 and key.z == 0 and _chunk_has_surface(chunk):
					EventBus.spawn_chunk_is_ready.emit()

	# Drain visual commit queue
	for i in range(min(COMMITS_PER_FRAME, s3_queue.size())):
		var chunk = s3_queue.pop_front()
		if not is_instance_valid(chunk):
			continue
		chunk.commit_visuals()
		chunk_gen_profiler.record_visual_commit(Time.get_ticks_msec())

	# Unload Distant Chunks
	for i in range(min(UNLOADS_PER_FRAME, chunk_unload_queue.size())):
		var chunk_key = chunk_unload_queue.pop_front()
		_unload_chunk(chunk_key)

func start_initial_generation(center: Vector2i) -> void:
	current_player_chunk = center
	_rebuild_queue(center)
	_start_thread_pool()

func _start_thread_pool() -> void:
	for thread in thread_pool:
		if not thread.is_started():
			thread.start(_worker)

func get_chunk_queue(center: Vector2i) -> Array:
	var chunk_queue: Array = []
	# We set the radius to one chunk beyond render distance, so that we can commit chunks that have
	# Cross-Chunk Structures at the edge of the render distance.
	var r: int = Settings.chunk_render_distance + 1
	var commit_radius: int = Settings.chunk_render_distance
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			if sqrt(float(x * x + z * z)) <= float(r):
				chunk_queue.append(Vector3i(center.x + x, 0, center.y + z))
	return chunk_queue

func _get_distance_priority(key: Vector3i) -> float:
	var dx: float = key.x - current_player_chunk.x
	var dz: float = key.z - current_player_chunk.y
	return sqrt(dx * dx + dz * dz)

func _rebuild_queue(center: Vector2i) -> void:
	current_player_chunk = center

	var new_queue: Array = []
	for key in get_chunk_queue(center):
		chunk_stages_mutex.lock()
		var stage: int = chunk_stages.get(key, 0)
		chunk_stages_mutex.unlock()
		if stage == 0:
			new_queue.append(key)

	new_queue.sort_custom(func(a, b):
		return _get_distance_priority(a) < _get_distance_priority(b))

	work_queue_mutex.lock()
	var existing: Dictionary = {}
	for key in work_queue:
		existing[key] = true
	var added: int = 0
	for key in new_queue:
		if not existing.has(key):
			work_queue.append(key)
			added += 1
	work_queue.sort_custom(func(a, b):
		return _get_distance_priority(a) < _get_distance_priority(b))
	work_queue_mutex.unlock()
	
	# Post only as many signals as there are threads to wake,
	# capped at actual new work added
	for i in range(mini(added, thread_pool.size())):
		work_semaphore.post()

func _is_in_range(key: Vector3i, center: Vector2i) -> bool:
	var dx: float = key.x - center.x
	var dz: float = key.z - center.y
	return sqrt(dx * dx + dz * dz) <= float(Settings.chunk_render_distance)
	
func _signal_work_available() -> void:
	work_semaphore.post()
	
# Each thread runs this loop: Pull from the shared queue, run Stage 1, then check and run Stage 2.
func _worker() -> void:
	#print("Worker started on thread: ", OS.get_thread_caller_id())
	while true:
		# Check s2 queue first without waiting
		s2_queue_mutex.lock()
		if not s2_queue.is_empty():
			var s2_key: Vector3i = s2_queue.pop_front()
			s2_queue_mutex.unlock()
			#print("Worker picking up S2: ", s2_key)
			_run_s2(s2_key)
			#print("Worker finished S2: ", s2_key)
			continue
		s2_queue_mutex.unlock()

		# Try s1 queue next without waiting
		work_queue_mutex.lock()
		if not work_queue.is_empty():
			var key: Vector3i = work_queue.pop_front()
			work_queue_mutex.unlock()

			chunk_stages_mutex.lock()
			var stage: int = chunk_stages.get(key, 0)
			chunk_stages_mutex.unlock()
			if stage > 0:
				#print("Worker skipping duplicate: ", key)
				continue
			#print("Worker picking up S1: ", key)
			_run_s1(key)
			#print("Worker finished S1: ", key)
			_check_s2_ready(key)
			for neighbor_key in _get_prerequisite_owners(key):
				_check_s2_ready(neighbor_key)
			continue
		work_queue_mutex.unlock()

		# Nothing to do — wait for either queue to have work
		print(Time.get_ticks_msec(), ": Worker sleeping, work_queue size: ", work_queue.size(), " s2_queue size: ", s2_queue.size())
		work_semaphore.wait()
		#print(Time.get_ticks_msec(), ": Worker woke up, kill_threads: ", kill_threads)
		if kill_threads:
			break
	#print(Time.get_ticks_msec(), ": Worker exiting")

# Stage 1: All terrain, but no trees or structures.
func _run_s1(key: Vector3i) -> void:
	var new_chunk: Chunk = chunk_class.instantiate()
	new_chunk.number_of_textures_in_atlas = world_manager.atlas_tiles
	new_chunk.world_origin = Vector3i(
		key.x * Settings.chunk_size,
		0,
		key.z * Settings.chunk_size)
	new_chunk.position = new_chunk.world_origin
	new_chunk.chunks_key = key
	new_chunk.world_seed = noise_settings.altitude_generator.seed
	new_chunk.generate_data(
		Settings.chunk_size,
		Settings.chunk_height,
		noise_settings.altitude_generator,
		noise_settings.worm_steering_noise)

	# Create a write mutex for this chunk so Stage 2 can safely write into it
	var write_mutex := Mutex.new()
	chunk_write_mutex_mutex.lock()
	chunk_write_mutexes[key] = write_mutex
	chunk_write_mutex_mutex.unlock()

	s1_mutex.lock()
	s1_chunks[key] = new_chunk
	s1_mutex.unlock()

	chunk_stages_mutex.lock()
	chunk_stages[key] = 1
	chunk_stages_mutex.unlock()

func _check_s2_ready(key: Vector3i) -> void:
	chunk_stages_mutex.lock()
	var stage: int = chunk_stages.get(key, 0)
	chunk_stages_mutex.unlock()
	if stage != 1:
		return

	for prereq in _get_s2_prerequisites(key):
		chunk_stages_mutex.lock()
		var prereq_stage: int = chunk_stages.get(prereq, 0)
		chunk_stages_mutex.unlock()
		if prereq_stage < 1:
			#print(Time.get_ticks_msec(), ": S2 not ready for ", key, " — prereq ", prereq, " at stage ", prereq_stage)
			return

	chunk_stages_mutex.lock()
	var still_at_1: bool = chunk_stages.get(key, 0) == 1
	if still_at_1:
		chunk_stages[key] = 2
	chunk_stages_mutex.unlock()

	if still_at_1:
		s2_queue_mutex.lock()
		s2_queue.append(key)
		s2_queue_mutex.unlock()
		work_semaphore.post()  # Wake exactly one thread)

# Stage 2. TODO: Check what stage 2 does.
func _run_s2(key: Vector3i) -> void:
	#print("_run_s2 started for: ", key)
	s1_mutex.lock()
	var this_chunk: Chunk = s1_chunks.get(key, null)
	s1_mutex.unlock()
	if this_chunk == null:
		#print("_run_s2: chunk is null for ", key)
		return

	var keys_needed: Array = [key]
	for prereq_key in _get_s2_prerequisites(key):
		keys_needed.append(prereq_key)

	# Sort keys for consistent lock ordering — prevents deadlocks
	keys_needed.sort_custom(func(a, b):
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)

	# Step 1 — gather all voxel references under s1_mutex first
	var all_voxels: Dictionary = {}
	s1_mutex.lock()
	for needed_key in keys_needed:
		var neighbor: Chunk = s1_chunks.get(needed_key, null)
		if neighbor != null:
			all_voxels[needed_key] = neighbor.voxels
	s1_mutex.unlock()

	# Fill in any keys not found in s1_chunks from committed chunks
	for needed_key in keys_needed:
		if all_voxels.has(needed_key):
			continue
		world_manager.chunks_mutex.lock()
		var committed: Chunk = world_manager.chunks.get(needed_key, null)
		world_manager.chunks_mutex.unlock()
		if committed != null:
			all_voxels[needed_key] = committed.voxels

	# Step 2 — acquire write mutexes in sorted order (no other locks held)
	var mutexes_to_unlock: Array = []
	for needed_key in keys_needed:
		chunk_write_mutex_mutex.lock()
		var write_mutex: Mutex = chunk_write_mutexes.get(needed_key, null)
		chunk_write_mutex_mutex.unlock()
		if write_mutex != null:
			write_mutex.lock()
			mutexes_to_unlock.append(write_mutex)

	# Step 3 — run features with all voxels gathered and write mutexes held
	this_chunk.generate_features(all_voxels)

	# Release write mutexes
	for write_mutex in mutexes_to_unlock:
		write_mutex.unlock()

	# Rebuild any already-committed neighbors that received new blocks
	#for neighbor_key in all_voxels:
		#if neighbor_key == key:
			#continue
		#world_manager.chunks_mutex.lock()
		#var committed: Chunk = world_manager.chunks.get(neighbor_key, null)
		#world_manager.chunks_mutex.unlock()
		#if committed != null:
			#committed.threaded_rebuild.call_deferred()

	# Build mesh
	mesh_semaphore.wait()   # Acquire a mesh slot
	this_chunk.generate_mesh()
	mesh_semaphore.post()   # Release the slot
	chunk_gen_profiler.report_stats.call_deferred(
		this_chunk.stat_generate_mesh_us, this_chunk.stat_add_face_us,
		this_chunk.stat_add_face_count, this_chunk.stat_generate_data_us,
		this_chunk.stat_perface_mesh_us, this_chunk.stat_transparent_mesh_us)

	this_chunk.was_generated_by_thread = true
	this_chunk.name = str(Vector3i(
		this_chunk.world_origin.x / Settings.chunk_size,
		0,
		this_chunk.world_origin.z / Settings.chunk_size))

	call_deferred("_commit_s3", key, this_chunk)
	#print(Time.get_ticks_msec(), ": _run_s2 finished for: ", key)

func _commit_s3(key: Vector3i, chunk: Chunk) -> void:
	if kill_threads:
		chunk.queue_free()
		return

	var dx: float = key.x - current_player_chunk.x
	var dz: float = key.z - current_player_chunk.y
	if sqrt(dx * dx + dz * dz) > float(Settings.chunk_render_distance):
		# Outside visible range — generated for S2 prerequisites only
		chunk_stages_mutex.lock()
		chunk_stages.erase(key)
		chunk_stages_mutex.unlock()
		s1_mutex.lock()
		s1_chunks.erase(key)
		s1_mutex.unlock()
		chunk.queue_free()
		return

	# Don't add_child immediately — queue it for the main thread
	add_child_queue.append({"key": key, "chunk": chunk})

func _get_s2_prerequisites(key: Vector3i) -> Array:
	var prereqs: Array = []
	for n in get_neighbors(key):
		prereqs.append(Vector3i(n.x, 0, n.y))
	return prereqs

func _get_prerequisite_owners(key: Vector3i) -> Array:
	# Chunks whose Stage 2 gate this chunk's completion might unlock
	var owners: Array = []
	for n in get_neighbors(key):
		owners.append(Vector3i(n.x, 0, n.y))
	return owners

func get_neighbors(key: Vector3i) -> Array:
	var cardinals: Array = [
		Vector2i(key.x + 1, key.z),
		Vector2i(key.x - 1, key.z),
		Vector2i(key.x, key.z + 1),
		Vector2i(key.x, key.z - 1)
	]
	if NEIGHBOR_MODE == 4:
		return cardinals
	return cardinals + [
		Vector2i(key.x + 1, key.z + 1),
		Vector2i(key.x + 1, key.z - 1),
		Vector2i(key.x - 1, key.z + 1),
		Vector2i(key.x - 1, key.z - 1)
	]

func _chunk_has_surface(chunk: Chunk) -> bool:
	for x in range(Settings.chunk_size):
		for z in range(Settings.chunk_size):
			if chunk.heightmap[x][z] != -1:
				return true
	return false

func unload_distant_chunks(center: Vector2i) -> void:
	var to_remove: Array = []
	world_manager.chunks_mutex.lock()
	for chunk_key in world_manager.chunks:
		if not _is_in_range(chunk_key, center):
			to_remove.append(chunk_key)
	world_manager.chunks_mutex.unlock()
	chunk_unload_queue.append_array(to_remove)

func _unload_chunk(chunk_key: Vector3i) -> void:
	s1_mutex.lock()
	s1_chunks.erase(chunk_key)
	s1_mutex.unlock()

	chunk_write_mutex_mutex.lock()
	chunk_write_mutexes.erase(chunk_key)
	chunk_write_mutex_mutex.unlock()

	chunk_stages_mutex.lock()
	chunk_stages.erase(chunk_key)
	chunk_stages_mutex.unlock()

	world_manager.remove_chunk(chunk_key)

func _on_chunk_changed(new_chunk_xz: Vector2i) -> void:
	current_player_chunk = new_chunk_xz
	unload_distant_chunks(new_chunk_xz)
	_rebuild_queue(new_chunk_xz)
	_start_thread_pool()

func thread_is_kill() -> bool:
	kill_threads = true
	return kill_threads

func _exit_tree() -> void:
	kill_threads = true
	# Wake all sleeping threads so they can exit
	for i in range(thread_pool.size()):
		work_semaphore.post()
	for thread in thread_pool:
		if thread.is_started():
			thread.wait_to_finish()
