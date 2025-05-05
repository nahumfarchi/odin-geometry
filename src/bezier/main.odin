package bezier_curve

import rl "vendor:raylib"

DEBUG                 :: false

// Convenience types
v2                    :: rl.Vector2

// The (initial) screen size
INITIAL_SCREEN_WIDTH  :: 1280
INITIAL_SCREEN_HEIGHT :: 720
TARGET_FPS            :: 60

// Display settings
BACKGROUND_COLOR      :: rl.RAYWHITE

CONTROL_POINT_RADIUS  :: 5
CONTROL_POINT_COLOR   :: rl.RED
CURVE_COLOR           :: rl.BLACK
CURVE_PREVIEW_COLOR   :: rl.RED

CURVE_DEBUG_RADIUS    :: 2
CURVE_DEBUG_COLOR     :: rl.YELLOW

GameState :: struct {
	editor: Editor,
	curve: BezierCurve,
}

GameInput :: struct {
	direction: v2,

	anyKeyPressed: bool,
	escapeKeyPressed: bool,

	toggleEditor: bool,
	togglePause: bool,

	// Editor related
	mainActionPressed: bool,
	mainActionKeyDown: bool,
	saveActionPressed: bool,
	loadActionPressed: bool,
}

main :: proc() {
    initWindow()
	state := initGame()

	for !rl.WindowShouldClose() {
		input := getInput()
		update(&state, input)
		draw(&state)
	}

	rl.CloseWindow()
}

initWindow :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags({.MSAA_4X_HINT}))
	rl.InitWindow(INITIAL_SCREEN_WIDTH, INITIAL_SCREEN_HEIGHT, "Splines")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(TARGET_FPS)
	rl.SetExitKey(nil)
}

initGame :: proc() -> GameState {
	return GameState{
		curve = createBezierCurve({
			{ 269, 412 },
			{ 599, 73 },
			{ 630, 649 },
			{ 983, 322 },
		}),
	}
}

update :: proc(state: ^GameState, input: GameInput) {
	editorUpdate(state, input)
}

draw :: proc(state: ^GameState) {
	rl.BeginDrawing()
    rl.ClearBackground(BACKGROUND_COLOR)

    rl.DrawText("Move control points with the mouse", 15, 20, 20, rl.GRAY)

	// Draw control points
	curve := state.curve
	for pt in curve.controlPoints {
		rl.DrawCircleV(pt, CONTROL_POINT_RADIUS, CONTROL_POINT_COLOR)
	}

	// Draw sample points (debug)
	when DEBUG {
		for pt0 in curve.samplePoints {
			rl.DrawCircleLinesV(pt0, CURVE_DEBUG_RADIUS, CURVE_DEBUG_COLOR)
		}
	}

	// Draw line segments
	rl.DrawLineStrip(raw_data(curve.samplePoints[:]), len(curve.samplePoints), CURVE_COLOR)

	// Draw the preview curve (if draggin a control point)
	editor := state.editor
	if editor.isDraggin {
		rl.DrawCircleV(editor.mousePosition, CONTROL_POINT_RADIUS, CONTROL_POINT_COLOR)
		previewCurve := editor.previewCurve
		rl.DrawLineStrip(raw_data(previewCurve.samplePoints[:]), len(previewCurve.samplePoints), CURVE_PREVIEW_COLOR)
	}

	rl.EndDrawing()
}

getInput :: proc() -> GameInput {
	input: GameInput
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.direction.x = -1
		input.direction.y = 0
	} else if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.direction.x = 1
		input.direction.y = 0
	} else if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.direction.x = 0
		input.direction.y = 1
	} else if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.direction.x = 0
		input.direction.y = -1
	}

	pressedKey := rl.GetKeyPressed()
	if pressedKey != .KEY_NULL {
		input.anyKeyPressed = true
	}
	if pressedKey == .ESCAPE {
		input.escapeKeyPressed = true
	}
	if pressedKey == .F2 {
		input.toggleEditor = true
	}
	if pressedKey == .P {
		input.togglePause = true
	}
	if rl.IsMouseButtonPressed(.LEFT) || pressedKey == .SPACE || pressedKey == .LEFT_SHIFT {
		input.mainActionPressed = true
	}
	if rl.IsMouseButtonDown(.LEFT) || rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.LEFT_SHIFT) {
		input.mainActionKeyDown = true
	}
	if rl.IsKeyDown(.LEFT_CONTROL) && pressedKey == .S {
		input.saveActionPressed = true
	}
	if rl.IsKeyDown(.LEFT_CONTROL) && pressedKey == .L {
		input.loadActionPressed = true
	}

	return input
}