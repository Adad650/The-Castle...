extends CharacterBody3D

# --- Options ---
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

# --- State Variables ---
var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

# --- Node References ---
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
# Make sure your SpotLight3D is named "Flashlight" and is a child of Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	# Start with flashlight off (optional)
	if flashlight:
		flashlight.visible = false
	else:
		print("WARNING: Flashlight node not found. Check path in player.gd")

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	# Freefly Toggle
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
			
	# Flashlight Toggle
	if Input.is_action_just_pressed(input_light):
		if flashlight:
			flashlight.visible = not flashlight.visible

func _physics_process(delta: float) -> void:
	# Freefly Movement
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Gravity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Jump
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Sprint
	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Standard Movement
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

# --- Helper Functions ---

func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

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
	# Checks if actions exist in the Input Map to prevent crashes
	var actions = [input_left, input_right, input_forward, input_back, input_jump, input_sprint, input_freefly]
	for action in actions:
		if not InputMap.has_action(action):
			push_warning("Missing Input Action: " + action)
			
	if not InputMap.has_action(input_light):
		push_warning("Missing Input Action: " + input_light + " (Flashlight wont work)")
