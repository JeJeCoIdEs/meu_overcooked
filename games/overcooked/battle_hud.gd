extends CanvasLayer
class_name BattleHUD

@onready var tug_bar: ProgressBar = $TopBar/TugOfWarBar
@onready var p1_label: Label = $TopBar/P1Label
@onready var p2_label: Label = $TopBar/P2Label
@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_label: Label = $VictoryPanel/VictoryLabel
@onready var restart_button: Button = $VictoryPanel/RestartButton

func _ready() -> void:
	add_to_group("BattleHUD")
	if victory_panel:
		victory_panel.visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func update_tug_of_war(val: float) -> void:
	if tug_bar:
		# Anima suavemente o valor da barra
		var tween = create_tween()
		tween.tween_property(tug_bar, "value", val * 100.0, 0.3)

func show_winner(winner_name: String) -> void:
	if victory_panel and victory_label:
		victory_panel.visible = true
		victory_label.text = "🏆 " + winner_name.to_upper() + " VENCEU O COOK BATTLE ROYALE!"
		if multiplayer.is_server():
			restart_button.visible = true
		else:
			restart_button.visible = false

func _on_restart_pressed() -> void:
	var bm = get_tree().get_first_node_in_group("BattleManager")
	if bm and bm.has_method("restart_game"):
		bm.restart_game.rpc()
