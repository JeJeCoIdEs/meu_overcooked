extends Node2D

signal all_players_loaded
@onready var players_container: Node2D = $PlayersContainer
@onready var map_container: Node2D = $MapContainer

const PLAYER = preload("uid://c4moe5kne6hjw")
const MAPA_1 = preload("uid://cw0aget8e1ep3")

var loaded_peers: Array[int] = []

func _ready() -> void:
	all_players_loaded.connect(
		func():
			_spawn_map.rpc()
			_spawn_players()
	)
	player_loaded.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func player_loaded() -> void:
	if not multiplayer.is_server():
		return
	
	var id = multiplayer.get_remote_sender_id()
	id = id if id != 0 else 1
	if not loaded_peers.has(id):
		loaded_peers.append(id)
	
	if loaded_peers.size() >= NetworkManager.players_data.size():
		all_players_loaded.emit()

@rpc("authority", "call_local", "reliable")
func _spawn_map() -> void:
	if map_container.get_child_count() == 0:
		var map = MAPA_1.instantiate()
		map_container.add_child(map)

func _spawn_players() -> void:
	var pids = NetworkManager.players_data.keys() if not NetworkManager.players_data.is_empty() else [1]
	if players_container.get_node_or_null(str(pids[0])):
		return
	for i in range(pids.size()):
		var p = PLAYER.instantiate()
		var pid = pids[i]
		p.name = str(pid)
		var spawn_x = 140.0 if i == 0 else (240.0 if i == 1 else clamp(140.0 + (i * 40.0), 100.0, 280.0))
		p.position = Vector2(spawn_x, 185.0)
		players_container.add_child(p, true)
