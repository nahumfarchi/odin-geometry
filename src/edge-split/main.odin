package edge_split

import "core:fmt"
import "core:math/rand"
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
first := true
update :: proc(state: ^GameState, input: GameInput) {
	if input.secondaryActionKeyDown {
		AUTO_PAN = true
	}

	editorUpdate(state, input, AUTO_PAN)

	if input.mainActionPressed {
		mesh := state.mesh
		face := rand.choice(mesh.faces[:])
		fi := face.index
		j := dgl.FaceIndex(rand.int_max(3))
		a := mesh.indices[3*fi + j]
		b := mesh.indices[3*fi + ((j + 1) % 3)]
		if edge, ok := dgl.getEdge(mesh, a, b); ok {
			fmt.printfln("Splitting [%p] edge#%v %v->%v: %v", edge, dgl.getEdgeKey(mesh, a, b), a, b, edge)
			dgl.splitEdge(mesh, edge)
		} else {
			fmt.printfln("Splitting edge %v->%v failed, could not find edge in mesh! key=%v", a, b, dgl.getEdgeKey(mesh, a, b))
		}
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

	mesh := state.mesh
	for key, _ in mesh.edges {
		edge, _ := dgl.getEdge(mesh, key)
		vi, vj := dgl.getEdgeVertices(mesh, edge)
		if vi.index < vj.index {
			rl.DrawLine3D(vi.position, vj.position, SURFACE_COLOR2)
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