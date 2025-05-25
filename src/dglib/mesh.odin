package dglib

import "core:fmt"
import rl "vendor:raylib"

VertexIndex :: u16
EdgeIndex :: u32
FaceIndex :: u16

Vertex :: struct {
    position: v3,
    incidentEdge: EdgeIndex,
    index: VertexIndex,
}

VertexPair :: struct {
    a: VertexIndex,
    b: VertexIndex,
}

Edge :: struct {
    index: EdgeIndex,
    opposite: EdgeIndex,
    // prev: EdgeIndex // TODO
    next: EdgeIndex,
    v0: VertexIndex,
    v1: VertexIndex,
    face: FaceIndex,
}

Face :: struct {
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

            eij.index = eij_key
            eij.opposite = eji_key
            eij.next = ejk_key
            eij.v0 = vi
            eij.v1 = vj
            eij.face = FaceIndex(fi)

            if i == 0 {
                mesh.faces[fi].incidentEdge = eij_key
            }

            if vi < vj {
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

getVertex :: proc(mesh: ^Mesh, index: VertexIndex) -> ^Vertex {
    return &mesh.vertices[index]
}

getEdgeFromVertexIndices :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex) -> (^Edge, bool) {
    return &mesh.edges[getEdgeKey(mesh, a, b)]
}

getEdgeFromIndex :: proc(mesh: ^Mesh, index: EdgeIndex) -> (^Edge, bool) {
    return &mesh.edges[index]
}

getEdge :: proc{getEdgeFromVertexIndices, getEdgeFromIndex}

getFace :: proc(mesh: ^Mesh, index: FaceIndex) -> ^Face {
    return &mesh.faces[index]
}

// TODO: mesh param is currently unused
getEdgeKey :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex) -> EdgeIndex {
    // The simplest key, but doesn't work well if you want to add or remove vertices.
    //return EdgeIndex(VertexIndex(len(mesh.vertices)) * vi + vj)

    // Cantor pairing function: https://en.wikipedia.org/wiki/Pairing_function#Cantor_pairing_function
    // Limitation: might not fit in 32 bits, probably doesn't matter since meshes usually don't 
    // have that many edges...
    //return EdgeKey(0.5 * f32((a + b) * (a + b + 1)) + f32(b))

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

addEdge :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex) -> ^Edge {
    key := getEdgeKey(mesh, a, b)
    edges := &mesh.edges
    if edge, found := &edges[key]; found {
        fmt.printfln("ERROR: addEdge: edge#%v %v->%v already exists!", key, getFromVertex(mesh, edge).index, getToVertex(mesh, edge).index)
        assert(false, "addEdge: trying to add an edge that already exists in the mesh!")
    }
    
    edges[key] = Edge{
        index = key,
        v0 = a,
        v1 = b,
    }
    fmt.printfln("\t\t\taddEdge: adding [%p] edge#%v %v->%v", &edges[key], key, a, b)

    return &edges[key]
}

addFace :: proc(mesh: ^Mesh, a: VertexIndex, b: VertexIndex, c: VertexIndex) -> ^Face {
    if _, found := getEdge(mesh, a, b); found {
        nf := len(mesh.faces)
        if a == b || b == c || a == c {
            fmt.printfln("ERROR: addFace: duplicate vertices %v, %v, %v", a, b, c)
            assert(false, "addFace: duplicated vertices!")
        }
        
        append(&mesh.indices, a, b, c)
        append(&mesh.faces, Face{
            // Use the first edge as the incident edge (arbitrary).
            index = FaceIndex(nf),
            incidentEdge = getEdgeKey(mesh, a, b,),
        })
    } else {
        assert(false, "addFace: could not find incident edge a->b!")
    }
    
    return &mesh.faces[len(mesh.faces)-1]
}

getNextEdge :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Edge {
    return &mesh.edges[edge.next]
}

getOppositeEdge :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Edge {
    return &mesh.edges[edge.opposite]
}

getEdgeFace :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Face {    
    return &mesh.faces[edge.face]
}

getOppositeFace :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Face {
    return &mesh.faces[getOppositeEdge(mesh, edge).face]
}

getEdgeVertices :: proc(mesh: ^Mesh, edge: ^Edge) -> (^Vertex, ^Vertex) {
    return &mesh.vertices[edge.v0], &mesh.vertices[edge.v1]
}

getFromVertex :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Vertex {
    return &mesh.vertices[edge.v0]
}

getToVertex :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Vertex {
    return &mesh.vertices[edge.v1]
}

flipEdge :: proc(mesh: ^Mesh, eij: ^Edge) {
    eji := getOppositeEdge(mesh, eij)
    ejk := getNextEdge(mesh, eij)
    eki := getNextEdge(mesh, ejk)
    eil := getNextEdge(mesh, eji)
    elj := getNextEdge(mesh, eil)

    vi, vj := getEdgeVertices(mesh, eij)
    vk := getFromVertex(mesh, eki)
    vl := getFromVertex(mesh, elj)

    // Flip the edges
    eij.v0 = vl.index
    eij.v1 = vk.index
    eij.next = eki.index

    eji.v0 = vk.index
    eji.v1 = vl.index
    eji.next = elj.index
    
    // Update adjacency info
    ejk.next = eji.index
    eki.next = eil.index
    eil.next = eij.index
    elj.next = ejk.index

    vi.incidentEdge = eil.index
    vj.incidentEdge = ejk.index
    vk.incidentEdge = eji.index
    vl.incidentEdge = eij.index

    fij := getEdgeFace(mesh, eij)
    fji := getEdgeFace(mesh, eji)
    fij.incidentEdge = eij.index
    fji.incidentEdge = eji.index
    
    indices := &mesh.indices
    indices[3*fij.index] = vl.index
    indices[3*fij.index+1] = vk.index
    indices[3*fij.index+2] = vi.index

    indices[3*fji.index] = vk.index
    indices[3*fji.index+1] = vl.index
    indices[3*fji.index+2] = vj.index
}

splitEdge :: proc(mesh: ^Mesh, edge: ^Edge) -> ^Vertex {
    fmt.printfln("\t\t(0) validate faces...")
    validateFaces(mesh)

    fmt.printfln("\t\t(0) validate edges...")
    validateEdges(mesh)

    abc := getEdgeFace(mesh, edge)
    bc := edge
    ca := getNextEdge(mesh, edge)
    ab := getNextEdge(mesh, ca)
    a := getFromVertex(mesh, ab)
    b := getToVertex(mesh, ab)
    c := getFromVertex(mesh, ca)

    dcb := getOppositeFace(mesh, edge)
    cb := getOppositeEdge(mesh, bc)
    bd := getNextEdge(mesh, cb)
    dc := getNextEdge(mesh, bd)
    d := getFromVertex(mesh, dc)

    indices := &mesh.indices

    assert(bc != nil, "splitEdge: bc is null!")
    assert(ca != nil, "splitEdge: ca is null!")
    assert(ab != nil, "splitEdge: ab is null!")
    assert(cb != nil, "splitEdge: cb is null!")
    assert(bd != nil, "splitEdge: bd is null!")
    assert(dc != nil, "splitEdge: dc is null!")

    fmt.printfln("\t\t(0.1) validate faces...")
    validateFaces(mesh)

    fmt.printfln("\t\tplitEdge: tris abc#%v=(%v, %v, %v), dcb#%v=(%v, %v, %v)", abc.index, a.index, b.index, c.index, dcb.index, d.index, c.index, b.index)
    fmt.printfln("\t\tsplitEdge: face0=(%v, %v, %v), face1=(%v, %v, %v)", 
        indices[3*abc.index], indices[3*abc.index+1], indices[3*abc.index+2], 
        indices[3*dcb.index], indices[3*dcb.index+1], indices[3*dcb.index+2])

    // Create the new vertex
    midpoint := (c.position + b.position) / 2
    m := addVertex(mesh, midpoint)
    fmt.printfln("\t\tsplitEdge: creating vertex %v", m.index)

    fmt.printfln("\t\t(0.1) validate edges...")
    validateEdges(mesh)

    // Create the new edges
    fmt.printfln("\t\tsplitEdge: adding a->m...")
    am := addEdge(mesh, a.index, m.index)
    fmt.printfln("\t\tsplitEdge: adding m->a...")
    ma := addEdge(mesh, m.index, a.index)
    m.incidentEdge = ma.index

    // Re-use cb/bc to avoid deleting an edge
    mc := addEdge(mesh, m.index, c.index)
    cm := addEdge(mesh, c.index, m.index)
    // mc := bc
    // cm := cb
    // mc.v0 = m
    // mc.v1 = c
    // cm.v0 = c
    // cm.v1 = m

    fmt.printfln("\t\tsplitEdge: adding m->d...")
    md := addEdge(mesh, m.index, d.index)
    fmt.printfln("\t\tsplitEdge: adding d->m...")
    dm := addEdge(mesh, d.index, m.index)

    fmt.printfln("\t\tsplitEdge: adding m->b...")
    mb := addEdge(mesh, m.index, b.index)
    fmt.printfln("\t\tsplitEdge: adding b->m...")
    bm := addEdge(mesh, b.index, m.index)

    fmt.printfln("\t\t(0.2) validate faces...")
    validateFaces(mesh)

    // Create the new faces
    // mca
    // Re-use the old faces abc/dcb to avoid deleting a face
    //mca := addFace(mesh, m.index, c.index, a.index)
    mca := abc
    mca.incidentEdge = mc.index
    mca_idx := mca.index
    indices[3*mca_idx] = m.index
    indices[3*mca_idx+1] = c.index
    indices[3*mca_idx+2] = a.index

    // mdc
    //mdc := addFace(mesh, m.index, d.index, c.index)
    mdc := dcb
    mdc.incidentEdge = md.index
    mdc_idx := mdc.index
    indices[3*mdc_idx] = m.index
    indices[3*mdc_idx+1] = d.index
    indices[3*mdc_idx+2] = c.index
    
    // mab
    mab := addFace(mesh, m.index, a.index, b.index)

    // mbd
    mbd := addFace(mesh, m.index, b.index, d.index)

    // Update outer edges
    ca.next = am.index
    ca.face = mca.index

    ab.next = bm.index
    ab.face = mab.index

    bd.next = dm.index
    bd.face = mbd.index

    dc.next = cm.index
    dc.face = mdc.index

    fmt.printfln("\t\t(0.3) validate faces...")
    validateFaces(mesh)

    // Update the outer vertices (it's possible that the incident edges will be deleted)
    a.incidentEdge = ab.index
    b.incidentEdge = bd.index
    c.incidentEdge = ca.index
    d.incidentEdge = dc.index

    // Update the (new) inner edges
    am.opposite = ma.index
    am.next = mc.index
    am.face = mca.index

    ma.opposite = am.index
    ma.next = ab.index
    ma.face = mab.index

    mc.opposite = cm.index
    mc.next = ca.index
    mc.face = mca.index

    cm.opposite = mc.index
    cm.next = md.index
    cm.face = mdc.index

    md.opposite = dm.index
    md.next = dc.index
    md.face = mdc.index

    dm.opposite = md.index
    dm.next = mb.index
    dm.face = mbd.index

    mb.opposite = bm.index
    mb.next = bd.index
    mb.face = mbd.index
    
    bm.opposite = mb.index
    bm.next = ma.index
    bm.face = mab.index

    fmt.printfln("\t\t(0.4) validate faces...")
    validateFaces(mesh)

    // Delete the old edges
    edges := &mesh.edges
    delete_key(edges, bc.index)
    delete_key(edges, cb.index)

    fmt.printfln("\t\t(0.5) validate faces...")
    validateFaces(mesh)

    mab_idx := mab.index
    mbd_idx := mbd.index
    fmt.printfln("\t\tsplitEdge: mca=%v, %v, %v", indices[3*mca_idx], indices[3*mca_idx+1], indices[3*mca_idx+2])
    fmt.printfln("\t\tsplitEdge: mdc=%v, %v, %v", indices[3*mdc_idx], indices[3*mdc_idx+1], indices[3*mdc_idx+2])
    fmt.printfln("\t\tsplitEdge: mab=%v, %v, %v", indices[3*mab_idx], indices[3*mab_idx+1], indices[3*mab_idx+2])
    fmt.printfln("\t\tsplitEdge: mbd=%v, %v, %v", indices[3*mbd_idx], indices[3*mbd_idx+1], indices[3*mbd_idx+2])

    // Sanity checks
    for key, _ in edges {
        vedge := &edges[key]
        if getNextEdge(mesh, edge) == nil {
            fmt.printfln("ERROR: splitEdge [%p] e#%v %v->NULL", edge, key, getFromVertex(mesh, edge).index)
            //printMesh(mesh)
            assert(false, "ERROR: splitEdge: null next edge!")
        }

        edge_next := getNextEdge(mesh, vedge)
        edge_next_next := getNextEdge(mesh, edge_next)
        edge_next_next_next := getNextEdge(mesh, edge_next_next)
        if edge != edge_next_next_next {
            fmt.printfln("ERROR: splitEdge [%p] e#%v loop is not closed!", vedge, key)
            assert(vedge == edge_next_next_next, "ERROR: splitEdge: loop is not closed!")
        }

        edge_face := getEdgeFace(mesh, vedge)
        edge_opposite_face := getOppositeFace(mesh, vedge)
        if edge_face.index == edge_opposite_face.index {
            fmt.printfln("ERROR: splitEdge edge#%v %v-%v has an opposite edge with the same face! face#%v", key, getFromVertex(mesh, vedge).index, getToVertex(mesh, vedge).index, edge_face.index)
            assert(false, "ERROR: splitEdge: invalid edge twin!")
        }

        if _, ok := getEdge(mesh, edge_face.incidentEdge); !ok {
            fmt.printfln("ERROR: splitEdge: edge#%v %v->%v has an invalid face! %v", key, getFromVertex(mesh, vedge).index, getToVertex(mesh, vedge).index,  edge_face)
            assert(false, "ERROR: splitEdge: invalid incident edge in face")
        }

        if _, ok := getEdge(mesh, edge_opposite_face.incidentEdge); !ok {
            //fmt.printfln("ERROR: splitEdge: opposite edge#%v %v->%v has an invalid face! %v", getEdgeKey(mesh, edge.opposite.v0.index, edge.opposite.v1.index), edge.opposite.v0.index, edge.opposite.v1.index, edge.opposite.face)
            assert(false, "ERROR: splitEdge: invalid incident edge in opposite face")
        }
    }

    fmt.printfln("\t\t(1) validate edges...")
    validateEdges(mesh)

    for face, idx in mesh.faces {
        if face.index > 10000 {
            fmt.printfln("ERROR: splitEdge: face#%v has an invalid index of %v", idx, face.index)
            assert(false, "ERROR: splitEdge: invalid face index!")
        }
    }

    fmt.printfln("\t\t(1) validate faces...")
    validateFaces(mesh)

    return m
}

validateEdges :: proc(mesh: ^Mesh) {
    for key, _ in mesh.edges {
        edge := &mesh.edges[key]
        isValid := false
        isOppositevalid := false
        for _, i in mesh.faces {
            face := getEdgeFace(mesh, edge)
            if face == &mesh.faces[i] {
                isValid = true
            }

            oppositeFace := getOppositeFace(mesh, edge)
            if oppositeFace == &mesh.faces[i] {
                isOppositevalid = true
            }
        }

        if !isValid {
            printMesh(mesh)
            fmt.printfln("ERROR: splitEdge: [%p] edge#%v %v->%v is point at an non-existant face [%p]!", &mesh.edges[key], key, getFromVertex(mesh, edge).index, getToVertex(mesh, edge).index, edge.face)
            assert(false, "ERROR: splitEdge: edge is point at an non-existant face!")
        }

        if !isOppositevalid {
            fmt.printfln("ERROR: splitEdge: edge#%v %v->%v is pointing at an non-existant opposite face!", key, getFromVertex(mesh, edge).index, getToVertex(mesh, edge).index)
            assert(false, "ERROR: splitEdge: edge is pointing at an non-existant oppsite face!")
        }
    }
}

validateFaces :: proc(mesh: ^Mesh) {
    indices := &mesh.indices
    for _, idx in mesh.faces {
        vi := indices[3*idx]
        vj := indices[3*idx+1]
        vk := indices[3*idx+2]
        _, okij := getEdge(mesh, vi, vj)
        if !okij {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vi, vj), vi, vj)
            assert(false, "ERROR: splitEdge: invalid face!")
        }

        _, okji := getEdge(mesh, vj, vi)
        if !okji {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vj, vi), vj, vi)
            assert(false, "ERROR: splitEdge: invalid face!")
        }

        _, okjk := getEdge(mesh, vj, vk)
        if !okjk {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vj, vk), vj, vk)
            assert(false, "ERROR: splitEdge: invalid face!")
        }

        _, okkj := getEdge(mesh, vk, vj)
        if !okkj {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vk, vj), vk, vj)
            assert(false, "ERROR: splitEdge: invalid face!")
        }

        _, okki := getEdge(mesh, vk, vi)
        if !okki {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vk, vi), vk, vi)
            assert(false, "ERROR: splitEdge: invalid face!")
        }

        _, okik := getEdge(mesh, vi, vk)
        if !okik {
            //fmt.printfln("ERROR: splitEdge: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", idx, vi, vj, vk, getEdgeKey(mesh, vi, vk), vi, vk)
            assert(false, "ERROR: splitEdge: invalid face!")
        }
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
        fmt.printfln("\tv#%v: %v", v.index, v.position)
    }

    fmt.printfln("Edges:")
    for key, _ in mesh.edges {
        edge := &mesh.edges[key]
        from := getFromVertex(mesh, edge)
        face := getEdgeFace(mesh, edge)
        oppositeFace := getOppositeFace(mesh, edge)
        if getNextEdge(mesh, edge) != nil {
            to := getToVertex(mesh, edge)
            fmt.printfln("\t[%p] e#%v: %v->%v, oppositeIndex=%v", &mesh.edges[key], key, from.index, to.index, edge.opposite)
            fmt.printfln("\t\t[%p] face: %v", face, face)
            fmt.printfln("\t\t[%p] opposite face: %v", oppositeFace, oppositeFace)
        } else {
            fmt.printfln("\te#%v: %v->NULL", key, from.index)
        }
    }

    fmt.printfln("Faces:")
    for f, i in mesh.faces {
        e0, _ := getEdge(mesh, f.incidentEdge)
        e1 := getNextEdge(mesh, e0)
        e2 := getNextEdge(mesh, e1)
        fmt.printfln("\t[%p] f#%v: %v, %v, %v", &mesh.faces[i], f.index, getFromVertex(mesh, e0).index, getFromVertex(mesh, e1).index, getFromVertex(mesh, e2))
    }
    fmt.printfln("====\n")
}