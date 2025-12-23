extends Node3D

@onready var trigger_area: Area3D = $TriggerArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var ghost_sprite: Sprite3D = $GhostSprite
@onready var scare_sfx: AudioStreamPlayer3D = $AudioStreamPlayer3D

# How long the ghost is visible (in seconds)
var flash_duration: float = 0.2 

var has_triggered: bool = false

func _ready() -> void:
	# Hide the ghost immediately when the game starts
	ghost_sprite.visible = false
	trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if has_triggered:
		return
	
	if body.name == "player" or body.is_in_group("player"):
		has_triggered = true
		_start_scare()

func _start_scare() -> void:
	ghost_sprite.visible = true
	
	# 1. CALCULATE SPEED
	# If the animation is normally 1.0 second, and we want it done in 0.2 seconds,
	# we need to play it at 5x speed (1.0 / 0.2 = 5.0).
	var speed_multiplier = 1.0 / flash_duration
	
	# 2. PLAY FAST
	# The 3rd argument in play() is the custom speed.
	anim_player.stop()
	anim_player.play("run_across", -1, speed_multiplier)
	
	# 3. PLAY SOUND
	if scare_sfx != null:
		scare_sfx.play()

	# 4. WAIT & HIDE
	# Wait for the flash duration, then instantly hide it.
	await get_tree().create_timer(flash_duration).timeout
	ghost_sprite.visible = false
