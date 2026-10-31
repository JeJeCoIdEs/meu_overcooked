extends CharacterBody2D

const SPEED = 300.0


func _enter_tree() -> void:
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)



func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	var direction := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if direction:
		velocity = SPEED * direction
	else:
		velocity = Vector2.ZERO
	move_and_slide()
