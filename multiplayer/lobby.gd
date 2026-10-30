extends Control

@onready var player_lobby: HBoxContainer = $PlayersContainer/PlayerLobby
@onready var players_container: VBoxContainer = $PlayersContainer
@onready var start_game: Button = $StartGame
@onready var leave_button: Button = $LeaveButton
@onready var banlist_button: Button = $BanlistButton

var confirm_kick_dialog: ConfirmationDialog
var confirm_ban_dialog: ConfirmationDialog
var banlist_dialog: AcceptDialog
var banlist_container: VBoxContainer

var pending_kick_pid: int = -1
var pending_ban_pid: int = -1
var last_ready_toggle_time: int = 0

func _ready() -> void:
	player_lobby.hide()
	
	# Diálogo de confirmação para Kick
	confirm_kick_dialog = ConfirmationDialog.new()
	confirm_kick_dialog.title = "Confirmar Expulsão"
	confirm_kick_dialog.dialog_text = "Deseja realmente expulsar este jogador?"
	confirm_kick_dialog.confirmed.connect(_on_kick_confirmed)
	add_child(confirm_kick_dialog)
	
	# Diálogo de confirmação para Ban
	confirm_ban_dialog = ConfirmationDialog.new()
	confirm_ban_dialog.title = "Confirmar Banimento"
	confirm_ban_dialog.dialog_text = "Deseja realmente BANIR este jogador?"
	confirm_ban_dialog.confirmed.connect(_on_ban_confirmed)
	add_child(confirm_ban_dialog)
	
	# Janela de Banlist (Desbanir)
	_setup_banlist_dialog()
	
	NetworkManager.players_updated.connect(
		func():
			update_slots()
			hide_client_buttons()
			enable_start_button()
	)
	NetworkManager.banlist_updated.connect(_update_banlist_ui)
	
	start_game.pressed.connect(_on_start_game)
	if leave_button:
		leave_button.pressed.connect(_on_leave_lobby)
	if banlist_button:
		banlist_button.pressed.connect(_on_banlist_pressed)

func _setup_banlist_dialog() -> void:
	banlist_dialog = AcceptDialog.new()
	banlist_dialog.title = "Jogadores Banidos"
	banlist_dialog.size = Vector2(380, 260)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 180)
	
	banlist_container = VBoxContainer.new()
	banlist_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(banlist_container)
	banlist_dialog.add_child(scroll)
	add_child(banlist_dialog)

func _on_leave_lobby() -> void:
	NetworkManager.leave_lobby()

func hide_client_buttons() -> void:
	if not NetworkManager.is_host():
		start_game.hide()
		if banlist_button:
			banlist_button.hide()
	else:
		start_game.show()
		if banlist_button:
			banlist_button.show()
			banlist_button.text = "Banidos (%d)" % NetworkManager.banned_players.size()

func enable_start_button() -> void:
	if not NetworkManager.is_host():
		start_game.disabled = true
		return
	
	var active_slots = players_container.get_children().filter(func(n): return n != player_lobby)
	if active_slots.is_empty():
		start_game.disabled = true
		return
	
	for slot in active_slots:
		var check_btn = slot.get_child(1) as CheckButton
		if not check_btn.button_pressed:
			start_game.disabled = true
			return
	
	start_game.disabled = false

func update_slots() -> void:
	# Remover slots de jogadores que saíram
	for node in players_container.get_children():
		if node == player_lobby:
			continue
		var pid_int = node.name.to_int()
		if not NetworkManager.players_data.has(pid_int):
			players_container.remove_child(node)
			node.queue_free()
			
	# Criar ou atualizar slots
	var is_active = NetworkManager.is_multiplayer_active()
	var my_id = multiplayer.get_unique_id() if is_active else 0
	var is_host = NetworkManager.is_host()

	for pid in NetworkManager.players_data.keys():
		var node = players_container.get_node_or_null(str(pid))
		var is_new = false
		if node == null:
			node = player_lobby.duplicate()
			node.name = str(pid)
			players_container.add_child(node)
			is_new = true
		
		var label = node.get_child(0) as Label
		var check_btn = node.get_child(1) as CheckButton
		var kick_btn = node.get_child(2) as Button
		var ban_btn = node.get_child(3) as Button
		
		var nick = NetworkManager.players_data[pid].get("nickname", "Conectando...")
		var is_ready = NetworkManager.players_data[pid].get("ready", false)
		var ping = NetworkManager.players_data[pid].get("ping", 0)
		
		if pid == 1:
			label.text = "%s  [Host]" % nick
		else:
			label.text = "%s  [%d ms]" % [nick, ping]
		
		check_btn.set_pressed_no_signal(is_ready)
		node.show()
		
		var is_other = (pid != 1 and pid != my_id)
		
		if is_new:
			if pid == my_id:
				check_btn.disabled = false
				check_btn.toggled.connect(_on_ready_toggled)
			else:
				check_btn.disabled = true
			
			if is_host and is_other:
				kick_btn.show()
				kick_btn.disabled = false
				kick_btn.pressed.connect(func(): _prompt_kick(pid))
				
				ban_btn.show()
				ban_btn.disabled = false
				ban_btn.pressed.connect(func(): _prompt_ban(pid))
			else:
				kick_btn.hide()
				ban_btn.hide()
		else:
			if is_host and is_other:
				kick_btn.show()
				ban_btn.show()
			else:
				kick_btn.hide()
				ban_btn.hide()

func _prompt_kick(pid: int) -> void:
	pending_kick_pid = pid
	var p_name = NetworkManager.players_data.get(pid, {}).get("nickname", "o jogador")
	confirm_kick_dialog.dialog_text = "Deseja realmente expulsar %s?" % p_name
	confirm_kick_dialog.popup_centered()

func _on_kick_confirmed() -> void:
	if pending_kick_pid != -1:
		NetworkManager.kick_player(pending_kick_pid)
		pending_kick_pid = -1

func _prompt_ban(pid: int) -> void:
	pending_ban_pid = pid
	var p_name = NetworkManager.players_data.get(pid, {}).get("nickname", "o jogador")
	confirm_ban_dialog.dialog_text = "Deseja realmente BANIR %s?\nO jogador será desconectado e impedido de reconectar." % p_name
	confirm_ban_dialog.popup_centered()

func _on_ban_confirmed() -> void:
	if pending_ban_pid != -1:
		NetworkManager.ban_player(pending_ban_pid)
		pending_ban_pid = -1

func _on_banlist_pressed() -> void:
	_update_banlist_ui()
	banlist_dialog.popup_centered()

func _update_banlist_ui() -> void:
	if banlist_button:
		banlist_button.text = "Banidos (%d)" % NetworkManager.banned_players.size()
	
	if not banlist_container:
		return
		
	for child in banlist_container.get_children():
		banlist_container.remove_child(child)
		child.queue_free()
		
	if NetworkManager.banned_players.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nenhum jogador banido."
		banlist_container.add_child(empty_label)
		return
		
	for ip in NetworkManager.banned_players.keys():
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 35)
		
		var nick = NetworkManager.banned_players[ip]
		var info_label = Label.new()
		info_label.text = "%s (%s)" % [nick, ip]
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_label)
		
		var unban_btn = Button.new()
		unban_btn.text = "Desbanir"
		unban_btn.pressed.connect(func(): NetworkManager.unban_ip(ip))
		row.add_child(unban_btn)
		
		banlist_container.add_child(row)

func _on_ready_toggled(is_pressed: bool) -> void:
	var now = Time.get_ticks_msec()
	if now - last_ready_toggle_time < 300:
		return
	last_ready_toggle_time = now
	NetworkManager.set_ready.rpc(is_pressed)

func _on_start_game() -> void:
	if NetworkManager.is_host():
		SceneManager.change_scene.rpc(SceneManager.GAME)
