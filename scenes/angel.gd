extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed: float = 12.0
@export var stop_distance: float = 1.6

# Point above the angel origin to test visibility (helps if origin is at feet)
@export var visible_point_height: float = 1.2

# NEW: how many degrees inside the edge should STILL count as "not looked at"
# Example: 7.5 means the last 7.5° on left and right edges won't freeze it.
@export var horizontal_fov_margin_deg: float = 7.5

# Optional: if you ALSO want top/bottom margin, set this too (or keep 0.0)
@export var vertical_fov_margin_deg: float = 0.0

@export var player: CharacterBody3D
@export var cam: Camera3D

@onready var sight_ray: RayCast3D = $SightRay

var frozen: bool = false


func _ready() -> void:
	if player == null:
		player = get_parent().get_node_or_null("player") as CharacterBody3D

	if cam == null and player != null:
		cam = player.get_node_or_null("Head/Camera3D") as Camera3D

	sight_ray.enabled = true
	sight_ray.exclude_parent = false

	if player != null:
		sight_ray.add_exception(player)

	if player == null or cam == null:
		push_error("Angel.gd: Assign 'player' and 'cam' or keep nodes named ../player and ../player/Head/Camera3D.")


func _physics_process(delta: float) -> void:
	if player == null or cam == null:
		return

	frozen = _is_visible_to_camera()

	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_move_towards_player()


func _move_towards_player() -> void:
	var to_player: Vector3 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist <= stop_distance:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var look_target := player.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)

	var dir: Vector3 = to_player.normalized()
	var speed: float = sprint_speed if dist > 6.0 else move_speed

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0

	move_and_slide()


func _is_visible_to_camera() -> bool:
	var check_pos: Vector3 = global_position + Vector3.UP * visible_point_height

	# Basic frustum check (quick reject)
	if cam.is_position_behind(check_pos):
		return false
	if not cam.is_position_in_frustum(check_pos):
		return false

	# --- NEW: Angular "must be inside FOV minus margin" check ---
	# Direction from camera -> angel in CAMERA LOCAL SPACE
	var dir_world: Vector3 = (check_pos - cam.global_position).normalized()
	var dir_local: Vector3 = cam.global_transform.basis.xform_inv(dir_world)

	# In Godot camera local space, "forward" is -Z.
	# Horizontal angle (left/right): atan2(x, -z)
	# Vertical angle (up/down):      atan2(y, -z)
	var h_angle_deg: float = abs(rad_to_deg(atan2(dir_local.x, -dir_local.z)))
	var v_angle_deg: float = abs(rad_to_deg(atan2(dir_local.y, -dir_local.z)))

	# Compute horizontal/vertical FOV based on aspect + keep_aspect mode
	var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / max(1.0, viewport_size.y)

	var h_fov_deg: float
	var v_fov_deg: float

	if cam.keep_aspect == Camera3D.KEEP_WIDTH:
		# cam.fov is horizontal
		h_fov_deg = cam.fov
		var h_half := deg_to_rad(h_fov_deg * 0.5)
		v_fov_deg = rad_to_deg(2.0 * atan(tan(h_half) / aspect))
	else:
		# cam.fov is vertical (common default)
		v_fov_deg = cam.fov
		var v_half := deg_to_rad(v_fov_deg * 0.5)
		h_fov_deg = rad_to_deg(2.0 * atan(tan(v_half) * aspect))

	var h_limit: float = max(0.0, (h_fov_deg * 0.5) - horizontal_fov_margin_deg)
	var v_limit: float = max(0.0, (v_fov_deg * 0.5) - vertical_fov_margin_deg)

	# If it's too close to the edges, treat as "not looked at" -> it can move
	if h_angle_deg > h_limit:
		return false
	if vertical_fov_margin_deg > 0.0 and v_angle_deg > v_limit:
		return false

	# Line of sight raycast (camera -> angel)
	sight_ray.global_transform = cam.global_transform
	sight_ray.target_position = sight_ray.to_local(check_pos)
	sight_ray.force_raycast_update()

	if not sight_ray.is_colliding():
		return false

	var hit_node := sight_ray.get_collider() as Node
	if hit_node == null:
		return false

	return hit_node == self or is_ancestor_of(hit_node)
