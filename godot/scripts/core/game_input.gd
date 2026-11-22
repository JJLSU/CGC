class_name GameInput
extends Node
## input.js: keyboard and mouse state with the pointer captured. Keys are named by the web's KeyboardEvent.code
## ("KeyW", "ShiftLeft", "Space", "Digit1", "Tab"...), from the physical key, so the rest of the game reads as the
## web version does: down(code), hit(code) (pressed this frame), dx/dy/wheel, clicked/mouse_down, right_clicked.
## end_frame() clears the per-frame state.

var keys := {}
var pressed := {}
var dx := 0.0
var dy := 0.0
var wheel := 0.0
var clicked := false
var mouse_down := false
var right_clicked := false
var right_down := false
var locked: bool:
	get: return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
var on_lock_change: Callable

static func code_of(e: InputEventKey) -> String:
	var k := e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if k >= KEY_A and k <= KEY_Z: return "Key" + char(k)
	if k >= KEY_0 and k <= KEY_9: return "Digit" + char(k)
	if k >= KEY_F1 and k <= KEY_F12: return "F%d" % (k - KEY_F1 + 1)
	match k:
		KEY_SHIFT: return "ShiftRight" if e.location == KEY_LOCATION_RIGHT else "ShiftLeft"
		KEY_CTRL: return "ControlRight" if e.location == KEY_LOCATION_RIGHT else "ControlLeft"
		KEY_ALT: return "AltRight" if e.location == KEY_LOCATION_RIGHT else "AltLeft"
		KEY_SPACE: return "Space"
		KEY_TAB: return "Tab"
		KEY_ESCAPE: return "Escape"
		KEY_ENTER: return "Enter"
		KEY_BACKSPACE: return "Backspace"
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_MINUS: return "Minus"
		KEY_EQUAL: return "Equal"
		KEY_BRACKETLEFT: return "BracketLeft"
		KEY_BRACKETRIGHT: return "BracketRight"
		KEY_COMMA: return "Comma"
		KEY_PERIOD: return "Period"
		KEY_SLASH: return "Slash"
		KEY_SEMICOLON: return "Semicolon"
		KEY_QUOTELEFT: return "Backquote"
	return OS.get_keycode_string(k)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var c := code_of(event)
		if event.pressed:
			if not keys.has(c): pressed[c] = true
			keys[c] = true
		else: keys.erase(c)
	elif event is InputEventMouseMotion and locked:
		dx += event.relative.x; dy += event.relative.y
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = event.pressed and locked
			if event.pressed and locked: clicked = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_down = event.pressed and locked
			if event.pressed and locked: right_clicked = true
		elif event.pressed and locked and event.button_index == MOUSE_BUTTON_WHEEL_UP: wheel -= 1.0
		elif event.pressed and locked and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: wheel += 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: keys.clear(); mouse_down = false; right_down = false

func lock() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if on_lock_change.is_valid(): on_lock_change.call(true)
func unlock() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	keys.clear(); mouse_down = false; right_down = false
	if on_lock_change.is_valid(): on_lock_change.call(false)

func down(code: String) -> bool: return keys.has(code)
func hit(code: String) -> bool: return pressed.has(code)

func end_frame() -> void:
	pressed.clear()
	dx = 0.0; dy = 0.0; wheel = 0.0
	clicked = false; right_clicked = false
