extends CanvasLayer

## Level up screen for choosing skills

signal skill_chosen(skill_name: String)

func _ready() -> void:
	hide()

func show_level_up() -> void:
	# Show the level up screen and pause the game
	show()
	get_tree().paused = true
	print("Level up screen shown - game paused")

func _on_skill_selected(skill_name: String) -> void:
	# Called when player selects a skill
	print("Player selected skill: ", skill_name)
	
	# Emit signal
	skill_chosen.emit(skill_name)
	
	# Hide and unpause
	hide()
	get_tree().paused = false
	print("Level up screen hidden - game unpaused")

