extends CharacterBody3D

# Radians per Pixel; needs VERY small values
@export var mouse_sensitivity: float = 0.01
@onready var head: Node3D = $Head
@onready var player_eyes: Camera3D = $Head/PlayerEyes
@onready var spawn_altitude_cast: RayCast3D = $SpawnAltitudeCast
@onready var player: CharacterBody3D = $"."

var flying: bool = false

const SPEED = 5.0
var running = 1
const JUMP_VELOCITY = 4.5

func _ready():
	await $"../".ready

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		if flying:
			velocity = Vector3.ZERO
		else:
			velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle toggling flying on and off.
	if Input.is_action_just_pressed("toggle_flying"):
		flying = !flying
	
	# Handle running.
	if Input.is_action_pressed("run"):
		running = 5
	else:
		running = 1
	

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player_eyes.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if flying:
				velocity = direction * SPEED * running
		else:
			velocity.x = direction.x * SPEED  * running
			velocity.z = direction.z * SPEED * running
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Dunno what this does, part of the tutorial
		var relative = event.relative * mouse_sensitivity
		head.rotate_y(-relative.x)
		player_eyes.rotate_x(-relative.y)
		player_eyes.rotation.x = clamp(player_eyes.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func spawn():
	var random_location_x = randf_range(0.0, 32.0)
	var random_location_z = randf_range(0.0, 32.0)
	player.global_position = Vector3(random_location_x, player.global_position.y, random_location_z)
	print("Player position was ", player.global_position)
	spawn_altitude_cast.force_raycast_update()
	print("Colliding with ", spawn_altitude_cast.get_collider())
	print("Terrain is at y ", spawn_altitude_cast.get_collision_point().y)
	player.global_position.y = spawn_altitude_cast.get_collision_point().y
	print("Player position is now ", player.global_position)
