extends Node

@export var tug_of_war: float = 0.5
var game_over: bool = false

var hud: CanvasLayer = null

func _enter_tree() -> void:
	add_to_group("BattleManager")

func _ready() -> void:
	if not hud:
		hud = get_node_or_null("../BattleHUD")
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud:
		hud.update_tug_of_war(tug_of_war)

func register_delivery(player_id: int, item_type: int, delivery_pos: Vector2 = Vector2.ZERO) -> void:
	if not multiplayer.is_server():
		return
	if game_over:
		return
		
	# Valor do avanço por receita:
	# Salada Completa/Mista = 25% (0.25)
	# Salada Simples (Tomate ou Alface) = 15% (0.15)
	var pull_amount = 0.25 if item_type == Item.ItemType.SALADA_PRONTA else 0.15
	
	# J1 (Host) puxa para 0.0 (azul)
	# J2 puxa para 1.0 (vermelho)
	if player_id == 1:
		tug_of_war = max(0.0, tug_of_war - pull_amount)
	else:
		tug_of_war = min(1.0, tug_of_war + pull_amount)
		
	sync_delivery_feedback.rpc(player_id, item_type, pull_amount, tug_of_war, delivery_pos)
	
	if tug_of_war <= 0.0:
		game_over = true
		end_game.rpc("Jogador 1 (Host)")
	elif tug_of_war >= 1.0:
		game_over = true
		end_game.rpc("Jogador 2 (Rival)")

@rpc("authority", "call_local", "reliable")
func sync_delivery_feedback(player_id: int, item_type: int, pull_amount: float, new_tug_val: float, delivery_pos: Vector2) -> void:
	tug_of_war = new_tug_val
	
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud:
		hud.update_tug_of_war(new_tug_val)
		if hud.has_method("pulse_tug_bar"):
			hud.pulse_tug_bar(player_id)
			
	# Sons e Juice
	var sfx = SoundEffects.get_instance()
	if sfx:
		if item_type == Item.ItemType.SALADA_PRONTA:
			sfx.play("deliver_big")
		else:
			sfx.play("deliver")
			
	# Popup de texto flutuante
	var recipe_title = "SALADA MISTA"
	var text_color = Color(0.3, 1.0, 0.4)
	if item_type == Item.ItemType.PRATO_TOMATE:
		recipe_title = "SALADA DE TOMATE"
		text_color = Color(1.0, 0.45, 0.3)
	elif item_type == Item.ItemType.PRATO_ALFACE:
		recipe_title = "SALADA DE ALFACE"
		text_color = Color(0.5, 0.95, 0.35)
		
	var pct_str = "+%d%% " % int(pull_amount * 100.0)
	_spawn_floating_text(pct_str + recipe_title + "!", delivery_pos + Vector2(0, -10), text_color)
	
	# Screen shake na câmera do jogador local
	_trigger_local_screen_shake(3.5, 0.2)

func _spawn_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var ft_scene = load("res://games/overcooked/floating_text.tscn")
	if ft_scene:
		var ft = ft_scene.instantiate()
		get_parent().add_child(ft)
		ft.global_position = pos
		ft.setup(text, color, 1.2)

func _trigger_local_screen_shake(intensity: float, duration: float) -> void:
	for p in get_tree().get_nodes_in_group("Players"):
		if p.has_method("is_local_authority") and p.is_local_authority() and p.has_method("shake_camera"):
			p.shake_camera(intensity, duration)

@rpc("authority", "call_local", "reliable")
func end_game(winner_name: String) -> void:
	game_over = true
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud:
		hud.show_winner(winner_name)
		
	var sfx = SoundEffects.get_instance()
	if sfx:
		sfx.play("win")
		
	_trigger_local_screen_shake(6.0, 0.5)

@rpc("any_peer", "call_local", "reliable")
func restart_game() -> void:
	if not multiplayer.is_server():
		return
	game_over = false
	tug_of_war = 0.5
	sync_delivery_feedback.rpc(1, Item.ItemType.NONE, 0.0, 0.5, Vector2.ZERO)
	restart_clients.rpc()

@rpc("authority", "call_local", "reliable")
func restart_clients() -> void:
	game_over = false
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud and hud.victory_panel:
		hud.victory_panel.visible = false
	if hud:
		hud.update_tug_of_war(0.5)
