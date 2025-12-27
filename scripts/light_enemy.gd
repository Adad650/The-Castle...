extends CharacterBody3D

# --- Movement Settings ---
@export var move_speed: float = 12.0
@export var sprint_speed: float = 24.0
@export var stop_distance: float = 1.6

# --- Body Dimensions (For hit detection) ---
@export var check_height_top: float = 1.7
@export var check_height_mid: float = 1.0
@export var check_height_bot: float = 0.2
@export var check_width: float = 0.45 

# --- References ---
@export var player: CharacterBody3D
@export var cam: Camera3D
@export var flashlight: SpotLight3D
@export var hit_area: Area3D

# --- Jumpscare ---
var frozen: bool = false
var jumpscaring: bool = false
var _can_trigger: bool = false

func _ready() -> void:
	# 1. ROBUST PLAYER FINDER
	if player == null:
		player = get_parent().get_node_or_null("player") as CharacterBody3D
		if player == null:
			player = get_tree().get_first_node_in_group("player")
	
	if player != null:
		# 2. ROBUST COMPONENT FINDER
		if cam == null:
			cam = player.get_node_or_null("Head/Camera3D")
		
		if flashlight == null:
			# Try standard path
			flashlight = player.get_node_or_null("Head/Camera3D/Flashlight")
			
			# Try finding ANY SpotLight3D if specific name fails
			if flashlight == null and cam != null:
				for child in cam.get_children():
					if child is SpotLight3D:
						flashlight = child
						break
	
	# Debug Print to tell you exactly what is missing
	if player == null: print("❌ ENEMY ERROR: Player not found!")
	if cam == null: print("❌ ENEMY ERROR: Camera not found!")
	if flashlight == null: print("⚠️ ENEMY WARNING: Flashlight not found! (Will use Camera as fallback)")

	if hit_area == null:
		hit_area = get_node_or_null("HitArea") as Area3D
	
	if hit_area != null:
		if not hit_area.body_entered.is_connected(_on_hit_area_body_entered):
			hit_area.body_entered.connect(_on_hit_area_body_entered)

	await get_tree().create_timer(0.1).timeout
	_can_trigger = true

func _physics_process(delta: float) -> void:
	if jumpscaring or player == null:
		velocity = Vector3.ZERO
		return

	frozen = _should_freeze()

	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_move_towards_player()

func _move_towards_player() -> void:
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if dist <= stop_distance:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var look_target = player.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)

	var dir = to_player.normalized()
	var speed = sprint_speed if dist > 6.0 else move_speed

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0

	move_and_slide()

# --- THE FIXED 3D DETECTION LOGIC ---
func _should_freeze() -> bool:
	# 1. NEW: BLINK CHECK
	# If player is blinking, return FALSE (Do Not Freeze)
	if player.get("is_blinking") == true:
		return false
	
	var origin_pos: Vector3
	var forward_vec: Vector3
	var angle_limit: float
	
	# 2. DETERMINE SOURCE (Flashlight Preferred, Camera Fallback)
	if flashlight != null and flashlight.visible:
		origin_pos = flashlight.global_position
		# In Godot, SpotLights shine towards -Z (Negative Z)
		forward_vec = -flashlight.global_transform.basis.z 
		# spot_angle is the full width. We need half for the radius check.
		angle_limit = flashlight.spot_angle / 2.0 
	elif cam != null:
		# Fallback: If flashlight is broken/missing, freeze if center of screen
		origin_pos = cam.global_position
		forward_vec = -cam.global_transform.basis.z
		angle_limit = 20.0 # Default angle if no light found
	else:
		return false # No eyes, cannot freeze

	# 3. CHECK BODY PARTS
	var basis_x = global_transform.basis.x
	var points_to_check = []
	
	points_to_check.append(global_position + Vector3.UP * check_height_top)
	points_to_check.append(global_position + Vector3.UP * check_height_mid)
	points_to_check.append(global_position + Vector3.UP * check_height_bot)
	points_to_check.append(global_position + Vector3.UP * check_height_mid - basis_x * check_width)
	points_to_check.append(global_position + Vector3.UP * check_height_mid + basis_x * check_width)

	for point in points_to_check:
		# A. Calculate 3D Angle (Handles Pitch AND Yaw automatically)
		var to_point = (point - origin_pos).normalized()
		var angle = rad_to_deg(to_point.angle_to(forward_vec))
		
		# B. Angle Check
		if angle < angle_limit:
			# C. Wall Check
			if _has_clear_line_of_sight(origin_pos, point):
				return true # Freeze immediately if any point is lit

	return false

func _has_clear_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self, player]
	var hit = space_state.intersect_ray(query)
	return hit.is_empty()

func _on_hit_area_body_entered(body: Node) -> void:
	if not _can_trigger or jumpscaring:
		return
	if body == player:
		_start_jumpscare()

func _start_jumpscare() -> void:
	jumpscaring = true
	frozen = true
	_can_trigger = false
	velocity = Vector3.ZERO
	get_tree().change_scene_to_file("res://scenes/JumpscareOverlay.tscn")
