extends CharacterBody3D

@export var move_speed: float = 12.0
@export var sprint_speed: float = 24.0
@export var stop_distance: float = 1.6

@export var offscreen_margin_deg: float = 15.0
@export var check_height_top: float = 1.7
@export var check_height_mid: float = 1.0
@export var check_height_bot: float = 0.2
@export var check_width: float = 0.45 

@export var player: CharacterBody3D
@export var cam: Camera3D

@export var hit_area: Area3D

@export var jumpscare_overlay: ColorRect
@export var you_died_label: Label
@export var jumpscare_sfx: AudioStreamPlayer
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

	await get_tree().create_timer(0.1).timeout
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
	var check_pos_center: Vector3 = global_position + Vector3.UP * check_height_mid
	
	var dir_world: Vector3 = (check_pos_center - cam.global_position).normalized()
	var dir_local: Vector3 = cam.global_transform.basis.inverse() * dir_world

	if dir_local.z >= 0.0:
		return false

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

	if h_angle_deg > h_freeze_limit or v_angle_deg > v_freeze_limit:
		return false

	var basis_x = global_transform.basis.x
	var points_to_check = []
	
	points_to_check.append(global_position + Vector3.UP * check_height_top)
	points_to_check.append(global_position + Vector3.UP * check_height_mid)
	points_to_check.append(global_position + Vector3.UP * check_height_bot)
	points_to_check.append(global_position + Vector3.UP * check_height_mid - basis_x * check_width)
	points_to_check.append(global_position + Vector3.UP * check_height_mid + basis_x * check_width)

	for point in points_to_check:
		if _has_clear_line_of_sight(cam.global_position, point):
			return true

	return false

func _has_clear_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self, player]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()
