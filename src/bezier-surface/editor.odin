package bezier_surface

import "core:fmt"
import rl "vendor:raylib"

Editor :: struct {
	camera: rl.Camera,
	isPanning: bool,

	isEditing: bool,
	draggedPoint: ^v3,
	mousePosition: v2,
	controlPointRayCollision: rl.RayCollision,

	previewSurface: BezierSurface3D,
}

editorUpdate :: proc(state: ^GameState, input: GameInput) {
	editor := &state.editor
	mousePosition := rl.GetMousePosition()
	editor.mousePosition = mousePosition
	currentSurface := &state.surface
	if input.mainActionPressed {
		fmt.printfln("Main action pressed")
		ray := rl.GetScreenToWorldRay(mousePosition, editor.camera)
		for curve, curveIndex in currentSurface.controlCurves {
			controlPoints := curve.controlPoints
			for controlPoint, ptIndex in controlPoints {
				collision := rl.GetRayCollisionSphere(ray, controlPoint, CONTROL_POINT_RADIUS)
				if collision.hit {
					fmt.printfln("Started dragging control point (%v, %v): %v", curveIndex, ptIndex, controlPoint)
					editor.isEditing = true
					editor.previewSurface = currentSurface^
					// TODO: there must be a nicer way to do this...
					editor.draggedPoint = &editor.previewSurface.controlCurves[curveIndex].controlPoints[ptIndex]
					editor.controlPointRayCollision = collision
					break
				}
			}
		}
	} else if editor.isEditing {
		// Update the preview curve
		// The new position will be in the direction of the ray cast though the mouse position, keeping
		// the same distance as the original point.
		// TODO: add an option to change the distance using the mouse wheel
		ray := rl.GetScreenToWorldRay(mousePosition, editor.camera)
		distance := editor.controlPointRayCollision.distance
		newPosition := ray.position + distance * ray.direction
		editor.draggedPoint^ = newPosition
		regenerateBezierSurface3D(&editor.previewSurface)
		
		if !input.mainActionKeyDown {
			// Stop draggin
			fmt.printfln("Stopped dragging control point: %v", editor.draggedPoint^)
			editor.isEditing = false
			currentSurface^ = editor.previewSurface
		}
	}

	if input.secondaryActionPressed {
		editor.isPanning = true
	} else if editor.isPanning {
		rl.UpdateCamera(&editor.camera, .ORBITAL)
		if !input.secondaryActionKeyDown {
			editor.isPanning = false
		}
	}
}
