extends StaticBody2D
class_name Bancada

@export var is_cutting_station: bool = false
@export var held_item_path: NodePath = NodePath("")
@export var cut_progress: float = 0.0

@onready var item_slot: Marker2D = $ItemSlot
@onready var cutting_board: Sprite2D = get_node_or_null("CuttingBoard")
@onready var progress_bar: ProgressBar = get_node_or_null("ProgressBar")

const CUT_DURATION: float = 1.5

func _ready() -> void:
	if cutting_board:
		cutting_board.visible = is_cutting_station
	if progress_bar:
		progress_bar.visible = false
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0

func _process(_delta: float) -> void:
	if progress_bar:
		if cut_progress > 0.0 and cut_progress < 1.0:
			progress_bar.visible = true
			progress_bar.value = cut_progress
		else:
			progress_bar.visible = false
			
	if has_item():
		var it = get_held_item()
		if it:
			it.global_position = item_slot.global_position if item_slot else (global_position + Vector2(0, -6))
			it.z_index = 1

func has_item() -> bool:
	return held_item_path != NodePath("") and get_held_item() != null

func get_held_item() -> Item:
	if held_item_path == NodePath(""):
		return null
	return get_node_or_null(held_item_path) as Item

func can_cut() -> bool:
	if not is_cutting_station:
		return false
	var it = get_held_item()
	return it != null and it.can_be_cut()

@rpc("any_peer", "call_local", "reliable")
func request_cut(delta_amount: float) -> void:
	if not multiplayer.is_server():
		return
	if not can_cut():
		cut_progress = 0.0
		return
		
	cut_progress += delta_amount / CUT_DURATION
	if cut_progress >= 1.0:
		cut_progress = 0.0
		var it = get_held_item()
		if it:
			it.set_item_type(it.get_cut_result())
