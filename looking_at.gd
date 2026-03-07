extends Label
@onready var player_focus: RayCast3D = $"../../../../PlayerFocus"
@onready var spawn_altitude_cast: RayCast3D = $"../../../../../../SpawnAltitudeCast"
@onready var player: CharacterBody3D = $"../../../../../.."
@onready var fps_counter: Label = $"../FPSCounter"
@onready var looking_at: Label = $"."
@onready var block_normal_label: Label = $"../BlockNormal"
@onready var cursor_location: Label = $"../CursorLocation"
@onready var chunk_manager: ChunkManager = $"../../../../../../../ChunkManager"
@onready var focus_thingy: MeshInstance3D = $"../../../../../../FocusThingy"
@onready var chunk: Label = $"../Chunk"

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
	else:
		looking_at.text = "Target: %s" % [player_focus.get_collision_point()]
		get_target(player_focus.get_collision_point())
		focus_thingy.visible = true
		chunk.text = player_focus.get_collider().name

func get_target(_collision_point):
	# Get the Chunk the player is looking at.
	if player_focus.get_collider() != null:# && collision_point:
		var currently_focused_chunk = player_focus.get_collider()
		var focus_location = Vector3(
			# We have to reverse z and y here because... reasons?
			int(currently_focused_chunk.global_position.x / Settings.chunk_size),
			int(currently_focused_chunk.global_position.z / Settings.chunk_height),
			int(currently_focused_chunk.global_position.y / Settings.chunk_size))
		var _chunk = chunk_manager.chunks.get(focus_location, null)
		focus_thingy.global_position = player_focus.get_collision_point()
	
	# 2/22/26: Shouldn't this be handled by the PlayerFocus object, not the label?
	# I had this && here for a reason but I don't know what. Commenting out the second part seems to work.
	if player_focus.get_collider() != null:# && collision_point:
		var block_normal = Vector3i(player_focus.get_collision_normal())
		# We set cursor as a Vector3i to eliminate some rounding errors. Not sure it helps.
		var cursor = Vector3i(player_focus.get_collision_point())
		#print(cursor)
		block_normal_label.text = "Normal: %s" % [block_normal]
		# Normals are positive or negative. Positive means the first direction below, negative means
		# the second. So 0, 0, -1 would be the south face of a cube.
		# East/-West, Top/-Bottom, North/-South
		
		# We set pos as a Vector3 version of cursor (a Vector3i) so we can keep the rounded results
		# of "cursor", but add a decimal (0.5) to the end.
		var pos: Vector3 = cursor
		
		# We use this For loop to go through all 3 axes; X, Y, and Z.
		for axes in 3:
			if block_normal[axes] == 0.0:
				focus_thingy.position[axes] = floor(focus_thingy.position[axes]) + 0.5
			else:
				focus_thingy.position[axes] -= 0.5 * block_normal[axes]

		cursor_location.text = "Cursor: %s" % [floor(focus_thingy.global_position) as Vector3i]
		
		# This gets the voxel coords that the player is looking at.
		#chunk_manager.get_chunk(cursor)
		return pos
	else:
		return
