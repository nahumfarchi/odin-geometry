package bezier_curve

import "core:fmt"
import rl "vendor:raylib"

Editor :: struct {
	isDraggin: bool,
	draggedPoint: ^v2,
	mousePosition: v2,

	previewCurve: BezierCurve,
}

editorUpdate :: proc(state: ^GameState, input: GameInput) {
    editor := &state.editor
	//mousePosition := windowToCanvasPosition(rl.GetMousePosition())
    mousePosition := rl.GetMousePosition()
	editor.mousePosition = mousePosition
    currentCurve := &state.curve
	if input.mainActionPressed {
		controlPoints := currentCurve.controlPoints
		for controlPoint, index in controlPoints {
			if rl.CheckCollisionPointCircle(mousePosition, controlPoint, CONTROL_POINT_RADIUS) {
				// Start dragging
				fmt.printfln("Started dragging control point: %v", controlPoint)
				editor.isDraggin = true

				// Create the preview curve and hold a reference to the control point that is
				// being dragged
				editor.previewCurve = createBezierCurve(currentCurve.controlPoints)
				editor.draggedPoint = &editor.previewCurve.controlPoints[index]
				break
			}
		}
	} else if editor.isDraggin {
		// Update the preview curve
		editor.draggedPoint^ = mousePosition
		editor.previewCurve = createBezierCurve(editor.previewCurve.controlPoints)
		
		if !input.mainActionKeyDown {
			// Stop draggin
			fmt.printfln("Stopped dragging control point: %v", editor.draggedPoint^)
			editor.isDraggin = false
			currentCurve^ = editor.previewCurve
		}
	}
}
