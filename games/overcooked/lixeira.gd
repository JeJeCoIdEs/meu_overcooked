extends StaticBody2D
class_name Lixeira

func discard_item(item: Item) -> void:
	if item:
		item.queue_free()
