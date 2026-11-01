extends CanvasLayer

@onready var control: Control = $Control
@onready var timer: Timer = $Timer
@onready var rich_text_label: RichTextLabel = $Control/VBoxContainer/RichTextLabel
@onready var line_edit: LineEdit = $Control/VBoxContainer/HBoxContainer/LineEdit
@onready var button: Button = $Control/VBoxContainer/HBoxContainer/Button

const MAX_MSG_LENGTH: int = 150
const CLIENT_COOLDOWN_MS: int = 500
const COLOR_SYSTEM_INFO: String = "#A0AEC0"   # Cinza-azulado suave para info
const COLOR_SYSTEM_ALERT: String = "#FF8A80"  # Coral suave para alertas/avisos

var last_client_send_time: int = 0
var peer_last_send_time: Dictionary = {}
var _fade_tween: Tween

func _ready() -> void:
	rich_text_label.scroll_following = true
	line_edit.text_submitted.connect(on_text_submitted)
	button.pressed.connect(on_send_button_pressed)
	
	line_edit.focus_entered.connect(func(): _show_chat(true))
	line_edit.focus_exited.connect(func(): timer.start(5.0))
	
	timer.timeout.connect(
		func():
			if not line_edit.has_focus():
				_show_chat(false)
	)
	
	# Inicia invisível e sem capturar cliques até ser necessário
	control.modulate.a = 0.0
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_submit"):
		if not NetworkManager.is_multiplayer_active():
			return
		if not line_edit.has_focus():
			line_edit.grab_focus()
			_show_chat(true)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if line_edit.has_focus():
			line_edit.release_focus()
			timer.start(3.0)
			get_viewport().set_input_as_handled()

func _show_chat(visible_target: bool) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	if visible_target:
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		_fade_tween.tween_property(control, "modulate:a", 1.0, 0.2)
	else:
		_fade_tween.tween_property(control, "modulate:a", 0.0, 0.8)
		_fade_tween.set_trans(Tween.TRANS_SINE)
		_fade_tween.set_ease(Tween.EASE_IN)
		_fade_tween.tween_callback(func():
			if control.modulate.a == 0.0:
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)

func on_text_submitted(line_edit_text: String) -> void:
	_try_send_message(line_edit_text)

func on_send_button_pressed() -> void:
	_try_send_message(line_edit.text)

func _try_send_message(text: String) -> void:
	var msg = text.strip_edges()
	line_edit.clear()
	line_edit.release_focus()
	
	if msg == "":
		timer.start(2.5)
		return
	
	if not NetworkManager.is_multiplayer_active():
		timer.start(2.5)
		return
		
	var now = Time.get_ticks_msec()
	if now - last_client_send_time < CLIENT_COOLDOWN_MS:
		return
	last_client_send_time = now
	
	timer.start(5.0)
	rpc_id(1, "request_send_message", msg)

@rpc("any_peer", "call_local", "reliable")
func request_send_message(msg: String) -> void:
	if not NetworkManager.is_host():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active() else 1
	
	var now = Time.get_ticks_msec()
	if now - peer_last_send_time.get(sender_id, 0) < CLIENT_COOLDOWN_MS:
		return
	peer_last_send_time[sender_id] = now
	
	var clean_msg = msg.strip_edges()
	if clean_msg.length() > MAX_MSG_LENGTH:
		clean_msg = clean_msg.substr(0, MAX_MSG_LENGTH)
	if clean_msg == "":
		return
	
	var sender_name = NetworkManager.players_data.get(sender_id, {}).get("nickname", "Player " + str(sender_id))
	if sender_name.strip_edges() == "":
		sender_name = "Player " + str(sender_id)
	
	rpc("receive_message", sender_name, clean_msg)

@rpc("authority", "call_local", "reliable")
func receive_message(sender_name: String, msg: String) -> void:
	rich_text_label.append_text("[color=#64B5F6][b]%s:[/b][/color] " % sender_name)
	rich_text_label.add_text(msg + "\n")
	_show_chat(true)
	timer.start(5.0)

@rpc("authority", "call_local", "reliable")
func system_message(text: String, is_alert: bool = false) -> void:
	var color = Color(COLOR_SYSTEM_ALERT if is_alert else COLOR_SYSTEM_INFO)
	rich_text_label.push_color(color)
	rich_text_label.push_italics()
	rich_text_label.add_text("* " + text + "\n")
	rich_text_label.pop()
	rich_text_label.pop()
	_show_chat(true)
	timer.start(5.0)

func system_messages(text: String) -> void:
	system_message(text, false)

@rpc("any_peer", "call_local", "reliable")
func send_message(msg: String) -> void:
	request_send_message(msg)
