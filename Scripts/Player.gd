extends CharacterBody2D

## Player wizard with punch-punch-kick combo system and platformer movement

signal hit_landed(damage: int)

@onready var visual_root: Node2D = $VisualRoot
@onready var combo_timer: Timer = $ComboTimer
@onready var hitstop_timer: Timer = $HitstopTimer
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_visual: ColorRect = $WeaponHitbox/WeaponVisual
@onready var anim_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

# Combo system
enum ComboState { IDLE, PUNCH1, PUNCH2, KICK }
var current_combo_state: ComboState = ComboState.IDLE
var combo_count: int = 0
var can_input: bool = true
var in_hitstop: bool = false
var game_active: bool = true

# Movement properties
const MOVE_SPEED: float = 400.0
const JUMP_VELOCITY: float = -600.0
const GRAVITY: float = 1500.0
var facing_right: bool = true

# Attack properties
const PUNCH_DAMAGE: int = 10
const KICK_DAMAGE: int = 25
const HITSTOP_DURATION: float = 0.08  # Freeze frames duration
const COMBO_WINDOW: float = 0.5  # Time to continue combo

# Animation offsets
var attack_offset: Vector2 = Vector2.ZERO
var attack_animation_time: float = 0.0

# Attack tracking
var current_attack_damage: int = 0
var hit_enemies_this_attack: Array = []

func _ready() -> void:
	combo_timer.wait_time = COMBO_WINDOW
	weapon_hitbox.monitoring = false
	# Set initial weapon position based on facing direction
	weapon_hitbox.position.x = 70 if facing_right else -70

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	
	if not in_hitstop:
		# Apply gravity
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		
		# Handle jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		# Handle horizontal movement
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			velocity.x = direction * MOVE_SPEED
			# Flip character to face movement direction
			if direction > 0 and not facing_right:
				_flip_character(true)
			elif direction < 0 and facing_right:
				_flip_character(false)
		else:
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 5.0)
		
		# Move character
		move_and_slide()
	
	# Animate sprite based on state
	if not in_hitstop and game_active:
		if velocity.x != 0 and is_on_floor():
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")
	
	# Animate attack offset back to neutral
	if attack_offset != Vector2.ZERO:
		attack_animation_time += delta * 10.0
		attack_offset = attack_offset.lerp(Vector2.ZERO, delta * 15.0)
		visual_root.position = attack_offset

func _flip_character(right: bool) -> void:
	facing_right = right
	visual_root.scale.x = 1.0 if right else -1.0
	# Flip weapon hitbox position
	weapon_hitbox.position.x = 70 if right else -70

func _input(event: InputEvent) -> void:
	if not game_active or in_hitstop:
		return
	
	if event.is_action_pressed("attack") and can_input:
		_perform_attack()

func _perform_attack() -> void:
	can_input = false
	
	# Determine which attack in the combo
	match current_combo_state:
		ComboState.IDLE:
			_attack_punch1()
		ComboState.PUNCH1:
			_attack_punch2()
		ComboState.PUNCH2:
			_attack_kick()
		ComboState.KICK:
			# Combo finished, reset
			_reset_combo()
			_attack_punch1()

func _attack_punch1() -> void:
	current_combo_state = ComboState.PUNCH1
	combo_count = 1
	_do_attack(PUNCH_DAMAGE, Vector2(30, -10))
	combo_timer.start()

func _attack_punch2() -> void:
	current_combo_state = ComboState.PUNCH2
	combo_count = 2
	_do_attack(PUNCH_DAMAGE, Vector2(40, 0))
	combo_timer.start()

func _attack_kick() -> void:
	current_combo_state = ComboState.KICK
	combo_count = 3
	_do_attack(KICK_DAMAGE, Vector2(60, 10))
	# After kick, combo resets
	combo_timer.stop()

func _do_attack(damage: int, offset: Vector2) -> void:
	# Play attack animation
	anim_sprite.play("attack")
	
	# Visual feedback
	attack_offset = offset
	visual_root.position = offset
	attack_animation_time = 0.0
	
	# Store damage for this attack
	current_attack_damage = damage
	hit_enemies_this_attack.clear()
	
	# Enable weapon hitbox
	weapon_hitbox.monitoring = true
	weapon_visual.visible = true
	
	# Disable after a short time (attack duration)
	await get_tree().create_timer(0.15).timeout
	weapon_hitbox.monitoring = false
	weapon_visual.visible = false
	
	# Re-enable input after attack completes (if not in hitstop from hitting something)
	if not in_hitstop:
		can_input = true

func _start_hitstop() -> void:
	in_hitstop = true
	hitstop_timer.wait_time = HITSTOP_DURATION
	hitstop_timer.start()

func _on_hitstop_timer_timeout() -> void:
	in_hitstop = false
	can_input = true

func _on_combo_timer_timeout() -> void:
	_reset_combo()

func _reset_combo() -> void:
	current_combo_state = ComboState.IDLE
	combo_count = 0

func _on_weapon_hitbox_area_entered(area: Area2D) -> void:
	# Check if we haven't hit this enemy yet in this attack
	if area.get_parent() in hit_enemies_this_attack:
		return
	
	# Mark as hit
	hit_enemies_this_attack.append(area.get_parent())
	
	# Deal damage
	hit_landed.emit(current_attack_damage)
	
	# Tell the enemy to react
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(current_attack_damage)
	
	# Start hitstop for impact
	_start_hitstop()

func game_over() -> void:
	game_active = false
	can_input = false
	weapon_hitbox.monitoring = false
