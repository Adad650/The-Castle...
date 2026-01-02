extends CharacterBody3D

@export var can_move : bool = true
@export var has_gravity : bool = true
@export var can_jump : bool = true
@export var can_sprint : bool = false
@export var can_freefly : bool = false

@export_group("Speeds")
@export var look_speed : float = 0.002
@export var base_speed : float = 7.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0
@export var freefly_speed : float = 50.0

@export_group("Input Actions")
@export var input_left : String = "left"
@export var input_right : String = "right"
@export var input_forward : String = "forward"
@export var input_back : String = "backward"
@export var input_jump : String = "jump"
@export var input_sprint : String = "run"
@export var input_freefly : String = "freefly"
@export var input_light : String = "light"
@export var input_blink : String = "blink"
# MAKE SURE THIS ACTION EXISTS IN PROJECT SETTINGS -> INPUT MAP
@export var input_pause : String = "pause" 

@export_group("Audio")
@export var audio_player_path: NodePath = "AudioStreamPlayer3D"
@export var base_pitch_scale: float = 1.0

@export_group("Blinking")
@export var max_eye_open_time: float = 8.0      
@export var blink_duration_short: float = 0.15 
@export var blink_duration_long: float = 2.0    
@export var blink_overlay_path: NodePath = "CanvasLayer/BlinkOverlay"
@export var fatigue_bar_path: NodePath = "CanvasLayer/EyeFatigueBar" 

@export_group("UI")

@export var pause_menu_path: NodePath = "PauseMenu"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var is_blinking: bool = false
var current_eye_time: float = 0.0

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

@onready var blink_overlay: ColorRect = get_node_or_null(blink_overlay_path)
@onready var fatigue_bar: ProgressBar = get_node_or_null(fatigue_bar_path)
@onready var footstep_audio = get_node_or_null(audio_player_path)

# FIX: We now look for the path you assign in Inspector, not "."
@onready var pause_menu: Control = get_node_or_null(pause_menu_path)

func _ready() -> void:
	# This ensures the Player script keeps running to detect un-pause inputs
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if blink_overlay:
		blink_overlay.modulate.a = 0.0
		blink_overlay.visible = true
		
	if fatigue_bar:
		fatigue_bar.max_value = 100
		fatigue_bar.value = 0
		
	if pause_menu:
		pause_menu.visible = false
	else:
		print("⚠️ UI WARNING: PauseMenu not found! Check Inspector 'Pause Menu Path'")

	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	if flashlight: flashlight.visible = false
	
	# Start with mouse captured
	capture_mouse()

func _process(delta: float) -> void:
	# If paused, we don't process blinking logic
	if get_tree().paused:
		return

	if Input.is_action_just_pressed(input_blink):
		if not is_blinking:
			start_blink(blink_duration_short)
	
	if not is_blinking:
		current_eye_time += delta
		
		if fatigue_bar:
			var percentage = (current_eye_time / max_eye_open_time) * 100
			fatigue_bar.value = percentage
		
		if current_eye_time >= max_eye_open_time:
			start_blink(blink_duration_long)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if can_freefly and freeflying:
		handle_freefly(delta)
		return

	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	if can_jump and Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity

	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	var input_dir := Vector2.ZERO
	if can_move:
		input_dir = Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	handle_footsteps(input_dir)

func handle_footsteps(input_dir: Vector2) -> void:
	if not footstep_audio or get_tree().paused:
		return

	if is_on_floor() and input_dir != Vector2.ZERO:
		if not footstep_audio.playing:
			footstep_audio.play()
		
		var speed_ratio = move_speed / base_speed
		footstep_audio.pitch_scale = base_pitch_scale * speed_ratio
	else:
		if footstep_audio.playing:
			footstep_audio.stop()

func start_blink(duration: float):
	is_blinking = true
	current_eye_time = 0.0
	
	if blink_overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(blink_overlay, "modulate:a", 1.0, 0.1)
	
	await get_tree().create_timer(duration).timeout
	
	if blink_overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(blink_overlay, "modulate:a", 0.0, 0.1)
	
	is_blinking = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(input_pause):
		toggle_pause()
		
	# While paused, do not process looking or movement
	if get_tree().paused:
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): capture_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying: enable_freefly()
		else: disable_freefly()
			
	if Input.is_action_just_pressed(input_light):
		if flashlight: flashlight.visible = not flashlight.visible

func toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	
	if pause_menu:
		pause_menu.visible = is_paused
	
	if is_paused:
		release_mouse() 
	else:
		capture_mouse() 

func _on_resume_pressed():
	toggle_pause()

func _on_menu_pressed():
	get_tree().quit()

func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

func handle_freefly(delta):
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	motion *= freefly_speed * delta
	move_and_collide(motion)

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
