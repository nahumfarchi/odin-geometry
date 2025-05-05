package bezier_surface

import rl "vendor:raylib"

// A (3D) bezier surface has 16 control points. It can be thought of as 4 Bezier curves, each constructed
// from 4 control points and interpolated using the Bernstein polynomial basis functions:
//
//  gamma_i(t) = (
//      p0.x * B0(t) + p1.x * B1(t) + p2.x * B2(t) + p3.x * B3(t)
//      p0.y * B0(t) + p1.y * B1(t) + p2.y * B2(t) + p3.y * B3(t)
//		p0.z * B0(t) + p1.z * B1(t) + p2.z * B2(t) + p3.z * B3(t)
//  )
//
// The Bezier basis matrix, B, is given by:
// 	 B = (
//  	1 -3  3 -1
//	  	0  3 -6  3
//	  	0  0  3 -3
//		0  0  0  1
//   )
//
// And the curve in matrix form is:
//		gamma_i(t) = G * B * T
//
// Where G is a matrix with the control points arranged in its columns:
//		p0.x p1.x p2.x p3.x
//		p0.y p1.y p2.y p3.y
//  	p0.z p1.z p2.z p3.z
//
// And T is the monomial basis:
//		1
//		t
//		t^2
//		t^3
//
// The surface is then created by taking a point on each curve for each sampled ts:
//		gamma_0(ts)
//		gamma_1(ts)
//		gamma_2(ts)
//		gamma_3(ts)
//
// These 4 points then serve as the control points for a new curve. Taken all together, we get a surface along
// the 4 "control" curves.

N_SAMPLES :: 100

BezierCurve3D :: struct {
	controlPoints: [4]v3,
	geometryMatrix: matrix[3, 4]f32,
	samplePoints: [N_SAMPLES]v3,
}

BezierSurface3D :: struct {
	controlCurves: [4]BezierCurve3D,
}

BEZIER_BASIS_MATRIX :: matrix[4, 4]f32{
	1, -3,  3, -1,
	0,  3, -6,  3,
	0,  0,  3, -3,
	0,  0,  0,  1,
}

createBezierSurface3D :: proc(controlPoints: [16]v3) -> BezierSurface3D {
	surface: BezierSurface3D
	for i in 0..<4 {
		surface.controlCurves[i] = createBezierCurve3D({ 
			controlPoints[i*4],
			controlPoints[i*4+1],
			controlPoints[i*4+2],
			controlPoints[i*4+3],
		})
	}

	return surface
}

regenerateBezierSurface3D :: proc(surface: ^BezierSurface3D) {
	for i in 0..<len(surface.controlCurves) {
		surface.controlCurves[i] = createBezierCurve3D(surface.controlCurves[i].controlPoints)
	}
}

/* Create a Bezier surface from the given control points (1 section). For simplicitly, the number of samples is hard-coded. */
createBezierCurve3D :: proc(controlPoints: [4]v3) -> BezierCurve3D {
	surface: BezierCurve3D

	surface.controlPoints = controlPoints
	p0 := controlPoints[0]
	p1 := controlPoints[1]
	p2 := controlPoints[2]
	p3 := controlPoints[3]
	geometryMatrix := matrix[3, 4]f32{
		p0.x, p1.x, p2.x, p3.x,
		p0.y, p1.y, p2.y, p3.y,
		p0.z, p1.z, p2.z, p3.z,
	}
	surface.geometryMatrix = geometryMatrix

	stepSize := f32(1)/f32(N_SAMPLES-1)
	t := f32(0)
	for i in 0..<N_SAMPLES {
		monomialBasis: matrix[4, 1]f32 = {
			1,
			t,
			t*t,
			t*t*t,
		}
		gamma_t := geometryMatrix * BEZIER_BASIS_MATRIX * monomialBasis
		surface.samplePoints[i] = {
			gamma_t[0, 0],
			gamma_t[1, 0],
			gamma_t[2, 0],
		}

		t += stepSize
	}

	return surface
}

drawSurface :: proc(surface: BezierSurface3D, lineColor1: rl.Color, lineColor2: rl.Color, pointColor: Maybe(rl.Color)) {
	for curve in surface.controlCurves {
		drawCurve3D(curve, lineColor1, pointColor)
	}

	// Iterate along the 4 curves
	nSamples := len(surface.controlCurves[0].samplePoints)
	for i in 0..<nSamples {
		pt0 := surface.controlCurves[0].samplePoints[i]
		pt1 := surface.controlCurves[1].samplePoints[i]
		pt2 := surface.controlCurves[2].samplePoints[i]
		pt3 := surface.controlCurves[3].samplePoints[i]
		curve := createBezierCurve3D({ pt0, pt1, pt2, pt3 })
		drawCurve3D(curve, lineColor2, nil)
	}
}

drawCurve3D :: proc(curve: BezierCurve3D, lineColor: rl.Color, pointColor: Maybe(rl.Color)) {
	if pointColorVal, ok := pointColor.(rl.Color); ok {
		for pt in curve.controlPoints {
			rl.DrawSphere(pt, 0.1, pointColorVal)
		}
	}
	
	// Draw the curve lines
	// TODO: do this more efficiently with a single call
	// e.g. similar to the 2d case: rl.DrawLineStrip(raw_data(curve.samplePoints[:]), len(curve.samplePoints), SURFACE_COLOR)
	for index in 0..<len(curve.samplePoints)-1 {
		pt0 := curve.samplePoints[index]
		pt1 := curve.samplePoints[index+1]
		// TODO: generate these points once instead of on every draw call
		rl.DrawLine3D(pt0, pt1, lineColor)
	}
}