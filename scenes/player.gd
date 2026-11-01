extends CharacterBody2D


const SPEED = 300.0
var facing_direction: Vector2 = Vector2.DOWN
var hold_item_path: NodePath
var item_last_position: Vector2
var is_holding: bool = false

@onready var hitbox: Area2D = $Hitbox
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _enter_tree() -> void:
	var id = name.to_int()
	if id > 0:
		set_multiplayer_authority(id)

func _ready() -> void:
	# Garante que o jogador inicie dentro da arena da cozinha
	if is_multiplayer_authority():
		if position == Vector2.ZERO or global_position == Vector2.ZERO:
			var pids = NetworkManager.players_data.keys()
			var idx = pids.find(name.to_int())
			if idx == -1:
				idx = 0 if name == "1" else 1
			var spawn_x = 140.0 if idx == 0 else (240.0 if idx == 1 else clamp(140.0 + (idx * 40.0), 100.0, 280.0))
			position = Vector2(spawn_x, 185.0)
			global_position = position

	# Ativa a câmera apenas para o jogador local da máquina
	if is_multiplayer_authority() and camera:
		camera.enabled = true
		camera.make_current()

	if hitbox.get_child_count() > 0:
		var col = hitbox.get_child(0) as CollisionShape2D
		if col:
			col.disabled = false
	hitbox.position = facing_direction * get_hitbox_reach()
	_update_animation()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction:
			facing_direction = direction
			velocity = SPEED * direction
		else:
			velocity = Vector2.ZERO
		# Corte do legume na tábua ao segurar "cut"
		if Input.is_action_pressed("cut") and not is_holding:
			var target = _get_interactable()
			if target and target is Bancada and target.can_cut():
				target.request_cut.rpc_id(1, delta)
				velocity = Vector2.ZERO

		move_and_slide()
	
	# Hitbox acompanha a direção em que o jogador está olhando (em todos os peers)
	hitbox.position = facing_direction * get_hitbox_reach()
	
	# Atualiza o sprite e direção do chef em todos os peers
	_update_animation()
	
	# Mantém a posição do item carregado atualizada
	if is_holding:
		var held_item = get_node_or_null(hold_item_path)
		if held_item:
			if is_multiplayer_authority() and held_item.get_multiplayer_authority() != multiplayer.get_unique_id():
				held_item.set_multiplayer_authority(multiplayer.get_unique_id())
			if held_item is Item and held_item.monitorable:
				held_item.set_collision_enabled(false)
			var hold_offset := Vector2.ZERO
			if abs(facing_direction.x) > abs(facing_direction.y):
				hold_offset = Vector2(9.0 if facing_direction.x > 0 else -9.0, 5.0)
			else:
				hold_offset = Vector2(0.0, 7.0 if facing_direction.y > 0 else -6.0)
			item_last_position = global_position + hold_offset
			held_item.global_position = item_last_position
			held_item.z_index = 0 if facing_direction.y < 0 else 2

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	if event.is_action_pressed("interact"):
		var target = _get_interactable()
		var target_path = target.get_path() if target else NodePath("")
		request_interact.rpc_id(1, target_path)

func _get_interactable() -> Node2D:
	# 1. Checa itens no chão (Area2D) dentro da Hitbox
	for area in hitbox.get_overlapping_areas():
		if area is Item:
			return area
	
	# 2. Checa estações (Caixa, Bancada, BalcaoEntrega, Lixeira)
	for body in hitbox.get_overlapping_bodies():
		if body is Caixa or body is Bancada or body is BalcaoEntrega or body is Lixeira:
			return body
	
	# 3. Consulta direta no PhysicsServer (caso a física ainda não tenha sincronizado no frame)
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = get_hitbox_radius()
	query.shape = shape
	query.transform = Transform2D(0.0, hitbox.global_position)
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var results = space.intersect_shape(query)
	
	var found_station: Node2D = null
	for res in results:
		if res.collider is Item:
			return res.collider
		elif (res.collider is Caixa or res.collider is Bancada or res.collider is BalcaoEntrega or res.collider is Lixeira) and not found_station:
			found_station = res.collider
	if found_station:
		return found_station
	
	return null

func get_hitbox_reach() -> float:
	var body_radius = 12.0
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		body_radius = col.shape.radius
	
	var hb_radius = get_hitbox_radius()
	return body_radius + hb_radius + 4.0

func get_hitbox_radius() -> float:
	if hitbox and hitbox.has_node("CollisionShape2D"):
		var hb_col = hitbox.get_node("CollisionShape2D")
		if hb_col and hb_col.shape is CircleShape2D:
			return hb_col.shape.radius
	return 8.0

func _update_animation() -> void:
	if not animated_sprite:
		return
	
	var is_moving: bool = velocity.length() > 5.0
	var dir_str := "down"
	if abs(facing_direction.x) > abs(facing_direction.y):
		dir_str = "right" if facing_direction.x > 0 else "left"
	else:
		dir_str = "up" if facing_direction.y < 0 else "down"
	
	var anim_name: String
	if is_holding:
		anim_name = ("hold_walk_" if is_moving else "hold_idle_") + dir_str
	else:
		anim_name = ("walk_" if is_moving else "idle_") + dir_str
	
	if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
		animated_sprite.play(anim_name)

@rpc("any_peer", "call_local", "reliable")
func request_interact(target_path: NodePath):
	if not multiplayer.is_server():
		return
		
	var pid = multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = multiplayer.get_unique_id()
	
	var player_node = get_parent().get_node_or_null(str(pid)) as CharacterBody2D
	if not player_node:
		return
	
	var target = get_node_or_null(target_path) if target_path != NodePath("") else null
	var hitbox_reach = player_node.get_hitbox_reach()
	var hitbox_pos = player_node.global_position + player_node.facing_direction * hitbox_reach
	var hitbox_radius = player_node.get_hitbox_radius()
	
	# ==============================================================
	# 1. JOGADOR JÁ ESTÁ SEGURANDO UM ITEM
	# ==============================================================
	if player_node.is_holding:
		var held_item = player_node.get_node_or_null(player_node.hold_item_path) as Item
		if not held_item:
			player_node.interact_accepted.rpc(NodePath(""), 0)
			return
			
		# 1.1 LIXEIRA: descarta o item
		if target and target is Lixeira:
			target.discard_item(held_item)
			player_node.interact_accepted.rpc(NodePath(""), 0)
			return
			
		# 1.2 BALCÃO DE ENTREGA: entrega o prato/salada
		if target and target is BalcaoEntrega:
			if target.deliver_item(player_node.name.to_int(), held_item):
				held_item.queue_free()
				player_node.interact_accepted.rpc(NodePath(""), 0)
			return
			
		# 1.3 BANCADA: apoiar ou combinar
		if target and target is Bancada:
			# Caso A: Bancada está vazia -> apoia o item nela
			if not target.has_item():
				target.held_item_path = held_item.get_path()
				held_item.global_position = target.item_slot.global_position if target.item_slot else (target.global_position + Vector2(0, -6))
				held_item.z_index = 1
				held_item.set_collision_enabled(false)
				held_item.set_item_authority(1)
				player_node.interact_accepted.rpc(NodePath(""), 0)
				return
			else:
				# Caso B: Bancada tem item -> tenta combinar!
				var b_item = target.get_held_item()
				if b_item:
					# B.1: Se o jogador segurar prato e a bancada tiver ingrediente
					var combo1 = held_item.can_combine_with(b_item.tipo)
					if combo1 > 0:
						held_item.set_item_type(combo1)
						b_item.queue_free()
						target.held_item_path = NodePath("")
						player_node.interact_accepted.rpc(held_item.get_path(), combo1)
						return
						
					# B.2: Se a bancada tiver prato e o jogador segurar ingrediente
					var combo2 = b_item.can_combine_with(held_item.tipo)
					if combo2 > 0:
						b_item.set_item_type(combo2)
						held_item.queue_free()
						player_node.interact_accepted.rpc(NodePath(""), 0)
						return
						
		# 1.4 ITEM NO CHÃO: tenta combinar se o alvo for outro item no chão
		if target and target is Item:
			# Caso A: segurando prato e chão tem ingrediente picado
			var combo1 = held_item.can_combine_with(target.tipo)
			if combo1 > 0:
				held_item.set_item_type(combo1)
				target.queue_free()
				player_node.interact_accepted.rpc(held_item.get_path(), combo1)
				return
				
			# Caso B: chão tem prato e segurando ingrediente picado
			var combo2 = target.can_combine_with(held_item.tipo)
			if combo2 > 0:
				target.set_item_type(combo2)
				held_item.queue_free()
				player_node.interact_accepted.rpc(NodePath(""), 0)
				return

		# 1.5 Chão ou espaço aberto: solta o item no chão
		var drop_pos = player_node.global_position + player_node.facing_direction * 16.0
		held_item.global_position = drop_pos
		held_item.z_index = 0
		held_item.set_collision_enabled(true)
		held_item.set_item_authority(1)
		player_node.interact_accepted.rpc(NodePath(""), 0)
		return
		
	# ==============================================================
	# 2. JOGADOR COM AS MÃOS VAZIAS
	# ==============================================================
	if not target:
		return
		
	# 2.1 BANCADA: se tiver item, pega o item da bancada
	if target is Bancada and target.has_item():
		var b_item = target.get_held_item()
		if b_item:
			target.held_item_path = NodePath("")
			b_item.set_collision_enabled(false)
			b_item.set_item_authority(player_node.name.to_int())
			player_node.interact_accepted.rpc(b_item.get_path(), b_item.tipo)
		return
		
	# 2.2 ITEM SOLTO NO CHÃO: pega o item
	if target is Item:
		var item_col = target.get_node_or_null("CollisionShape2D")
		var item_col_pos = item_col.global_position if item_col else target.global_position
		var item_radius: float = 8.0
		if item_col and item_col.shape is CircleShape2D:
			item_radius = item_col.shape.radius
		
		var max_dist = hitbox_radius + item_radius + 12.0
		if hitbox_pos.distance_to(item_col_pos) <= max_dist:
			target.set_collision_enabled(false)
			target.set_item_authority(player_node.name.to_int())
			player_node.interact_accepted.rpc(target.get_path(), target.tipo)
		return
		
	# 2.3 CAIXA DISPENSADORA: spawna novo item
	if target is Caixa:
		var caixa_col = target.get_node_or_null("CollisionShape2D")
		var caixa_col_pos = caixa_col.global_position if caixa_col else target.global_position
		var caixa_radius: float = 10.0
		if caixa_col and caixa_col.shape is CircleShape2D:
			caixa_radius = caixa_col.shape.radius
		elif caixa_col and caixa_col.shape is RectangleShape2D:
			caixa_radius = caixa_col.shape.size.length() / 2.0
		
		var max_allowed_distance = hitbox_radius + caixa_radius + 12.0
		if hitbox_pos.distance_to(caixa_col_pos) <= max_allowed_distance:
			var item_path = target.spawn_item()
			var spawned_item = get_node_or_null(item_path) as Item
			if spawned_item:
				spawned_item.set_collision_enabled(false)
				spawned_item.set_item_authority(player_node.name.to_int())
			var it_type = spawned_item.tipo if spawned_item else int(target.type)
			player_node.interact_accepted.rpc(item_path, it_type)
		return

@rpc("any_peer", "call_local", "reliable")
func interact_accepted(item_path: NodePath, item_type: int):
	var sender = multiplayer.get_remote_sender_id()
	if sender > 1: # Apenas o host (peer 1 ou chamada local 0) pode aprovar
		return
	
	if item_path == NodePath(""):
		# Soltou ou entregou item
		is_holding = false
		hold_item_path = NodePath("")
		_update_animation()
		return
	else:
		# Pegou item (do chão, caixa ou bancada)
		hold_item_path = item_path
		is_holding = true
		var picked_item = get_node_or_null(item_path) as Item
		if picked_item:
			picked_item.set_item_type(item_type)
			picked_item.set_collision_enabled(false)
			picked_item.set_multiplayer_authority(name.to_int())
		_update_animation()
