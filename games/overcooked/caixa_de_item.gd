extends StaticBody2D
class_name Caixa

enum tipo_caixa {
	NONE,
	ALFACE,
	TOMATE,
	PRATO
}
const ITEM = preload("uid://co5m3gamxker4")

@export var type: tipo_caixa:
	set(val):
		type = val
		_update_icon()

var item_icons: Dictionary = {
	tipo_caixa.TOMATE: preload("res://games/overcooked/assets/tomato.png"),
	tipo_caixa.ALFACE: preload("res://games/overcooked/assets/lettuce.png"),
	tipo_caixa.PRATO: preload("res://games/overcooked/assets/plate.png"),
}

func _ready() -> void:
	_update_icon()

func _update_icon() -> void:
	if not is_inside_tree():
		return
	var icon = get_node_or_null("ItemIcon") as Sprite2D
	if item_icons.has(type):
		if not icon:
			icon = Sprite2D.new()
			icon.name = "ItemIcon"
			icon.position = Vector2(0, -6)
			add_child(icon)
		icon.texture = item_icons[type]
		icon.scale = Vector2(0.5, 0.5)
	elif icon:
		icon.texture = null
	
func spawn_item() -> NodePath:
	var containers = get_tree().get_nodes_in_group("Items_container_group")
	if containers.is_empty():
		return NodePath()
		
	var items_container = containers[0]
	var item = ITEM.instantiate() as Item
	
	var item_type := int(type)
	if type == tipo_caixa.PRATO:
		item_type = Item.ItemType.PRATO
	elif type == tipo_caixa.ALFACE:
		item_type = Item.ItemType.ALFACE
	elif type == tipo_caixa.TOMATE:
		item_type = Item.ItemType.TOMATE
		
	items_container.add_child(item, true)
	item.global_position = self.global_position
	item.set_item_type(item_type)
	return item.get_path()
