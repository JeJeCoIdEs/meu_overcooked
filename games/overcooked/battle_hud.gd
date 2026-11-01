extends CanvasLayer
class_name BattleHUD

@onready var tug_bar: ProgressBar = $TopBar/TugOfWarBar
@onready var p1_label: Label = $TopBar/P1Label
@onready var p2_label: Label = $TopBar/P2Label
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_label: Label = $VictoryPanel/VictoryLabel
@onready var restart_button: Button = $VictoryPanel/RestartButton
@onready var orders_panel: PanelContainer = $TopBar/OrdersPanel

func _ready() -> void:
	add_to_group("BattleHUD")
	if victory_panel:
		victory_panel.visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func update_tug_of_war(val: float) -> void:
	if tug_bar:
		var tween = create_tween()
		tween.tween_property(tug_bar, "value", val * 100.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func pulse_tug_bar(_player_id: int) -> void:
	if not tug_bar:
		return
	# Efeito de impacto elástico na barra
	var tween = create_tween()
	tug_bar.pivot_offset = tug_bar.size / 2.0
	tween.tween_property(tug_bar, "scale", Vector2(1.08, 1.2), 0.08)
	tween.tween_property(tug_bar, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func show_winner(winner_name: String) -> void:
	if victory_panel and victory_label:
		victory_panel.visible = true
		victory_label.text = "🏆 " + winner_name.to_upper() + " VENCEU O COOK BATTLE ROYALE!"
		# Animação de entrada do painel de vitória
		victory_panel.scale = Vector2(0.7, 0.7)
		victory_panel.pivot_offset = victory_panel.size / 2.0
		var tween = create_tween()
		tween.tween_property(victory_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		if multiplayer.is_server():
			restart_button.visible = true
		else:
			restart_button.visible = false

func _on_restart_pressed() -> void:
	var bm = get_tree().get_first_node_in_group("BattleManager")
	if bm and bm.has_method("restart_game"):
		bm.restart_game.rpc()
