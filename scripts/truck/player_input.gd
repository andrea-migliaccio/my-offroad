class_name PlayerInput
extends RefCounted
## Keyboard / joypad controller. `prefix` allows extra local players later
## (e.g. "p2_" actions).

var prefix := ""


func update(truck: Truck, _delta: float) -> void:
	truck.in_steer = Input.get_action_strength(prefix + "steer_right") - Input.get_action_strength(prefix + "steer_left")
	if Input.is_action_pressed(prefix + "accelerate"):
		truck.in_throttle = 1.0
	elif Input.is_action_pressed(prefix + "reverse"):
		truck.in_throttle = -1.0
	else:
		truck.in_throttle = 0.0
	truck.in_nitro = Input.is_action_pressed(prefix + "nitro")
