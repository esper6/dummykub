extends CanvasLayer

## Ability selection screen for level 3+ rewards
## Displays 3 random abilities for the player to choose from

signal ability_chosen(ability_name: String)

@onready var ability_container = $Panel/VBoxContainer/AbilityContainer

var player: Node = null  # Reference to player for checking ability levels

# Define available abilities with their properties
var abilities: Array[Dictionary] = [
	{
		"id": "attack_speed",
		"name": "Swift Strikes",
		"description": "+50% Attack Speed\nPunch-Kick-Uppercut combo 50% faster",
		"icon": "⚔️",
		"color": Color(1.0, 0.5, 0.2)
	},
	{
		"id": "crit_chance",
		"name": "Critical Mastery",
		"description": "+20% Critical Hit Chance\nCrits deal 2x damage",
		"icon": "💥",
		"color": Color(1.0, 0.9, 0.2)
	},
	{
		"id": "cooldown_reduction",
		"name": "Arcane Haste",
		"description": "+25% Cooldown Reduction\nSkills and combo cooldown faster",
		"icon": "⚡",
		"color": Color(0.3, 0.8, 1.0)
	}
]

func _ready() -> void:
	hide()
	# Process mode allows this UI to work while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_ability_selection(player_ref: Node = null) -> void:
	"""Show the ability selection screen with 3 random abilities."""
	player = player_ref  # Store player reference for level checking
	
	# Clear previous buttons
	for child in ability_container.get_children():
		child.queue_free()
	
	# Create a horizontal container for the buttons
	var h_container = HBoxContainer.new()
	h_container.add_theme_constant_override("separation", 30)
	h_container.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_container.add_child(h_container)
	
	# Pick 3 random abilities (or all if less than 3)
	var available_abilities = abilities.duplicate()
	available_abilities.shuffle()
	var choices = available_abilities.slice(0, 3)
	
	# Create buttons for each choice
	for ability in choices:
		var button_container = _create_ability_button(ability)
		h_container.add_child(button_container)
	
	# Show and pause
	show()
	get_tree().paused = true

func _create_ability_button(ability: Dictionary) -> Control:
	"""Create a styled button container for an ability choice."""
	# Check if this ability is at level 5 (breakpoint)
	var ability_level = 0
	if player and player.has_method("get_ability_level"):
		ability_level = player.get_ability_level(ability.id)
	var is_breakpoint = ability_level >= 5
	
	# Create a VBoxContainer to hold button and description
	var container = VBoxContainer.new()
	
	# Create the main button
	var button = Button.new()
	button.custom_minimum_size = Vector2(250, 140)
	
	# Set button text with icon and name
	button.text = ability.icon + "\n" + ability.name.to_upper()
	
	# Style the button - enhanced for breakpoint
	var style_normal = StyleBoxFlat.new()
	if is_breakpoint:
		# Breakpoint styling: brighter, more prominent
		style_normal.bg_color = ability.color * 0.35  # Brighter background
		style_normal.border_width_left = 6
		style_normal.border_width_top = 6
		style_normal.border_width_right = 6
		style_normal.border_width_bottom = 6
		style_normal.border_color = Color(1.0, 1.0, 0.5, 1.0)  # Golden border for breakpoint
	else:
		style_normal.bg_color = ability.color * 0.25  # Darker version
		style_normal.border_width_left = 4
		style_normal.border_width_top = 4
		style_normal.border_width_right = 4
		style_normal.border_width_bottom = 4
		style_normal.border_color = ability.color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	button.add_theme_stylebox_override("normal", style_normal)
	
	# Hover style (brighter)
	var style_hover = style_normal.duplicate()
	if is_breakpoint:
		style_hover.bg_color = ability.color * 0.5
		style_hover.border_width_left = 7
		style_hover.border_width_top = 7
		style_hover.border_width_right = 7
		style_hover.border_width_bottom = 7
	else:
		style_hover.bg_color = ability.color * 0.4
		style_hover.border_width_left = 5
		style_hover.border_width_top = 5
		style_hover.border_width_right = 5
		style_hover.border_width_bottom = 5
	button.add_theme_stylebox_override("hover", style_hover)
	
	# Pressed style
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = ability.color * 0.6
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# Font color and size - enhanced for breakpoint
	if is_breakpoint:
		button.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7, 1.0))  # Brighter, more golden
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_font_size_override("font_size", 30)  # Slightly larger
	else:
		button.add_theme_color_override("font_color", ability.color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 28)
	
	# Add breakpoint indicator badge if at level 5
	if is_breakpoint:
		var breakpoint_badge = Label.new()
		breakpoint_badge.text = "⭐ BREAKPOINT ⭐"
		breakpoint_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		breakpoint_badge.add_theme_font_size_override("font_size", 18)
		breakpoint_badge.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 1.0))  # Golden color
		breakpoint_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		breakpoint_badge.add_theme_constant_override("outline_size", 3)
		container.add_child(breakpoint_badge)
		
		# Animate the badge with pulsing glow
		var badge_tween = create_tween()
		badge_tween.set_loops()  # Loop forever
		badge_tween.set_parallel(true)
		badge_tween.tween_property(breakpoint_badge, "modulate", Color(1.5, 1.5, 0.8, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		badge_tween.tween_property(breakpoint_badge, "scale", Vector2(1.1, 1.1), 1.0).set_ease(Tween.EASE_IN_OUT)
		badge_tween.tween_property(breakpoint_badge, "modulate", Color(1.0, 1.0, 0.5, 1.0), 1.0).set_delay(1.0).set_ease(Tween.EASE_IN_OUT)
		badge_tween.tween_property(breakpoint_badge, "scale", Vector2(1.0, 1.0), 1.0).set_delay(1.0).set_ease(Tween.EASE_IN_OUT)
		
		# Add pulsing glow effect to the button
		_add_breakpoint_glow_effect(button, ability.color)
		
		# Add subtle scale pulse to button
		var button_pulse = create_tween()
		button_pulse.set_loops()  # Loop forever
		button_pulse.tween_property(button, "scale", Vector2(1.02, 1.02), 1.5).set_ease(Tween.EASE_IN_OUT)
		button_pulse.tween_property(button, "scale", Vector2(1.0, 1.0), 1.5).set_ease(Tween.EASE_IN_OUT)
	
	# Create description label - enhanced for breakpoint
	var description = Label.new()
	description.custom_minimum_size = Vector2(250, 0)
	if is_breakpoint:
		description.text = ability.description + "\n[BREAKPOINT ACTIVE]"
	else:
		description.text = ability.description
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_breakpoint:
		description.add_theme_font_size_override("font_size", 15)  # Slightly larger
		description.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7, 1.0))  # Brighter, golden tint
	else:
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	description.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description.add_theme_constant_override("outline_size", 1)
	
	# Add level indicator if not at breakpoint yet
	if not is_breakpoint and ability_level > 0:
		var level_label = Label.new()
		level_label.text = "Level " + str(ability_level) + " / 5"
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		level_label.add_theme_constant_override("outline_size", 1)
		container.add_child(level_label)
	
	# Connect button press
	button.pressed.connect(_on_ability_selected.bind(ability.id))
	
	# Add to container
	container.add_child(button)
	container.add_child(description)
	
	# Store button reference for breakpoint effects
	if is_breakpoint:
		button.set_meta("is_breakpoint", true)
		button.set_meta("ability_color", ability.color)
	
	return container

func _add_breakpoint_glow_effect(button: Button, ability_color: Color) -> void:
	"""Add a pulsing glow effect to breakpoint buttons by animating border color."""
	# Animate the border color to create a pulsing glow effect
	var glow_tween = create_tween()
	glow_tween.set_loops()  # Loop forever
	
	# Get the normal stylebox
	var style_normal = button.get_theme_stylebox("normal")
	if not style_normal:
		return
	
	# Create a copy to animate
	var animated_style = style_normal.duplicate()
	button.add_theme_stylebox_override("normal", animated_style)
	
	# Animate border color between bright gold and slightly dimmer
	var bright_gold = Color(1.0, 1.0, 0.5, 1.0)
	var dim_gold = Color(0.9, 0.9, 0.4, 1.0)
	
	# Create callback function for border color animation
	var border_color_callback = func(color: Color):
		if animated_style:
			animated_style.border_color = color
	
	glow_tween.tween_method(border_color_callback, bright_gold, dim_gold, 1.5).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_method(border_color_callback, dim_gold, bright_gold, 1.5).set_ease(Tween.EASE_IN_OUT)
	
	# Also animate background color slightly
	var base_bg = ability_color * 0.35
	var bright_bg = ability_color * 0.45
	
	# Create callback function for background color animation
	var bg_color_callback = func(color: Color):
		if animated_style:
			animated_style.bg_color = color
	
	var bg_tween = create_tween()
	bg_tween.set_loops()
	bg_tween.tween_method(bg_color_callback, base_bg, bright_bg, 1.5).set_ease(Tween.EASE_IN_OUT)
	bg_tween.tween_method(bg_color_callback, bright_bg, base_bg, 1.5).set_ease(Tween.EASE_IN_OUT)

func _on_ability_selected(ability_id: String) -> void:
	"""Called when player selects an ability."""
	
	# Emit signal
	ability_chosen.emit(ability_id)
	
	# Hide and unpause
	hide()
	get_tree().paused = false
