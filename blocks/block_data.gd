class_name BlockData
extends Resource

# This is the Block Data resource prototype. Data that all block types need to have access to is
# defined here.
@export var block_name: String = ""
@export var texture: = Texture2D
@export var breakable: bool = true # Blocks that players can't break in normal circumstances (like
# bedrock in Minecraft) should be set to False.
@export var hardness: int = 10 # This will determine how long it takes to break a block.
# We need some way to determine if breaking this block by hand will drop resources.
# We need some way to determine what resources will drop when this block is broken.

# Resources this block can drop:
@export var by_hand: String = "None"
@export var by_axe: String = ""
@export var by_pickaxe: String = ""
@export var by_hoe: String = ""

# All block textures are combined into an atlas. We use the pixel coordinates to determine which
# texture this block uses.
var uv_offset: Vector2 = Vector2.ZERO

# Set to False for things like water, tall grass.
@export var is_solid: bool = true
