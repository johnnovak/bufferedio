import endians, strformat


type
  BufferedReader* = object
    filename:   string
    file:       File
    readBuffer: seq[uint8]
    endianness: Endianness
    swapEndian: bool

  BufferedReaderError* = object of Exception


func filename*(br: var BufferedReader): string {.inline.} =
  br.filename

func file*(br: var BufferedReader): File {.inline.} =
  br.file

func endianness*(br: var BufferedReader): Endianness {.inline.} =
  br.endianness

func swapEndian*(br: var BufferedReader): bool {.inline.} =
  br.swapEndian


proc openFile*(file: File, bufSize: Natural = 4096,
               endianness = littleEndian): BufferedReader =
  var br: BufferedReader
  br.file = file
  br.readBuffer = newSeq[uint8](bufSize)
  br.endianness = endianness
  br.swapEndian = cpuEndian != endianness

  result = br


proc openFile*(filename: string, bufSize: Natural = 4096,
               endianness = littleEndian,
               writeAccess = false): BufferedReader =
  var f: File
  let mode = if writeAccess: fmReadWriteExisting else: fmRead

  if not open(f, filename, mode):
    raise newException(BufferedReaderError, fmt"Error opening file")

  result = openFile(f, bufSize, endianness)
  result.filename = filename


proc close*(br: var BufferedReader) =
  if br.file == nil:
    raise newException(BufferedReaderError, fmt"File has already been closed")

  br.file.close()
  br.file = nil
  br.filename = ""


proc readBuf(br: var BufferedReader, data: pointer, len: Natural) =
  if br.file == nil:
    raise newException(BufferedReaderError, fmt"File has been closed")

  let bytesRead = readBuffer(br.file, data, len)
  if  bytesRead != len:
    raise newException(BufferedReaderError,
      fmt"Error reading file, tried reading {len} bytes, " &
      fmt"actually read {bytesRead}"
    )

# {{{ Single-value read

proc readString*(br: var BufferedReader, len: Natural): string =
  ## TODO
  result = newString(len)
  br.readBuf(result[0].addr, len)

proc readInt8*(br: var BufferedReader): int8 =
  ## Reads a single ``int8`` value from the current file position. Raises
  ## a ``BufferedReaderError`` on read errors.
  br.readBuf(result.addr, 1)

proc readInt16*(br: var BufferedReader): int16 =
  ## Reads a single ``int16`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: int16
    br.readBuf(buf.addr, 2)
    swapEndian16(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 2)

proc readInt32*(br: var BufferedReader): int32 =
  ## Reads a single ``int32`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: int32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readInt64*(br: var BufferedReader): int64 =
  ## Reads a single ``int64`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: int64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

proc readUInt8*(br: var BufferedReader): uint8 =
  ## Reads a single ``uint8`` value from the current file position. Raises
  ## a ``BufferedReaderError`` on read errors.
  br.readBuf(result.addr, 1)

proc readUInt16*(br: var BufferedReader): uint16 =
  ## Reads a single ``uint16`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: uint16
    br.readBuf(buf.addr, 2)
    swapEndian16(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 2)

proc readUInt32*(br: var BufferedReader): uint32 =
  ## Reads a single ``uint32`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: uint32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readUInt64*(br: var BufferedReader): uint64 =
  ## Reads a single ``uint64`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: uint64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

proc readFloat32*(br: var BufferedReader): float32 =
  ## Reads a single ``float32`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: float32
    br.readBuf(buf.addr, 4)
    swapEndian32(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 4)

proc readFloat64*(br: var BufferedReader): float64 =
  ## Reads a single ``float64`` value from the current file position and
  ## performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  if br.swapEndian:
    var buf: float64
    br.readBuf(buf.addr, 8)
    swapEndian64(result.addr, buf.addr)
  else:
    br.readBuf(result.addr, 8)

# }}}
# {{{ Buffered read

# TODO readData methods should use pointers

# 8-bit

proc readData*(br: var BufferedReader,
               dest: var openArray[int8|uint8], len: Natural) =
  ## Reads `len` number of ``int8|uint8`` values into `dest` from the current
  ## file position and performs endianness conversion if necessary. Raises
  ## a ``BufferedReaderError`` on read errors.
  br.readBuf(dest[0].addr, len)

# 16-bit

proc readData*(br: var BufferedReader,
               dest: var openArray[int16|uint16], len: Natural) =
  ## Reads `len` number of ``int16|uint16`` values into `dest` from the
  ## current file position and performs endianness conversion if necessary.
  ## Raises a ``BufferedReaderError`` on read errors.
  const WIDTH = 2
  if br.swapEndian:
    var
      bytesToRead = len * WIDTH
      readBufferSize = (br.readBuffer.len div WIDTH) * WIDTH
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian16(dest[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest[0].addr, len * WIDTH)

# 24-bit

# TODO

# 32-bit

proc readData*(br: var BufferedReader,
               dest: var openArray[int32|uint32|float32], len: Natural) =
  ## Reads `len` number of ``int32|uint32|float32`` values into `dest` from
  ## the current file position and performs endianness conversion if
  ## necessary. Raises a ``BufferedReaderError`` on read errors.
  const WIDTH = 4
  if br.swapEndian:
    var
      bytesToRead = len * WIDTH
      readBufferSize = (br.readBuffer.len div WIDTH) * WIDTH
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian32(dest[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest[0].addr, len * WIDTH)

# 64-bit

proc readData*(br: var BufferedReader,
               dest: var openArray[int64|uint64|float64], len: Natural) =
  ## Reads `len` number of ``int64|uint64|float64`` values into `dest` from
  ## the current file position and performs endianness conversion if
  ## necessary.  Raises a ``BufferedReaderError`` on read errors.
  const WIDTH = 8
  if br.swapEndian:
    var
      bytesToRead = len * WIDTH
      readBufferSize = (br.readBuffer.len div WIDTH) * WIDTH
      destPos = 0

    while bytesToRead > 0:
      let count = min(readBufferSize, bytesToRead)
      br.readBuf(br.readBuffer[0].addr, count)
      var pos = 0
      while pos < count:
        swapEndian64(dest[destPos].addr, br.readBuffer[pos].addr)
        inc(pos, WIDTH)
        inc(destPos)
      dec(bytesToRead, count)
  else:
    br.readBuf(dest[0].addr, len * WIDTH)


proc readData*(br: var BufferedReader, data: var openArray[int8|uint8]) =
  ## Shortcut to fill the whole `data` buffer with data.
  readData(br, data, data.len)

proc readData*(br: var BufferedReader,
               data: var openArray[int16|uint16|int32|uint32|int64|uint64|float32|float64]) =
  ## Shortcut to fill the whole `data` buffer with data.
  readData(br, data, data.len)

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


func filename*(bw: var BufferedWriter): string {.inline.} =
  bw.filename

func file*(bw: var BufferedWriter): File {.inline.} =
  bw.file

func endianness*(bw: var BufferedWriter): Endianness {.inline.} =
  bw.endianness

func swapEndian*(bw: var BufferedWriter): bool {.inline.} =
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


proc writeBuf(bw: var BufferedWriter, data: pointer, len: Natural) =
  if bw.file == nil:
    raise newException(BufferedWriterError, fmt"File has been closed")

  let bytesWritten = writeBuffer(bw.file, data, len)
  if bytesWritten != len:
    raise newException(BufferedWriterError,
      fmt"Error writing file, tried writing {len} bytes, " &
      fmt"actually written {bytesWritten}"
    )


# {{{ Single-value write

proc writeString*(bw: var BufferedWriter, s: string) =
  ## TODO
  var buf = s
  bw.writeBuf(buf[0].addr, s.len)

proc writeString*(bw: var BufferedWriter, s: string, len: Natural) =
  ## TODO
  assert len <= s.len
  var buf = s
  bw.writeBuf(buf[0].addr, len)

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

# }}}
# {{{ Buffered write

# 8-bit
#
proc writeData8*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  bw.writeBuf(data, len)

proc writeData*(bw: var BufferedWriter, data: var openArray[int8|uint8]) =
  ## TODO
  bw.writeBuf(data[0].addr, data.len)

proc writeData*(bw: var BufferedWriter, data: var openArray[int8|uint8],
                len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeBuf(data[0].addr, len)


# 16-bit

proc writeData16*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  const WIDTH = 2
  assert len mod WIDTH == 0

  if bw.swapEndian:
    let writeBufferSize = (bw.writeBuffer.len div WIDTH) * WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < len:
      swapEndian16(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, len)

proc writeData*(bw: var BufferedWriter, data: var openArray[int16|uint16]) =
  ## TODO
  bw.writeData16(data[0].addr, data.len * 2)

proc writeData*(bw: var BufferedWriter, data: var openArray[int16|uint16],
                len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeData16(data[0].addr, len * 2)


# 24-bit

proc writeData24Packed*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  const WIDTH = 3
  assert len mod WIDTH == 0

  if bw.swapEndian:
    let writeBufferSize = (bw.writeBuffer.len div WIDTH) * WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < len:
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
    bw.writeBuf(data, len)

proc writeData24Packed*(bw: var BufferedWriter, data: var openArray[int8|uint8]) =
  ## TODO
  bw.writeData24Packed(data[0].addr, data.len)

proc writeData24Packed*(bw: var BufferedWriter,
                        data: var openArray[int8|uint8], len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeData24Packed(data[0].addr, len)


proc writeData24Unpacked*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  assert len mod 4 == 0

  let writeBufferSize = (bw.writeBuffer.len div 3) * 3
  var
    src = cast[ptr UncheckedArray[uint8]](data)
    pos = 0
    destPos = 0

  while pos < len:
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

proc writeData24Unpacked*(bw: var BufferedWriter, data: var openArray[int32]) =
  ## TODO
  bw.writeData24Unpacked(data[0].addr, data.len * 4)

proc writeData24Unpacked*(bw: var BufferedWriter,
                        data: var openArray[int32], len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeData24Unpacked(data[0].addr, len * 4)


# 32-bit

proc writeData32*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  const WIDTH = 4
  assert len mod WIDTH == 0

  if bw.swapEndian:
    let writeBufferSize = (bw.writeBuffer.len div WIDTH) * WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < len:
      swapEndian32(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, len)

proc writeData*(bw: var BufferedWriter, data: var openArray[int32|uint32|float32]) =
  ## TODO
  bw.writeData32(data[0].addr, data.len * 4)

proc writeData*(bw: var BufferedWriter,
                data: var openArray[int32|uint32|float32], len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeData32(data[0].addr, len * 4)


# 64-bit

proc writeData64*(bw: var BufferedWriter, data: pointer, len: Natural) =
  ## TODO
  const WIDTH = 8
  assert len mod WIDTH == 0

  if bw.swapEndian:
    let writeBufferSize = (bw.writeBuffer.len div WIDTH) * WIDTH
    var
      src = cast[ptr UncheckedArray[uint8]](data)
      pos = 0
      destPos = 0

    while pos < len:
      swapEndian64(bw.writeBuffer[destPos].addr, src[pos].addr)
      inc(destPos, WIDTH)
      inc(pos, WIDTH)
      if destPos >= writeBufferSize:
        bw.writeBuf(bw.writeBuffer[0].addr, writeBufferSize)
        destPos = 0

    if destPos > 0:
      bw.writeBuf(bw.writeBuffer[0].addr, destPos)
  else:
    bw.writeBuf(data, len)

proc writeData*(bw: var BufferedWriter, data: var openArray[int64|uint64|float64]) =
  ## TODO
  bw.writeData64(data[0].addr, data.len * 8)

proc writeData*(bw: var BufferedWriter,
                data: var openArray[int64|uint64|float64], len: Natural) =
  ## TODO
  assert len <= data.len
  bw.writeData64(data[0].addr, len * 8)

# }}}

# vim: et:ts=2:sw=2:fdm=marker
