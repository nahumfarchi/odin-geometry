package dglib

import "core:fmt"

assertPrint :: proc(condition: bool, msg: string, args: ..any) {
    fmt.printfln(msg, ..args)
    assert(condition)
}