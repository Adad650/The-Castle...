extends Node

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _on_move_area_1_body_entered(body: Node3D) -> void:
	animation_player.play("firstWallMove")
	
func _on_move_area_2_body_entered(body: Node3D) -> void:
	animation_player.play("secondWallMove")
