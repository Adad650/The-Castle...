extends CharacterBody3D

# --- Movement Options ---
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
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
@export var input_left : String = "left"
@export var input_right : String = "right"
@export var input_forward : String = "forward"
@export var input_back : String = "backward"
@export var input_jump : String = "jump"
@export var input_sprint : String = "run"
@export var input_freefly : String = "freefly"
@export var input_light : String = "light"
@export var input_blink : String = "blink" # Make sure this matches Input Map exactly

# --- Blink Settings ---
@export_group("Blinking")
@export var max_eye_open_time: float = 8.0     
@export var blink_duration_short: float = 0.15 
@export var blink_duration_long: float = 2.0   
# CHECK THESE PATHS CAREFULLY IN THE INSPECTOR
@export var blink_overlay_path: NodePath = "CanvasLayer/BlinkOverlay"
@export var fatigue_bar_path: NodePath = "CanvasLayer/EyeFatigueBar" 

# --- State Variables ---
var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

# --- Blink State ---
var is_blinking: bool = false
var current_eye_time: float = 0.0

# --- Nodes ---
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

# We grab these in _ready to ensure they exist
var blink_overlay: ColorRect 
var fatigue_bar: ProgressBar # Or TextureProgressBar

func _ready() -> void:
	# --- DEBUGGING UI CONNECTION ---
	blink_overlay = get_node_or_null(blink_overlay_path)
	fatigue_bar = get_node_or_null(fatigue_bar_path)
	
	if blink_overlay:
		print("✅ UI SUCCESS: BlinkOverlay found!")
		blink_overlay.modulate.a = 0.0 # Make transparent start
		blink_overlay.visible = true
	else:
		print("❌ UI ERROR: BlinkOverlay NOT found at path: ", blink_overlay_path)
		
	if fatigue_bar:
		print("✅ UI SUCCESS: FatigueBar found!")
		fatigue_bar.max_value = 100
		fatigue_bar.value = 0
	else:
		print("⚠️ UI WARNING: FatigueBar NOT found at path: ", fatigue_bar_path)

	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	if flashlight: flashlight.visible = false

func _process(delta: float) -> void:
	# --- 1. HANDLE INPUTS ---
	# We put this in _process to ensure it catches the press every frame
	if Input.is_action_just_pressed(input_blink):
		if not is_blinking:
			print("👀 Blink Button Pressed!")
			start_blink(blink_duration_short)
	
	# --- 2. EYE FATIGUE LOGIC ---
	if not is_blinking:
		current_eye_time += delta
		
		# Update Progress Bar
		if fatigue_bar:
			var percentage = (current_eye_time / max_eye_open_time) * 100
			fatigue_bar.value = percentage
		
		# Forced Penalty Blink
		if current_eye_time >= max_eye_open_time:
			print("⚠️ Forced Blink Triggered!")
			start_blink(blink_duration_long)

func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		handle_freefly(delta)
		return

	# Gravity
	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if can_jump and Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity

	# Sprint
	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Move
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
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

# --- BLINK FUNCTION ---
func start_blink(duration: float):
	# If UI is missing, we still want the mechanic to work logic-wise, 
	# but we can't show the visual.
	is_blinking = true
	current_eye_time = 0.0 # Reset Timer Immediately
	
	if blink_overlay:
		# Close Eyes (Alpha 0 -> 1)
		var tween = get_tree().create_tween()
		tween.tween_property(blink_overlay, "modulate:a", 1.0, 0.1)
	
	# Wait for the duration (eyes closed)
	await get_tree().create_timer(duration).timeout
	
	if blink_overlay:
		# Open Eyes (Alpha 1 -> 0)
		var tween = get_tree().create_tween()
		tween.tween_property(blink_overlay, "modulate:a", 0.0, 0.1)
	
	is_blinking = false
	print("👀 Eyes Opened")

# --- INPUT HANDLING ---
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE): release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying: enable_freefly()
		else: disable_freefly()
			
	if Input.is_action_just_pressed(input_light):
		if flashlight: flashlight.visible = not flashlight.visible

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

func check_input_mappings():
	var actions = [input_blink]
	for action in actions:
		if not InputMap.has_action(action):
			print("❌ CRITICAL ERROR: Input Action '", action, "' is missing in Project Settings!")
