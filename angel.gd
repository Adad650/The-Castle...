extends CharacterBody3D

@export var move_speed: float = 6.0
@export var sprint_speed: float = 12.0
@export var stop_distance: float = 1.6

@export var visible_point_height: float = 1.2
@export var offscreen_margin_deg: float = 7.5

@export var player: CharacterBody3D
@export var cam: Camera3D

@export var hit_area: Area3D
@export var jumpscare_overlay: ColorRect
@export var jumpscare_sfx: AudioStreamPlayer

@export var jumpscare_duration: float = 1.2
@export var jumpscare_volume_db: float = 45.0
@export var death_text: String = "YOU DIED"

var frozen: bool = false
var jumpscaring: bool = false
var died_label: Label


func _ready() -> void:
	if player == null:
		player = get_parent().get_node_or_null("player") as CharacterBody3D

	if cam == null and player != null:
		cam = player.get_node_or_null("Head/Camera3D") as Camera3D

	if hit_area == null:
		hit_area = get_node_or_null("HitArea") as Area3D

	if hit_area != null and not hit_area.body_entered.is_connected(_on_hit_area_body_entered):
		hit_area.body_entered.connect(_on_hit_area_body_entered)

	if jumpscare_overlay != null:
		jumpscare_overlay.visible = false
		_setup_died_label()

	if player == null or cam == null:
		push_error("Angel.gd: Missing player/cam reference.")

	if hit_area == null:
		push_error("Angel.gd: Missing HitArea (Area3D). Add a child Area3D named 'HitArea' with a CollisionShape3D.")


func _physics_process(delta: float) -> void:
	if jumpscaring:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if player == null or cam == null:
		return

	frozen = _should_freeze()

	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_move_towards_player()


func _on_hit_area_body_entered(body: Node) -> void:
	if jumpscaring:
		return
	if body == player:
		_start_jumpscare()


func _start_jumpscare() -> void:
	jumpscaring = true
	frozen = true
	velocity = Vector3.ZERO

	if jumpscare_overlay != null:
		jumpscare_overlay.visible = true

	if died_label != null:
		died_label.text = death_text
		died_label.visible = true

	if jumpscare_sfx != null:
		jumpscare_sfx.volume_db = jumpscare_volume_db
		jumpscare_sfx.stop()
		jumpscare_sfx.play()

	await get_tree().create_timer(jumpscare_duration).timeout

	get_tree().reload_current_scene()


func _setup_died_label() -> void:
	if jumpscare_overlay == null:
		return

	died_label = jumpscare_overlay.get_node_or_null("DiedLabel") as Label
	if died_label == null:
		died_label = Label.new()
		died_label.name = "DiedLabel"
		jumpscare_overlay.add_child(died_label)

	died_label.visible = false
	died_label.text = death_text
	died_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	died_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	died_label.anchor_left = 0.0
	died_label.anchor_top = 0.0
	died_label.anchor_right = 1.0
	died_label.anchor_bottom = 1.0
	died_label.offset_left = 0.0
	died_label.offset_top = 0.0
	died_label.offset_right = 0.0
	died_label.offset_bottom = 0.0
	died_label.autowrap_mode = TextServer.AUTOWRAP_OFF


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
	var check_pos: Vector3 = global_position + Vector3.UP * visible_point_height
	var dir_world: Vector3 = (check_pos - cam.global_position).normalized()
	var dir_local: Vector3 = cam.global_transform.basis.inverse() * dir_world

	if dir_local.z >= 0.0:
		return false

	var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
	var aspect: float = float(viewport_size.x) / max(1.0, float(viewport_size.y))

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

	if h_angle_deg > h_freeze_limit:
		return false
	if v_angle_deg > v_freeze_limit:
		return false

	return _has_clear_line_of_sight(cam.global_position, check_pos)


func _has_clear_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)

	var exclude_list: Array = [self]
	if player != null:
		exclude_list.append(player)
	query.exclude = exclude_list

	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()
