extends Label
@onready var player_focus: RayCast3D = $"../../../../PlayerFocus"
@onready var spawn_altitude_cast: RayCast3D = $"../../../../../../SpawnAltitudeCast"
@onready var player: CharacterBody3D = $"../../../../../.."
@onready var block_selection_indicator: MeshInstance3D = $"../../../../../../BlockSelectionIndicator"
@onready var fps_counter: Label = $"../FPSCounter"
@onready var looking_at: Label = $"."
@onready var block_normal_label: Label = $"../BlockNormal"

func _ready():
	# Ignore the player's collision mesh! Or else the raycaster won't work. We don't have to ignore
	# the selection indicator because it has no collision mesh.
	player_focus.add_exception(player)

func _process(delta: float):
	# This handles a label in the HUD that tells you what you're looking at. PlayerFocus hits a chunk,
	# then get_block_target figures out the position of the block the player is looking at.
	if player_focus.get_collider() == null:
		looking_at.text = "Target: Nothing"
		block_selection_indicator.visible = false
	else:
		looking_at.text = "Target: %s" % [player_focus.get_collision_point()]
		block_selection_indicator.visible = true
		block_selection_indicator.global_position = get_target(player_focus.get_collision_point())
		#block_selection_indicator.rotation = Vector3i(0, 0, 0)

func get_target(collision_point):
	# 2/22/26: Shouldn't this be handled by the PlayerFocus object, not the label?
	# I had this && here for a reason but I don't know what. Commenting out the second part seems to work.
	if player_focus.get_collider() != null:# && collision_point:
		var block_normal = player_focus.get_collision_normal()
		block_normal_label.text = "Normal: %s" % [block_normal]
		# Normals are positive or negative. Positive means the first direction below, negative means
		# the second. So 0, 0, -1 would be the south face of a cube.
		# East/-West, Top/-Bottom, North/-South
		
		# This line checks the location Player is looking at. Using the Normal of the collider, it
		# determines where to put the cube cursor.
		var pos = (collision_point + block_normal * -0.5).floor() + Vector3(0.5, 0.5, 0.5)
		
		# Now that we have the coordinates for our block, we need to go out to the chunk it's in and
		# get information about it. We also need to be able to delete it, but I'm not certain where
		# to put that code yet.
		return pos
	else:
		return
