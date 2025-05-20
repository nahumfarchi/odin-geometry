package dglib

import "core:fmt"
import rl "vendor:raylib"

VertexIndex :: u16
EdgeIndex :: u32
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
    v0: ^Vertex,
    v1: ^Vertex,
    face: ^Face,

    oppositeIndex: EdgeIndex,
    //nextIndex: EdgeIndex,
    vertexIndex: VertexIndex,
    faceIndex: FaceIndex,
}

Face :: struct {
    index: FaceIndex,
    incidentEdge: ^Edge,
}

Mesh :: struct {
    positions: [dynamic]f32,
    indices: [dynamic]VertexIndex,

    vertices: [dynamic]Vertex,
    edges: map[EdgeIndex]Edge,
    faces: [dynamic]Face,
}

/*
 * Create a triangle mesh from a list of vertex positions and face indices.
 * Each face is defined by 3 indices into the vertex positions array.
 * 
 * Note: call `freeMesh` to free the allocated memory.
 */
createTriangleMesh :: proc(positions: []v3, faces: [][3]VertexIndex) -> ^Mesh {
    nv := len(positions)
    nf := len(faces)
    mesh := new(Mesh)
    mesh.positions = make([dynamic]f32, 3*nv)
    mesh.indices = make([dynamic]VertexIndex, 3*nf)
    mesh.vertices = make([dynamic]Vertex, nv)
    mesh.edges = make(map[EdgeIndex]Edge)
    mesh.faces = make([dynamic]Face, len(faces))
    reserve(&mesh.edges, 6*nv) // TODO: count the number of edges instead?

    for pos, i in positions {
        mesh.positions[3*i] = pos[0]
        mesh.positions[3*i+1] = pos[1]
        mesh.positions[3*i+2] = pos[2]

        mesh.vertices[i].position = pos
        mesh.vertices[i].index = VertexIndex(i)
    }
    
    edges := &mesh.edges
    for faceVertices, fi in faces {
        mesh.indices[3*fi] = VertexIndex(faceVertices[0])
        mesh.indices[3*fi+1] = VertexIndex(faceVertices[1])
        mesh.indices[3*fi+2] = VertexIndex(faceVertices[2])
        mesh.faces[fi].index = FaceIndex(fi)
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
            eij.v0 = &mesh.vertices[vi]
            eij.v1 = &mesh.vertices[vj]
            eij.face = &mesh.faces[fi]

            eij.oppositeIndex = eji_key
            //eij.nextIndex = ejk_key
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
    delete(mesh.positions)
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
    result.vertices = raw_data(mesh.positions[:])
    result.indices = raw_data(mesh.indices[:])

    rl.UploadMesh(&result, false)

    return result
}

getEdgeKey :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex) -> EdgeIndex {
    // The simplest key, but doesn't work well if you want to add or remove vertices.
    //return EdgeIndex(VertexIndex(len(mesh.vertices)) * vi + vj)

    // Cantor pairing function: https://en.wikipedia.org/wiki/Pairing_function#Cantor_pairing_function
    // Limitation: might not fit in 32 bits, probably doesn't matter since meshes usually don't 
    // have that many edges...
    //return 0.5 * (vi + vj) * (vi + vj + 1) + vj

    // Szudzik function: http://szudzik.com/ElegantPairing.pdf
    // Advantage: 32 bits at most, no division or floating points.
    return EdgeIndex(a >= b ? a * a + a + b : a + b * b) // where a, b >= 0
}

addVertex :: proc(mesh: ^Mesh, position: v3) -> ^Vertex {
    //append_elem(mesh.positions, position)
    append(&mesh.positions, position.x, position.y, position.z)
    append(&mesh.vertices, Vertex{
        position = position,
        index = VertexIndex(len(mesh.vertices)),
    })
    return &mesh.vertices[len(mesh.vertices)-1]
}

flipEdge :: proc(mesh: ^Mesh, eij: ^Edge) {
    eji := eij.opposite
    ejk := eij.next
    eki := ejk.next
    eil := eji.next
    elj := eil.next

    vi := eij.v0
    vj := eij.v1
    vk := eki.v0
    vl := elj.v0

    // Flip the edges
    eij.v0 = vl
    eij.v1 = vk
    eij.next = eki

    eji.v0 = vk
    eji.v1 = vl
    eji.next = elj
    
    // Update adjacency info
    ejk.next = eji
    eki.next = eil
    eil.next = eij
    elj.next = ejk

    vi.incidentEdge = eil
    vj.incidentEdge = ejk
    vk.incidentEdge = eji
    vl.incidentEdge = eij

    fij := eij.face
    fji := eji.face
    fij.incidentEdge = eij
    fji.incidentEdge = eji
    
    indices := &mesh.indices
    indices[3*fij.index] = vl.index
    indices[3*fij.index+1] = vk.index
    indices[3*fij.index+2] = vi.index

    indices[3*fji.index] = vk.index
    indices[3*fji.index+1] = vl.index
    indices[3*fji.index+2] = vj.index
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
        fmt.printfln("\tf %v, %v, %v", e0.v0.index, e1.v0.index, e2.v0.index)
    }
    fmt.printfln("====\n")
}