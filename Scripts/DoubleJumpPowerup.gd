extends Area2D

## Double Jump power-up that grants the player double jump ability

@onready var visual: Node2D = $Visual
@onready var outer_ring: Polygon2D = $Visual/OuterRing
@onready var inner_glow: Polygon2D = $Visual/InnerGlow
@onready var up_arrow_1: Polygon2D = $Visual/UpArrow1
@onready var up_arrow_2: Polygon2D = $Visual/UpArrow2
@onready var label: Label = $Visual/Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var collected: bool = false

func _ready() -> void:
	_setup_animations()

func _setup_animations() -> void:
	"""Create floating and pulsing animations."""
	# Float up and down
	var float_tween = create_tween().set_loops()
	float_tween.tween_property(visual, "position:y", -10, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(visual, "position:y", 10, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Rotate slowly
	var rotate_tween = create_tween().set_loops()
	rotate_tween.tween_property(visual, "rotation", TAU, 3.0)
	
	# Pulse the glow
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(inner_glow, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(inner_glow, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# Animate arrows moving up
	var arrow1_tween = create_tween().set_loops()
	arrow1_tween.tween_property(up_arrow_1, "position:y", -10, 0.6)
	arrow1_tween.tween_property(up_arrow_1, "modulate:a", 0.0, 0.2)
	arrow1_tween.tween_callback(func(): 
		up_arrow_1.position.y = -5
		up_arrow_1.modulate.a = 1.0
	)
	
	var arrow2_tween = create_tween().set_loops()
	arrow2_tween.tween_property(up_arrow_2, "position:y", 0, 0.6)
	arrow2_tween.tween_property(up_arrow_2, "modulate:a", 0.0, 0.2)
	arrow2_tween.tween_callback(func(): 
		up_arrow_2.position.y = 5
		up_arrow_2.modulate.a = 0.7
	)

func _on_body_entered(body: Node2D) -> void:
	"""Called when player collects the power-up."""
	if collected:
		return
	
	# Check if it's the player
	if body.name == "Player" or body.is_in_group("player") or body is CharacterBody2D:
		_collect(body)

func _collect(player: Node2D) -> void:
	"""Grant double jump to player and destroy power-up."""
	collected = true
	
	# Disable collision to prevent multiple triggers
	monitoring = false
	monitorable = false
	
	# Grant double jump ability
	if player.has_method("grant_double_jump"):
		player.grant_double_jump()
	
	# Visual feedback
	_play_collection_effect()
	
	# Destroy after effect
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_collection_effect() -> void:
	"""Play collection visual effect."""
	# Stop all animations
	for tween in get_tree().get_nodes_in_group("tween"):
		if tween.is_inside_tree():
			tween.kill()
	
	# Expand and fade out
	var collect_tween = create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(visual, "scale", Vector2(2.0, 2.0), 0.3)
	collect_tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	
	# Sparkle effect - make arrows shoot up
	var sparkle1 = create_tween()
	sparkle1.tween_property(up_arrow_1, "position:y", -50, 0.3)
	sparkle1.tween_property(up_arrow_1, "modulate:a", 0.0, 0.3)
	
	var sparkle2 = create_tween()
	sparkle2.tween_property(up_arrow_2, "position:y", -40, 0.3)
	sparkle2.tween_property(up_arrow_2, "modulate:a", 0.0, 0.3)

