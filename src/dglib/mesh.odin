package dglib

import "core:fmt"
import rl "vendor:raylib"

DEBUG :: false

VertexIndex :: u16
EdgeIndex :: u32
FaceIndex :: u16

Vertex :: struct {
    mesh: ^Mesh,
    position: v3,
    incidentEdge: EdgeIndex,
    index: VertexIndex,

    _isNew: bool,
    _newPosition: v3,
}

Edge :: struct {
    mesh: ^Mesh,
    index: EdgeIndex,
    opposite: EdgeIndex,
    // prev: EdgeIndex // TODO
    next: EdgeIndex,
    v0: VertexIndex,
    v1: VertexIndex,
    face: FaceIndex,

    _isNew: bool,
    _newMidpoint: v3,
}

Face :: struct {
    mesh: ^Mesh,
    index: FaceIndex,
    incidentEdge: EdgeIndex,
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
    // TODO: this is a hack since when the edge map is out of space, it's re-allocated and the memory moves around. If this happens, for example, in the middle of a split operations then all of the edge pointers in use will be invalidated. Reserving a large amount of space in advance is a temporary work around.
    c := 100000
    mesh.positions = make([dynamic]f32, 3*nv)
    mesh.indices = make([dynamic]VertexIndex, 3*nf)
    mesh.vertices = make([dynamic]Vertex, nv)
    mesh.edges = make(map[EdgeIndex]Edge)
    mesh.faces = make([dynamic]Face, nf)

    reserve(&mesh.positions, c*3*nv)
    reserve(&mesh.indices, c*3*nf)
    reserve(&mesh.vertices, c*nv)
    reserve(&mesh.faces, c*nf)
    reserve(&mesh.edges, c*6*nv) // TODO: count the number of edges instead?

    for pos, i in positions {
        mesh.positions[3*i] = pos[0]
        mesh.positions[3*i+1] = pos[1]
        mesh.positions[3*i+2] = pos[2]

        mesh.vertices[i].mesh = mesh
        mesh.vertices[i].position = pos
        mesh.vertices[i].index = VertexIndex(i)
    }
    
    edges := &mesh.edges
    for faceVertices, fi in faces {
        mesh.indices[3*fi] = VertexIndex(faceVertices[0])
        mesh.indices[3*fi+1] = VertexIndex(faceVertices[1])
        mesh.indices[3*fi+2] = VertexIndex(faceVertices[2])
        mesh.faces[fi].mesh = mesh
        mesh.faces[fi].index = FaceIndex(fi)
        for i in 0..<3 {
            vi := faceVertices[i]
            vj := faceVertices[(i+1)%3]
            vk := faceVertices[(i+2)%3]
            eij_key := getEdgeKey(vi, vj)
            eji_key := getEdgeKey(vj, vi)
            ejk_key := getEdgeKey(vj, vk)
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

            eij.mesh = mesh
            eij.index = eij_key
            eij.opposite = eji_key
            eij.next = ejk_key
            eij.v0 = vi
            eij.v1 = vj
            eij.face = FaceIndex(fi)

            if i == 0 {
                mesh.faces[fi].incidentEdge = eij_key
            }

            if mesh.vertices[vi].incidentEdge <= 0 {
                mesh.vertices[vi].incidentEdge = eij_key
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

getEdgeFromVertexIndices :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex) -> (^Edge, bool) {
    return &mesh.edges[getEdgeKey(a, b)]
}

getEdgeFromIndex :: proc(mesh: ^Mesh, index: EdgeIndex) -> (^Edge, bool) {
    return &mesh.edges[index]
}

getEdgeKey :: proc(a: VertexIndex, b: VertexIndex) -> EdgeIndex {
    // The simplest key, but doesn't work well if you want to add or remove vertices.
    //return EdgeIndex(VertexIndex(len(mesh.vertices)) * vi + vj)

    // Cantor pairing function: https://en.wikipedia.org/wiki/Pairing_function#Cantor_pairing_function
    // Limitation: might not fit in 32 bits, probably doesn't matter since meshes usually don't 
    // have that many edges...
    //return EdgeKey(0.5 * f32((a + b) * (a + b + 1)) + f32(b))

    // Szudzik function: http://szudzik.com/ElegantPairing.pdf
    // Advantage: 32 bits at most, no division or floating points.
    return a >= b ? EdgeIndex(a) * EdgeIndex(a) + EdgeIndex(a) + EdgeIndex(b) : EdgeIndex(a) + EdgeIndex(b) * EdgeIndex(b) // where a, b >= 0
}

addVertex :: proc(mesh: ^Mesh, position: v3) -> ^Vertex {
    append(&mesh.positions, position.x, position.y, position.z)
    append(&mesh.vertices, Vertex{
        mesh = mesh,
        position = position,
        index = VertexIndex(len(mesh.vertices)),
        _newPosition = position,
    })
    return &mesh.vertices[len(mesh.vertices)-1]
}

addEdge :: proc(mesh: ^Mesh, a: ^Vertex, b: ^Vertex) -> ^Edge {
    key := getEdgeKey(a.index, b.index)
    mesh.edges[key] = Edge{
        mesh = mesh,
        index = key,
        v0 = a.index,
        v1 = b.index,
        _isNew = false,
    }

    return &mesh.edges[key]
}

addFace :: proc(mesh: ^Mesh, a: ^Vertex, b: ^Vertex, c: ^Vertex) -> ^Face {
    ai := a.index
    bi := b.index
    ci := c.index
    when DEBUG {
        _, found := getEdgeFromIndex(mesh, ai, bi)
        assertPrint(found, "addFace: could not find incident edge %v->%v!", ai, bi)
        assertPrint(!(ai == bi || bi == ci || ai == ci), "ERROR: addFace: duplicate vertices %v, %v, %v", ai, bi, ci)
    }

    nf := len(mesh.faces)
    append(&mesh.indices, ai, bi, ci)
    append(&mesh.faces, Face{
        // Use the first edge as the incident edge (arbitrary).
        index = FaceIndex(nf),
        incidentEdge = getEdgeKey(ai, bi),
    })
    
    return &mesh.faces[len(mesh.faces)-1]
}

getNextEdge :: proc(edge: ^Edge) -> ^Edge {
    return &edge.mesh.edges[edge.next]
}

getOppositeEdge :: proc(edge: ^Edge) -> ^Edge {
    return &edge.mesh.edges[edge.opposite]
}

getEdgeFace :: proc(edge: ^Edge) -> ^Face {    
    return &edge.mesh.faces[edge.face]
}

getOppositeFace :: proc(edge: ^Edge) -> ^Face {
    return &edge.mesh.faces[getOppositeEdge(edge).face]
}

getEdgeVertices :: proc(edge: ^Edge) -> (^Vertex, ^Vertex) {
    mesh := edge.mesh
    return &mesh.vertices[edge.v0], &mesh.vertices[edge.v1]
}

getFromVertex :: proc(edge: ^Edge) -> ^Vertex {
    return &edge.mesh.vertices[edge.v0]
}

getToVertex :: proc(edge: ^Edge) -> ^Vertex {
    return &edge.mesh.vertices[edge.v1]
}

getVertexIncidentEdge :: proc(vertex: ^Vertex) -> ^Edge {
    edge, _ := getEdgeFromIndex(vertex.mesh, vertex.incidentEdge)
    return edge
}

getFaceIncidentEdge :: proc(face: ^Face) -> ^Edge {
    edge, _ := getEdgeFromIndex(face.mesh, face.incidentEdge)
    return edge
}

getIncidentEdge :: proc{getVertexIncidentEdge, getFaceIncidentEdge}

getVertexDegree :: proc(vertex: ^Vertex) -> VertexIndex {
    degree := 1
    startEdge := getIncidentEdge(vertex)
    currentEdge: ^Edge = getOppositeEdge(startEdge)
    for getNextEdge(currentEdge) != startEdge {
        currentEdge = getNextEdge(currentEdge)
        currentEdge = getOppositeEdge(currentEdge)
        degree += 1
    }

    return VertexIndex(degree)
}

flipEdge :: proc(edge: ^Edge) {
    mesh := edge.mesh
    edges := &mesh.edges

    eij := edge
    eji := getOppositeEdge(eij)
    ejk := getNextEdge(eij)
    eki := getNextEdge(ejk)
    eil := getNextEdge(eji)
    elj := getNextEdge(eil)

    vi, vj := getEdgeVertices(eij)
    vk := getFromVertex( eki)
    vl := getFromVertex(elj)

    // Flip the edges
    eij.v0 = vl.index
    eij.v1 = vk.index
    eij.next = eki.index
    eij_old_index := eij.index
    eij.index = getEdgeKey(vl.index, vk.index)
    edges[eij.index] = eij^
    eij = &mesh.edges[eij.index]
    delete_key(edges, eij_old_index)

    eji.v0 = vk.index
    eji.v1 = vl.index
    eji.next = elj.index
    eji_old_index := eji.index
    eji.index = getEdgeKey(vk.index, vl.index)
    edges[eji.index] = eji^
    eji = &mesh.edges[eji.index]
    delete_key(edges, eji_old_index)

    eij.opposite = eji.index
    eji.opposite = eij.index
    
    // Update adjacency info
    ejk.next = eji.index
    eki.next = eil.index
    eil.next = eij.index
    elj.next = ejk.index

    vi.incidentEdge = eil.index
    vj.incidentEdge = ejk.index
    vk.incidentEdge = eji.index
    vl.incidentEdge = eij.index

    fij := getEdgeFace(eij)
    fji := getEdgeFace(eji)
    fij.incidentEdge = eij.index
    fji.incidentEdge = eji.index
    
    indices := &mesh.indices
    indices[3*fij.index] = vl.index
    indices[3*fij.index+1] = vk.index
    indices[3*fij.index+2] = vi.index

    indices[3*fji.index] = vk.index
    indices[3*fji.index+1] = vl.index
    indices[3*fji.index+2] = vj.index

    eij.face = fij.index
    eki.face = fij.index
    eil.face = fij.index

    eji.face = fji.index
    elj.face = fji.index
    ejk.face = fji.index
}

splitEdge :: proc(edge: ^Edge) -> ^Vertex {
    mesh := edge.mesh
    indices := &mesh.indices
    edges := &mesh.edges

    abc := getEdgeFace(edge)
    bc := edge
    ca := getNextEdge(edge)
    ab := getNextEdge(ca)
    a := getFromVertex(ab)
    b := getToVertex(ab)
    c := getFromVertex(ca)

    dcb := getOppositeFace(edge)
    cb := getOppositeEdge(bc)
    bd := getNextEdge(cb)
    dc := getNextEdge(bd)
    d := getFromVertex(dc)

    // Create the new vertex
    midpoint := (c.position + b.position) / 2
    m := addVertex(mesh, midpoint)
    m._isNew = true

    // Create the new edges
    am := addEdge(mesh, a, m)
    ma := addEdge(mesh, m, a)
    m.incidentEdge = ma.index

    // TODO: Re-use cb/bc to avoid deleting an edge?
    mc := addEdge(mesh, m, c)
    cm := addEdge(mesh, c, m)
    // mc := bc
    // cm := cb
    // mc.v0 = m
    // mc.v1 = c
    // cm.v0 = c
    // cm.v1 = m

    md := addEdge(mesh, m, d)
    dm := addEdge(mesh, d, m)

    mb := addEdge(mesh, m, b)
    bm := addEdge(mesh, b, m)

    // Create the new faces
    // mca
    // Re-use the old faces abc/dcb to avoid deleting a face
    mca := abc
    mca.incidentEdge = mc.index
    mca_idx := mca.index
    indices[3*mca_idx] = m.index
    indices[3*mca_idx+1] = c.index
    indices[3*mca_idx+2] = a.index

    // mdc
    mdc := dcb
    mdc.incidentEdge = md.index
    mdc_idx := mdc.index
    indices[3*mdc_idx] = m.index
    indices[3*mdc_idx+1] = d.index
    indices[3*mdc_idx+2] = c.index
    
    // mab
    mab := addFace(mesh, m, a, b)

    // mbd
    mbd := addFace(mesh, m, b, d)

    // Update outer edges
    ca.next = am.index
    ca.face = mca.index

    ab.next = bm.index
    ab.face = mab.index

    bd.next = dm.index
    bd.face = mbd.index

    dc.next = cm.index
    dc.face = mdc.index

    // Update the outer vertices (it's possible that the incident edges will be deleted)
    a.incidentEdge = ab.index
    b.incidentEdge = bd.index
    c.incidentEdge = ca.index
    d.incidentEdge = dc.index

    // Update the (new) inner edges
    am.opposite = ma.index
    am.next = mc.index
    am.face = mca.index
    am._isNew = true

    ma.opposite = am.index
    ma.next = ab.index
    ma.face = mab.index
    ma._isNew = true

    mc.opposite = cm.index
    mc.next = ca.index
    mc.face = mca.index
    mc._isNew = false

    cm.opposite = mc.index
    cm.next = md.index
    cm.face = mdc.index
    cm._isNew = false

    md.opposite = dm.index
    md.next = dc.index
    md.face = mdc.index
    md._isNew = true

    dm.opposite = md.index
    dm.next = mb.index
    dm.face = mbd.index
    dm._isNew = true

    mb.opposite = bm.index
    mb.next = bd.index
    mb.face = mbd.index
    mb._isNew = false
    
    bm.opposite = mb.index
    bm.next = ma.index
    bm.face = mab.index
    bm._isNew = false


    // Delete the old edges
    delete_key(edges, bc.index)
    delete_key(edges, cb.index)

    return m
}

loopSubdivision :: proc(mesh: ^Mesh) {
    edges := &mesh.edges
    vertices := &mesh.vertices
    initialVertexCount := VertexIndex(len(mesh.vertices))

    // Calculate the new edge midpoints
    for _, &edge in edges {
        vi := getFromVertex(&edge)
        vj := getToVertex(&edge)
        vk := getToVertex(getNextEdge(&edge))
        oppositeEdge := &edges[edge.opposite]
        vl := getToVertex(getNextEdge(oppositeEdge))
        edge._newMidpoint = (3.0/8.0)*(vi.position + vj.position) + (1.0/8.0)*(vk.position + vl.position)
    }

    // Calculate the new vertex positions
    for &v in vertices {
        degree := getVertexDegree(&v)
        u := f32(degree == 3 ? 3.0/16.0 : 3.0/(8.0*f32(degree)))
        v._newPosition = (1-f32(degree)*u) * v.position
        startEdge := getIncidentEdge(&v)
        currentEdge := startEdge
        sanityCheckDegree := VertexIndex(0)
        for {
            next := getNextEdge(currentEdge)
            v._newPosition += u * getToVertex(next).position
            currentEdge = getOppositeEdge(getNextEdge(next))
            sanityCheckDegree += 1
            if currentEdge == startEdge {
                break
            }
        }

        when DEBUG {
            assertPrint(degree == sanityCheckDegree, "ERROR: vertex %v, degree=%v, sanityCheck=%v", i, degree, sanityCheckDegree)
        }
    }

    // Split all of the edges
    for _, &edge in edges {
        vi, vj := getEdgeVertices(&edge)

        // Check that we haven't split this edge already or that it's not a newly created edge
        if vi.index < vj.index && vi.index < initialVertexCount && vj.index < initialVertexCount {
            splitEdge(&edge)
        }
    }

    // Flip new edges that connect a new to an old vertex
    for _, &edge in edges {
        vi, vj := getEdgeVertices(&edge)
        if edge._isNew && vi.index < vj.index && 
            ((vi._isNew && !vj._isNew) || (!vi._isNew && vj._isNew)) {

            flipEdge(&edge)
            edge._isNew = false
        }
    }

    positions := &mesh.positions
    for i in 0..<len(vertices) {
        v := &vertices[i]
        v.position = v._newPosition
        v._isNew = false
        positions[3*i] = v._newPosition[0]
        positions[3*i+1] = v._newPosition[1]
        positions[3*i+2] = v._newPosition[2]
    }

    for _, &edge in edges {
        edge._isNew = false
    }
}

/* Create a cube half-edge mesh. Memory has to be freed using `freeMesh`. */
createCube :: proc(scale: f32) -> ^Mesh {
    return createTriangleMesh({
        scale * v3{ 1, -1, -1 },
        scale * v3{ 1, -1, 1 },
        scale * v3{ 1, 1, 1 },
        scale * v3{ 1, 1, -1 },
        scale * v3{ -1, -1, -1 },
        scale * v3{ -1, -1, 1 },
        scale * v3{ -1, 1, 1 },
        scale * v3{ -1, 1, -1 },
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
createTetrahedron :: proc(scale: f32) -> ^Mesh {
    return createTriangleMesh({
        scale * v3{ 0.000, 1.333, 0 },
        scale * v3{ 0.943, 0, 0 },
        scale * v3{ -0.471, 0, 0.816 },
        scale * v3{ -0.471, 0, -0.816 },
    }, {
        { 2,1,0 },
        { 3,2,0 },
        { 1,3,0 },
        { 1,2,3 },
    })
}

createIcosahedron :: proc(scale: f32) -> ^Mesh {
    return createTriangleMesh({
        scale * v3{ 0.000,  0.000,  1.000 },
        scale * v3{ 0.894,  0.000,  0.447 },
        scale * v3{ 0.276,  0.851,  0.447 },
        scale * v3{ -0.724,  0.526,  0.447 },
        scale * v3{ -0.724, -0.526,  0.447 },
        scale * v3{ 0.276, -0.851,  0.447 },
        scale * v3{ 0.724,  0.526, -0.447 },
        scale * v3{ -0.276,  0.851, -0.447 },
        scale * v3{ -0.894,  0.000, -0.447 },
        scale * v3{ -0.276, -0.851, -0.447 },
        scale * v3{ 0.724, -0.526, -0.447 },
        scale * v3{ 0.000,  0.000, -1.000 },
    }, {
        { 0,1,2 },
        { 0,2,3 },
        { 0,3,4 },
        { 0,4,5 },
        { 0,5,1 },
        { 7,6,11 },
        { 8,7,11 },
        { 9,8,11 },
        { 10,9,11 },
        { 6,10,11 },
        { 6,2,1 },
        { 7,3,2 },
        { 8,4,3 },
        { 9,5,4 },
        { 10,1,5 },
        { 6,7,2 },
        { 7,8,3 },
        { 8,9,4 },
        { 9,10,5 },
        { 10,6,1 },
    });
}

printMesh :: proc(mesh: ^Mesh) {
    fmt.printfln("Half-Edge Mesh:")
    fmt.printfln("Vertices: ")
    for v in mesh.vertices {
        fmt.printfln("\tv#%v: position=%v, newPosition=%v", v.index, v.position, v._newPosition)
    }

    fmt.printfln("Edges:")
    for key, &edge in mesh.edges {
        from := getFromVertex(&edge)
        if getNextEdge(&edge) != nil {
            to := getToVertex(&edge)
            fmt.printfln("\t[%p] e#%v: %v->%v, oppositeIndex=%v", &edge, key, from.index, to.index, edge.opposite)
        } else {
            fmt.printfln("\te#%v: %v->NULL", key, from.index)
        }
    }

    fmt.printfln("Faces:")
    for &f in mesh.faces {
        e0 := getIncidentEdge(&f)
        e1 := getNextEdge(e0)
        e2 := getNextEdge(e1)
        fmt.printfln("\t[%p] f#%v: %v, %v, %v", 
            &f, 
            f.index, 
            getFromVertex(e0).index, 
            getFromVertex(e1).index, 
            getFromVertex(e2).index)
    }
    fmt.printfln("====\n")
}