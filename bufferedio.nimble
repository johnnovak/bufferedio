# Package

version       = "0.1.0"
author        = "John Novak <john@johnnovak.net>"
description   = "Buffered I/O with endianness conversion"
license       = "WTFPL"

skipDirs = @["doc", "testdata"]

# Dependencies

requires "nim >= 0.20.0"

# Tasks

#task examples, "Compiles the examples":
#  exec "nim c -d:release examples/boxdrawing.nim"

#task examplesDebug, "Compiles the examples (debug mode)":
#  exec "nim c examples/boxdrawing.nim"

task docgen, "Generate HTML documentation":
  exec "nim doc -o:doc/bufferedio.html bufferedio"

