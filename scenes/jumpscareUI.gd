extends CanvasLayer

@export var hold_seconds: float = 1.25
@export var volume_db: float = 24.0

@onready var fade: ColorRect = $ColorRect
@onready var overlay: CanvasItem = $Overlay
@onready var sfx: AudioStreamPlayer3D = $SFX

var _running: bool = false

func _ready() -> void:
	visible = false
	overlay.visible = false

func play_and_reset_scene() -> void:
	if _running:
		return
	_running = true

	visible = true
	fade.visible = true
	overlay.visible = true

	if sfx != null:
		sfx.volume_db = volume_db
		sfx.play()

	await get_tree().create_timer(hold_seconds).timeout

	get_tree().reload_current_scene()
