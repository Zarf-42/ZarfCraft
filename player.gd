extends CharacterBody3D

# Signals for adding or removing a block
signal add_block
signal remove_block

# Radians per Pixel; needs VERY small values
@export var mouse_sensitivity: float = Settings.mouse_sensitivity / 100
@onready var head: Node3D = $Head
@onready var player_eyes: Camera3D = $Head/PlayerEyes
@onready var spawn_altitude_cast: RayCast3D = $SpawnAltitudeCast
@onready var player: CharacterBody3D = $"."
@onready var chunk_size: int = Settings.chunk_size
@onready var player_focus: BlockRay = $Head/PlayerEyes/PlayerFocus
@onready var chunk_manager: ChunkManager = $"../ChunkManager"

var flying: bool = false

const SPEED = 5.0
var running = 1
const JUMP_VELOCITY = 9.8
const GRAVITY: float = 9.8
var paused = Settings.pause_state

func _ready():
	player.global_position = Vector3i(0, 100, 0)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#player_focus.target_position = Settings.player_reach

func _physics_process(delta: float) -> void:
	# Add gravity, if the player is not flying.
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			velocity.y += (-GRAVITY * delta) * 3

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
		direction = (player_eyes.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
		player_eyes.rotate_x(-relative.y)
		player_eyes.rotation.x = clamp(player_eyes.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	# Handle placing and removing blocks
	if event.is_action_pressed("add_block"):
		var hit: BlockRay.RayHit = player_focus.get_ray_hit()
		if hit:
			add_block.emit(hit.add_position)
	if event.is_action_pressed("remove_block"):
		var hit: BlockRay.RayHit = player_focus.get_ray_hit()
		if hit:
			remove_block.emit(hit.add_position)

func spawn():
	# This is written to spawn the player in initially. It can't do movable spawn points yet.
	# This gets all of the block locations in the spawn_chunk.
	var spawn_chunk = chunk_manager.chunks.get(Vector3i(0, 0, 0), null)
	if spawn_chunk:
		var random_location_x = randi_range(0, chunk_size)
		var random_location_z = randi_range(0, chunk_size)
		# From 0 to whatever chunk_height is...
		for y in Settings.chunk_height:
			# If there's a block there, mark it down
			var altitude = y + 1.5
			# Adjust the spawn altitude for every layer that a block exists.
			if spawn_chunk.voxels.has(Vector3i(random_location_x, y, random_location_z)):
				altitude = y + 1.5
			else:
				# As soon as we run out of blocks, break out of this If statement
				return
			# We have the max altitude, so spawn the player there. This will spawn players under 
			# overhangs, including ones that are too short. Need to write something that checks if
			# there's a gap large enough for the player.
			player.global_position = Vector3(random_location_x, altitude, random_location_z)
