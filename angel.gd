extends CharacterBody3D

@export var move_speed: float = 12.0
@export var sprint_speed: float = 24.0
@export var stop_distance: float = 1.6
@export var visible_point_height: float = 1.2
@export var offscreen_margin_deg: float = 7.5

# NEW: How far apart the side raycasts are (adjust based on your model's width)
@export var shoulder_width: float = 0.5 

@export var player: CharacterBody3D
@export var cam: Camera3D

@export var hit_area: Area3D
@export var jumpscare_overlay: ColorRect
@export var you_died_label: Label
@export var jumpscare_sfx: AudioStreamPlayer

@export var jumpscare_duration: float = 1.2
@export var jumpscare_volume_db: float = 45.0

var frozen: bool = false
var jumpscaring: bool = false
var _can_trigger: bool = false

var _angel_start_transform: Transform3D
var _player_start_transform: Transform3D

func _ready() -> void:
	_angel_start_transform = global_transform

	if player == null:
		player = get_parent().get_node_or_null("player") as CharacterBody3D
	
	if player != null:
		_player_start_transform = player.global_transform
		if cam == null:
			cam = player.get_node_or_null("Head/Camera3D") as Camera3D

	if hit_area == null:
		hit_area = get_node_or_null("HitArea") as Area3D
	
	if hit_area != null:
		hit_area.body_entered.connect(_on_hit_area_body_entered)

	if jumpscare_overlay != null:
		jumpscare_overlay.visible = false
	if you_died_label != null:
		you_died_label.visible = false

	if player == null or cam == null:
		push_error("Angel.gd: Missing player or camera references.")

	await get_tree().create_timer(0.5).timeout
	_can_trigger = true

func _physics_process(_delta: float) -> void:
	if jumpscaring or player == null or cam == null:
		velocity = Vector3.ZERO
		return

	frozen = _should_freeze()

	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_move_towards_player()

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
	
	if jumpscare_overlay != null:
		jumpscare_overlay.visible = true
	if you_died_label != null:
		you_died_label.text = "YOU DIED"
		you_died_label.visible = true

	if jumpscare_sfx != null:
		jumpscare_sfx.volume_db = jumpscare_volume_db
		jumpscare_sfx.play()

	await get_tree().create_timer(jumpscare_duration).timeout

	get_tree().change_scene_to_file("res://scenes/JumpscareOverlay.tscn")

func _move_towards_player() -> void:
	var to_player: Vector3 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist <= stop_distance:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var look_target: Vector3 = player.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)

	var dir: Vector3 = to_player.normalized()
	var speed: float = sprint_speed if dist > 6.0 else move_speed

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0

	move_and_slide()

func _should_freeze() -> bool:
	# 1. First, check if the general direction is within the Camera FOV
	# We use the head point for the FOV math
	var head_pos: Vector3 = global_position + Vector3.UP * visible_point_height
	var dir_world: Vector3 = (head_pos - cam.global_position).normalized()
	var dir_local: Vector3 = cam.global_transform.basis.inverse() * dir_world

	# If behind camera
	if dir_local.z >= 0.0:
		return false

	# Calculate FOV angles
	var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / max(1.0, viewport_size.y)
	var h_fov_deg: float
	var v_fov_deg: float

	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		h_fov_deg = cam.fov
		var h_half_rad: float = deg_to_rad(h_fov_deg * 0.5)
		v_fov_deg = rad_to_deg(2.0 * atan(tan(h_half_rad) / aspect))
	else:
		v_fov_deg = cam.fov
		var v_half_rad: float = deg_to_rad(v_fov_deg * 0.5)
		h_fov_deg = rad_to_deg(2.0 * atan(tan(v_half_rad) * aspect))

	var h_angle_deg: float = abs(rad_to_deg(atan2(dir_local.x, -dir_local.z)))
	var v_angle_deg: float = abs(rad_to_deg(atan2(dir_local.y, -dir_local.z)))

	var h_freeze_limit: float = (h_fov_deg * 0.5) + offscreen_margin_deg
	var v_freeze_limit: float = (v_fov_deg * 0.5)

	# If completely off screen based on angles
	if h_angle_deg > h_freeze_limit or v_angle_deg > v_freeze_limit:
		return false

	# 2. If we are inside the FOV, perform the detailed Raycasts (Head + Shoulders)
	return _is_any_part_visible(cam.global_position)


func _is_any_part_visible(from_pos: Vector3) -> bool:
	# Define offsets based on current rotation (Basis)
	var right_dir = global_transform.basis.x
	
	# Point 1: Top Head
	var p1 = global_position + Vector3.UP * visible_point_height
	# Point 2: Right Shoulder (Lower than head, shifted right)
	var p2 = global_position + Vector3.UP * (visible_point_height * 0.8) + (right_dir * shoulder_width)
	# Point 3: Left Shoulder (Lower than head, shifted left)
	var p3 = global_position + Vector3.UP * (visible_point_height * 0.8) - (right_dir * shoulder_width)
	
	# If ANY of these hit, we are visible
	if _raycast_check(from_pos, p1): return true
	if _raycast_check(from_pos, p2): return true
	if _raycast_check(from_pos, p3): return true
	
	return false

func _raycast_check(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	
	# Don't let the angel block its own view, or the player block the view
	query.exclude = [self, player]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	
	# If hit is empty, it means the ray reached the target point unobstructed
	return hit.is_empty()
