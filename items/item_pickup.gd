class_name ItemPickup
extends RigidBody3D

# Defines behaviors for items that the player can pick up.
# They bob up and down in the world, and exist as miniature, 3D objects.

@onready var collection_area: Area3D = $CollectionArea
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var item_stack: ItemStack = null
var bob_time: float = 0.0
const BOB_SPEED: float = 2.0
const BOB_HEIGHT: float = 0.15
const ROTATE_SPEED: float = 0.0
const COLLECTION_DELAY: float = 0.8  # Seconds before item can be picked up

var can_collect: bool = false

# Mini collision pool — just the block below and the two above
const MINI_POOL_SIZE: int = 3  # below, at, and above item position
var mini_pool: Array = []

# Terrain uses a special shader because I'm a bad developer. This makes it so our item drops can use
# the same shader. See _apply_texture() below.
#static var material_cache: Dictionary = {}  # BlockType -> ShaderMaterial

func _ready() -> void:
	collection_area.body_entered.connect(_on_body_entered)
	_build_mini_pool()
	# Small delay before item can be collected, prevents instant pickup
	# when breaking a block you're standing on
	await get_tree().create_timer(COLLECTION_DELAY).timeout
	can_collect = true
	# Check if player is already overlapping after delay
	for body in collection_area.get_overlapping_bodies():
		if body is CharacterBody3D:
			_on_body_entered(body)
			break

func _build_mini_pool() -> void:
	for i in range(MINI_POOL_SIZE):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		shape.shape = box
		body.collision_layer = 1
		body.collision_mask = 0  # Pool boxes don't need to detect anything
		body.add_child(shape)
		get_parent().add_child(body)
		body.get_child(0).disabled = true
		mini_pool.append(body)

func _physics_process(delta: float) -> void:
	if mini_pool.is_empty():
		return
	bob_time += delta
	var bob_offset: float = sin(bob_time * BOB_SPEED) * BOB_HEIGHT
	mesh_instance.position.y = bob_offset
	mesh_instance.rotate_y(ROTATE_SPEED * delta)
	_update_mini_pool()

func _update_mini_pool() -> void:
	if mini_pool.is_empty():
		return
	if EventBus.world_manager == null:
		return

	# Check the block below, at, and above the item
	var feet: Vector3i = Vector3i(
		int(floor(global_position.x)),
		int(floor(global_position.y)) - 1,
		int(floor(global_position.z)))

	var solid_positions: Array = []
	var any_disabled: bool = false
	for dy in range(MINI_POOL_SIZE):
		var world_pos: Vector3i = feet + Vector3i(0, dy, 0)
		if _is_solid(world_pos):
			solid_positions.append(world_pos)

	for i in range(MINI_POOL_SIZE):
		var body: StaticBody3D = mini_pool[i]
		if i < solid_positions.size():
			var wp: Vector3i = solid_positions[i]
			body.global_position = Vector3(wp) + Vector3(0.5, 0.5, 0.5)
			body.get_child(0).disabled = false
		else:
			if not body.get_child(0).disabled:
				any_disabled = true
			body.get_child(0).disabled = true

	if any_disabled:
		sleeping = false
		apply_central_impulse(Vector3.ZERO)  # Nudge to wake physics

func _apply_texture() -> void:
	if item_stack == null or item_stack.item_type == null:
		return
	var block: BlockType = item_stack.item_type.get_placeable_block()
	if block == null:
		return

	var wm = EventBus.world_manager
	var num_tiles: Vector2 = wm.atlas_tiles
	mesh_instance.mesh = Cube.build_block_mesh(block, 0.25, num_tiles)
	mesh_instance.material_override = BlockRegistry.get_block_material(block)

func _is_solid(world_pos: Vector3i) -> bool:
	var wm = EventBus.world_manager
	var chunk_x: int = int(floor(float(world_pos.x) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(world_pos.y) / Settings.chunk_height))
	var chunk_z: int = int(floor(float(world_pos.z) / Settings.chunk_size))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	var chunk = wm.chunks.get(chunk_key, null)
	if chunk == null:
		return false
	var local_pos: Vector3i = Vector3i(
		world_pos.x - chunk_x * Settings.chunk_size,
		world_pos.y - chunk_layer * Settings.chunk_height,
		world_pos.z - chunk_z * Settings.chunk_size)
	return chunk.voxels.has(local_pos)

func setup(stack: ItemStack, spawn_position: Vector3) -> void:
	item_stack = stack
	global_position = spawn_position
	_apply_texture()
	# Give it a small random impulse so items scatter a little
	var impulse: Vector3 = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(2.0, 4.0),
		randf_range(-2.0, 2.0))
	apply_central_impulse(impulse)

func _on_body_entered(body: Node) -> void:
	if not can_collect:
		return
	if body is not CharacterBody3D:
		return
	var player = body as CharacterBody3D
	if not player.has_method("add_to_inventory"):
		return
	var leftover: int = player.add_to_inventory(item_stack)
	if leftover <= 0:
		_cleanup()
		queue_free()
	else:
		item_stack.count = leftover

func _cleanup() -> void:
	for body in mini_pool:
		body.queue_free()
	mini_pool.clear()
