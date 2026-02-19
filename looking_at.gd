extends Label
@onready var player_focus: RayCast3D = $"../../../../PlayerFocus"
@onready var spawn_altitude_cast: RayCast3D = $"../../../../../../SpawnAltitudeCast"
@onready var player: CharacterBody3D = $"../../../../../.."
@onready var block_selection_indicator: MeshInstance3D = $"../../../../../../BlockSelectionIndicator"

func _ready():
	# Ignore the player's collision mesh! Or else the raycaster won't work. We don't have to ignore
	# the selection indicator because it has no collision mesh.
	player_focus.add_exception(player)

func _process(delta: float):
	# This handles a label in the HUD that tells you what you're looking at. PlayerFocus hits a chunk,
	# then get_block_target figures out the position of the block the player is looking at.
	if player_focus.get_collider() == null:
		text = "Target: Nothing"
		block_selection_indicator.visible = false
	else:
		text = "Target: %s" % [get_target(player_focus.get_collision_point())]
		block_selection_indicator.visible = true
		block_selection_indicator.global_position = get_target(player_focus.get_collision_point())
		#block_selection_indicator.rotation = Vector3i(0, 0, 0)

func get_target(collision_point):
	if player_focus.get_collider() != null && collision_point:
		var block_normal = player_focus.get_collision_normal()
		
		# Snap cursor to the block underneath the cursor. Blocks appear on the vertical axis at every 0.5 instead of every 1. This causes misses on cursor alignment.
		
		# Snap the cursor to the grid.
		var pos = (collision_point + block_normal * (1/2))
		# These If statements help prevent misses by the cursor. We might be able to tighten this up,
		# which would be nice. Essentially, if the normal is negative, we need to add 1. If it's positive 1,
		# we don't need to do anything. If it's inbetween, we need to add 0.5.
		if block_normal.x == -1.0:
			pos.x = floor(pos.x + 1)
		elif block_normal.x == 1.0:
			pos.x = floor(pos.x)
		else:
			pos.x = floor(pos.x + 0.5)
		
		pos.y = round(pos.y) - 0.5
		
		if block_normal.z == -1:
			pos.z = floor(pos.z + 1)
		elif block_normal.z == 1:
			pos.z = floor(pos.z) + 1.5
		else:
			pos.z = floor(pos.z + 0.5)
		
		return pos
	else:
		return
