class_name WorldManager extends Node

# World Manager defines the order in which chunks are generated. It splits this task among the available threads.

# Chunk Size and Height are two seperate variables in case we want to use tall chunks (Like 16x16x32).
@onready var chunk_size: int = Settings.chunk_size
@onready var chunk_height: int = Settings.chunk_height
@onready var chunk_gen_profiler: ChunkGenProfiler = $ChunkGenProfiler
@onready var noise_settings: NoiseSettings = $NoiseSettings
@onready var chunk_scheduler: ChunkScheduler = $ChunkScheduler

@export var block_types: Array[BlockType] = [] # Not sure this is the best way to handle this, but
	# this is an array that contains every block type in the game. Filled in the Godot Editor.

var kill_thread: bool = false
var surface_level = Settings.sea_level
var atlas_tiles: Vector2 = Vector2.ZERO
var chunks_mutex: Mutex = Mutex.new()
var loading_threads: Array = Settings.threads
var generation_thread: Thread = Thread.new()
var chunk_unload_queue: Array = []

# We've sped up chunk generation so much that the act of placing all available chunks in the scene
# is slowing things down to the point where it feels like the game is frozen when we first start.
# We need to make a commit queue that will divide that work into different frames, as it all needs
# to happen on one thread. Additionally, I've split this between Visuals and Collision commits, because
# collision is much more expensive. Users need to see generated chunks first, far before they need
# to be able to collide with them.
var chunk_visual_queue: Array = []

var chunk_class = preload("res://world/generation/chunk.tscn")
var pickup_class = preload("res://items/item_pickup.tscn")
var chunks: Dictionary[Vector3i, Chunk] = {}
var commits_per_frame = 4

func _ready() -> void:
	print("Surface level: ", (Settings.world_height / Settings.chunk_height))
	BlockRegistry.register(block_types)
	
	var temp_chunk: Chunk = chunk_class.instantiate()  # just to access its precomp tables
	var atlas_texture: Texture2D = temp_chunk.material.get_shader_parameter("texture_albedo")
	if atlas_texture != null:
		atlas_tiles = Vector2(atlas_texture.get_size().x / Settings.texture_size, 1.0)
	temp_chunk.free()
	noise_settings.initialize()
	
	# This makes it so the Signal emission at the end of generate_chunks() doesn't fire until the
	# World script is loaded. If we don't have these lines, that signal emits before the connection
	# is made in World's script.
	await $"../".ready

	# This tells everybody when the Chunk Manager (I.E. this file) is ready
	EventBus.world_manager = self
	#EventBus.chunk_changed.connect(on_chunk_changed)
	
	chunk_scheduler.start_initial_generation(Vector2i(0, 0))
	
	# Tell other scenes we're ready
	EventBus.blocks_ready.emit(block_types)

# This ensures voxels get added to the correct chunk. If chunk size is 32x32 and player adds one at
# 33, it'll add the block to the neighboring chunk.
func get_target_chunk(world_position: Vector3i) -> Dictionary:	
	var chunk_key: Vector3i = world_pos_to_chunk_key(world_position)
	chunks_mutex.lock()
	var chunk: Chunk = chunks.get(chunk_key, null)
	chunks_mutex.unlock()
	if chunk == null:
		return {} # This may help if we ever have constrained-sized worlds.
	return {"chunk": chunk, "local_pos": world_position - Vector3i(chunk.global_position)}

# Used to get the chunk the player is in; converts the player's exact position to a chunk position
func world_pos_to_chunk_key(world_position: Vector3i) -> Vector3i:
	return Vector3i(
		int(floor(float(world_position.x) / chunk_size)),
		#int(floor(float(world_position.y) / chunk_height)), # This was the Y checker we used when
		# we had multiple vertical chunks. With tall chunks, we don't need this.
		0,
		int(floor(float(world_position.z) / chunk_size))
	)

# Completely remove a chunk if it's empty
func remove_chunk(chunk_position: Vector3i) -> void:
	chunks_mutex.lock()
	if not chunks.has(chunk_position):
		chunks_mutex.unlock()
		return
	var chunk = chunks[chunk_position]
	chunks.erase(chunk_position)
	chunks_mutex.unlock()
	chunk_scheduler.s3_queue.erase(chunk)
	chunk.queue_free()

# Helper Function that can return the Surface Height of any chunk.
# Call EventBus.world_manager.get_surface(x, z) from anywhere.
func get_surface_y(world_x: int, world_z: int) -> int:
	var chunk_key: Vector3i = world_pos_to_chunk_key(Vector3i(world_x, 0, world_z))
	var local_x: int = world_x - chunk_key.x * chunk_size
	var local_z: int = world_z - chunk_key.z * chunk_size
	chunks_mutex.lock()
	var chunk: Chunk = chunks.get(chunk_key, null)
	chunks_mutex.unlock()
	if chunk == null:
		return -1
	return chunk.heightmap[local_x][local_z]
