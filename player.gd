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

var flying: bool = false

const SPEED = 5.0
var running = 1
const JUMP_VELOCITY = 4.5
const GRAVITY: float = 9.8
var paused = Settings.pause_state

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Add gravity, if the player is not flying.
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			velocity.y += -GRAVITY * delta

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
		running = 1.5
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
	print("player.spawn")
	var random_location_y = 300.0
	# Randomizes the horizontal location that the player spawns in, within the first chunk.
	var random_location_x = randf_range(0.0, chunk_size)
	var random_location_z = randf_range(0.0, chunk_size)
	#print("Spawning player at %s, %s, %s." % [random_location_x, player.position.y, random_location_z])
	player.global_position = Vector3(random_location_x, random_location_y, random_location_z)
	# Once the player is initially spawned, we immediately move them so they are standing on the terrain.
	# We get the location of the terrain with this RayCast3D.
	spawn_altitude_cast.force_raycast_update()
	player.global_position.y = spawn_altitude_cast.get_collision_point().y
