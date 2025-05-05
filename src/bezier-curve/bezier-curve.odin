package bezier_curve

// A (2D) bezier curve has 4 control points. 
// These act as the coeffs to the Bezier basis polynomial functions:
//
//  gamma(t) = (
//      p0.x * B0(t) + p1.x * B1(t) + p2.x * B2(t) + p3.x * B3(t)
//      p0.y * B0(t) + p1.y * B1(t) + p2.y * B2(t) + p3.y * B3(t)
//  )
//
// The Bezier basis matrix, B, is given by:
//  B = (
//    1 -3  3 -1
//	  0  3 -6  3
//	  0  0  3 -3
//	  0  0  0  1
//  )
//
// And the curve in matrix form is:
//	gamma(t) = G * B * T
//
// Where G is a matrix with the control points arranged in its columns:
//	p0.x p1.x p2.x p3.x
//	p0.y p1.y p2.y p3.y
//
// And T is the monomial basis:
//	1
//	t
//	t^2
//	t^3

N_SAMPLES :: 100

BezierCurve :: struct {
	controlPoints: [4]v2,
	geometryMatrix: matrix[2, 4]f32,
	samplePoints: [N_SAMPLES]v2,
}

BEZIER_BASIS_MATRIX :: matrix[4, 4]f32{
	1, -3,  3, -1,
	0,  3, -6,  3,
	0,  0,  3, -3,
	0,  0,  0,  1,
}

/* Create a Bezier curve from the given control points (1 section). For simplicitly, the number of samples is hard-coded. */
createBezierCurve :: proc(controlPoints: [4]v2) -> BezierCurve {
	curve: BezierCurve

	curve.controlPoints = controlPoints
	p0 := controlPoints[0]
	p1 := controlPoints[1]
	p2 := controlPoints[2]
	p3 := controlPoints[3]
	geometryMatrix := matrix[2, 4]f32{
		p0.x, p1.x, p2.x, p3.x,
		p0.y, p1.y, p2.y, p3.y,
	}
	curve.geometryMatrix = geometryMatrix

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
		curve.samplePoints[i] = {
			gamma_t[0, 0],
			gamma_t[1, 0],
		}

		t += stepSize
	}

	return curve
}