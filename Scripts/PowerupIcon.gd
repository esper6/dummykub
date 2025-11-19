extends Control

## Displays a single power-up icon with optional timer for temporary buffs
## Also supports cooldown overlay for relics with cooldowns (like Dash)

@onready var background: ColorRect = $Background
@onready var overlay: ColorRect = $Overlay
@onready var cooldown_label: Label = $CooldownLabel
@onready var icon_label: Label = $IconLabel
@onready var keybind_label: Label = $KeybindLabel
@onready var timer_label: Label = $TimerLabel
@onready var stack_label: Label = $StackLabel

var powerup_type: String = ""
var is_temporary: bool = false
var time_remaining: float = 0.0
var max_duration: float = 0.0
var extra_data: Dictionary = {}

# Cooldown support (for relics like Dash)
var cooldown_time: float = 0.0
var max_cooldown: float = 0.0
var is_on_cooldown: bool = false
var radial_material: ShaderMaterial

func _ready() -> void:
	timer_label.visible = false
	stack_label.visible = false
	cooldown_label.visible = false
	keybind_label.visible = false
	overlay.visible = false
	_setup_radial_shader()

func _setup_radial_shader() -> void:
	"""Setup shader for radial wipe cooldown effect."""
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	
	// Calculate angle starting from 12 o'clock (top), going clockwise
	float angle = atan(uv.x, uv.y);
	
	// Normalize to 0-1 range, starting at top
	angle = (angle + PI) / (2.0 * PI);
	
	// Hide overlay where angle is greater than progress (clockwise wipe)
	if (angle > progress) {
		discard;
	}
}
"""
	
	radial_material = ShaderMaterial.new()
	radial_material.shader = shader
	overlay.material = radial_material

func setup(type: String, temporary: bool, duration: float, data: Dictionary) -> void:
	"""Setup the power-up icon."""
	powerup_type = type
	is_temporary = temporary
	time_remaining = duration
	max_duration = duration
	extra_data = data
	
	# Configure appearance based on type
	match powerup_type:
		"double_jump":
			background.color = Color(0.6, 0.9, 1.0, 0.9)  # Light blue (matches relic color)
			icon_label.text = "🪽"  # Wings emoji (matches relic)
			keybind_label.text = "Space"
			keybind_label.visible = true
		"dash":
			background.color = Color(0.4, 1.0, 0.6, 0.9)  # Green (matches relic color)
			icon_label.text = "💨"  # Wind emoji (matches relic)
			keybind_label.text = "Shift"
			keybind_label.visible = true
		"damage_multiplier":
			background.color = Color(1.0, 0.6, 0.2, 0.9)  # Orange
			icon_label.text = "⚔"
			# Show multiplier value
			if "multiplier" in data:
				stack_label.text = "%.1fx" % data["multiplier"]
				stack_label.visible = true
		"elemental_imbue":
			var element = data.get("element", "physical")
			match element:
				"lightning":
					background.color = Color(0.9, 0.9, 0.2, 0.9)  # Yellow
					icon_label.text = "⚡"
				"fire":
					background.color = Color(1.0, 0.3, 0.1, 0.9)  # Red
					icon_label.text = "🔥"
				"ice":
					background.color = Color(0.3, 0.8, 1.0, 0.9)  # Cyan
					icon_label.text = "❄"
				_:
					background.color = Color(0.7, 0.4, 1.0, 0.9)  # Purple
					icon_label.text = "✨"
		"no_cooldown":
			background.color = Color(0.2, 1.0, 0.5, 0.9)  # Green
			icon_label.text = "⏱"
	
	# Show timer for temporary power-ups
	if is_temporary:
		timer_label.visible = true

func _process(delta: float) -> void:
	# Handle temporary power-up timer
	if is_temporary and time_remaining > 0:
		time_remaining -= delta
		
		if time_remaining <= 0:
			# Power-up expired - remove this icon
			_expire()
		else:
			# Update timer display
			timer_label.text = "%.1f" % time_remaining
			
			# Flash red when time is running out
			if time_remaining < 3.0:
				var flash_intensity = sin(Time.get_ticks_msec() / 100.0) * 0.5 + 0.5
				background.modulate = Color(1.0, flash_intensity, flash_intensity)
	
	# Handle cooldown timer (for relics)
	if is_on_cooldown:
		cooldown_time -= delta
		
		if cooldown_time <= 0:
			_end_cooldown()
		else:
			# Update radial progress (1.0 = full overlay, 0.0 = no overlay)
			var progress = cooldown_time / max_cooldown
			if radial_material:
				radial_material.set_shader_parameter("progress", progress)
			
			# Update cooldown text
			cooldown_label.text = "%.1f" % cooldown_time

func _expire() -> void:
	"""Animate removal of expired power-up."""
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	fade_tween.tween_callback(queue_free)

func update_stack(data: Dictionary) -> void:
	"""Update stack display for stackable power-ups like damage multiplier."""
	extra_data = data
	if "multiplier" in data:
		stack_label.text = "%.1fx" % data["multiplier"]
		stack_label.visible = true
		
		# Pulse effect when stack increases
		var pulse_tween = create_tween()
		pulse_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func start_cooldown(duration: float) -> void:
	"""Start a cooldown animation on this icon (for relics with cooldowns)."""
	cooldown_time = duration
	max_cooldown = duration
	is_on_cooldown = true
	overlay.visible = true
	cooldown_label.visible = true
	
	if radial_material:
		radial_material.set_shader_parameter("progress", 1.0)

func _end_cooldown() -> void:
	"""End the cooldown."""
	is_on_cooldown = false
	cooldown_time = 0.0
	overlay.visible = false
	cooldown_label.visible = false

func force_end_cooldown() -> void:
	"""Immediately end cooldown (for external calls like No Cooldown buff)."""
	_end_cooldown()

