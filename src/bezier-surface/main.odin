package bezier_surface

import rl "vendor:raylib"

DEBUG                  :: false

// Convenience types
v2                     :: rl.Vector2
v3                     :: rl.Vector3

// The (initial) screen size
INITIAL_SCREEN_WIDTH   :: 1280
INITIAL_SCREEN_HEIGHT  :: 720
TARGET_FPS             :: 60

// Display settings
BACKGROUND_COLOR       :: rl.RAYWHITE

CONTROL_POINT_RADIUS   :: 0.1
CONTROL_POINT_COLOR    :: rl.RED
SURFACE_COLOR1         :: rl.BLACK
SURFACE_COLOR2         :: rl.BLUE
SURFACE_PREVIEW_COLOR1 :: rl.RED
SURFACE_PREVIEW_COLOR2 :: rl.MAGENTA

SURFACE_DEBUG_RADIUS   :: 2
SURFACE_DEBUG_COLOR    :: rl.YELLOW

GameState :: struct {
	editor: Editor,
	surface: BezierSurface3D,
}

GameInput :: struct {
	direction: v3,

	anyKeyPressed: bool,
	escapeKeyPressed: bool,

	toggleEditor: bool,
	togglePause: bool,

	// Editor related
	mainActionPressed: bool,
	mainActionKeyDown: bool,
	secondaryActionPressed: bool,
	secondaryActionKeyDown: bool,
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
	zOffset := v3{ 0, 0, -1 }
	pt0 := v3{ 0.238335609, 1.63186836, 4.631317 }
	pt1 := v3{ 0.6189909, 4.3153944, 2.6025438 }
	pt2 := v3{ 4.128795, 5.173849, 2.3728337 }
	pt3 := v3{ 5.170785, 2.3052678, 2.3020606 }
	
	return GameState{
		editor = {
			camera = {
				position = v3{ 10.0, 10.0, 10.0 },
				target = v3{ 0.0, 0.0, 0.0 },
				up = v3{ 0.0, 1.0, 0.0 },
				fovy = 45.0,
				projection = .PERSPECTIVE,
			},
		},
		surface = createBezierSurface3D({
			// 1st curve
			pt0,
			pt1,
			pt2,
			pt3,
			// 2nd curve
			pt0 + zOffset,
			pt1 + zOffset,
			pt2 + zOffset,
			pt3 + zOffset,
			// 3rd curve
			pt0 + 2*zOffset,
			pt1 + 2*zOffset,
			pt2 + 2*zOffset,
			pt3 + 2*zOffset,
			// 4th curve
			pt0 + 3*zOffset,
			pt1 + 3*zOffset,
			pt2 + 3*zOffset,
			pt3 + 3*zOffset,
		}),
	}
}

update :: proc(state: ^GameState, input: GameInput) {
	editorUpdate(state, input)
}

draw :: proc(state: ^GameState) {
	editor := state.editor

	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	rl.BeginMode3D(editor.camera)

	// Draw the current surface
	drawSurface(state.surface, SURFACE_COLOR1, SURFACE_COLOR2, CONTROL_POINT_COLOR)

	// Draw the preview curve (if draggin a control point)
	if editor.isEditing {
		rl.DrawSphere(editor.draggedPoint^, 0.1, CONTROL_POINT_COLOR)
		drawSurface(editor.previewSurface, SURFACE_PREVIEW_COLOR1, SURFACE_PREVIEW_COLOR2, nil)
	}

	rl.DrawGrid(10, 1.0)

	rl.EndMode3D()
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
	if rl.IsMouseButtonPressed(.RIGHT) {
		input.secondaryActionPressed = true
	}
	if rl.IsMouseButtonDown(.RIGHT) {
		input.secondaryActionKeyDown = true
	}
	if rl.IsKeyDown(.LEFT_CONTROL) && pressedKey == .S {
		input.saveActionPressed = true
	}
	if rl.IsKeyDown(.LEFT_CONTROL) && pressedKey == .L {
		input.loadActionPressed = true
	}

	return input
}