extends CanvasLayer

## Relic selection screen shown at level 4
## Displays 3 random relics for permanent character upgrades

signal relic_chosen(relic_id: String)

@onready var relic_container = $Panel/VBoxContainer/RelicContainer

# Define available relics with their properties
var relics: Array[Dictionary] = [
	{
		"id": "double_jump",
		"name": "Wings of Hermes",
		"description": "Unlock Double Jump\nPress jump again while airborne to jump a second time",
		"icon": "🪽",
		"color": Color(0.6, 0.9, 1.0)
	},
	{
		"id": "dash",
		"name": "Swift Step",
		"description": "Unlock Dash\nPress Shift to dash in the direction you're facing\n1 second cooldown",
		"icon": "💨",
		"color": Color(0.4, 1.0, 0.6)
	},
	# Future relics can be added here:
	# - Extra projectile on skill cast
	# - Increased movement speed
	# - Life steal
	# - Shield/armor
	# - etc.
]

func _ready() -> void:
	hide()
	# Process mode allows this UI to work while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_relic_selection() -> void:
	"""Show the relic selection screen with 3 random relics."""
	# Clear previous buttons
	for child in relic_container.get_children():
		child.queue_free()
	
	# Create a horizontal container for the buttons
	var h_container = HBoxContainer.new()
	h_container.add_theme_constant_override("separation", 30)
	h_container.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_container.add_child(h_container)
	
	# Pick 3 random relics (or all if less than 3)
	var available_relics = relics.duplicate()
	available_relics.shuffle()
	var choices = available_relics.slice(0, 3)
	
	# Create buttons for each choice
	for relic in choices:
		var button_container = _create_relic_button(relic)
		h_container.add_child(button_container)
	
	# Show and pause
	show()
	get_tree().paused = true
	print("Relic selection screen shown - game paused")

func _create_relic_button(relic: Dictionary) -> Control:
	"""Create a styled button container for a relic choice."""
	# Create a VBoxContainer to hold button and description
	var container = VBoxContainer.new()
	
	# Create the main button
	var button = Button.new()
	button.custom_minimum_size = Vector2(250, 200)
	
	# Set button text with icon and name
	button.text = relic.icon + "\n" + relic.name.to_upper()
	
	# Style the button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = relic.color * 0.25  # Darker version
	style_normal.border_width_left = 4
	style_normal.border_width_top = 4
	style_normal.border_width_right = 4
	style_normal.border_width_bottom = 4
	style_normal.border_color = relic.color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	button.add_theme_stylebox_override("normal", style_normal)
	
	# Hover style (brighter)
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = relic.color * 0.4
	style_hover.border_width_left = 5
	style_hover.border_width_top = 5
	style_hover.border_width_right = 5
	style_hover.border_width_bottom = 5
	button.add_theme_stylebox_override("hover", style_hover)
	
	# Pressed style
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = relic.color * 0.6
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# Font color and size
	button.add_theme_color_override("font_color", relic.color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 28)
	
	# Create description label
	var description = Label.new()
	description.custom_minimum_size = Vector2(250, 0)
	description.text = relic.description
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	description.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description.add_theme_constant_override("outline_size", 1)
	
	# Connect button press
	button.pressed.connect(_on_relic_selected.bind(relic.id))
	
	# Add to container
	container.add_child(button)
	container.add_child(description)
	
	return container

func _on_relic_selected(relic_id: String) -> void:
	"""Called when player selects a relic."""
	print("Player selected relic: ", relic_id)
	
	# Emit signal
	relic_chosen.emit(relic_id)
	
	# Hide and unpause
	hide()
	get_tree().paused = false
	print("Relic selection screen hidden - game unpaused")

