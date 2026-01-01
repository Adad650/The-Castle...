extends CanvasLayer

@export var hold_seconds: float = 9.0
@export var volume_db: float = 24.0
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready():
	await get_tree().create_timer(hold_seconds).timeout

	get_tree().change_scene_to_file("res://scenes/mainMeny.tscn")
