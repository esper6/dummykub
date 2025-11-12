extends Control

## Cooldown icon with radial wipe overlay (WoW-style)

@onready var overlay: ColorRect = $Overlay
@onready var cooldown_label: Label = $CooldownLabel
@onready var keybind_label: Label = $KeybindLabel
@onready var icon_texture: TextureRect = $IconTexture

var cooldown_time: float = 0.0
var max_cooldown: float = 0.0
var is_on_cooldown: bool = false

# For radial wipe effect
var radial_material: ShaderMaterial

func _ready() -> void:
	_setup_radial_shader()
	cooldown_label.visible = false
	overlay.visible = false

func _setup_radial_shader() -> void:
	"""Setup shader for radial wipe effect."""
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	
	// Calculate angle starting from 12 o'clock (top), going clockwise
	// atan gives us angle from -PI to PI
	float angle = atan(uv.x, uv.y);  // Note: positive y points down in UV space
	
	// Normalize to 0-1 range, starting at top (12 o'clock)
	angle = (angle + PI) / (2.0 * PI);  // Now 0-1, with top at 1.0/0.0
	// No offset needed - top is already at 0.0!
	
	// Hide overlay where angle is greater than progress (clockwise wipe)
	if (angle > progress) {
		discard;  // Completely remove this pixel
	}
	// Keep the original red color from the ColorRect
}
"""
	
	radial_material = ShaderMaterial.new()
	radial_material.shader = shader
	overlay.material = radial_material

func set_icon(texture: Texture2D) -> void:
	"""Set the icon texture."""
	icon_texture.texture = texture

func set_keybind(key_text: String) -> void:
	"""Set the keybind display text."""
	keybind_label.text = key_text

func start_cooldown(duration: float) -> void:
	"""Start a cooldown animation."""
	cooldown_time = duration
	max_cooldown = duration
	is_on_cooldown = true
	overlay.visible = true
	cooldown_label.visible = true
	
	if radial_material:
		radial_material.set_shader_parameter("progress", 1.0)

func _process(delta: float) -> void:
	if not is_on_cooldown:
		return
	
	cooldown_time -= delta
	
	if cooldown_time <= 0:
		_end_cooldown()
	else:
		# Update radial progress (1.0 = full overlay, 0.0 = no overlay)
		var progress = cooldown_time / max_cooldown
		if radial_material:
			radial_material.set_shader_parameter("progress", progress)
		
		# Update text
		cooldown_label.text = "%.1f" % cooldown_time

func _end_cooldown() -> void:
	"""End the cooldown."""
	is_on_cooldown = false
	cooldown_time = 0.0
	overlay.visible = false
	cooldown_label.visible = false

func force_end_cooldown() -> void:
	"""Immediately end cooldown (for external calls)."""
	_end_cooldown()

