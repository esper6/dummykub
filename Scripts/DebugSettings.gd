extends Node

## Debug settings autoload for testing and debugging features

var god_mode: bool = false:
	set(value):
		god_mode = value
		if god_mode:
			print("🔥 GOD MODE ENABLED - 100x damage!")
		else:
			print("God mode disabled")

