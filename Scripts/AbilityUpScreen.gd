extends CanvasLayer

## Ability selection screen for level 3+ rewards
## Displays 3 random abilities for the player to choose from

signal ability_chosen(ability_name: String)

@onready var ability_container = $Panel/VBoxContainer/AbilityContainer

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

func show_ability_selection() -> void:
	"""Show the ability selection screen with 3 random abilities."""
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
	print("Ability selection screen shown - game paused")

func _create_ability_button(ability: Dictionary) -> Control:
	"""Create a styled button container for an ability choice."""
	# Create a VBoxContainer to hold button and description
	var container = VBoxContainer.new()
	
	# Create the main button
	var button = Button.new()
	button.custom_minimum_size = Vector2(250, 140)
	
	# Set button text with icon and name
	button.text = ability.icon + "\n" + ability.name.to_upper()
	
	# Style the button
	var style_normal = StyleBoxFlat.new()
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
	
	# Font color and size
	button.add_theme_color_override("font_color", ability.color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 28)
	
	# Create description label
	var description = Label.new()
	description.custom_minimum_size = Vector2(250, 0)
	description.text = ability.description
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	description.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description.add_theme_constant_override("outline_size", 1)
	
	# Connect button press
	button.pressed.connect(_on_ability_selected.bind(ability.id))
	
	# Add to container
	container.add_child(button)
	container.add_child(description)
	
	return container

func _on_ability_selected(ability_id: String) -> void:
	"""Called when player selects an ability."""
	print("Player selected ability: ", ability_id)
	
	# Emit signal
	ability_chosen.emit(ability_id)
	
	# Hide and unpause
	hide()
	get_tree().paused = false
	print("Ability selection screen hidden - game unpaused")
