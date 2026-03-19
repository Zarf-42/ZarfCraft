extends CharacterBody3D

# Signals for adding or removing a block
signal add_block
signal remove_block
signal scroll

var chunk_manager: ChunkManager

# Radians per Pixel; needs VERY small values
@export var mouse_sensitivity: float = Settings.mouse_sensitivity / 100
@onready var head: Node3D = $Head
@onready var eyes: Camera3D = $Head/PlayerEyes
@onready var spawn_altitude_cast: RayCast3D = $SpawnAltitudeCast
@onready var player: CharacterBody3D = $"."
@onready var chunk_size: int = Settings.chunk_size
@onready var player_focus: BlockRay = $Head/PlayerEyes/PlayerFocus
@onready var ray_cast: BlockRay = $Head/PlayerEyes/PlayerFocus
@onready var player_is_spawned: bool = false
@onready var selected_block: Node = $SelectedBlock

@export var selected_block_type_index: int = 1
var selected_block_type: BlockType

var flying: bool = false

const SPEED = 5.0
var running = 1
const JUMP_VELOCITY = 9.8
const GRAVITY: float = 9.8
var paused = Settings.pause_state

var found_chunk: Chunk = null # For finding the chunk the player is spawning in

func _ready() -> void:
	visible = false
	#player.global_position = Vector3i(0, -1000, 0) # Place the player far below the world until the chunk is ready
	EventBus.blocks_ready.connect(_on_blocks_ready)

	process_mode = Node.PROCESS_MODE_PAUSABLE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#player_focus.target_position = Settings.player_reach
	EventBus.player = self

func _on_blocks_ready(block_types: Array) -> void:
	# Initialize the player's current Block Choice to be stone
	if block_types.size() > 0:
		selected_block_type_index = 1
		selected_block_type = block_types[selected_block_type_index]

func _physics_process(delta: float) -> void:
	# Add gravity, if the player is not flying.
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			velocity.y += (-GRAVITY * delta) * 3

	# Handle jump.
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_released("jump") and !is_on_floor():
		if velocity.y > 0:
			velocity.y = velocity.y / 2
		
	# Handle toggling flying on and off.
	if Input.is_action_just_pressed("toggle_flying"):
		flying = !flying
	
	# Handle running.
	if Input.is_action_pressed("run"):
		running = 2
	else:
		running = 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction
	if flying:
		direction = (eyes.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		velocity = direction * SPEED * 2 * running
	else:
		direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		velocity.x = direction.x * SPEED  * running
		velocity.z = direction.z * SPEED * running

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Dunno what this does, part of the tutorial
		var relative = event.relative * mouse_sensitivity
		head.rotate_y(-relative.x)
		eyes.rotate_x(-relative.y)
		eyes.rotation.x = clamp(eyes.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	# Handle placing and removing blocks
	if event.is_action_pressed("add_block"):
		var hit: BlockRay.RayHit = player_focus.get_ray_hit()
		if hit:
			add_block.emit(hit.add_position)
	if event.is_action_pressed("remove_block"):
		var hit: BlockRay.RayHit = player_focus.get_ray_hit()
		if hit:
			remove_block.emit(hit.add_position)

	if event.is_action_pressed("scroll_up"):
		scroll.emit("scroll_up")
	if event.is_action_pressed("scroll_down"):
		scroll.emit("scroll_down")
	
	if event.is_action_pressed("toggle_transparent"):
		var chunk_manager = EventBus.chunk_manager
		for chunk_pos in chunk_manager.chunks:
			var chunk = chunk_manager.chunks[chunk_pos]
			chunk.debug_transparent = !chunk.debug_transparent
			chunk.commit_visuals()

func spawn() -> void:
	if Settings.player_is_spawned == true:
		return
		
	var spawn_chunk = EventBus.chunk_manager.chunks.get(Vector3i(0, 0, 0), null)
	if spawn_chunk == null:
		return
		
	# Find any horizontal location within the chunk, with the -1 helping to stay inside the chunk
	var random_location_x = randi_range(0, chunk_size - 1)
	var random_location_z = randi_range(0, chunk_size - 1)

	for y in range(Settings.chunk_height - 1, -1, -1):
		if spawn_chunk.voxels.has(Vector3i(random_location_x, y, random_location_z)):
			# Ensure there are at least 2 empty blocks above the player so we don't spawn inside the roof of a cave
			var player_legs = spawn_chunk.voxels.has(Vector3i(random_location_x, y + 1, random_location_z))
			var player_torso = spawn_chunk.voxels.has(Vector3i(random_location_x, y + 2, random_location_z))
			if not player_legs and not player_torso:
				# Check for horizontal clearance too
				var has_horizontal_clearance = true
				# Check each horizontal offset - here called "Delta", or "d".
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if dx == 0 and dz == 0:
							continue
						var neighbor = Vector3i(random_location_x + dx, y + 1, random_location_z + dz)
						if spawn_chunk.voxels.has(neighbor):
							has_horizontal_clearance = false
							print("Must push player back for horizontal clearance")
							break
					if not has_horizontal_clearance:
						break
				
				if has_horizontal_clearance:
					player.global_position = Vector3(random_location_x, y + 1, random_location_z)
					Settings.player_is_spawned = true
					visible = true
					print("Spawned player at ", player.global_position)
					return
	
	# If no valid spawn point is found, try again:
	print("Unable to find valid spawn point, retrying...")
	Settings.player_is_spawned = false
	spawn()

func load_spawn() -> void: # For loading a savegame
	found_chunk = null
	#print("load_spawn called, pending_load: ", SaveManager.pending_load)
	var world_data = SaveManager.load_world()
	#print("world_data: ", world_data)
	if world_data.is_empty():
		print("world_data empty, falling back to spawn()")
		spawn() # Fall back to the normal spawn function if the world doesn't load correctly
		return
	
	var pos = world_data["player_position"]
	var target_pos = Vector3(pos["x"], pos["y"], pos["z"])
	#player.global_position = Vector3(pos["x"], pos["y"], pos["z"])
	
	var chunk_x = int(floor(target_pos.x / Settings.chunk_size))
	var chunk_z = int(floor(target_pos.z / Settings.chunk_size))
	var chunk_key = Vector3i(chunk_x, chunk_z, 0)
	while not EventBus.chunk_manager.chunks.has(chunk_key): # Attempt to prevent player spawning
		# until the chunk they spawn in is ready
		await get_tree().process_frame

	var spawn_chunk = EventBus.chunk_manager.chunks.get(chunk_key, null)

	
	if spawn_chunk:
		# Convert world position to local chunk position
		var local_pos = Vector3i(
		int(target_pos.x) - chunk_x * Settings.chunk_size,
		int(target_pos.y),
		int(target_pos.z) - chunk_z * Settings.chunk_size
	)	
		# Nudge player upwards until feet are clear
		for i in range(10):
			var feet = Vector3i(local_pos.x, local_pos.y, local_pos.z)
			var head_pos = Vector3i(local_pos.x, local_pos.y + 1, local_pos.z)
			if not spawn_chunk.voxels.has(feet) and not spawn_chunk.voxels.has(head_pos):
				break
			target_pos.y += 1.0
			local_pos.y += 1
		found_chunk = spawn_chunk
	
	# Check if this chunk has saved diffs that will trigger a rebuild
	var chunk_filename = "%d_%d_%d.json" % [chunk_key.x, chunk_key.y, chunk_key.z]
	var chunk_filepath = SaveManager.SAVE_DIR + SaveManager.pending_load + "/terrain/" + chunk_filename
	var has_diffs = FileAccess.file_exists(chunk_filepath)
	
	if found_chunk and has_diffs:
		print("Waiting for collision after diffs...")
		await found_chunk.collision_ready

	
	player.global_position = target_pos
	print("Player reloaded at ", player.global_position)
	head.rotation.y = world_data["player_rotation"]["head_y"]
	eyes.rotation.x = world_data["player_rotation"]["eyes_x"]
	Settings.player_is_spawned = true
	visible = true
