package edge_flip

import "core:fmt"
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

GameState :: struct {
	editor: Editor,
	model: rl.Model,
	mesh: ^dgl.Mesh,
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
	//mesh := createTetrahedron()
	mesh := dgl.createCube(3)
	rlMesh := dgl.toRaylibMesh(mesh)
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
	}
}

iter := 0
update :: proc(state: ^GameState, input: GameInput) {
	editorUpdate(state, input)

	if iter % 100 == 0{
		mesh := state.mesh

		fmt.printfln("Flipping edges...")
		e01 := &mesh.edges[dgl.getEdgeKey(mesh, 1, 3)]
		e52 := &mesh.edges[dgl.getEdgeKey(mesh, 5, 2)]
		e57 := &mesh.edges[dgl.getEdgeKey(mesh, 5, 7)]
		e43 := &mesh.edges[dgl.getEdgeKey(mesh, 4, 3)]
		e27 := &mesh.edges[dgl.getEdgeKey(mesh, 2, 7)]
		e14 := &mesh.edges[dgl.getEdgeKey(mesh, 1, 4)]
		fmt.printfln("=== MESH BEFORE ===")
		dgl.printMesh(mesh)

		dgl.flipEdge(mesh, e01)
		dgl.flipEdge(mesh, e52)
		dgl.flipEdge(mesh, e57)
		dgl.flipEdge(mesh, e43)
		dgl.flipEdge(mesh, e27)
		dgl.flipEdge(mesh, e14)

		fmt.printfln("=== MESH AFTER ===")
		dgl.printMesh(mesh)

		rlMesh := dgl.toRaylibMesh(mesh)
		state.model = rl.LoadModelFromMesh(rlMesh)
	}

	iter += 1
}

draw :: proc(state: ^GameState) {
	editor := state.editor

	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)

	rl.BeginMode3D(editor.camera)

	//model := state.model
	//position := v3{ 0, 1, 0 }
	//rl.DrawModelEx(model, position, 1.0, 1.0, scale=2.0, tint=rl.DARKBLUE)
	//rl.DrawModelWiresEx(model, position,1.0, 1.0, scale=2.0, tint=SURFACE_COLOR2)

	for _, edge in state.mesh.edges {
		vi := edge.v0
		vj := edge.v1
		if vi.index < vj.index {
			rl.DrawLine3D(edge.v0.position, edge.v1.position, SURFACE_COLOR2)
		}
	}

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