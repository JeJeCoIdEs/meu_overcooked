extends Node

signal all_players_loaded
@onready var players_container: Node = $PlayersContainer
@onready var map_container: Node = $MapContainer

const PLAYER = preload("uid://c4moe5kne6hjw")

var loaded_peers: Array[int] = []

func _ready() -> void:
	all_players_loaded.connect(_spawn_players)
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

func _spawn_players() -> void:
	var pids = NetworkManager.players_data.keys() if not NetworkManager.players_data.is_empty() else [1]
	for i in range(pids.size()):
		var p = PLAYER.instantiate()
		var pid = pids[i]
		p.name = str(pid)
		p.position = Vector2(150 + (i * 120), 200)
		players_container.add_child(p, true)
