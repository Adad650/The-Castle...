extends CharacterBody3D

# --- Settings ---
@export var move_speed: float = 12.0
@export var sprint_speed: float = 24.0
@export var stop_distance: float = 1.6
@export var gravity: float = 9.8
@export var flashlight_angle_limit: float = 35.0 

@export var hit_area: Area3D
var jumpscaring: bool = false
var _can_trigger: bool = false

# --- References ---
@export var player: CharacterBody3D
@export var player_flashlight: SpotLight3D 
@export var player_camera: Camera3D

@onready var body_mesh: Node3D = $BodyMesh 

func _ready() -> void:
	# 1. Debug Player Finding
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		print("ERROR: LightEnemy could not find 'player'! Is the player in the group 'player'?")
	else:
		print("SUCCESS: Player found.")
		# Check for components
		if player_flashlight == null:
			player_flashlight = player.get_node_or_null("Head/Camera3D/Flashlight")
		if player_camera == null:
			player_camera = player.get_node_or_null("Head/Camera3D")
			
		if player_flashlight == null:
			print("ERROR: Flashlight node not found at 'Head/Camera3D/Flashlight'")
		if player_camera == null:
			print("ERROR: Camera node not found at 'Head/Camera3D'")

	# 2. Debug Hit Area
	if hit_area == null:
		hit_area = get_node_or_null("HitArea") as Area3D
	
	if hit_area != null:
		if not hit_area.body_entered.is_connected(_on_hit_area_body_entered):
			hit_area.body_entered.connect(_on_hit_area_body_entered)
	else:
		print("ERROR: HitArea node is missing!")

	await get_tree().create_timer(0.1).timeout
	_can_trigger = true

func _physics_process(delta: float) -> void:
	if jumpscaring: return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Check if player exists to avoid crashes
	if player == null:
		return

	if _is_in_flashlight():
		# DEBUG: Uncomment this if you suspect it's freezing when it shouldn't
		# print("Frozen by Light!") 
		velocity.x = 0
		velocity.z = 0
	else:
		_move_towards_player()

	move_and_slide()

func _move_towards_player() -> void:
	var to_player: Vector3 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist <= stop_distance:
		velocity.x = 0
		velocity.z = 0
		return

	# Look logic
	var look_target: Vector3 = player.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)

	var dir: Vector3 = to_player.normalized()
	var speed: float = sprint_speed if dist > 6.0 else move_speed

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _on_hit_area_body_entered(body: Node) -> void:
	if not _can_trigger or jumpscaring:
		return
	if body == player:
		print("Player Touched! Jumpscare starting...")
		_start_jumpscare()

func _start_jumpscare() -> void:
	jumpscaring = true
	_can_trigger = false
	velocity = Vector3.ZERO
	get_tree().change_scene_to_file("res://scenes/JumpscareOverlay.tscn")

func _is_in_flashlight() -> bool:
	if player == null or player_flashlight == null or player_camera == null:
		return false
	
	if not player_flashlight.visible:
		return false

	var to_enemy = (global_position - player_camera.global_position).normalized()
	var player_facing = -player_camera.global_transform.basis.z 
	var angle_to_enemy = rad_to_deg(to_enemy.angle_to(player_facing))
	
	if angle_to_enemy > flashlight_angle_limit:
		return false 

	# Raycast Check
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(player_camera.global_position, global_position + Vector3.UP * 1.0)
	query.exclude = [self, player]
	var result = space_state.intersect_ray(query)
	
	# If we hit something, print what it is (helps debug invisible walls)
	if not result.is_empty():
		# print("Light blocked by: ", result.collider.name)
		return false
	
	return true
