# world/generation/block_interaction_manager.gd
class_name BlockInteractionManager extends Node

@onready var player: CharacterBody3D = $"../../Player"
@onready var player_focus: BlockRay = $"../../Player/Head/PlayerEyes/PlayerFocus"
var pickup_class = preload("res://items/item_pickup.tscn")

func _ready() -> void:
	await $"../../".ready
	player.add_block.connect(_on_add_block)
	player.remove_block.connect(_on_remove_block)

func get_target_chunk(world_position: Vector3i) -> Dictionary:
	return EventBus.world_manager.get_target_chunk(world_position)

# Checks to see if a block the player is placing would collide with the player, which could cause the
# player to fall through geometry
func would_collide_with_player(world_position: Vector3i) -> bool:
	var player_center = player.global_position + Vector3(0.0, 0.5, 0.0)
	var block_center = Vector3(world_position) + Vector3(0.5, 0.5, 0.5)
	var horizontal_dist = Vector2(
		player_center.x - block_center.x,
		player_center.z - block_center.z).length()
	var vertical_overlap = abs(player_center.y - block_center.y) < 1.2
	return horizontal_dist < 0.75 and vertical_overlap

func _on_add_block(_pos: Vector3i) -> void:
	var ray_hit = player_focus.get_ray_hit()
	if ray_hit == null:
		return
	var world_position = player_focus.get_ray_hit().add_position
	if would_collide_with_player(world_position):
		return
	var target = get_target_chunk(world_position)
	if target.is_empty():
		return
	var correct_chunk = target["chunk"]
	var correct_local_pos = target["local_pos"]
	var selected_block = player.selected_block_type
	correct_chunk.regen_mutex.lock()
	correct_chunk.voxels[correct_local_pos] = selected_block
	correct_chunk.dirty_voxels[correct_local_pos] = selected_block
	correct_chunk.regen_mutex.unlock()
	correct_chunk.request_rebuild()

func _on_remove_block(_pos: Vector3i) -> void:
	var ray_hit = player_focus.get_ray_hit()
	if ray_hit == null:
		return
	var world_position: Vector3i = player_focus.get_ray_hit().remove_position
	var target = get_target_chunk(world_position)
	if target.is_empty():
		return
	var correct_chunk = target["chunk"]
	var correct_local_pos = target["local_pos"]
	if correct_chunk.voxels.has(correct_local_pos):
		var broken_block: BlockType = correct_chunk.voxels[correct_local_pos]
		correct_chunk.regen_mutex.lock()
		correct_chunk.voxels.erase(correct_local_pos)
		correct_chunk.dirty_voxels[correct_local_pos] = null
		correct_chunk.regen_mutex.unlock()
		correct_chunk.threaded_rebuild()
		var drops: Array[ItemStack] = broken_block.get_drops("hand")
		for stack in drops:
			if stack.is_empty():
				continue
			var pickup: ItemPickup = pickup_class.instantiate()
			add_child(pickup)
			var spawn_pos: Vector3 = Vector3(world_position) + Vector3(0.5, 0.5, 0.5)
			pickup.setup(stack, spawn_pos)
