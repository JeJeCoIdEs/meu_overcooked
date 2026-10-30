extends Node

const DEFAULT_MAX_PLAYERS: int = 32

var players_data: Dictionary = {}
var my_nick: String = ""
var max_players: int = DEFAULT_MAX_PLAYERS
var last_error_message: String = ""
var kicked_peers: Array[int] = []

var ping_timer: float = 0.0
var last_ready_times: Dictionary = {}
var last_kick_time: int = 0
var banned_players: Dictionary = {}

signal players_updated
signal connection_error(message: String)
signal banlist_updated

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_failed_to_connect)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		ping_timer += delta
		if ping_timer >= 1.5:
			ping_timer = 0.0
			_update_pings()

func _update_pings() -> void:
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer:
		return
	var pings: Dictionary = {}
	pings[1] = 0
	for pid in players_data.keys():
		if pid == 1:
			continue
		var ep = peer.get_peer(pid)
		if ep:
			pings[pid] = ep.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		else:
			pings[pid] = 0
	rpc("sync_pings", pings)

@rpc("authority", "call_local", "unreliable")
func sync_pings(pings: Dictionary) -> void:
	var changed: bool = false
	for pid in pings:
		if players_data.has(pid):
			players_data[pid]["ping"] = pings[pid]
			changed = true
	if changed:
		players_updated.emit()

func _on_peer_connected(pid: int) -> void:
	print("novo peer conectado: " + str(pid))
	if multiplayer.is_server():
		# Verificar limite máximo de jogadores
		if players_data.size() >= max_players:
			print("Servidor lotado (%d/%d). Desconectando peer %d" % [players_data.size(), max_players, pid])
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(pid)
			return
		
		# Timeout rápido do ENet e checagem de IP banido
		var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer:
			var ep = peer.get_peer(pid)
			if ep:
				var incoming_ip = ep.get_remote_address()
				if banned_players.has(incoming_ip):
					print("IP banido tentou conectar (%s). Rejeitando..." % incoming_ip)
					peer.disconnect_peer(pid)
					return
				ep.set_timeout(0, 3000, 7000)
		
		players_data[pid] = {"nickname": "Conectando...", "ready": false, "ping": 0}
		rpc("sync_players", players_data)
	
func _on_peer_disconnected(pid: int) -> void:
	print("peer desconectado: " + str(pid))
	if multiplayer.is_server():
		if pid in kicked_peers:
			kicked_peers.erase(pid)
			if players_data.has(pid):
				players_data.erase(pid)
				rpc("sync_players", players_data)
			return
			
		var nome = players_data.get(pid, {}).get("nickname", "Player " + str(pid))
		if nome.strip_edges() == "" or nome == "Conectando...":
			nome = "Player " + str(pid)
		players_data.erase(pid)
		rpc("sync_players", players_data)
		ChatUi.system_message.rpc("%s saiu do jogo" % nome, false)
		
func _on_connected_to_server() -> void:
	print("conectado ao server... enviando o nick")
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer:
		var ep = peer.get_peer(1)
		if ep:
			ep.set_timeout(0, 3000, 7000)
	rpc("send_nick", my_nick)
	
func _on_failed_to_connect() -> void:
	print("nao foi possivel conectar ao servidor.")
	multiplayer.multiplayer_peer = null
	players_data.clear()
	players_updated.emit()
	last_error_message = "Não foi possível conectar ao servidor."
	connection_error.emit(last_error_message)
	
func _on_server_disconnected() -> void:
	players_data.clear()
	players_updated.emit()
	multiplayer.multiplayer_peer = null
	ChatUi.system_message("A conexão com o servidor foi encerrada.", true)
	last_error_message = "A conexão com o servidor foi encerrada."
	connection_error.emit(last_error_message)
	
func create_server(port: int, nick: String, max_clients: int = DEFAULT_MAX_PLAYERS):
	max_players = max_clients if max_clients > 0 else DEFAULT_MAX_PLAYERS
	var peer := ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_players)
	if err != OK:
		print("Erro ao criar servidor: " + error_string(err))
		last_error_message = "Erro ao criar servidor: " + error_string(err)
		connection_error.emit(last_error_message)
		return err
	
	# Compressão de pacotes
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	print("server criado com max_players = " + str(max_players))
	multiplayer.multiplayer_peer = peer
	players_data.clear()
	banned_players.clear()
	banlist_updated.emit()
	var clean_nick = sanitize_nickname(nick, 1)
	players_data[1] = {"nickname": clean_nick, "ready": false, "ping": 0}
	rpc("sync_players", players_data)
	return err
	
func join_server(ip: String, port: int, nick: String):
	my_nick = nick.strip_edges()
	var peer := ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		print("falha na conexão com servidor: " + error_string(err))
		last_error_message = "Falha ao iniciar cliente: " + error_string(err)
		connection_error.emit(last_error_message)
		return err
	
	# Compressão de pacotes
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.multiplayer_peer = peer
	return err

func kick_player(pid: int) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or pid == 1:
		return
	var now = Time.get_ticks_msec()
	if now - last_kick_time < 500:
		return
	last_kick_time = now
	
	if multiplayer.multiplayer_peer:
		var nome = players_data.get(pid, {}).get("nickname", "Player " + str(pid))
		if nome.strip_edges() == "" or nome == "Conectando...":
			nome = "Player " + str(pid)
		kicked_peers.append(pid)
		ChatUi.system_message.rpc("%s foi expulso pelo host." % nome, true)
		players_data.erase(pid)
		rpc("sync_players", players_data)
		multiplayer.multiplayer_peer.disconnect_peer(pid)

func ban_player(pid: int) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or pid == 1:
		return
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer:
		return
	var ep = peer.get_peer(pid)
	if not ep:
		return
	
	var ip = ep.get_remote_address()
	var nome = players_data.get(pid, {}).get("nickname", "Player " + str(pid))
	if nome.strip_edges() == "" or nome == "Conectando...":
		nome = "Player " + str(pid)
	
	banned_players[ip] = nome
	kicked_peers.append(pid)
	ChatUi.system_message.rpc("%s foi banido pelo host." % nome, true)
	players_data.erase(pid)
	rpc("sync_players", players_data)
	peer.disconnect_peer(pid)
	banlist_updated.emit()

func unban_ip(ip: String) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if banned_players.has(ip):
		var nome = banned_players[ip]
		banned_players.erase(ip)
		ChatUi.system_message.rpc("%s foi desbanido pelo host." % nome, false)
		banlist_updated.emit()

func leave_lobby() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players_data.clear()
	players_updated.emit()
	connection_error.emit("")
	if SceneManager:
		SceneManager.change_scene(SceneManager.MAIN_MENU)

func sanitize_nickname(nick: String, pid: int) -> String:
	var clean_nick = nick.strip_edges()
	if clean_nick == "":
		clean_nick = "Player " + str(pid)
	
	var base_nick = clean_nick
	var counter = 1
	var is_duplicate = true
	while is_duplicate:
		is_duplicate = false
		for other_pid in players_data.keys():
			if other_pid == pid:
				continue
			if players_data[other_pid].get("nickname", "") == clean_nick:
				is_duplicate = true
				clean_nick = "%s (%d)" % [base_nick, counter]
				counter += 1
				break
	return clean_nick

@rpc("authority", "call_local", "reliable")
func sync_players(players_info: Dictionary) -> void:
	players_data = players_info
	players_updated.emit()

@rpc("any_peer", "call_remote", "reliable")
func send_nick(nick: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		var clean_nick = sanitize_nickname(nick, sender_id)
		if not players_data.has(sender_id):
			players_data[sender_id] = {"ready": false, "ping": 0}
		players_data[sender_id]["nickname"] = clean_nick
		rpc("sync_players", players_data)
		ChatUi.system_message.rpc(clean_nick + " entrou no jogo", false)

@rpc("any_peer", "call_local", "reliable")
func set_ready(is_ready: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0:
			sender_id = 1
		
		var now = Time.get_ticks_msec()
		if now - last_ready_times.get(sender_id, 0) < 300:
			return
		last_ready_times[sender_id] = now
		
		if players_data.has(sender_id):
			players_data[sender_id]["ready"] = is_ready
			rpc("sync_players", players_data)

	
