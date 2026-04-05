extends Label
@onready var player_focus: RayCast3D = $"../../../../PlayerFocus"
@onready var spawn_altitude_cast: RayCast3D = $"../../../../../../SpawnAltitudeCast"
@onready var player: CharacterBody3D = $"../../../../../.."
@onready var fps_counter: Label = $"../FPSCounter"
@onready var looking_at: Label = $"."
@onready var block_normal_label: Label = $"../BlockNormal"
@onready var cursor_location: Label = $"../CursorLocation"
@onready var world_manager: WorldManager = $"../../../../../../../WorldManager"
@onready var focus_thingy: MeshInstance3D = $"../../../../../../FocusThingy"
@onready var chunk: Label = $"../Chunk"
@onready var type: Label = $"../Type"

func _ready():
	# Ignore the player's collision mesh! Or else the raycaster won't work. We don't have to ignore
	# the selection indicator because it has no collision mesh.
	player_focus.add_exception(player)

func _process(_delta: float):
	# This handles a label in the HUD that tells you what you're looking at. PlayerFocus hits a chunk,
	# then get_block_target figures out the position of the block the player is looking at.
	if player_focus.get_collider() == null:
		looking_at.text = "Target: Nothing"
		cursor_location.text = "Cursor: Nothing"
		focus_thingy.visible = false
		block_normal_label.text = "Normal: "
		type.text = "Type: "
		chunk.text = "Chunk: "
	else:
		looking_at.text = "Target: %s" % [player_focus.get_collision_point()]
		focus_thingy.visible = true
		get_target(player_focus.get_collision_point())

func get_target(_collision_point):
	# Get the Chunk the player is looking at.
	var block_normal = Vector3i(player_focus.get_collision_normal())
	var face_direction = ""
	if block_normal == Vector3i(0, 0, 1):
		face_direction = "Front"
	elif block_normal == Vector3i(0, 0, -1):
		face_direction = "Back"
	elif block_normal == Vector3i(-1, 0, 0):
		face_direction = "Left"
	elif block_normal == Vector3i(1, 0, 0):
		face_direction = "Right"
	elif block_normal == Vector3i(0, -1, 0):
		face_direction = "Bottom"
	elif block_normal == Vector3i(0, 1, 0):
		face_direction = "Top"
	block_normal_label.text = "Normal: %s Direction: %s" % [block_normal, face_direction]
	
	focus_thingy.global_position = player_focus.get_collision_point()
	for axes in 3:
		if block_normal[axes] == 0.0:
			focus_thingy.position[axes] = floor(focus_thingy.position[axes]) + 0.5
		else:
			focus_thingy.position[axes] -= 0.5 * block_normal[axes]

	var current_block: Vector3i = floor(focus_thingy.position)
	cursor_location.text = "Cursor: %s" % [current_block]

	# Find the chunk from world position instead of from the collider
	var chunk_x: int = int(floor(float(current_block.x) / Settings.chunk_size))
	var chunk_z: int = int(floor(float(current_block.z) / Settings.chunk_size))
	var chunk_layer: int = int(floor(float(current_block.y) / Settings.chunk_height))
	var chunk_key: Vector3i = Vector3i(chunk_x, chunk_layer, chunk_z)
	var current_chunk: Chunk = world_manager.chunks.get(chunk_key, null)

	if current_chunk != null:
		chunk.text = "Chunk: " + current_chunk.name
		var local_voxel_pos = current_block - Vector3i(current_chunk.global_position)
		if current_chunk.regen_mutex.try_lock():
			if current_chunk.voxels.has(local_voxel_pos):
				type.text = "Type: " + current_chunk.voxels[local_voxel_pos].block_name
			else:
				type.text = "Type: Air"
			current_chunk.regen_mutex.unlock()
	else:
		chunk.text = "Chunk: None"
		type.text = "Type: Unknown"
