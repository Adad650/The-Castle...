extends Node3D 
class_name MainGame  


static var environment_enabled: bool = true 

@onready var world_env = $WorldEnvironment
@onready var default_env = world_env.environment

func _ready():
	
	if MainGame.environment_enabled:
		world_env.environment = default_env
	else:
		world_env.environment = null
