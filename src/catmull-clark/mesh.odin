package catmull_clark

import "core:fmt"
import rl "vendor:raylib"

VertexIndex :: u16
EdgeIndex :: u16
FaceIndex :: u16

Vertex :: struct {
    position: v3,
    incidentEdge: ^Edge,
    index: VertexIndex,
}

Edge :: struct {
    opposite: ^Edge,
    // prev: EdgeIndex // TODO
    next: ^Edge,
    vertex: ^Vertex,
    face: ^Face,

    oppositeIndex: EdgeIndex,
    nextIndex: EdgeIndex,
    vertexIndex: VertexIndex,
    faceIndex: FaceIndex,
}

Face :: struct {
    incidentEdge: ^Edge,
}

Mesh :: struct {
    coords: [dynamic]f32,
    indices: [dynamic]VertexIndex,

    vertices: [dynamic]Vertex,
    edges: map[EdgeIndex]Edge,
    faces: [dynamic]Face,
}

getEdgeKey :: proc(mesh: ^Mesh, vi: VertexIndex, vj: VertexIndex) -> EdgeIndex {
    return EdgeIndex(VertexIndex(len(mesh.vertices)) * vi + vj)
}

/*
 * Create a triangle mesh from a list of vertex coordinates and face indices.
 * Each face is defined by 3 indices into the vertex coordinates array.
 * 
 * Note: call `freeMesh` to free the allocated memory.
 */
createTriangleMesh :: proc(vertexCoords: []v3, faces: [][3]VertexIndex) -> ^Mesh {
    nv := len(vertexCoords)
    nf := len(faces)
    mesh := new(Mesh)
    mesh.coords = make([dynamic]f32, 3*nv)
    mesh.indices = make([dynamic]VertexIndex, 3*nf)
    mesh.vertices = make([dynamic]Vertex, nv)
    mesh.edges = make(map[EdgeIndex]Edge)
    mesh.faces = make([dynamic]Face, len(faces))
    reserve(&mesh.edges, 6*nv) // TODO: count the number of edges instead?

    for coords, i in vertexCoords {
        mesh.coords[3*i] = coords[0]
        mesh.coords[3*i+1] = coords[1]
        mesh.coords[3*i+2] = coords[2]

        mesh.vertices[i].position = coords
        mesh.vertices[i].index = VertexIndex(i)
    }
    
    edges := &mesh.edges
    for faceVertices, fi in faces {
        mesh.indices[3*fi] = VertexIndex(faceVertices[0])
        mesh.indices[3*fi+1] = VertexIndex(faceVertices[1])
        mesh.indices[3*fi+2] = VertexIndex(faceVertices[2])
        for i in 0..<3 {
            vi := faceVertices[i]
            vj := faceVertices[(i+1)%3]
            vk := faceVertices[(i+2)%3]
            eij_key := getEdgeKey(mesh, vi, vj)
            eji_key := getEdgeKey(mesh, vj, vi)
            ejk_key := getEdgeKey(mesh, vj, vk)
            eij, ok_ij := &edges[eij_key]
            if !ok_ij {
                edges[eij_key] = Edge{}
                eij = &edges[eij_key]
            }
            eji, ok_ji :=  &edges[eji_key]
            if !ok_ji {
                edges[eji_key] = Edge{}
                eji = &edges[eji_key]
            }
            ejk, ok_jk := &edges[ejk_key]
            if !ok_jk {
                edges[ejk_key] = Edge{}
                ejk = &edges[ejk_key]
            }

            eij.opposite = eji
            eij.next = ejk
            eij.vertex = &mesh.vertices[vi]
            eij.face = &mesh.faces[fi]

            eij.oppositeIndex = eji_key
            eij.nextIndex = ejk_key
            eij.vertexIndex = VertexIndex(vi)
            eij.faceIndex = FaceIndex(fi)

            if i == 0 {
                mesh.faces[fi].incidentEdge = eij
            }

            if vi < vj {
                mesh.vertices[vi].incidentEdge = eij
            }
        }
    }

    return mesh
}

freeMesh :: proc(mesh: ^Mesh) {
    delete(mesh.coords)
    delete(mesh.indices)
    delete(mesh.vertices)
    delete(mesh.edges)
    delete(mesh.faces)
    free(mesh)
}

/* 
 * Convert the half-edge mesh to a raylib mesh. 
 * Note: the same underlying data is used and no allocations are performed.
 */
toRaylibMesh :: proc(mesh: ^Mesh) -> rl.Mesh {
    nv := len(mesh.vertices)
    nf := len(mesh.faces)

    result: rl.Mesh
    result.vertexCount = i32(nv)
    result.triangleCount = i32(nf)
    result.vertices = raw_data(mesh.coords[:])
    result.indices = raw_data(mesh.indices[:])

    rl.UploadMesh(&result, false)

    return result
}

/* Create a cube half-edge mesh. Memory has to be freed using `freeMesh`. */
createCube :: proc() -> ^Mesh {
    return createTriangleMesh({
        { 1, -1, -1 },
        { 1, -1, 1 },
        { 1, 1, 1 },
        { 1, 1, -1 },
        { -1, -1, -1 },
        { -1, -1, 1 },
        { -1, 1, 1 },
        { -1, 1, -1 },
    }, {
        { 3, 1, 0 },
        { 2, 1, 3 },
        { 2, 5, 1 },
        { 6, 5, 2 },
        { 7, 4, 5 },
        { 6, 7, 5 },
        { 0, 4, 3 },
        { 7, 3, 4 },
        { 7, 2, 3 },
        { 6, 2, 7 },
        { 0, 1, 4 },
        { 5, 4, 1 },
    })
}

/* Create a tetrahedron half-edge mesh. Memory has to be freed using `freeMesh`. */
createTetrahedron :: proc() -> ^Mesh {
    return createTriangleMesh({
        { 0.000, 1.333, 0 },
        { 0.943, 0, 0 },
        { -0.471, 0, 0.816 },
        { -0.471, 0, -0.816 },
    }, {
        { 2,1,0 },
        { 3,2,0 },
        { 1,3,0 },
        { 1,2,3 },
    })
}

printMesh :: proc(mesh: ^Mesh) {
    fmt.printfln("Half-Edge Mesh:")
    fmt.printfln("Vertices: ")
    for v in mesh.vertices {
        fmt.printfln("\tv_%v: %v", v.index, v.position)
    }

    fmt.printfln("Edges:")
    for key, edge in mesh.edges {
        fmt.printfln("\t e_%v %v -> %v", key, edge.vertexIndex, edge.next.vertexIndex)
    }

    fmt.printfln("Faces:")
    for f in mesh.faces {
        e0 := f.incidentEdge
        e1 := e0.next
        e2 := e1.next
        fmt.printfln("\tf %v, %v, %v", e0.vertex.index, e1.vertex.index, e2.vertex.index)
    }
    fmt.printfln("====\n")
}