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

func register_delivery(player_id: int, _item_type: int) -> void:
	if not multiplayer.is_server():
		return
	if game_over:
		return
		
	# J1 (Host) puxa para 0.0 (lado esquerdo / azul)
	# J2 puxa para 1.0 (lado direito / vermelho)
	if player_id == 1:
		tug_of_war = max(0.0, tug_of_war - 0.20)
	else:
		tug_of_war = min(1.0, tug_of_war + 0.20)
		
	sync_tug_of_war.rpc(tug_of_war)
	
	if tug_of_war <= 0.0:
		game_over = true
		end_game.rpc("Jogador 1 (Host)")
	elif tug_of_war >= 1.0:
		game_over = true
		end_game.rpc("Jogador 2 (Rival)")

@rpc("authority", "call_local", "reliable")
func sync_tug_of_war(val: float) -> void:
	tug_of_war = val
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud:
		hud.update_tug_of_war(val)

@rpc("authority", "call_local", "reliable")
func end_game(winner_name: String) -> void:
	game_over = true
	if not hud:
		hud = get_tree().get_first_node_in_group("BattleHUD")
	if hud:
		hud.show_winner(winner_name)

@rpc("any_peer", "call_local", "reliable")
func restart_game() -> void:
	if not multiplayer.is_server():
		return
	game_over = false
	tug_of_war = 0.5
	sync_tug_of_war.rpc(0.5)
	
	# Reinicia o painel em todos
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
