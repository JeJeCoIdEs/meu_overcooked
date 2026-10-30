extends Control

@onready var network_ui: Control = $NetworkUI
@onready var host: Button = $NetworkUI/Host
@onready var join: Button = $NetworkUI/Join
@onready var ip: LineEdit = $NetworkUI/Ip
@onready var port: LineEdit = $NetworkUI/Port
@onready var max_players: LineEdit = $NetworkUI.get_node_or_null("MaxPlayers")
@onready var nick: LineEdit = $NetworkUI/Nick
@onready var lobby: Control = $Lobby
@onready var error_label: Label = $NetworkUI.get_node_or_null("ErrorLabel")

const CONFIG_FILE_PATH = "user://network_settings.cfg"

func _ready() -> void:
	lobby.hide()
	network_ui.show()
	
	if error_label == null:
		error_label = Label.new()
		error_label.name = "ErrorLabel"
		error_label.position = Vector2(0, 250)
		error_label.size = Vector2(231, 55)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
		network_ui.add_child(error_label)
	
	_load_saved_settings()
	NetworkManager.connection_error.connect(_on_connection_error)
	
	if NetworkManager.last_error_message != "":
		show_error(NetworkManager.last_error_message)
		NetworkManager.last_error_message = ""

func _load_saved_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)
	if err == OK:
		if nick and config.has_section_key("network", "nick"):
			nick.text = config.get_value("network", "nick", "")
		if ip and config.has_section_key("network", "ip"):
			ip.text = config.get_value("network", "ip", "127.0.0.1")
		if port and config.has_section_key("network", "port"):
			port.text = str(config.get_value("network", "port", 7000))
		if max_players and config.has_section_key("network", "max_players"):
			max_players.text = str(config.get_value("network", "max_players", 32))

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("network", "nick", nick.text.strip_edges() if nick else "")
	config.set_value("network", "ip", ip.text.strip_edges() if ip else "127.0.0.1")
	config.set_value("network", "port", port.text.to_int() if port else 7000)
	if max_players and max_players.text.strip_edges() != "":
		config.set_value("network", "max_players", max_players.text.to_int())
	config.save(CONFIG_FILE_PATH)

func _on_host_pressed() -> void:
	clear_error()
	var port_num = port.text.to_int()
	var nickname = nick.text
	
	if port_num <= 0:
		show_error("Porta inválida.")
		return
	if nickname.strip_edges() == "":
		show_error("Digite um nickname.")
		return
	
	var max_p = 32
	if max_players and max_players.text.strip_edges() != "":
		var parsed = max_players.text.to_int()
		if parsed > 0:
			max_p = parsed
			
	_save_settings()
	var err = NetworkManager.create_server(port_num, nick.text, max_p)
	if err == OK:
		network_ui.hide()
		lobby.show()

func _on_join_pressed() -> void:
	clear_error()
	var port_num = port.text.to_int()
	var nickname = nick.text
	
	if port_num <= 0:
		show_error("Porta inválida.")
		return
	if ip.text.strip_edges() == "":
		show_error("IP não pode ser vazio.")
		return
	if nickname.strip_edges() == "":
		show_error("Digite um nickname.")
		return
		
	_save_settings()
	var err = NetworkManager.join_server(ip.text, port_num, nick.text)
	if err == OK:
		network_ui.hide()
		lobby.show()

func _on_connection_error(msg: String) -> void:
	if msg != "":
		show_error(msg)
	else:
		clear_error()
	lobby.hide()
	network_ui.show()

func show_error(msg: String) -> void:
	if error_label:
		error_label.text = msg

func clear_error() -> void:
	if error_label:
		error_label.text = ""
