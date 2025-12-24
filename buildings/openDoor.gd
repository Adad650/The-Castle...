extends StaticBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_player_near: bool = false
var is_door_open: bool = false  # NEW: We track the state ourselves

func _on_player_area_body_entered(body: Node3D) -> void:
	if body.name == "player":
		is_player_near = true

func _on_player_area_body_exited(body: Node3D) -> void:
	if body.name == "player":
		is_player_near = false

func _process(delta: float) -> void:
	if is_player_near and Input.is_action_just_pressed("opening"):
		
		if is_door_open:
			animation_player.play("closeDoor")
			is_door_open = false
		else:
			animation_player.play("openDoor")
			is_door_open = true
