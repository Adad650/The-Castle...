extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _on_area_3d_body_entered(body: Node3D) -> void:
	animation_player.play("moveWall")
