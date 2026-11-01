extends Area2D
class_name Item

enum ItemType {
	NONE = 0,
	ALFACE = 1,
	TOMATE = 2,
	TOMATE_PICADO = 3,
	ALFACE_PICADA = 4,
	PRATO = 5,
	PRATO_ALFACE = 6,
	PRATO_TOMATE = 7,
	SALADA_PRONTA = 8
}

var item_list: Dictionary = {
	ItemType.TOMATE: preload("res://games/overcooked/assets/tomato.png"),
	ItemType.ALFACE: preload("res://games/overcooked/assets/lettuce.png"),
	ItemType.TOMATE_PICADO: preload("res://games/overcooked/assets/sliced_tomato.png"),
	ItemType.ALFACE_PICADA: preload("res://games/overcooked/assets/sliced_lettuce.png"),
	ItemType.PRATO: preload("res://games/overcooked/assets/plate.png"),
	ItemType.PRATO_ALFACE: preload("res://games/overcooked/assets/sliced_lettuce.png"),
	ItemType.PRATO_TOMATE: preload("res://games/overcooked/assets/sliced_tomato.png"),
	ItemType.SALADA_PRONTA: preload("res://games/overcooked/assets/salad.png"),
}

@export var tipo: int = 0:
	set(val):
		tipo = val
		_update_sprite()

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var plate_bg: Sprite2D = get_node_or_null("PlateBackground")

func _ready() -> void:
	_update_sprite()

@rpc("any_peer", "call_local", "reliable")
func sync_item_type(new_tipo: int) -> void:
	tipo = new_tipo
	_update_sprite()

func set_item_type(new_tipo: int) -> void:
	tipo = new_tipo
	_update_sprite()
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_item_type.rpc(new_tipo)

@rpc("any_peer", "call_local", "reliable")
func sync_item_authority(new_auth: int) -> void:
	set_multiplayer_authority(new_auth)

func set_item_authority(new_auth: int) -> void:
	set_multiplayer_authority(new_auth)
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_item_authority.rpc(new_auth)

func _update_sprite() -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not plate_bg:
		plate_bg = get_node_or_null("PlateBackground")
		
	if sprite and item_list.has(tipo):
		sprite.texture = item_list[tipo]
		
	if plate_bg:
		plate_bg.visible = (tipo == ItemType.PRATO_ALFACE or tipo == ItemType.PRATO_TOMATE)

func set_collision_enabled(enabled: bool) -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)
	set_deferred("monitorable", enabled)
	set_deferred("monitoring", enabled)

func can_be_cut() -> bool:
	return tipo == ItemType.TOMATE or tipo == ItemType.ALFACE

func get_cut_result() -> int:
	if tipo == ItemType.TOMATE:
		return ItemType.TOMATE_PICADO
	elif tipo == ItemType.ALFACE:
		return ItemType.ALFACE_PICADA
	return tipo

func can_combine_with(other_tipo: int) -> int:
	if tipo == ItemType.PRATO:
		if other_tipo == ItemType.ALFACE_PICADA:
			return ItemType.PRATO_ALFACE
		elif other_tipo == ItemType.TOMATE_PICADO:
			return ItemType.PRATO_TOMATE
	elif tipo == ItemType.PRATO_ALFACE and other_tipo == ItemType.TOMATE_PICADO:
		return ItemType.SALADA_PRONTA
	elif tipo == ItemType.PRATO_TOMATE and other_tipo == ItemType.ALFACE_PICADA:
		return ItemType.SALADA_PRONTA
	return 0

func is_deliverable_recipe() -> bool:
	return tipo == ItemType.SALADA_PRONTA or tipo == ItemType.PRATO_TOMATE or tipo == ItemType.PRATO_ALFACE

func get_recipe_info() -> Dictionary:
	match tipo:
		ItemType.SALADA_PRONTA:
			return {"name": "Salada Mista", "value": 0.25, "color": Color(0.3, 1.0, 0.4)}
		ItemType.PRATO_TOMATE:
			return {"name": "Salada de Tomate", "value": 0.15, "color": Color(1.0, 0.45, 0.35)}
		ItemType.PRATO_ALFACE:
			return {"name": "Salada de Alface", "value": 0.15, "color": Color(0.5, 0.9, 0.3)}
		_:
			return {"name": "", "value": 0.0, "color": Color.WHITE}

func play_squash_and_stretch(squash: Vector2 = Vector2(1.3, 0.7)) -> void:
	scale = squash
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
