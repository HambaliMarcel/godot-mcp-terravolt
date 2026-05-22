extends CharacterBody2D

## Terravolt playable demo — 2D top-down character.
##
## Move with arrow keys (ui_left / ui_right / ui_up / ui_down).
## Press ui_accept (Enter/Space) to cycle the player's color.

@export var speed: float = 220.0

@onready var _sprite: ColorRect = $Body
@onready var _hint: Label = $Hint

const _PALETTE: Array[Color] = [
	Color(0.36, 0.78, 0.98),
	Color(0.98, 0.65, 0.32),
	Color(0.55, 0.92, 0.58),
	Color(0.92, 0.45, 0.78),
]

var _color_idx: int = 0


func _ready() -> void:
	_apply_color()
	if _hint != null:
		_hint.text = "Arrow keys / WASD = move    Enter = swap color"


func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	velocity = dir.normalized() * speed if dir.length_squared() > 0.01 else Vector2.ZERO
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_color_idx = (_color_idx + 1) % _PALETTE.size()
		_apply_color()


func _apply_color() -> void:
	if _sprite != null:
		_sprite.color = _PALETTE[_color_idx]
