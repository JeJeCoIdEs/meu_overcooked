extends StaticBody2D
class_name BalcaoEntrega

signal item_delivered(player_id: int, item_type: int)

@onready var sprite: Sprite2D = $Sprite2D

func can_accept_item(item: Item) -> bool:
	if not item:
		return false
	# Atualmente a salada pronta é a receita aceita
	return item.tipo == Item.ItemType.SALADA_PRONTA

func deliver_item(player_id: int, item: Item) -> bool:
	if not can_accept_item(item):
		return false
	
	emit_signal("item_delivered", player_id, item.tipo)
	
	# Notifica o BattleManager se existir na cena
	var bm = get_tree().get_first_node_in_group("BattleManager")
	if bm and bm.has_method("register_delivery"):
		bm.register_delivery(player_id, item.tipo)
	
	return true
