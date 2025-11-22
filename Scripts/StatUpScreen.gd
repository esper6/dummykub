extends CanvasLayer

## Stat allocation screen shown at every level up
## Shows 3 random stats that get +1 automatically (with animation)
## Player can allocate 2 points manually

signal stats_confirmed(auto_stats: Array, manual_allocations: Dictionary)

@onready var stat_container: HBoxContainer = $Panel/VBoxContainer/StatContainer
@onready var confirm_button: Button = $Panel/VBoxContainer/ConfirmButton
@onready var points_label: Label = $Panel/VBoxContainer/PointsLabel
@onready var animation_container: Control = $Panel/VBoxContainer/AnimationContainer

# Stat definitions (11 stats)
var stats: Array[Dictionary] = [
	{
		"id": "physical_damage",
		"name": "Physical\nDamage",
		"icon": "⚔️",
		"color": Color(1.0, 0.5, 0.2),
		"description": "+10% melee damage per point"
	},
	{
		"id": "skill_damage",
		"name": "Skill\nDamage",
		"icon": "✨",
		"color": Color(0.6, 0.9, 1.0),
		"description": "+10% skill damage per point"
	},
	{
		"id": "speed",
		"name": "Speed",
		"icon": "💨",
		"color": Color(0.4, 1.0, 0.6),
		"description": "+5% movement speed per point"
	},
	{
		"id": "companion",
		"name": "Companion",
		"icon": "🐾",
		"color": Color(1.0, 0.8, 0.4),
		"description": "Unlock familiars (to implement)"
	},
	{
		"id": "crit_chance",
		"name": "Crit\nChance",
		"icon": "💥",
		"color": Color(1.0, 0.9, 0.2),
		"description": "+2% crit chance per point"
	},
	{
		"id": "crit_damage",
		"name": "Crit\nDamage",
		"icon": "🔥",
		"color": Color(1.0, 0.3, 0.3),
		"description": "+0.2x crit multiplier per point"
	},
	{
		"id": "exp_gain",
		"name": "EXP\nGain",
		"icon": "⭐",
		"color": Color(0.8, 0.6, 1.0),
		"description": "+10% EXP per point"
	},
	{
		"id": "cooldown_reduction",
		"name": "CD\nReduction",
		"icon": "⚡",
		"color": Color(0.3, 0.8, 1.0),
		"description": "+2% cooldown reduction per point"
	},
	{
		"id": "attack_range",
		"name": "Attack\nRange",
		"icon": "🎯",
		"color": Color(0.8, 0.4, 1.0),
		"description": "+5% hitbox size per point"
	},
	{
		"id": "luck",
		"name": "Luck",
		"icon": "🍀",
		"color": Color(0.4, 1.0, 0.4),
		"description": "+5% power-up spawn chance per point"
	},
	{
		"id": "jump_height",
		"name": "Jump\nHeight",
		"icon": "⬆️",
		"color": Color(0.6, 0.8, 1.0),
		"description": "+5% jump velocity per point"
	}
]

# Animation state
var animation_active: bool = false
var animation_timer: float = 0.0
const ANIMATION_DURATION: float = 3.0
var current_highlighted_indices: Array[int] = []
var final_auto_stats: Array[int] = []  # 3 random stat indices
var flashing_active: bool = false
var flash_count: int = 0
const FLASH_COUNT_TARGET: int = 3
var last_jump_time: float = 0.0
var highlighted_tictacs: Dictionary = {}  # Track which tic-tacs are currently highlighted

# Allocation state
var points_remaining: int = 2
var manual_allocations: Dictionary = {}  # {"stat_id": amount} - only manual allocations
var auto_allocations: Dictionary = {}  # {"stat_id": amount} - auto-bestowed stats (not removable)
var stat_columns: Array[Control] = []
var player: Node = null  # Reference to player for getting current stat values

func _ready() -> void:
	hide()
	# Process mode allows this UI to work while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect confirm button
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

func _process(delta: float) -> void:
	if animation_active:
		animation_timer += delta
		_update_animation(delta)
		
		# Check for skip input (click or attack button)
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_select"):
			_skip_animation()

func show_stat_selection(player_ref: Node) -> void:
	"""Show the stat selection screen with animation."""
	player = player_ref
	
	# Reset state
	points_remaining = 2
	manual_allocations.clear()
	auto_allocations.clear()
	animation_timer = 0.0
	last_jump_time = 0.0
	animation_active = true
	flashing_active = false
	flash_count = 0
	
	# Clear previous UI
	_clear_ui()
	
	# Create stat columns
	_create_stat_columns()
	
	# Pick 3 random stats for auto-allocation
	_pick_random_stats()
	
	# Reset button state (ensure it's set to "Confirm" and connected properly)
	confirm_button.text = "Confirm"
	confirm_button.disabled = true
	points_label.text = "Points Remaining: 2"
	
	# Ensure button is connected to confirm function (disconnect GO! if it was connected)
	if confirm_button.pressed.is_connected(_on_go_pressed):
		confirm_button.pressed.disconnect(_on_go_pressed)
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Show and pause
	show()
	get_tree().paused = true
	print("Stat selection screen shown - game paused")

func _clear_ui() -> void:
	"""Clear all UI elements."""
	for child in stat_container.get_children():
		child.queue_free()
	stat_columns.clear()
	
	_clear_highlighted_tictacs()

func _create_stat_columns() -> void:
	"""Create the 11 stat columns with tic-tac indicators."""
	for i in range(stats.size()):
		var stat = stats[i]
		var column = _create_stat_column(stat, i)
		stat_container.add_child(column)
		stat_columns.append(column)

func _create_stat_column(stat: Dictionary, index: int) -> Control:
	"""Create a single stat column with tic-tac stack."""
	# Use a Control node as the base so we can position elements absolutely
	var column = Control.new()
	column.custom_minimum_size = Vector2(90, 0)  # Fixed width, height will be set by content
	
	# Stat name label (positioned at top, independent of bar)
	var name_label = Label.new()
	name_label.text = stat.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(90, 40)  # Fixed width and height
	name_label.position = Vector2(0, 0)  # Top of column
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", stat.color)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = true
	name_label.name = "NameLabel"
	column.add_child(name_label)
	
	# Icon label (positioned below name, fixed position)
	var icon_label = Label.new()
	icon_label.text = stat.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(90, 40)  # Fixed width and height
	icon_label.position = Vector2(0, 40)  # Below name label
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.name = "IconLabel"
	column.add_child(icon_label)
	
	# Tic-tac stack container (positioned at fixed offset from top, independent of name)
	var stack_container = VBoxContainer.new()
	stack_container.add_theme_constant_override("separation", 2)
	stack_container.custom_minimum_size = Vector2(40, 200)  # Fixed height for stack
	stack_container.position = Vector2(25, 80)  # Fixed position: below icon (40 + 40 = 80)
	stack_container.name = "StackContainer"
	column.add_child(stack_container)
	
	# Create tic-tac indicators (max 10 shown)
	# Add in normal order: VBoxContainer displays top-to-bottom, so index 0 = top, index 9 = bottom
	var max_indicators = 10
	var current_value = player.get_stat_value(stat.id) if player else 0
	for i in range(max_indicators):  # Count from 0 to 9 (normal order)
		var tictac = ColorRect.new()
		tictac.custom_minimum_size = Vector2(30, 15)  # Tic-tac shape (wide, short)
		# Calculate if this tic-tac should be filled (from bottom up)
		# Index 0 = top (last to fill), index 9 = bottom (first to fill)
		# To fill N from bottom, fill indices (max_indicators - N) to (max_indicators - 1)
		# So index i is filled if i >= (max_indicators - current_value)
		var filled_count_from_bottom = max_indicators - i  # How many from bottom (including this one)
		var is_filled = filled_count_from_bottom <= current_value
		tictac.color = stat.color if is_filled else Color(0.3, 0.3, 0.3, 0.5)
		tictac.name = "TicTac" + str(i)
		stack_container.add_child(tictac)
		
		# Add emoji label if this tic-tac is already filled
		if is_filled:
			_add_emoji_to_tictac(tictac, stat.icon, false)  # false = no animation for existing
	
	# Current value label (positioned below stack)
	var value_label = Label.new()
	value_label.text = str(current_value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(90, 25)  # Fixed width and height
	value_label.position = Vector2(0, 280)  # Below stack (80 + 200 = 280)
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.name = "ValueLabel"
	column.add_child(value_label)
	
	# Button container (plus and minus buttons - vertical layout, positioned below value)
	var button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 5)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.position = Vector2(25, 305)  # Below value label (280 + 25 = 305)
	button_container.custom_minimum_size = Vector2(40, 0)  # Width for buttons
	
	# Plus button
	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(40, 40)
	plus_button.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	plus_button.add_theme_font_size_override("font_size", 24)
	# Style the button green
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.6, 0.2, 0.3)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.2, 1.0, 0.2)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.corner_radius_bottom_left = 4
	plus_button.add_theme_stylebox_override("normal", style_normal)
	plus_button.name = "PlusButton"
	plus_button.pressed.connect(_on_plus_button_pressed.bind(stat.id, index))
	button_container.add_child(plus_button)
	
	# Minus button (initially hidden, shown when stat has manual allocation)
	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(40, 40)
	minus_button.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	minus_button.add_theme_font_size_override("font_size", 24)
	# Style the button red
	var style_minus = StyleBoxFlat.new()
	style_minus.bg_color = Color(0.6, 0.2, 0.2, 0.3)
	style_minus.border_width_left = 2
	style_minus.border_width_top = 2
	style_minus.border_width_right = 2
	style_minus.border_width_bottom = 2
	style_minus.border_color = Color(1.0, 0.2, 0.2)
	style_minus.corner_radius_top_left = 4
	style_minus.corner_radius_top_right = 4
	style_minus.corner_radius_bottom_right = 4
	style_minus.corner_radius_bottom_left = 4
	minus_button.add_theme_stylebox_override("normal", style_minus)
	minus_button.name = "MinusButton"
	minus_button.visible = false  # Hidden by default
	minus_button.pressed.connect(_on_minus_button_pressed.bind(stat.id, index))
	button_container.add_child(minus_button)
	
	column.add_child(button_container)
	
	# Set column height to accommodate all elements
	column.custom_minimum_size = Vector2(90, 350)  # Total height: name(40) + icon(40) + stack(200) + value(25) + buttons(45) = 350
	
	# Store stat_id in column metadata
	column.set_meta("stat_id", stat.id)
	column.set_meta("stat_index", index)
	
	return column

func _add_emoji_to_tictac(tictac: ColorRect, emoji: String, animate: bool = true) -> void:
	"""Add an emoji label to a tic-tac, with optional dramatic animation."""
	# Remove any existing emoji
	for child in tictac.get_children():
		if child.name == "EmojiLabel":
			child.queue_free()
	
	# Create emoji label
	var emoji_label = Label.new()
	emoji_label.name = "EmojiLabel"
	emoji_label.text = emoji
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Use anchors to perfectly center the emoji in the tic-tac
	# Adjust vertical offset to move emoji 3 pixels higher
	emoji_label.anchor_left = 0.0
	emoji_label.anchor_top = 0.0
	emoji_label.anchor_right = 1.0
	emoji_label.anchor_bottom = 1.0
	emoji_label.offset_left = 0
	emoji_label.offset_top = -3  # Move 3 pixels higher
	emoji_label.offset_right = 0
	emoji_label.offset_bottom = -3  # Move 3 pixels higher
	
	emoji_label.add_theme_font_size_override("font_size", 14)
	
	if animate:
		# Start hidden and scaled down for dramatic entrance
		emoji_label.modulate.a = 0.0
		emoji_label.scale = Vector2(0.0, 0.0)
	
	tictac.add_child(emoji_label)
	
	if animate:
		# Dramatic entrance animation
		var entrance_tween = create_tween()
		entrance_tween.set_parallel(true)
		entrance_tween.tween_property(emoji_label, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		entrance_tween.tween_property(emoji_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
		entrance_tween.chain().tween_property(emoji_label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN)

func _clear_highlighted_tictacs() -> void:
	"""Clear all highlighted tic-tacs."""
	for key in highlighted_tictacs:
		var tictac_data = highlighted_tictacs[key]
		if tictac_data.has("tictac") and is_instance_valid(tictac_data.tictac):
			var tictac = tictac_data.tictac
			var original_color = tictac_data.original_color
			# Restore original color (gray if empty, or stat color if already filled)
			tictac.color = original_color
			tictac.modulate = Color.WHITE
	highlighted_tictacs.clear()

func _pick_random_stats() -> void:
	"""Pick 3 random stats for auto-allocation."""
	var available_indices: Array[int] = []
	for i in range(stats.size()):
		available_indices.append(i)
	available_indices.shuffle()
	final_auto_stats = available_indices.slice(0, 3)
	print("Random stats selected: ", final_auto_stats)

func _update_animation(_delta: float) -> void:
	"""Update the animation - tic-tacs randomly light up, starting fast and slowing down."""
	if flashing_active:
		# Don't update animation during flash sequence
		return
		
	if animation_timer >= ANIMATION_DURATION:
		_on_animation_complete()
		return
	
	# Calculate animation progress (0.0 to 1.0)
	var progress = animation_timer / ANIMATION_DURATION
	
	# Calculate jump interval - starts very fast (0.02s) and slows down (0.3s) using ease-out curve
	# Use a quadratic ease-out: faster at start, slower at end
	var ease_out = 1.0 - pow(1.0 - progress, 2.0)
	var min_interval = 0.02  # Very fast at start
	var max_interval = 0.3    # Slower at end (but still faster than before)
	var current_interval = lerp(min_interval, max_interval, ease_out)
	
	# Jump to new random stats based on current interval
	if animation_timer - last_jump_time >= current_interval:
		last_jump_time = animation_timer
		
		# Clear previous highlights
		_clear_highlighted_tictacs()
		
		# Pick 3 random stats to highlight
		current_highlighted_indices.clear()
		var available: Array[int] = []
		for i in range(stats.size()):
			available.append(i)
		available.shuffle()
		current_highlighted_indices = available.slice(0, 3)
		
		# Highlight one random tic-tac from each of the 3 stats
		_highlight_random_tictacs()

func _highlight_random_tictacs() -> void:
	"""Highlight the next step up tic-tac from each of the currently selected stats."""
	_clear_highlighted_tictacs()
	
	for stat_index in current_highlighted_indices:
		if stat_index >= stat_columns.size():
			continue
		
		var column = stat_columns[stat_index]
		var stack_container = column.get_node("StackContainer")
		var stat = stats[stat_index]
		var max_indicators = stack_container.get_child_count()
		
		if max_indicators == 0:
			continue
		
		# Get current value of this stat (base value from player before this level up)
		var base_value = player.get_stat_value(stat.id) if player else 0
		
		# During roulette animation, manual_allocations should be empty,
		# but include it just in case for consistency
		var manual_allocated = manual_allocations.get(stat.id, 0)
		
		# Get current base value of this stat (from player, before any allocations in this level up)
		var current_value = player.get_stat_value(stat.id) if player else 0
		
		# Only highlight if there's room for another tic-tac
		if current_value >= max_indicators:
			continue
		
		# Calculate which tic-tac is the "next one to fill"
		# Tic-tacs are in normal order: index 0 = top, index 9 = bottom
		# If we have N filled tic-tacs, the next one to fill is at position N+1 from bottom
		# Position from bottom = max_indicators - container_index
		# So if we want position (current_value + 1) from bottom:
		#   max_indicators - container_index = current_value + 1
		#   container_index = max_indicators - current_value - 1
		var next_tictac_index = max_indicators - current_value - 1
		
		# Validate index
		if next_tictac_index < 0 or next_tictac_index >= max_indicators:
			continue
		
		# Get the tic-tac node
		var tictac = stack_container.get_child(next_tictac_index)
		
		# Verify it's actually empty using the same logic as _update_stat_column
		# In _update_stat_column: tic-tac is filled if (max_indicators - i) <= total_value
		var position_from_bottom = max_indicators - next_tictac_index
		
		# This should equal current_value + 1 (the next empty position to fill)
		# If this position is already filled, it means position_from_bottom <= current_value
		if position_from_bottom <= current_value:
			# This tic-tac should already be filled - something is wrong, skip
			continue
		
		# Double-check: verify tic-tac color indicates it's empty (gray = empty)
		# Allow for slight color variations due to previous highlights
		var gray_color = Color(0.3, 0.3, 0.3, 0.5)
		var is_visually_filled = (tictac.color != gray_color and tictac.color.a > 0.6)
		if is_visually_filled:
			# This tic-tac appears filled - skip it (shouldn't happen if calculation is correct)
			continue
		
		# Store original color before highlighting
		var original_color = tictac.color
		
		# Set it to the stat's color (what it will be when filled)
		tictac.color = stat.color
		tictac.modulate = Color.WHITE
		
		# Store reference with original color for restoration
		var key = str(stat_index) + "_" + str(next_tictac_index)
		highlighted_tictacs[key] = {
			"tictac": tictac,
			"original_color": original_color
		}

func _skip_animation() -> void:
	"""Skip the animation and immediately land on final stats."""
	if not animation_active:
		return
	
	animation_active = false
	animation_timer = ANIMATION_DURATION  # Set to completion
	_on_animation_complete()

func _on_animation_complete() -> void:
	"""Animation finished - land on final 3 stats."""
	animation_active = false
	current_highlighted_indices = final_auto_stats.duplicate()
	
	# Clear previous highlights
	_clear_highlighted_tictacs()
	
	# Highlight the bottom-most tic-tac of each final stat (the one that will be filled)
	for stat_index in final_auto_stats:
		if stat_index >= stat_columns.size():
			continue
		
		var column = stat_columns[stat_index]
		var stack_container = column.get_node("StackContainer")
		var stat = stats[stat_index]
		var current_value = player.get_stat_value(stat.id) if player else 0
		var max_indicators = stack_container.get_child_count()
		
		# Find the bottom-most tic-tac that will be filled (the new one)
		# Tic-tacs are in normal order: index 0 = top, index 9 = bottom
		# After auto-allocation, total will be current_value + 1
		# Position from bottom = max_indicators - container_index
		# We want position (current_value + 1) from bottom:
		#   max_indicators - container_index = current_value + 1
		#   container_index = max_indicators - current_value - 1
		var bottom_tictac_index = max_indicators - (current_value + 1)
		if bottom_tictac_index >= 0 and bottom_tictac_index < max_indicators:
			var tictac = stack_container.get_child(bottom_tictac_index)
			# Store original color
			var original_color = tictac.color
			
			# Set it to the stat's color (what it will be when filled)
			tictac.color = stat.color
			tictac.modulate = Color.WHITE
			
			var key = str(stat_index) + "_" + str(bottom_tictac_index)
			highlighted_tictacs[key] = {
				"tictac": tictac,
				"original_color": original_color
			}
	
	# Apply auto stats (+1 to each) - these go into auto_allocations, not manual
	for stat_index in final_auto_stats:
		var stat_id = stats[stat_index].id
		auto_allocations[stat_id] = auto_allocations.get(stat_id, 0) + 1
		_update_stat_column(stat_index)
		
		# Add dramatic emoji animation for auto-allocated stats
		var column = stat_columns[stat_index]
		var stack_container = column.get_node("StackContainer")
		var stat = stats[stat_index]
		var current_value = player.get_stat_value(stat.id) if player else 0
		var max_indicators = stack_container.get_child_count()
		var bottom_tictac_index = max_indicators - (current_value + 1)
		if bottom_tictac_index >= 0 and bottom_tictac_index < max_indicators:
			var tictac = stack_container.get_child(bottom_tictac_index)
			# Add emoji with dramatic animation (stagger slightly for visual effect)
			await get_tree().create_timer(stat_index * 0.1).timeout  # Stagger animations
			_add_emoji_to_tictac(tictac, stat.icon, true)  # true = animate dramatically
	
	# Start flash sequence
	_start_flash_sequence()

func _start_flash_sequence() -> void:
	"""Flash the yellow boxes and tic-tacs 3 times."""
	flashing_active = true
	flash_count = 0
	_perform_flash()

func _perform_flash() -> void:
	"""Perform a single flash animation."""
	if flash_count >= FLASH_COUNT_TARGET:
		# Flash sequence complete, clear highlights
		_clear_highlighted_tictacs()
		flashing_active = false
		# Enable allocation (but confirm button stays disabled until all points allocated)
		_update_points_display()
		return
	
	flash_count += 1
	
	# Flash the highlighted tic-tacs (the ones that were auto-allocated)
	for stat_index in final_auto_stats:
		if stat_index >= stat_columns.size():
			continue
		
		var column = stat_columns[stat_index]
		var stack_container = column.get_node("StackContainer")
		var stat = stats[stat_index]
		var current_value = player.get_stat_value(stat.id) if player else 0
		var manual_allocated = manual_allocations.get(stat.id, 0)
		var auto_allocated = auto_allocations.get(stat.id, 0)
		var total_value = current_value + manual_allocated + auto_allocated
		var max_indicators = stack_container.get_child_count()
		
		# Find the bottom-most filled tic-tac (the newly added one)
		var bottom_tictac_index = max_indicators - total_value
		if bottom_tictac_index >= 0 and bottom_tictac_index < max_indicators and total_value > 0:
			var tictac = stack_container.get_child(bottom_tictac_index)
			var tictac_flash = create_tween()
			tictac_flash.set_parallel(true)
			tictac_flash.tween_property(tictac, "modulate", Color.WHITE * 2.0, 0.1)
			tictac_flash.tween_property(tictac, "scale", Vector2(1.3, 1.3), 0.1)
			tictac_flash.chain().tween_property(tictac, "modulate", stat.color, 0.1)
			tictac_flash.tween_property(tictac, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Wait before next flash
	await get_tree().create_timer(0.3).timeout
	_perform_flash()

func _on_plus_button_pressed(stat_id: String, column_index: int) -> void:
	"""Called when player clicks a + button."""
	if points_remaining <= 0:
		return
	
	# Allocate a point
	points_remaining -= 1
	manual_allocations[stat_id] = manual_allocations.get(stat_id, 0) + 1
	
	# Update display
	_update_stat_column(column_index)
	_update_points_display()
	
	print("Allocated point to ", stat_id, " (", points_remaining, " remaining)")

func _on_minus_button_pressed(stat_id: String, column_index: int) -> void:
	"""Called when player clicks a - button."""
	var current_allocation = manual_allocations.get(stat_id, 0)
	if current_allocation <= 0:
		return  # Can't remove if nothing allocated
	
	# Remove a point
	points_remaining += 1
	manual_allocations[stat_id] = current_allocation - 1
	if manual_allocations[stat_id] <= 0:
		manual_allocations.erase(stat_id)
	
	# Update display
	_update_stat_column(column_index)
	_update_points_display()
	
	print("Removed point from ", stat_id, " (", points_remaining, " remaining)")

func _update_stat_column(column_index: int) -> void:
	"""Update a stat column's display."""
	if column_index >= stat_columns.size():
		return
	
	var column = stat_columns[column_index]
	var stat_id = column.get_meta("stat_id")
	var current_value = player.get_stat_value(stat_id) if player else 0
	var manual_allocated = manual_allocations.get(stat_id, 0)
	var auto_allocated = auto_allocations.get(stat_id, 0)
	var total_value = current_value + manual_allocated + auto_allocated
	
	# Update tic-tac indicators (filled from bottom to top)
	# Index 0 = top (last to fill), index 9 = bottom (first to fill)
	var stack_container = column.get_node("StackContainer")
	var max_indicators = stack_container.get_child_count()
	for i in range(max_indicators):
		var tictac = stack_container.get_child(i)
		var stat = stats[column_index]
		# Calculate how many from bottom (including this tic-tac)
		# Index 9 = 1 from bottom, index 8 = 2 from bottom, ... index 0 = 10 from bottom
		var filled_count_from_bottom = max_indicators - i
		# Fill if this position is within the total_value (from bottom)
		var is_filled = filled_count_from_bottom <= total_value
		var is_locked_in = filled_count_from_bottom <= (current_value + auto_allocated)  # Base + auto only (confirmed)
		var is_manual_unconfirmed = is_filled and not is_locked_in  # Manual allocation not yet confirmed
		
		if is_filled:
			tictac.color = stat.color
			# Only add emoji if this tic-tac is locked in (base value or auto-allocated)
			# Don't add emojis for manual allocations until confirm is pressed
			if is_locked_in:
				if not tictac.has_node("EmojiLabel"):
					_add_emoji_to_tictac(tictac, stat.icon, false)  # No animation for already locked in
			elif is_manual_unconfirmed:
				# Manual allocation - remove emoji if present (wait until confirm)
				var emoji_label = tictac.get_node_or_null("EmojiLabel")
				if emoji_label:
					emoji_label.queue_free()
		else:
			tictac.color = Color(0.3, 0.3, 0.3, 0.5)
			# Remove emoji if present
			var emoji_label = tictac.get_node_or_null("EmojiLabel")
			if emoji_label:
				emoji_label.queue_free()
	
	# Update value label
	var value_label = column.get_node("ValueLabel")
	value_label.text = str(total_value)
	
	# Update buttons
	var button_container = column.get_node("ButtonContainer")
	var plus_button = button_container.get_node("PlusButton")
	var minus_button = button_container.get_node("MinusButton")
	
	# Disable plus button if no points remaining
	plus_button.disabled = (points_remaining <= 0)
	
	# Show/hide minus button based on MANUAL allocation only (not auto-bestowed)
	minus_button.visible = (manual_allocated > 0)
	minus_button.disabled = false  # Always enabled if visible

func _update_points_display() -> void:
	"""Update the points remaining label."""
	points_label.text = "Points Remaining: " + str(points_remaining)
	
	# Update all stat columns
	for i in range(stat_columns.size()):
		_update_stat_column(i)
	
	# Enable confirm button only when all points are allocated
	confirm_button.disabled = (points_remaining > 0)

func _on_confirm_pressed() -> void:
	"""Called when player confirms their allocation."""
	if points_remaining > 0:
		# Player hasn't allocated all points - warn them or auto-allocate?
		print("Warning: ", points_remaining, " points remaining!")
		# For now, we'll allow confirmation with remaining points
	
	# Update all stat columns to ensure visual state is correct
	for i in range(stat_columns.size()):
		_update_stat_column(i)
	
	# Collect manual allocation tic-tacs BEFORE emitting signal
	# (Once signal is emitted, player stats update and they become "locked in")
	var manual_tictacs_to_animate = _collect_manual_allocation_tictacs()
	
	# Emit signal with auto stats and manual allocations immediately
	var auto_stat_ids: Array[String] = []
	for index in final_auto_stats:
		auto_stat_ids.append(stats[index].id)
	
	stats_confirmed.emit(auto_stat_ids, manual_allocations)
	
	# Start animations in background (player can cut them off with GO! button)
	# Wait a frame to ensure visual updates are complete
	await get_tree().process_frame
	_animate_collected_tictacs(manual_tictacs_to_animate)
	
	# Change button to GO! and reconnect to close function
	confirm_button.text = "GO!"
	confirm_button.disabled = false  # Re-enable as GO! button
	# Disconnect old signal and connect to close function
	if confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.disconnect(_on_confirm_pressed)
	confirm_button.pressed.connect(_on_go_pressed)
	
	print("Stats confirmed! Click GO! when ready to continue.")

func _on_go_pressed() -> void:
	"""Called when player clicks GO! to return to game."""
	# Hide and unpause
	hide()
	get_tree().paused = false
	print("Stat selection complete - game unpaused")

func _collect_manual_allocation_tictacs() -> Array:
	"""Collect manual allocation tic-tacs BEFORE signal is emitted."""
	var all_manual_tictacs: Array = []
	
	# If no manual allocations, return empty array
	if manual_allocations.is_empty():
		return all_manual_tictacs
	
	for stat_id in manual_allocations:
		var allocated_count = manual_allocations[stat_id]
		if allocated_count <= 0:
			continue
		
		# Find the stat index
		var stat_index = -1
		for i in range(stats.size()):
			if stats[i].id == stat_id:
				stat_index = i
				break
		
		if stat_index < 0 or stat_index >= stat_columns.size():
			continue
		
		var column = stat_columns[stat_index]
		var stat = stats[stat_index]
		var stack_container = column.get_node("StackContainer")
		var max_indicators = stack_container.get_child_count()
		var current_value = player.get_stat_value(stat_id) if player else 0
		var auto_allocated = auto_allocations.get(stat_id, 0)
		var total_value = current_value + allocated_count + auto_allocated
		
		# Find the tic-tacs that were manually allocated (the newly filled ones)
		# These are the tic-tacs that are filled but not yet locked in
		# Matching the logic from _update_stat_column: manual_unconfirmed = filled AND not locked_in
		var locked_in_value = current_value + auto_allocated
		
		# Iterate through tic-tacs and find manually allocated ones
		# Use the EXACT same logic as _update_stat_column
		for i in range(max_indicators):
			var tictac = stack_container.get_child(i)
			# Calculate filled_count_from_bottom exactly as in _update_stat_column
			var filled_count_from_bottom = max_indicators - i  # Index 9 = 1 from bottom, index 0 = 10 from bottom
			
			# Use EXACT same conditions as _update_stat_column
			var is_filled = filled_count_from_bottom <= total_value
			var is_locked_in = filled_count_from_bottom <= locked_in_value
			var is_manual_unconfirmed = is_filled and not is_locked_in
			
			# Also verify the tic-tac is actually filled (has stat color)
			var is_actually_filled = (tictac.color != Color(0.3, 0.3, 0.3, 0.5))
			
			if is_manual_unconfirmed and is_actually_filled:
				# This is a manual allocation tic-tac - verify it doesn't have an emoji yet
				if not tictac.has_node("EmojiLabel"):
					# Calculate delay based on which manual allocation this is (1st = 0, 2nd = 0.1, etc.)
					var manual_position = filled_count_from_bottom - locked_in_value  # 1, 2, 3...
					var delay = (manual_position - 1) * 0.1  # 0, 0.1, 0.2...
					all_manual_tictacs.append({
						"tictac": tictac,
						"emoji": stat.icon,
						"delay": delay,
						"position": filled_count_from_bottom  # For debugging/sorting
					})
	
	# Return collected tic-tacs
	return all_manual_tictacs

func _animate_collected_tictacs(all_manual_tictacs: Array) -> void:
	"""Animate emojis dramatically appearing in collected manual allocation tic-tacs."""
	# If no tic-tacs to animate, return
	if all_manual_tictacs.is_empty():
		return
	
	# Animate sequentially to ensure each completes
	# This ensures smooth playback and we know when all are done
	var animation_duration = 0.65  # 0.3s fade + 0.2s scale up + 0.15s scale down
	
	var last_delay = 0.0
	for tictac_data in all_manual_tictacs:
		var tictac = tictac_data.tictac
		var emoji = tictac_data.emoji
		var delay = tictac_data.delay
		
		# Wait for the delay since last animation (stagger)
		var delay_since_last = delay - last_delay
		if delay_since_last > 0:
			await get_tree().create_timer(delay_since_last).timeout
		
		last_delay = delay
		
		# Add emoji with dramatic animation
		_add_emoji_to_tictac(tictac, emoji, true)
		
		# Small gap between starting animations for smoother effect
		await get_tree().create_timer(0.05).timeout
	
	# Wait for the final animation to complete fully
	# Animation duration is 0.65s, add extra buffer to ensure it's fully visible
	await get_tree().create_timer(animation_duration + 0.5).timeout
