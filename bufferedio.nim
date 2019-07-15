import endians, strformat

# {{{ Reader

type
  BufferedReader* = object
    filename:   string
    file:       File
    readBuffer: seq[uint8]
    endianness: Endianness
    swapEndian: bool


func filename*(br: BufferedReader): string {.inline.} =
  br.filename

func file*(br: BufferedReader): File {.inline.} =
  br.file

func endianness*(br: BufferedReader): Endianness {.inline.} =
  br.endianness

proc setEndianness(br: var BufferedReader, endianness: Endianness) {.inline.} =
  br.endianness = endianness
  br.swapEndian = cpuEndian != endianness

proc `endianness=`*(br: var BufferedReader, endianness: Endianness) {.inline.} =
  setEndianness(br, endianness)

func swapEndian*(br: BufferedReader): bool {.inline.} =
  br.swapEndian

proc openFile*(file: File, bufSize: Natural = 4096,
               endianness = littleEndian): BufferedReader =
  var br: BufferedReader
  br.file = file
  br.readBuffer = newSeq[uint8](bufSize)
  setEndianness(br, endianness)

  result = br


proc openFile*(filename: string, bufSize: Natural = 4096,
               endianness = littleEndian,
               writeAccess = false): BufferedReader =
  var f: File
  let mode = if writeAccess: fmReadWriteExisting else: fmRead

  if not open(f, filename, mode):
    raise newException(IOError, fmt"Error opening file")

  result = openFile(f, bufSize, endianness)
  result.filename = filename


proc close*(br: var BufferedReader) =
  if br.file == nil:
    raise newException(IOError, fmt"File has already been closed")

  br.file.close()
  br.file = nil
  br.filename = ""


proc readBuf(br: var BufferedReader, dest: pointer, numBytes: Natural) =
  if br.file == nil:
    raise newException(IOError, fmt"File has been closed")

  let bytesRead = readBuffer(br.file, dest, numBytes)
  if  bytesRead != numBytes:
    raise newException(IOError,
      fmt"Error reading file, tried reading {numBytes} bytes, " &
      fmt"actually read {bytesRead}"
    )

# {{{ Single-value read

proc readString*(br: var BufferedReader, numBytes: Natural): string =
  result = newString(numBytes)
  br.readBuf(result[0].addr, numBytes)

proc readInt8*(br: var BufferedReader): int8 =
  ## Reads a single `int8` value from the current file position. Raises
  ## a `IOError` on read errors.
  br.readBuf(result.addr, 1)

proc readInt16*(br: var BufferedReader): int16 =
  ## Reads a single `int16` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: int16
    br.readBuf(buf.addr, 2)
    swapEndian16(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 2)

proc readInt32*(br: var BufferedReader): int32 =
  ## Reads a single `int32` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: int32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readInt64*(br: var BufferedReader): int64 =
  ## Reads a single `int64` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: int64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

proc readUInt8*(br: var BufferedReader): uint8 =
  ## Reads a single `uint8` value from the current file position. Raises
  ## a `IOError` on read errors.
  br.readBuf(result.addr, 1)

proc readUInt16*(br: var BufferedReader): uint16 =
  ## Reads a single `uint16` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: uint16
    br.readBuf(buf.addr, 2)
    swapEndian16(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 2)

proc readUInt32*(br: var BufferedReader): uint32 =
  ## Reads a single `uint32` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: uint32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readUInt64*(br: var BufferedReader): uint64 =
  ## Reads a single `uint64` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: uint64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

proc readFloat32*(br: var BufferedReader): float32 =
  ## Reads a single `float32` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: float32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readFloat64*(br: var BufferedReader): float64 =
  ## Reads a single `float64` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a `IOError` on read errors.
  if br.swapEndian:
    var buf: float64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

# }}}
# {{{ Buffered read

# 8-bit

proc readData8*(br: var BufferedReader, dest: pointer, numItems: Natural) =
  ## Reads `numItems` number of `int8|uint8` values into `dest` from the
  ## current file position and performs endianness conversion if necessary.
  ## Raises a `IOError` on read errors.
  br.readBuf(dest, numItems)

proc readData*(br: var BufferedReader,
               dest: var openArray[int8|uint8], numItems: Natural) =
  ## Reads `numItems` number of `int8|uint8` values into `dest` from the
  ## current file position and performs endianness conversion if necessary.
  ## Raises a `IOError` on read errors.
  assert numItems <= dest.len
  br.readBuf(dest[0].addr, numItems)


# 16-bit

proc readData16*(br: var BufferedReader, dest: pointer, numItems: Natural) =
  ## Reads `numItems` number of `int16|uint16` values into `dest` from the
  ## current file position and performs endianness conversion if necessary.
  ## Raises a `IOError` on read errors.
  const WIDTH = 2
  if br.swapEndian:
    var
      bytesToRead = numItems * WIDTH
      readBufferSize = br.readBuffer.len - br.readBuffer.len mod WIDTH
      destArr = cast[ptr UncheckedArray[uint8]](dest)
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian16(destArr[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos, WIDTH)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest, numItems * WIDTH)


proc readData*(br: var BufferedReader,
               dest: var openArray[int16|uint16], numItems: Natural) =
  ## Reads `numItems` number of `int16|uint16` values into `dest` from the
  ## current file position and performs endianness conversion if necessary.
  ## Raises a `IOError` on read errors.
  assert numItems <= dest.len
  br.readData16(dest[0].addr, numItems)


# 24-bit

proc readData24Unpacked*(br: var BufferedReader, dest: pointer,
                         numItems: Natural) =
  const WIDTH = 3
  var
    bytesToRead = numItems * WIDTH
    readBufferSize = br.readBuffer.len - br.readBuffer.len mod WIDTH
    destArr = cast[ptr UncheckedArray[int32]](dest)
    destPos = 0

  while bytesToRead > 0:
    let count = min(readBufferSize, bytesToRead)
    br.readBuf(br.readBuffer[0].addr, count)
    var pos = 0
    while pos < count:
      var v: int32
      case br.endianness:
      of littleEndian:
        v = br.readBuffer[pos].int32 or
            (br.readBuffer[pos+1].int32 shl 8) or
            ashr(br.readBuffer[pos+2].int32 shl 24, 8)
      of bigEndian:
        v = br.readBuffer[pos+2].int32 or
            (br.readBuffer[pos+1].int32 shl 8) or
            ashr(br.readBuffer[pos].int32 shl 24, 8)
      destArr[destPos] = v
      inc(pos, WIDTH)
      inc(destPos)

    dec(bytesToRead, count)


proc readData24Unpacked*(br: var BufferedReader,
                         dest: var openArray[int32|uint32], numItems: Natural) =
  assert numItems <= dest.len
  br.readData24Unpacked(dest[0].addr, numItems)


proc readData24Unpacked*(br: var BufferedReader,
                         dest: var openArray[int32|uint32]) =
  br.readData24Unpacked(dest, dest.len)


proc readData24Packed*(br: var BufferedReader, dest: pointer,
                       numItems: Natural) =
  const WIDTH = 3
  var
    bytesToRead = numItems * WIDTH
    readBufferSize = br.readBuffer.len - br.readBuffer.len mod WIDTH
    destArr = cast[ptr UncheckedArray[uint8]](dest)
    destPos = 0

  while bytesToRead > 0:
    let count = min(readBufferSize, bytesToRead)
    br.readBuf(br.readBuffer[0].addr, count)
    var pos = 0
    while pos < count:
      if br.swapEndian:
        destArr[destPos]   = br.readBuffer[pos+2]
        destArr[destPos+1] = br.readBuffer[pos+1]
        destArr[destPos+2] = br.readBuffer[pos]
      else:
        destArr[destPos]   = br.readBuffer[pos]
        destArr[destPos+1] = br.readBuffer[pos+1]
        destArr[destPos+2] = br.readBuffer[pos+2]
      inc(pos, WIDTH)
      inc(destPos, WIDTH)

    dec(bytesToRead, count)


proc readData24Packed*(br: var BufferedReader, dest: var openArray[int8|uint8],
                       numItems: Natural) =
  assert numItems <= dest.len div 3
  br.readData24Packed(dest[0].addr, dest.len div 3)


proc readData24Packed*(br: var BufferedReader, dest: var openArray[int8|uint8]) =
  br.readData24Packed(dest, dest.len div 3)


# 32-bit

proc readData32*(br: var BufferedReader, dest: pointer, numItems: Natural) =
  const WIDTH = 4
  if br.swapEndian:
    var
      bytesToRead = numItems * WIDTH
      readBufferSize = br.readBuffer.len - br.readBuffer.len mod WIDTH
      destArr = cast[ptr UncheckedArray[uint8]](dest)
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian32(destArr[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos, WIDTH)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest, numItems * WIDTH)


proc readData*(br: var BufferedReader,
               dest: var openArray[int32|uint32|float32], numItems: Natural) =
  ## Reads `numItems` number of `int32|uint32|float32` values into `dest`
  ## from the current file position and performs endianness conversion if
  ## necessary. Raises a `IOError` on read errors.
  assert numItems <= dest.len
  br.readData32(dest[0].addr, numItems)


# 64-bit

proc readData64*(br: var BufferedReader, dest: pointer, numItems: Natural) =
  const WIDTH = 8
  if br.swapEndian:
    var
      bytesToRead = numItems * WIDTH
      readBufferSize = br.readBuffer.len - br.readBuffer.len mod WIDTH
      destArr = cast[ptr UncheckedArray[uint8]](dest)
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian64(destArr[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos, WIDTH)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest, numItems * WIDTH)


proc readData*(br: var BufferedReader,
               dest: var openArray[int64|uint64|float64], numItems: Natural) =
  ## Reads `len` number of `int64|uint64|float64` values into `dest` from
  ## the current file position and performs endianness conversion if
  ## necessary.  Raises a `IOError` on read errors.
  assert numItems <= dest.len
  br.readData64(dest[0].addr, numItems)


# Extra

type AllBufferedTypes = int8|uint8|int16|uint16|int32|uint32|float32|int64|uint64|float64

proc readData*(br: var BufferedReader,
               dest: var openArray[AllBufferedTypes]) =
  ## Shortcut to fill the whole `dest` buffer with data.
  br.readData(dest, dest.len)


# }}}
# }}}
# {{{ Writer

type
  BufferedWriter* = object
    filename:    string
    file:        File
    writeBuffer: seq[uint8]
    endianness:  Endianness
    swapEndian:  bool

  BufferedWriterError* = object of Exception


func filename*(bw: BufferedWriter): string {.inline.} =
  bw.filename

func file*(bw: BufferedWriter): File {.inline.} =
  bw.file

func endianness*(bw: BufferedWriter): Endianness {.inline.} =
  bw.endianness

proc setEndianness(bw: var BufferedWriter, endianness: Endianness) {.inline.} =
  bw.endianness = endianness
  bw.swapEndian = cpuEndian != endianness

proc `endianness=`*(br: var BufferedWriter, endianness: Endianness) {.inline.} =
  setEndianness(br, endianness)

func swapEndian*(bw: BufferedWriter): bool {.inline.} =
  bw.swapEndian


proc createFile*(file: File, bufSize: Natural = 4096,
                 endianness = littleEndian): BufferedWriter =
  var bw: BufferedWriter

  bw.file = file
  bw.writeBuffer = newSeq[uint8](bufSize)
  bw.endianness = endianness
  bw.swapEndian = cpuEndian != endianness

  result = bw


proc createFile*(filename: string, bufSize: Natural = 4096,
                 endianness = littleEndian,
                 readAccess = false): BufferedWriter =
  var f: File
  let mode = if readAccess: fmReadWrite else: fmWrite

  if not open(f, filename, mode):
    raise newException(BufferedWriterError, "Error creating file")

  result = createFile(f, bufSize, endianness)
  result.filename = filename


proc close*(bw: var BufferedWriter) =
  if bw.file == nil:
    raise newException(BufferedWriterError, fmt"File has already been closed")

  bw.file.close()
  bw.file = nil
  bw.filename = ""


proc writeBuf(bw: var BufferedWriter, src: pointer, numBytes: Natural) =
  if bw.file == nil:
    raise newException(BufferedWriterError, fmt"File has been closed")

  let bytesWritten = writeBuffer(bw.file, data, numBytes)
  if bytesWritten != numBytes:
    raise newException(BufferedWriterError,
      fmt"Error writing file, tried writing {numBytes} bytes, " &
      fmt"actually written {bytesWritten}"
    )


# {{{ Single-value write

proc writeInt8*(bw: var BufferedWriter, d: int8) =
  ## TODO
  var dest = d
  bw.writeBuf(dest.addr, 1)

proc writeInt16*(bw: var BufferedWriter, d: int16) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int16
    swapEndian16(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 2)
  else:
    bw.writeBuf(src.addr, 2)

proc writeInt32*(bw: var BufferedWriter, d: int32) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int32
    swapEndian32(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 4)
  else:
    bw.writeBuf(src.addr, 4)

proc writeInt64*(bw: var BufferedWriter, d: int64) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int64
    swapEndian64(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 8)
  else:
    bw.writeBuf(src.addr, 8)

proc writeUInt8*(bw: var BufferedWriter, d: uint8) =
  ## TODO
  var dest = d
  bw.writeBuf(dest.addr, 1)

proc writeUInt16*(bw: var BufferedWriter, d: uint16) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int16
    swapEndian16(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 2)
  else:
    bw.writeBuf(src.addr, 2)

proc writeUInt32*(bw: var BufferedWriter, d: uint32) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int32
    swapEndian32(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 4)
  else:
    bw.writeBuf(src.addr, 4)

proc writeUInt64*(bw: var BufferedWriter, d: uint64) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: int64
    swapEndian64(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 8)
  else:
    bw.writeBuf(src.addr, 8)

proc writeFloat32*(bw: var BufferedWriter, d: float32) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: float32
    swapEndian32(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 4)
  else:
    bw.writeBuf(src.addr, 4)

proc writeFloat64*(bw: var BufferedWriter, d: float64) =
  ## TODO
  var src = d
  if bw.swapEndian:
    var dest: float64
    swapEndian64(dest.addr, src.addr)
    bw.writeBuf(dest.addr, 8)
  else:
    bw.writeBuf(src.addr, 8)

proc writeString*(bw: var BufferedWriter, s: string, numBytes: Natural) =
  ## TODO
  assert numBytes <= s.len
  var buf = s
  bw.writeBuf(buf[0].addr, numBytes)

proc writeString*(bw: var BufferedWriter, s: string) =
  ## TODO
  bw.writeString(s, s.len)

# }}}
# {{{ Buffered write

# 8-bit
#
proc writeData8*(bw: var BufferedWriter, src: pointer, numItems: Natural) =
  ## TODO
  bw.writeBuf(data, numItems)

proc writeData*(bw: var BufferedWriter, src: var openArray[int8|uint8]) =
  ## TODO
  bw.writeBuf(data[0].addr, data.len)

proc writeData*(bw: var BufferedWriter, src: var openArray[int8|uint8],
                numItems: Natural) =
  ## TODO
  assert numItems <= data.len
  bw.writeBuf(data[0].addr, numItems)


# 16-bit

proc writeData16*(bw: var BufferedWriter, src: pointer, numItems: Natural) =
  ## TODO
  const WIDTH = 2
  let numBytes = numItems * WIDTH

  if bw.swapEndian:
    let writeBufferSize = bw.writeBuffer.len - bw.writeBuffer.len mod WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < numBytes:
      swapEndian16(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, numBytes)

proc writeData*(bw: var BufferedWriter, src: var openArray[int16|uint16]) =
  ## TODO
  bw.writeData16(data[0].addr, data.len)

proc writeData*(bw: var BufferedWriter, src: var openArray[int16|uint16],
                numItems: Natural) =
  ## TODO
  assert numItems <= data.len
  bw.writeData16(data[0].addr, numItems)


# 24-bit

proc writeData24Packed*(bw: var BufferedWriter, src: pointer,
                        numItems: Natural) =
  ## TODO
  const WIDTH = 3
  let numBytes = numItems * WIDTH

  if bw.swapEndian:
    let writeBufferSize = bw.writeBuffer.len - bw.writeBuffer.len mod WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < numBytes:
      bw.writeBuffer[destPos]   = src[pos+2]
      bw.writeBuffer[destPos+1] = src[pos+1]
      bw.writeBuffer[destPos+2] = src[pos]

      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, numBytes)


proc writeData24Packed*(bw: var BufferedWriter,
                        src: var openArray[int8|uint8], numItems: Natural) =
  ## TODO
  assert numItems * 3 <= data.len
  bw.writeData24Packed(data[0].addr, numItems)


proc writeData24Packed*(bw: var BufferedWriter,
                        src: var openArray[int8|uint8]) =
  ## TODO
  bw.writeData24Packed(data[0].addr, data.len div 3)


proc writeData24Unpacked*(bw: var BufferedWriter, src: pointer,
                          numItems: Natural) =
  ## TODO
  let numBytes = numItems * 4

  let writeBufferSize = bw.writeBuffer.len - bw.writeBuffer.len mod 3
  var
    src = cast[ptr UncheckedArray[uint8]](data)
    pos = 0
    destPos = 0

  while pos < numBytes:
    if bw.swapEndian:
      bw.writeBuffer[destPos]   = src[pos+2]
      bw.writeBuffer[destPos+1] = src[pos+1]
      bw.writeBuffer[destPos+2] = src[pos]
    else:
      bw.writeBuffer[destPos]   = src[pos]
      bw.writeBuffer[destPos+1] = src[pos+1]
      bw.writeBuffer[destPos+2] = src[pos+2]

    inc(destPos, 3)
    inc(pos, 4)
    if destPos >= writeBufferSize:
      bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
      destPos = 0

  if destPos > 0:
    bw.writeBuf(bw.writeBuffer[0].addr, destPos)


proc writeData24Unpacked*(bw: var BufferedWriter,
                          src: var openArray[int32|uint32], numItems: Natural) =
  ## TODO
  assert numItems <= data.len
  bw.writeData24Unpacked(data[0].addr, numItems)


proc writeData24Unpacked*(bw: var BufferedWriter,
                          src: var openArray[int32|uint32]) =
  ## TODO
  bw.writeData24Unpacked(data[0].addr, data.len)


# 32-bit

proc writeData32*(bw: var BufferedWriter, src: pointer, numItems: Natural) =
  ## TODO
  const WIDTH = 4
  let numBytes = numItems * 4

  if bw.swapEndian:
    let writeBufferSize = bw.writeBuffer.len - bw.writeBuffer.len mod WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < numBytes:
      swapEndian32(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, numBytes)


proc writeData*(bw: var BufferedWriter,
                src: var openArray[int32|uint32|float32], numItems: Natural) =
  ## TODO
  assert numItems <= data.len
  bw.writeData32(data[0].addr, numItems)


proc writeData*(bw: var BufferedWriter,
                src: var openArray[int32|uint32|float32]) =
  ## TODO
  bw.writeData32(data[0].addr, data.len)


# 64-bit

proc writeData64*(bw: var BufferedWriter, src: pointer, numItems: Natural) =
  ## TODO
  const WIDTH = 8
  let numBytes = numItems * WIDTH

  if bw.swapEndian:
    let writeBufferSize = bw.writeBuffer.len - bw.writeBuffer.len mod WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < numBytes:
      swapEndian64(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, numBytes)


proc writeData*(bw: var BufferedWriter,
                src: var openArray[int64|uint64|float64], numItems: Natural) =
  ## TODO
  assert numItems <= data.len
  bw.writeData64(data[0].addr, numItems)


proc writeData*(bw: var BufferedWriter,
                src: var openArray[int64|uint64|float64]) =
  ## TODO
  bw.writeData64(data[0].addr, data.len)


# }}}

# vim: et:ts=2:sw=2:fdm=marker
