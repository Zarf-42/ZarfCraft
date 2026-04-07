class_name Hotbar
extends Control

@onready var slots: HBoxContainer = $MarginContainer/HotbarSlots

const HOTBAR_SIZE: int = 9
var slot_scenes: Array[HotbarSlot] = []
var selected_slot: int = 0

var slot_scene = preload("res://ui/inventory/hotbar_slot.tscn")

func _ready() -> void:
	var slot_size: int = 64 * Settings.ui_scale
	var total_width: int = slot_size * HOTBAR_SIZE + 4 * (HOTBAR_SIZE - 1)  # slots + separation
	custom_minimum_size = Vector2(total_width, slot_size)
	scale = Vector2(Settings.ui_scale, Settings.ui_scale)
	# Create 9 slots
	for i in range(HOTBAR_SIZE):
		var slot: HotbarSlot = slot_scene.instantiate()
		slot.slot_index = i
		slots.add_child(slot)
		slot_scenes.append(slot)
		print("Instantiated Slot %s" % [slot.slot_index])

	slot_scenes[0].set_selected(true)
	EventBus.inventory_changed.connect(_on_inventory_changed)

func _input(event: InputEvent) -> void:
	# Number keys 1-9
	for i in range(HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			set_selected_slot(i)
			return

	# Mouse scroll wheel
	if event.is_action_pressed("scroll_up"):
		set_selected_slot((selected_slot - 1 + HOTBAR_SIZE) % HOTBAR_SIZE)
	elif event.is_action_pressed("scroll_down"):
		set_selected_slot((selected_slot + 1) % HOTBAR_SIZE)

func set_selected_slot(index: int) -> void:
	slot_scenes[selected_slot].set_selected(false)
	selected_slot = index
	slot_scenes[selected_slot].set_selected(true)
	EventBus.hotbar_slot_changed.emit(selected_slot)

func _on_inventory_changed(inventory: Inventory) -> void:
	for i in range(HOTBAR_SIZE):
		slot_scenes[i].update_slot(inventory.get_hotbar_slot(i))
		print("Updated slot ", slot_scenes[i])
