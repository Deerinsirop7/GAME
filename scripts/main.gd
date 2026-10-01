extends Node
## Корневой узел: переключает экраны.

const SCREENS := {
	"title": preload("res://scripts/screens/title.gd"),
	"pet_select": preload("res://scripts/screens/pet_select.gd"),
	"home": preload("res://scripts/screens/home.gd"),
}

var current: Node


func _ready() -> void:
	GameState.load_settings()
	GameState.screen_requested.connect(goto)
	goto("title")


func goto(screen: String) -> void:
	if current:
		current.queue_free()
	current = SCREENS[screen].new()
	add_child(current)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		GameState.settings["fullscreen"] = not GameState.settings["fullscreen"]
		GameState.apply_display()
		GameState.save_settings()
