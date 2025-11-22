extends CanvasLayer

## Manages HUD elements including cooldown icons and power-up display

const PowerupIcon = preload("res://Scenes/PowerupIcon.tscn")

@onready var attack_icon: Control = $HUD/CooldownIcons/AttackIcon
@onready var skill_icon: Control = $HUD/CooldownIcons/SkillIcon
@onready var permanent_powerup_container: HBoxContainer = $HUD/PermanentPowerups

# Track active power-up icons
var active_powerups: Dictionary = {}  # {powerup_type: PowerupIcon instance}
var player_powerup_container: HBoxContainer = null  # Reference to player's powerup display (temporary buffs)

func _ready() -> void:
	# Setup keybind labels
	attack_icon.set_keybind("LMB")
	skill_icon.set_keybind("RMB")
	
	# Setup placeholder visuals (user can replace with real textures)
	_setup_placeholder_icons()

func _setup_placeholder_icons() -> void:
	"""Setup placeholder icons until user adds real textures."""
	# Create attack icon placeholder (fist)
	var attack_bg = attack_icon.get_node("Background")
	attack_bg.color = Color(0.8, 0.3, 0.2, 1.0)  # Red-orange for melee
	
	# Create skill icon placeholder (magic)
	var skill_bg = skill_icon.get_node("Background")
	skill_bg.color = Color(0.3, 0.5, 0.9, 1.0)  # Blue for magic
	
	# Add placeholder symbols using labels
	var attack_symbol = Label.new()
	attack_symbol.text = "✊"  # Fist emoji
	attack_symbol.add_theme_font_size_override("font_size", 32)
	attack_symbol.position = Vector2(16, 8)
	attack_icon.add_child(attack_symbol)
	
	var skill_symbol = Label.new()
	skill_symbol.text = "⚡"  # Lightning emoji
	skill_symbol.add_theme_font_size_override("font_size", 32)
	skill_symbol.position = Vector2(16, 8)
	skill_icon.add_child(skill_symbol)

func setup_player_connections(player: Node) -> void:
	"""Connect to player's cooldown and power-up signals."""
	if player.has_signal("attack_cooldown_started"):
		player.attack_cooldown_started.connect(_on_attack_cooldown_started)
	if player.has_signal("skill_cooldown_started"):
		player.skill_cooldown_started.connect(_on_skill_cooldown_started)
	if player.has_signal("dash_cooldown_started"):
		player.dash_cooldown_started.connect(_on_dash_cooldown_started)
	if player.has_signal("no_cooldown_activated"):
		player.no_cooldown_activated.connect(_on_no_cooldown_activated)
	if player.has_signal("powerup_collected"):
		player.powerup_collected.connect(_on_powerup_collected)
	
	# Get reference to player's powerup display container
	if player.has_node("PowerupDisplay"):
		player_powerup_container = player.get_node("PowerupDisplay")

func _on_attack_cooldown_started(duration: float) -> void:
	attack_icon.start_cooldown(duration)

func _on_skill_cooldown_started(duration: float) -> void:
	skill_icon.start_cooldown(duration)

func _on_dash_cooldown_started(duration: float) -> void:
	# Route dash cooldown to the permanent relic icon (if it exists)
	if "dash" in active_powerups:
		active_powerups["dash"].start_cooldown(duration)

func _on_no_cooldown_activated() -> void:
	"""Force end all cooldown animations when No Cooldown buff is active."""
	attack_icon.force_end_cooldown()
	skill_icon.force_end_cooldown()
	
	# Also clear cooldowns on relic icons that have cooldowns
	if "dash" in active_powerups:
		active_powerups["dash"].force_end_cooldown()
	
	print("UI: Cooldown animations cleared!")

func _on_powerup_collected(powerup_type: String, is_temporary: bool, duration: float, extra_data: Dictionary) -> void:
	"""Display a collected power-up in the UI."""
	print("UI: Power-up collected - ", powerup_type, " (temporary: ", is_temporary, ")")
	
	# Choose the right container based on whether it's temporary or permanent
	var target_container: HBoxContainer
	if is_temporary:
		target_container = player_powerup_container
		if not target_container:
			push_warning("No player powerup container found!")
			return
	else:
		target_container = permanent_powerup_container
		if not target_container:
			push_warning("No permanent powerup container found!")
			return
	
	# Check if this power-up type already exists
	if powerup_type in active_powerups:
		var existing_icon = active_powerups[powerup_type]
		
		# Special handling for damage_multiplier - permanent, stack multiplicatively
		if powerup_type == "damage_multiplier" and not is_temporary:
			var is_stack = extra_data.get("is_stack", false)
			if is_stack:
				# Update existing icon with new combined multiplier
				existing_icon.update_stack(extra_data)
				print("UI: Updated damage multiplier icon with stacked value: %.1fx" % extra_data.get("multiplier", 1.0))
				return
			else:
				# First multiplier, but icon already exists (shouldn't happen, but handle it)
				existing_icon.queue_free()
				active_powerups.erase(powerup_type)
		# Special handling for no_cooldown - stack by adding duration
		elif powerup_type == "no_cooldown" and is_temporary:
			var is_stack = extra_data.get("is_stack", false)
			print("UI: no_cooldown collected, is_stack=%s, existing icon found, duration=%.1f" % [is_stack, duration])
			# If icon exists and we have a duration, always update it (stacking or refreshing)
			if is_stack or duration > 0:
				# Update existing icon with new total duration
				existing_icon.update_timer(duration)
				print("UI: Updated no cooldown icon with duration: %.1f seconds" % duration)
				return
			else:
				# Edge case: icon exists but something went wrong - refresh it
				print("UI: no_cooldown icon exists but duration invalid - refreshing")
				existing_icon.queue_free()
				active_powerups.erase(powerup_type)
		# Special handling for movement_speed - permanent, uses higher multiplier
		elif powerup_type == "movement_speed" and not is_temporary:
			var is_stack = extra_data.get("is_stack", false)
			if is_stack:
				# Update existing icon with new multiplier
				existing_icon.update_stack(extra_data)
				print("UI: Updated movement speed icon with stacked value: %.1fx speed" % extra_data.get("multiplier", 1.0))
				return
			else:
				# First movement_speed, but icon already exists (shouldn't happen, but handle it)
				existing_icon.queue_free()
				active_powerups.erase(powerup_type)
		# For other temporary power-ups, refresh the icon
		elif is_temporary:
			existing_icon.queue_free()
			active_powerups.erase(powerup_type)
		# For permanent power-ups, just keep the existing icon
		else:
			print("Permanent powerup already exists, keeping existing icon")
			return
	
	# Create new power-up icon in the appropriate container
	var powerup_icon = PowerupIcon.instantiate()
	target_container.add_child(powerup_icon)
	powerup_icon.setup(powerup_type, is_temporary, duration, extra_data)
	
	# Track it
	active_powerups[powerup_type] = powerup_icon
	
	# Connect to removal signal for temporary power-ups
	if is_temporary:
		powerup_icon.tree_exited.connect(_on_powerup_expired.bind(powerup_type))

func _on_powerup_expired(powerup_type: String) -> void:
	"""Called when a temporary power-up expires."""
	if powerup_type in active_powerups:
		active_powerups.erase(powerup_type)
	print("UI: Power-up expired - ", powerup_type)

