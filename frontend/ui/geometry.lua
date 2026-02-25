--[[--
Utilities for 2D geometry - Rust implementation via krengine FFI.

All of these apply to full rectangles:

    local Geom = require("ui/geometry")
    Geom:new{ x = 1, y = 0, w = Screen:scaleBySize(100), h = Screen:scaleBySize(200), }

Some behaviour is defined for points:

    Geom:new{ x = 0, y = 0, }

Some behaviour is defined for dimensions:

    Geom:new{ w = Screen:scaleBySize(600), h = Screen:scaleBySize(800), }

Just use it on simple tables that have x, y and/or w, h
or define your own types using this as a metatable.

Where @{ffi.blitbuffer|BlitBuffer} is concerned, a point at (0, 0) means the top-left corner.

This module uses the Rust implementation from krengine library.

]]

-- Load the Rust implementation
return require("ffi/geometry")
