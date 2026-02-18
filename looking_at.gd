extends Label
@onready var player_focus: RayCast3D = $"../../../../PlayerFocus"
@onready var spawn_altitude_cast: RayCast3D = $"../../../../../../SpawnAltitudeCast"
@onready var player: CharacterBody3D = $"../../../../../.."

func _ready():
	player_focus.add_exception(player)

func _process(delta: float):
	if player_focus.get_collider() == null:
		text = "Target: Nothing"
	else:
		text = "Target: %s" % [player_focus.get_collider()]
		
	# The following is AI generated. Unslop. Might not even work.
	if Input.is_action_just_pressed("left_click"):
		var target_pos = get_block_target()
		if target_pos:
			var chunk = get_chunk_at_world_position(target_pos)
			if chunk:
				chunk.remove_block(target_pos)

func get_block_target() -> Vector3:
	var camera = $Player/Camera3D
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + camera.global_transform.basis.z * 10.0
	)
	query.collision_mask = 1  # Your block layer
	
	var result = space_state.intersect_ray(query)
	if result:
		# Snap to block grid
		var pos = result.position
		pos.x = floor(pos.x + 0.5)
		pos.y = floor(pos.y + 0.5)
		pos.z = floor(pos.z + 0.5)
		return pos
	
	return null
