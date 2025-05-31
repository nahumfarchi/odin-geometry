package dglib

import "core:fmt"

validateEdgesPrint :: proc(mesh: ^Mesh) {
    fmt.printfln("\n============================")
    for key, _ in mesh.edges {
        validateEdgePrint(mesh, &mesh.edges[key])
    }
    fmt.printfln("\n============================\n")
}

validateEdgeOpposites :: proc(mesh: ^Mesh) {
    for key, _ in mesh.edges {
        edge := &mesh.edges[key]
        opposite := getOppositeEdge(mesh, edge)
        if opposite == nil {
            fromVertex := getFromVertex(mesh, edge).index
            toVertex := getToVertex(mesh, edge).index
            fmt.printfln("Edge#%v %v->%v opposite edge#%v does not exist!", edge.index, fromVertex, toVertex, edge.opposite)
            assert(false, "Opposite edge does not exist!")
        }
    }
}

validateFaceEdges :: proc(mesh: ^Mesh) {
    for f, i in mesh.faces {
        edge, ok := getEdge(mesh, f.incidentEdge)
        if !ok {
            fmt.printfln("Face#%v incident edge#%v does not exist!", i, f.incidentEdge)
            assert(false, "Face incident edge does not exist!")
        }

        vs: [3]VertexIndex
        vs[0] = getFromVertex(mesh, edge).index
        vs[1] = getToVertex(mesh, edge).index
        next := getNextEdge(mesh, edge)
        vs[2] = getToVertex(mesh, next).index
        abc: [3]VertexIndex
        abc[0] = mesh.indices[3*i]
        abc[1] = mesh.indices[3*i+1]
        abc[2] = mesh.indices[3*i+2]
        isValid := false
        for j in 0..<3 {
            if vs[j%3] == abc[0] && vs[(j+1)%3] == abc[1] && vs[(j+2)%3] == abc[2] {
                isValid = true
                break
            }
        }

        if !isValid {
            fmt.printfln("Face#%v edges don't point at the correct vertices. Incident edge#%v %v->%v, vs=%v, abc=%v", 
                i, edge.index, vs[0], vs[1], vs, abc)
            assert(false, "Invalid face edges!")
        }
    }

    for key, _ in mesh.edges {
        edge, _ := getEdge(mesh, key)
        ij := edge
        jk := getNextEdge(mesh, ij)
        ki := getNextEdge(mesh, jk)
        i := getFromVertex(mesh, ij).index
        j := getToVertex(mesh, ij).index
        k := getFromVertex(mesh ,ki).index

        ij_face_idx := ij.face
        jk_face_idx := jk.face
        ki_face_idx := ki.face
        if !(ij_face_idx == jk_face_idx && jk_face_idx == ki_face_idx) {
            fmt.printfln("Edges ij#%v %v->%v, jk#%v %v->%v ki#%v %v->%v don't point at the same faces! %v, %v, %v",
                ij.index, i, j,
                jk.index, j, k,
                ki.index, k, i,
                ij_face_idx, jk_face_idx, ki_face_idx)
            assert(ij_face_idx == jk_face_idx && jk_face_idx == ki_face_idx, "Edges ij, jk, ki don't have the same incident face!")
        }
        
    }
}

validateEdgePrint :: proc(mesh: ^Mesh, edge: ^Edge) {
    fromVertex := getFromVertex(mesh, edge).index
    toVertex := getToVertex(mesh, edge).index
    fmt.printfln("Validating edge#%v %v->%v", edge.index, fromVertex, toVertex)

    opposite := getOppositeEdge(mesh, edge)
    if opposite == nil {
        fmt.printfln("Edge#%v %v->%v opposite edge#%v does not exist!", edge.index, fromVertex, toVertex, edge.opposite)
        assert(false, "Opposite edge does not exist!")
    }

    for key, _ in mesh.edges {
        e := &mesh.edges[key]
        if edge == e {
            fmt.printfln("\tEdge#%v %v->%v found in map at [%p] with index %v", 
                edge.index, fromVertex, toVertex, edge, edge.index)
        }
        
        oe := getOppositeEdge(mesh, e)
        if edge == oe {
            oFromVertex := getFromVertex(mesh, e).index
            oToVertex := getToVertex(mesh, e).index
            fmt.printfln("\tEdge#%v %v->%v is opposite of edge#%v %v->%v", 
                edge.index, fromVertex, toVertex, e.index, oFromVertex, oToVertex)
        }

        ne := getNextEdge(mesh, e)
        if edge == ne {
            nFromVertex := getFromVertex(mesh, e).index
            nToVertex := getToVertex(mesh, e).index
            fmt.printfln("\tEdge#%v %v->%v is next of edge%v %v->%v", 
                edge.index, fromVertex, toVertex, e.index, nFromVertex, nToVertex)
        }
    }

    for i in 0..<len(mesh.vertices) {
        v := &mesh.vertices[i]
        ve, _ := getEdgeFromIndex(mesh, v.incidentEdge)
        if edge == ve {
            fmt.printfln("\tEdge#%v %v->%v is incident edge of vertex#%v", edge.index, fromVertex, toVertex, i)
        }
    }

    for i in 0..<len(mesh.faces) {
        f := &mesh.faces[i]
        fe, _ := getEdgeFromIndex(mesh, f.incidentEdge)
        a := mesh.indices[3*i]
        b := mesh.indices[3*i+1]
        c := mesh.indices[3*i+2]
        if edge == fe {
            fmt.printfln("\tEdge#%v %v->%v is incident edge of face#%v %v, %v, %v", edge.index, fromVertex, toVertex, i, a, b, c)
        }
    }
}

validateEdges :: proc(mesh: ^Mesh) {
    for key, _ in mesh.edges {
        edge := &mesh.edges[key]
        from := getFromVertex(mesh, edge).index
        to := getToVertex(mesh, edge).index
        isValid := false
        isOppositevalid := false

        face := getEdgeFace(mesh, edge)
        if face.index == getOppositeFace(mesh, edge).index {
            fmt.printfln("ERROR: [%p]edge#%v %v->%v and and it's opposite both point at [%p]face#%v",
                edge, edge.index, from, to, face, face.index)
            assert(false, "ERROR: edge and it's opposite both point at the same face!")
        }

        for _, i in mesh.faces {
            fi := getEdgeFace(mesh, edge)
            if fi == &mesh.faces[i] {
                isValid = true
            }

            oppositeFace := getOppositeFace(mesh, edge)
            if oppositeFace == &mesh.faces[i] {
                isOppositevalid = true
            }
        }

        if !isValid {
            // printMesh(mesh)
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
            //printMesh(mesh)
            fmt.printfln("ERROR: validateFaces: ij: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vi, vj), vi, vj)
            assert(false, "ERROR: validateFaces: invalid face!")
        }

        _, okji := getEdge(mesh, vj, vi)
        if !okji {
            fmt.printfln("ERROR: validateFaces: ji: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vj, vi), vj, vi)
            assert(false, "ERROR: validateFaces: invalid face!")
        }

        _, okjk := getEdge(mesh, vj, vk)
        if !okjk {
            fmt.printfln("ERROR: validateFaces: jk: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vj, vk), vj, vk)
            assert(false, "ERROR: validateFaces: invalid face!")
        }

        _, okkj := getEdge(mesh, vk, vj)
        if !okkj {
            fmt.printfln("ERROR: validateFaces: kj: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vk, vj), vk, vj)
            assert(false, "ERROR: validateFaces: invalid face!")
        }

        _, okki := getEdge(mesh, vk, vi)
        if !okki {
            fmt.printfln("ERROR: validateFaces: ki: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vk, vi), vk, vi)
            assert(false, "ERROR: validateFaces: invalid face!")
        }

        _, okik := getEdge(mesh, vi, vk)
        if !okik {
            fmt.printfln("ERROR: validateFaces: ik: face#%v has an edge that does not exist! vertices=(%v, %v, %v), edge#%v=%v->%v", 
                idx, vi, vj, vk, getEdgeKey(mesh, vi, vk), vi, vk)
            assert(false, "ERROR: validateFaces: invalid face!")
        }
    }
}