extends Control

## Intro cutscene with three animated sentences
## Each sentence enters from bottom, holds, then exits to top

@onready var sentence_label: Label = $SentenceContainer/SentenceLabel
@onready var animation_timer: Timer = $AnimationTimer
@onready var skip_label: Label = $SkipLabel

# The three intro sentences
var sentences: Array[String] = [
	"Deep in the ancient halls of the Dummykub...",
	"A young wizard seeks to prove their worth...",
	"The training dummy awaits. Time to show what you've got!"
]

var current_sentence_index: int = 0
var animation_state: String = "entering"  # "entering", "holding", "exiting"

# Animation parameters
const ENTER_DURATION: float = 0.8
const HOLD_DURATION: float = 3.0
const EXIT_DURATION: float = 0.8

var animation_time: float = 0.0
var can_skip: bool = true

func _ready() -> void:
	# Start with label off-screen at bottom
	sentence_label.position.y = get_viewport_rect().size.y
	sentence_label.text = sentences[0]
	animation_state = "entering"
	animation_time = 0.0

func _process(delta: float) -> void:
	animation_time += delta
	
	match animation_state:
		"entering":
			_animate_enter(delta)
		"holding":
			_animate_hold(delta)
		"exiting":
			_animate_exit(delta)

func _animate_enter(delta: float) -> void:
	var progress = min(animation_time / ENTER_DURATION, 1.0)
	# Smooth ease out
	progress = 1.0 - pow(1.0 - progress, 3.0)
	
	var viewport_height = get_viewport_rect().size.y
	var target_y = 0.0  # Center (handled by CenterContainer)
	var start_y = viewport_height
	
	# Move the container
	$SentenceContainer.position.y = lerp(start_y, target_y, progress)
	
	if animation_time >= ENTER_DURATION:
		animation_state = "holding"
		animation_time = 0.0

func _animate_hold(delta: float) -> void:
	if animation_time >= HOLD_DURATION:
		animation_state = "exiting"
		animation_time = 0.0

func _animate_exit(delta: float) -> void:
	var progress = min(animation_time / EXIT_DURATION, 1.0)
	# Smooth ease in
	progress = pow(progress, 3.0)
	
	var viewport_height = get_viewport_rect().size.y
	var start_y = 0.0
	var target_y = -viewport_height
	
	# Move the container
	$SentenceContainer.position.y = lerp(start_y, target_y, progress)
	
	if animation_time >= EXIT_DURATION:
		_next_sentence()

func _next_sentence() -> void:
	current_sentence_index += 1
	
	if current_sentence_index >= sentences.size():
		# All sentences done, go to main menu
		_finish_intro()
	else:
		# Start next sentence
		sentence_label.text = sentences[current_sentence_index]
		animation_state = "entering"
		animation_time = 0.0
		$SentenceContainer.position.y = get_viewport_rect().size.y

func _finish_intro() -> void:
	# Transition to main menu
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if can_skip and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		if event.is_pressed():
			_skip_intro()

func _skip_intro() -> void:
	can_skip = false
	_finish_intro()

