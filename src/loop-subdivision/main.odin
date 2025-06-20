package loop_subdivision

import dgl "../dglib"
import rl "vendor:raylib"

DEBUG                  :: false

// Convenience types
v2                     :: rl.Vector2
v3                     :: rl.Vector3
v3i                    :: [3]int

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

AUTO_PAN := false
K :: 6

GameState :: struct {
	editor: Editor,
	model: rl.Model,
	mesh: ^dgl.Mesh,
	meshes: [K]^dgl.Mesh,
	models: [K]rl.Model,
	currentMeshIndex: int,
	inc: int,
	elapsed: f32,
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

	dgl.freeMesh(state.mesh)
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
	mesh := dgl.createIcosahedron(3)
	meshes: [K]^dgl.Mesh
	models: [K]rl.Model
	for i in 0..<K {
		meshCopy := dgl.copyMesh(mesh)
		meshes[i] = meshCopy
		rlMeshCopy := dgl.toRaylibMesh(meshCopy)
		models[i] = rl.LoadModelFromMesh(rlMeshCopy)
		dgl.loopSubdivision(mesh)
	}

	rlMesh := dgl.toRaylibMesh(meshes[2])
	model := rl.LoadModelFromMesh(rlMesh)	

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
		model = model,
		mesh = mesh,
		meshes = meshes,
		models = models,
		currentMeshIndex = 0,
		inc = 1,
	}
}

iter := 0
first := true
update :: proc(state: ^GameState, input: GameInput) {
	// if input.secondaryActionKeyDown {
	// 	AUTO_PAN = true
	// }

	editorUpdate(state, input, AUTO_PAN)

	dt := 1000*rl.GetFrameTime()
	state.elapsed += dt
	if state.elapsed >= 115 {
		state.elapsed = 0
		state.currentMeshIndex = (state.currentMeshIndex+state.inc) % K

		if state.currentMeshIndex == K-1 || state.currentMeshIndex == 0 {
			state.inc *= -1
		}
	}

	iter += 1
}

draw :: proc(state: ^GameState) {
	editor := state.editor

	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	rl.BeginMode3D(editor.camera)

	position := v3{ 0, 0, 0 }
	model := state.models[state.currentMeshIndex]
	rl.DrawModelWiresEx(model, position, 1.0, 1.0, scale=2.0, tint=SURFACE_COLOR2)

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