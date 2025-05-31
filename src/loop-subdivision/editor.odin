package loop_subdivision

// import "core:fmt"
import rl "vendor:raylib"

Editor :: struct {
	camera: rl.Camera,
	isPanning: bool,

	isEditing: bool,
	draggedPoint: ^v3,
	mousePosition: v2,
	controlPointRayCollision: rl.RayCollision,
}

editorUpdate :: proc(state: ^GameState, input: GameInput, autoPan: bool = false) {
	editor := &state.editor
	if input.secondaryActionPressed || autoPan {
		editor.isPanning = true
	}
	
	if editor.isPanning {
		rl.UpdateCamera(&editor.camera, .ORBITAL)
		if !input.secondaryActionKeyDown {
			editor.isPanning = false
		}
	}
}
