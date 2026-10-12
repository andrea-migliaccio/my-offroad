class_name Pickup
extends Node2D
## Money bag or nitro canister lying on the track. First truck over it wins it.

enum Kind { MONEY, NITRO }

const LIFETIME := 9.0

var kind := Kind.MONEY
var value := 10_000
var ground_h := 0.0
var _life := LIFETIME
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/money.png" if kind == Kind.MONEY else "res://assets/sprites/nitro.png")
	_sprite.position = Vector2(0, -ground_h - 5.0)
	add_child(_sprite)
	z_index = int(position.y) - 2


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	_sprite.position.y = -ground_h - 5.0 - absf(sin(_t * 5.0)) * 2.0
	visible = _life > 2.0 or int(_t * 10.0) % 2 == 0
	if _life <= 0.0:
		queue_free()


func label() -> String:
	if kind == Kind.MONEY:
		return "$%dK" % (value / 1000)
	return "+%d N" % value
