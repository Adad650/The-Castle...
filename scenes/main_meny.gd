extends Control


@onready var click: AudioStreamPlayer = $Click

func _on_button_pressed() -> void:
	click.play()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
