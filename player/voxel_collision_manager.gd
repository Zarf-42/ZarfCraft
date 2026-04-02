# voxel_collision_manager.gd
# Maintains a small pool of StaticBody3D boxes around the player for voxel collision.
# This replaces per-chunk trimesh collision, keeping physics body count to a fixed maximum.
class_name VoxelCollisionManager
extends Node3D

const POOL_SIZE: int = 36  # 3x4x3
const HALF_WIDTH: int = 1   # 1 block either side of player = 3 wide
const HEIGHT_BELOW: int = 1 # 1 block below player's feet
const HEIGHT_ABOVE: int = 2 # 2 blocks above player's feet

var pool: Array = []
var player: CharacterBody3D

func _ready() -> void:
	player = get_parent()
	
	# Pre-build the pool of StaticBody3D boxes
	for i in range(POOL_SIZE):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.visible = false
		pool.append(body)

func _physics_process(_delta: float) -> void:
	if not Settings.player_is_spawned:
		return
	if EventBus.chunk_manager == null:
		return

	# Get the block position of the player's feet
	var feet: Vector3i = Vector3i(
		int(floor(player.global_position.x)),
		int(floor(player.global_position.y)),
		int(floor(player.global_position.z)))

	# Collect all solid block positions in the 3x4x3 area
	var solid_positions: Array = []
	for dx in range(-HALF_WIDTH, HALF_WIDTH + 1):
		for dy in range(-HEIGHT_BELOW, HEIGHT_ABOVE + 1):
			for dz in range(-HALF_WIDTH, HALF_WIDTH + 1):
				var world_pos: Vector3i = feet + Vector3i(dx, dy, dz)
				if is_solid(world_pos):
					solid_positions.append(world_pos)

	# Assign solid positions to pool, disable unused boxes
	for i in range(POOL_SIZE):
		var body: StaticBody3D = pool[i]
		if i < solid_positions.size():
			var wp: Vector3i = solid_positions[i]
			body.global_position = Vector3(wp) + Vector3(0.5, 0.5, 0.5)
			body.get_child(0).disabled = false
		else:
			body.get_child(0).disabled = true

func is_solid(world_pos: Vector3i) -> bool:
	var chunk_manager = EventBus.chunk_manager
	var chunk_x: int = int(floor(float(world_pos.x) / Settings.chunk_size))
	var chunk_z: int = int(floor(float(world_pos.z) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(world_pos.y) / Settings.chunk_height))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	var chunk = chunk_manager.chunks.get(chunk_key, null)
	if chunk == null:
		return false
	var local_pos: Vector3i = Vector3i(
		world_pos.x - chunk_x * Settings.chunk_size,
		world_pos.y - chunk_layer * Settings.chunk_height,
		world_pos.z - chunk_z * Settings.chunk_size)
	return chunk.voxels.has(local_pos)
