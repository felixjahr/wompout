extends GPUParticles2D

const BASE_RADIUS := 150.0


func _ready() -> void:
	finished.connect(queue_free)


func play(radius: float) -> void:
	scale = Vector2.ONE * radius / BASE_RADIUS
	emitting = true
