extends StaticBody2D
class_name BalcaoEntrega

signal item_delivered(player_id: int, item_type: int)

@onready var sprite: Sprite2D = $Sprite2D

func can_accept_item(item: Item) -> bool:
	if not item:
		return false
	return item.has_method("is_deliverable_recipe") and item.is_deliverable_recipe()

func deliver_item(player_id: int, item: Item) -> bool:
	if not can_accept_item(item):
		return false
	
	var item_type = item.tipo
	var pos = global_position
	emit_signal("item_delivered", player_id, item_type)
	
	# Efeito de squash e retorno no balcão
	var tween = create_tween()
	scale = Vector2(1.2, 0.85)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var bm = get_tree().get_first_node_in_group("BattleManager")
	if bm and bm.has_method("register_delivery"):
		bm.register_delivery(player_id, item_type, pos)
	
	return true

