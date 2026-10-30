extends Node

@export_file("*.tscn") var main_menu_scene: String = "res://multiplayer/main_menu.tscn"
@export_file("*.tscn") var game_scene: String = "res://game_scene.tscn"

var MAIN_MENU: String:
	get: return main_menu_scene

var GAME: String:
	get: return game_scene

var fade_overlay: ColorRect

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_tela_de_transicao()

func _on_server_disconnected() -> void:
	if get_tree().current_scene and not _is_same_scene(get_tree().current_scene.scene_file_path, main_menu_scene):
		change_scene(main_menu_scene)

@rpc("authority", "call_local", "reliable")
func change_scene(scene: String) -> void:
	if get_tree().current_scene and _is_same_scene(get_tree().current_scene.scene_file_path, scene):
		return
		
	if not fade_overlay:
		get_tree().change_scene_to_file(scene)
		return
		
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.25)
	await tween.finished
	
	# Lock de players: fecha para novas conexões durante o jogo
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = _is_same_scene(scene, GAME)
	
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	
	var tween2 = create_tween()
	tween2.tween_property(fade_overlay, "color:a", 0.0, 0.25)
	await tween2.finished
	
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _resolve_path(path: String) -> String:
	if path.begins_with("uid://"):
		var id = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return path

func _is_same_scene(path_a: String, path_b: String) -> bool:
	return _resolve_path(path_a) == _resolve_path(path_b)

func _tela_de_transicao() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)
	
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_overlay)
