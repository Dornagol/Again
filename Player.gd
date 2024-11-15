extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var shootsound = $ShootSound

var health = 3
const SPEED = 10.0
const JUMP_VELOCITY = 10.0
const SPAWN_POSITIONS = [
	Vector3.ZERO,
	Vector3(0, 0, 5),
	Vector3(5, 0, 0),
	Vector3(-5, 0, 0),
	Vector3(0, 0, -5)
]

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	# Set initial spawn position based on player ID
	var player_id = str(name).to_int()
	position = SPAWN_POSITIONS[player_id % SPAWN_POSITIONS.size()]

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	
	for child in $WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, false)

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if Input.is_action_just_pressed("shoot") \
			and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")
	if is_multiplayer_authority():
   	# Votre code de mouvement existant...
		move_and_slide()
	# Synchroniser la position avec les autres clients
	sync_position.rpc(position, rotation)

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	shootsound.play()
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	health -= 1
	health_changed.emit(health)  # Émettre le signal avant de vérifier la mort
	if health <= 0:
		health = 3
		# Utiliser la même logique de spawn que dans _enter_tree
		var player_id = str(name).to_int()
		position = SPAWN_POSITIONS[player_id % SPAWN_POSITIONS.size()]
		health_changed.emit(health)  # Émettre le signal après la réinitialisation

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")

# Dans Player.gd, ajoutez ceci
@rpc("unreliable", "any_peer", "call_local")
func sync_position(pos: Vector3, rot: Vector3):
	if not is_multiplayer_authority():
		position = pos
		rotation = rot
