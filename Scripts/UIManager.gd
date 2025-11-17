extends CanvasLayer

## Manages HUD elements including cooldown icons

@onready var attack_icon: Control = $HUD/CooldownIcons/AttackIcon
@onready var skill_icon: Control = $HUD/CooldownIcons/SkillIcon

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
	"""Connect to player's cooldown signals."""
	if player.has_signal("attack_cooldown_started"):
		player.attack_cooldown_started.connect(_on_attack_cooldown_started)
	if player.has_signal("skill_cooldown_started"):
		player.skill_cooldown_started.connect(_on_skill_cooldown_started)
	if player.has_signal("no_cooldown_activated"):
		player.no_cooldown_activated.connect(_on_no_cooldown_activated)

func _on_attack_cooldown_started(duration: float) -> void:
	attack_icon.start_cooldown(duration)

func _on_skill_cooldown_started(duration: float) -> void:
	skill_icon.start_cooldown(duration)

func _on_no_cooldown_activated() -> void:
	"""Force end all cooldown animations when No Cooldown buff is active."""
	attack_icon.force_end_cooldown()
	skill_icon.force_end_cooldown()
	print("UI: Cooldown animations cleared!")

