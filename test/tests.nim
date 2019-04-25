import endians, math, os, strformat, terminal, unittest

import bufferedio


proc printBytes(src: pointer, len: Natural,
                bytesPerRow = 24, grouping = 4) =
  var
    s = ""
    byteCount = 0

  for i in 0..<len:
    let p = cast[int](src) + i
    let val = cast[ptr byte](p)[]
    if byteCount == 0:
      s = fmt"{p:016X} (+{i:04}):  "
    s = s & fmt"{val:02X} "

    inc(byteCount)
    if byteCount == bytesPerRow:
      echo s
      s = ""
      byteCount = 0
    else:
      if byteCount mod grouping == 0:
        s = s & "| "

  if byteCount > 0:
    echo s


const TEST_DATA_DIR = "testdata"
const TEST_OUT_DIR = "test_out"

# {{{ Test data generation
proc createInt8TestData(): seq[int8] =
  var buf = newSeq[int8](15000)
  for i in 0..buf.high:
    buf[i] = (i mod 256 - 128).int8
  result = buf

proc createInt16TestData(): seq[int16] =
  var buf = newSeq[int16](15000)
  for i in 0..buf.high:
    buf[i] = (i * 4 - 30000).int16
  result = buf

proc createInt24UnpackedTestData(): seq[int32] =
  var buf = newSeq[int32](15000)
  for i in 0..buf.high:
    buf[i] = (i * 2^9 - 30000).int32
  result = buf

proc createInt24PackedTestData(): seq[uint8] =
  let dataLen = 15000
  var
    buf = newSeq[uint8](dataLen * 3)
    bufPos = 0
  for i in 0..<dataLen:
    var d = (i * 2^9 - 30000).int32
    if cpuEndian == littleEndian:
      buf[bufPos+0] = ( d         and 0xff).uint8
      buf[bufPos+1] = ((d shr  8) and 0xff).uint8
      buf[bufPos+2] = ((d shr 16) and 0xff).uint8
    else:
      buf[bufPos+0] = ((d shr 16) and 0xff).uint8
      buf[bufPos+1] = ((d shr  8) and 0xff).uint8
      buf[bufPos+2] = ( d         and 0xff).uint8
    inc(bufPos, 3)
  result = buf

proc createInt32TestData(): seq[int32] =
  var buf = newSeq[int32](15000)
  for i in 0..buf.high:
    buf[i] = (i * 2^18 / (buf.len * 2^18 div 2)).int32
  result = buf

proc createInt64TestData(): seq[int64] =
  var buf = newSeq[int64](15000)
  for i in 0..buf.high:
    buf[i] = (i * 2^49 / (buf.len * 2^49 div 2)).int64
  result = buf


proc createUInt8TestData(): seq[uint8] =
  var buf = newSeq[uint8](15000)
  for i in 0..buf.high:
    buf[i] = (i mod 256).uint8
  result = buf

proc createUInt16TestData(): seq[uint16] =
  var buf = newSeq[uint16](15000)
  for i in 0..buf.high:
    buf[i] = (i * 4).uint16
  result = buf

proc createUInt32TestData(): seq[uint32] =
  var buf = newSeq[uint32](15000)
  for i in 0..buf.high:
    buf[i] = (i * 2^18).uint32
  result = buf

proc createUInt64TestData(): seq[uint64] =
  var buf = newSeq[uint64](15000)
  for i in 0..buf.high:
    buf[i] = (i * 2^49).uint64
  result = buf


proc createFloat32TestData(): seq[float32] =
  var buf = newSeq[float32](15000)
  for i in 0..buf.high:
    buf[i] = 123.456789 * i.float32
  result = buf

proc createFloat64TestData(): seq[float64] =
  var buf = newSeq[float64](15000)
  for i in 0..buf.high:
    buf[i] = 123.45678912345678912345 * i.float64
  result = buf

# }}}
# {{{ Test helpers
proc cleanTestResults() =
  removeDir(TEST_OUT_DIR)
  discard existsOrCreateDir(TEST_OUT_DIR)

proc displayError(msg: string) =
  styledEcho(fgRed, msg, resetStyle)


proc diffFiles(resultPath, expectedPath: string,
               onlyResultNumBytes: bool = false): bool =
  var f1, f2: FILE
  if not f1.open(resultPath):
    displayError(fmt"Cannot open file '{resultPath}'")
    return false
  if not f2.open(expectedPath):
    displayError(fmt"Cannot open file '{expectedPath}'")
    return false

  let resultSize = f1.getFileSize
  let expectedSize = f2.getFileSize

  if not onlyResultNumBytes and resultSize != expectedSize:
    displayError(fmt"File size mismatch, expected size: {expectedSize}, " &
                 fmt"result size: {resultSize}")
    return false

  const BUFSIZE = 8192
  var buf1, buf2: array[BUFSIZE, uint8]
  var currPos = 0'i64

  while currPos < resultSize:
    let
      bytesRemaining = resultSize - currPos
      len = min(bytesRemaining, BUFSIZE)
    if f1.readBytes(buf1, 0, len) != len:
      displayError(fmt"Error reading file '{resultPath}'")
      return false
    if f2.readBytes(buf2, 0, len) != len:
      displayError(fmt"Error reading file '{expectedPath}'")
      return false

    if not equalMem(buf1[0].addr, buf2[0].addr, len):
      displayError(fmt"Expected and result WAV files differ")
      return false
    currPos += len

  result = true


proc compareBuf[T](a, b: seq[T]): bool =
  var len = min(a.len, b.len)
  for i in 0..<len:
    if a[i] != b[i]:
      return false
  result = true
# }}}

# {{{ BufferedReader
suite "BufferedReader":

  test "open file - file not found":
    expect(BufferedReaderError):
      var br = openFile("does-not-exist")


  test "open file - file exists (empty file)":
    var br = openFile(joinPath(TEST_DATA_DIR, "empty-file"))
    br.close()

    expect(BufferedReaderError):
      br.close()

  # {{{ single-value reads (little-endian)
  test "single-value reads (little-endian)":
    let fname = joinPath(TEST_DATA_DIR, "single-values-LE")
    var br = openFile(fname)

    check:
      br.filename == fname
      br.endianness == littleEndian
      br.swapEndian == (cpuEndian == bigEndian)

      br.file.getFilePos() == 0
      br.readInt8() == -53'i8
      br.readInt16() == -6078'i16
      br.readInt32() == -138549182'i32
      br.readInt64() == -595064205101262256'i64
      br.readFloat32() == -7.70355367e+33'f32
      br.readFloat64() == -6.1718129885202168e+268'f64
      br.readString(16) == "the final answer"
      br.file.getFilePos() == 43

    br.file.setFilePos(0)
    check:
      br.file.getFilePos() == 0
      br.readUInt8() == 203'u8
      br.readUInt16() == 59458'u16
      br.readUInt32() == 4156418114'u32
      br.readUInt64() == 17851679868608289360'u64
      br.file.getFilePos() == 15

    br.close()

    expect(BufferedReaderError):
      br.close()

    expect(BufferedReaderError):
      discard br.readUInt8()

  # }}}
  # {{{ single-value reads (big-endian)
  test "single-value reads (big-endian)":
    let fname = joinPath(TEST_DATA_DIR, "single-values-be")
    var br = openFile(fname, endianness=bigEndian)
    check:
      br.filename == fname
      br.endianness == bigEndian
      br.swapEndian == (cpuEndian == littleEndian)

      br.file.getFilePos() == 0
      br.readInt8() == -53'i8
      br.readInt16() == -6078'i16
      br.readInt32() == -138549182'i32
      br.readInt64() == -595064205101262256'i64
      br.readFloat32() == -7.70355367e+33'f32
      br.readFloat64() == -6.1718129885202168e+268'f64
      br.readString(16) == "the final answer"
      br.file.getFilePos() == 43

    br.file.setFilePos(0)
    check:
      br.file.getFilePos() == 0
      br.readUInt8() == 203'u8
      br.readUInt16() == 59458'u16
      br.readUInt32() == 4156418114'u32
      br.readUInt64() == 17851679868608289360'u64

    br.close()

    expect(BufferedReaderError):
      br.close()

    expect(BufferedReaderError):
      discard br.readUInt8()
  # }}}

  # {{{ buffered read (int8, little-endian)
  test "buffered read (int8, little-endian)":
    var
      expected = createInt8TestData()
      buf = newSeq[int8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int8-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096)
    buf = newSeq[int8](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000)
    buf = newSeq[int8](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000)
    buf = newSeq[int8](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000)
    buf = newSeq[int8](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int16, little-endian)
  test "buffered read (int16, little-endian)":
    var
      expected = createInt16TestData()
      buf = newSeq[int16](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int16-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 2)
    buf = newSeq[int16](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 2)
    buf = newSeq[int16](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 2)
    buf = newSeq[int16](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 2)
    buf = newSeq[int16](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int24 unpacked, little-endian)
  test "buffered read (int24 unpacked, little-endian)":
    var
      expected = createInt24UnpackedTestData()
      buf = newSeq[int32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int24-LE")
    var br = openFile(fname)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 3)
    buf = newSeq[int32](4096)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 3)
    buf = newSeq[int32](1000)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 3)
    buf = newSeq[int32](1200)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 3)
    buf = newSeq[int32](4000)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int24 packed, little-endian)
  test "buffered read (int24 packed, little-endian)":
    var
      expected = createInt24PackedTestData()
      buf = newSeq[uint8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int24-LE")
    var br = openFile(fname)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 3)
    buf = newSeq[uint8](4096 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 3)
    buf = newSeq[uint8](1000 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 3)
    buf = newSeq[uint8](1200 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 3)
    buf = newSeq[uint8](4000 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int32, little-endian)
  test "buffered read (int32, little-endian)":
    var
      expected = createInt32TestData()
      buf = newSeq[int32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int32-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 4)
    buf = newSeq[int32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 4)
    buf = newSeq[int32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 4)
    buf = newSeq[int32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 4)
    buf = newSeq[int32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int64, little-endian)
  test "buffered read (int64, little-endian)":
    var
      expected = createInt64TestData()
      buf = newSeq[int64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int64-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 8)
    buf = newSeq[int64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 8)
    buf = newSeq[int64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 8)
    buf = newSeq[int64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 8)
    buf = newSeq[int64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint8, little-endian)
  test "buffered read (uint8, little-endian)":
    var
      expected = createUInt8TestData()
      buf = newSeq[uint8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint8-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096)
    buf = newSeq[uint8](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000)
    buf = newSeq[uint8](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000)
    buf = newSeq[uint8](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000)
    buf = newSeq[uint8](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint16, little-endian)
  test "buffered read (uint16, little-endian)":
    var
      expected = createUInt16TestData()
      buf = newSeq[uint16](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint16-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 2)
    buf = newSeq[uint16](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 2)
    buf = newSeq[uint16](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 2)
    buf = newSeq[uint16](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 2)
    buf = newSeq[uint16](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint32, little-endian)
  test "buffered read (uint32, little-endian)":
    var
      expected = createUInt32TestData()
      buf = newSeq[uint32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint32-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 4)
    buf = newSeq[uint32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 4)
    buf = newSeq[uint32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 4)
    buf = newSeq[uint32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 4)
    buf = newSeq[uint32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint64, little-endian)
  test "buffered read (uint64, little-endian)":
    var
      expected = createUInt64TestData()
      buf = newSeq[uint64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint64-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 8)
    buf = newSeq[uint64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 8)
    buf = newSeq[uint64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 8)
    buf = newSeq[uint64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 8)
    buf = newSeq[uint64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (float32, little-endian)
  test "buffered read (float32, little-endian)":
    var
      expected = createFloat32TestData()
      buf = newSeq[float32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-float32-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 4)
    buf = newSeq[float32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 4)
    buf = newSeq[float32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 4)
    buf = newSeq[float32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 4)
    buf = newSeq[float32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (float64, little-endian)
  test "buffered read (float64, little-endian)":
    var
      expected = createFloat64TestData()
      buf = newSeq[float64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-float64-LE")
    var br = openFile(fname)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=4096 * 8)
    buf = newSeq[float64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=3000 * 8)
    buf = newSeq[float64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=1000 * 8)
    buf = newSeq[float64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, bufSize=2000 * 8)
    buf = newSeq[float64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}

  # {{{ buffered read (int8, big-endian)
  test "buffered read (int8, big-endian)":
    var
      expected = createInt8TestData()
      buf = newSeq[int8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int8-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096)
    buf = newSeq[int8](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000)
    buf = newSeq[int8](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000)
    buf = newSeq[int8](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000)
    buf = newSeq[int8](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int16, big-endian)
  test "buffered read (int16, big-endian)":
    var
      expected = createInt16TestData()
      buf = newSeq[int16](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int16-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 2)
    buf = newSeq[int16](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 2)
    buf = newSeq[int16](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 2)
    buf = newSeq[int16](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 2)
    buf = newSeq[int16](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int24 unpacked, big-endian)
  test "buffered read (int24 unpacked, big-endian)":
    var
      expected = createInt24UnpackedTestData()
      buf = newSeq[int32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int24-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 3)
    buf = newSeq[int32](4096)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 3)
    buf = newSeq[int32](1000)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 3)
    buf = newSeq[int32](1200)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 3)
    buf = newSeq[int32](4000)
    br.readData24Unpacked(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int24 packed, big-endian)
  test "buffered read (int24 packed, big-endian)":
    var
      expected = createInt24PackedTestData()
      buf = newSeq[uint8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int24-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 3)
    buf = newSeq[uint8](4096 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 3)
    buf = newSeq[uint8](1000 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 3)
    buf = newSeq[uint8](1200 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 3)
    buf = newSeq[uint8](4000 * 3)
    br.readData24Packed(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int32, big-endian)
  test "buffered read (int32, big-endian)":
    var
      expected = createInt32TestData()
      buf = newSeq[int32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int32-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 4)
    buf = newSeq[int32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 4)
    buf = newSeq[int32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 4)
    buf = newSeq[int32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 4)
    buf = newSeq[int32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (int64, big-endian)
  test "buffered read (int64, big-endian)":
    var
      expected = createInt64TestData()
      buf = newSeq[int64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-int64-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 8)
    buf = newSeq[int64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 8)
    buf = newSeq[int64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 8)
    buf = newSeq[int64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 8)
    buf = newSeq[int64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint8, big-endian)
  test "buffered read (uint8, big-endian)":
    var
      expected = createUInt8TestData()
      buf = newSeq[uint8](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint8-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096)
    buf = newSeq[uint8](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000)
    buf = newSeq[uint8](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000)
    buf = newSeq[uint8](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000)
    buf = newSeq[uint8](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint16, big-endian)
  test "buffered read (uint16, big-endian)":
    var
      expected = createUInt16TestData()
      buf = newSeq[uint16](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint16-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 2)
    buf = newSeq[uint16](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 2)
    buf = newSeq[uint16](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 2)
    buf = newSeq[uint16](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 2)
    buf = newSeq[uint16](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint32, big-endian)
  test "buffered read (uint32, big-endian)":
    var
      expected = createUInt32TestData()
      buf = newSeq[uint32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint32-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 4)
    buf = newSeq[uint32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 4)
    buf = newSeq[uint32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 4)
    buf = newSeq[uint32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 4)
    buf = newSeq[uint32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (uint64, big-endian)
  test "buffered read (uint64, big-endian)":
    var
      expected = createUInt64TestData()
      buf = newSeq[uint64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-uint64-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 8)
    buf = newSeq[uint64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 8)
    buf = newSeq[uint64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 8)
    buf = newSeq[uint64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 8)
    buf = newSeq[uint64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (float32, big-endian)
  test "buffered read (float32, big-endian)":
    var
      expected = createFloat32TestData()
      buf = newSeq[float32](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-float32-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 4)
    buf = newSeq[float32](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 4)
    buf = newSeq[float32](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 4)
    buf = newSeq[float32](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 4)
    buf = newSeq[float32](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
  # {{{ buffered read (float64, little-endian)
  test "buffered read (float64, little-endian)":
    var
      expected = createFloat64TestData()
      buf = newSeq[float64](expected.len)

    let fname = joinPath(TEST_DATA_DIR, "buffered-float64-BE")
    var br = openFile(fname, endianness=bigEndian)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=4096 * 8)
    buf = newSeq[float64](4096)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=3000 * 8)
    buf = newSeq[float64](1000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=1000 * 8)
    buf = newSeq[float64](1200)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)

    br = openFile(fname, endianness=bigEndian, bufSize=2000 * 8)
    buf = newSeq[float64](4000)
    br.readData(buf)
    br.close()
    check compareBuf(buf, expected)
  # }}}
# }}}

# {{{ BufferedWriter
suite "BufferedWriter":

  cleanTestResults()

  # {{{ single-value writes (little-endian)
  test "single-value writes (little-endian)":
    let
      resultName = "single-values-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)

    check:
      bw.filename == resultPath
      bw.endianness == littleEndian
      bw.swapEndian == (cpuEndian == bigEndian)
      bw.file.getFilePos() == 0

    bw.writeInt8(-53'i8)
    bw.writeInt16(-6078'i16)
    bw.writeInt32(-138549182'i32)
    bw.writeInt64(-595064205101262256'i64)
    bw.writeFloat32(-7.70355367e+33'f32)
    bw.writeFloat64(-6.1718129885202168e+268'f64)
    bw.writeString("the final answer")

    check bw.file.getFilePos() == 43
    bw.file.setFilePos(0)
    check bw.file.getFilePos() == 0
    bw.file.flushFile()

    check diffFiles(resultPath, expectedPath)

    bw.writeUInt8(203'u8)
    bw.writeUInt16(59458'u16)
    bw.writeUInt32(4156418114'u32)
    bw.writeUInt64(17851679868608289360'u64)
    bw.writeFloat32(-7.70355367e+33'f32)
    bw.writeFloat64(-6.1718129885202168e+268'f64)
    bw.writeString("the final answer is 42", 16)  # partial write test

    check bw.file.getFilePos() == 43

    bw.close()

    expect(BufferedWriterError):
      bw.close()

    expect(BufferedWriterError):
      bw.writeUInt8(203'u8)

    check diffFiles(resultPath, expectedPath )

  # }}}
  # {{{ single-value writes (big-endian)
  test "single-value writes (big-endian)":
    let
      resultName = "single-values-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)

    check:
      bw.filename == resultPath
      bw.endianness == bigEndian
      bw.swapEndian == (cpuEndian == littleEndian)
      bw.file.getFilePos() == 0

    bw.writeInt8(-53'i8)
    bw.writeInt16(-6078'i16)
    bw.writeInt32(-138549182'i32)
    bw.writeInt64(-595064205101262256'i64)
    bw.writeFloat32(-7.70355367e+33'f32)
    bw.writeFloat64(-6.1718129885202168e+268'f64)
    bw.writeString("the final answer")

    check bw.file.getFilePos() == 43
    bw.file.setFilePos(0)
    check bw.file.getFilePos() == 0
    bw.file.flushFile()

    check diffFiles(resultPath, expectedPath)

    bw.writeUInt8(203'u8)
    bw.writeUInt16(59458'u16)
    bw.writeUInt32(4156418114'u32)
    bw.writeUInt64(17851679868608289360'u64)
    bw.writeFloat32(-7.70355367e+33'f32)
    bw.writeFloat64(-6.1718129885202168e+268'f64)
    bw.writeString("the final answer is 42", 16)  # partial write test

    check bw.file.getFilePos() == 43

    bw.close()

    expect(BufferedWriterError):
      bw.close()

    expect(BufferedWriterError):
      bw.writeUInt8(203'u8)

    check diffFiles(resultPath, expectedPath)

  # }}}

  # {{{ buffered write (int8, little-endian)
  test "buffered write (int8, little-endian)":
    var buf = createInt8TestData()

    let
      resultName = "buffered-int8-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int16, little-endian)
  test "buffered write (int16, little-endian)":
    var buf = createInt16TestData()

    let
      resultName = "buffered-int16-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 2)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 2)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 2)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 2)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int24 unpacked, little-endian)
  test "buffered write (int24 unpacked, little-endian)":
    var buf = createInt24UnpackedTestData()

    let
      resultName = "buffered-int24-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData24Unpacked(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 3)
    bw.writeData24Unpacked(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 3)
    bw.writeData24Unpacked(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 3)
    bw.writeData24Unpacked(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 3)
    bw.writeData24Unpacked(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int24 packed, little-endian)
  test "buffered write (int24 packed, little-endian)":
    var buf = createInt24PackedTestData()

    let
      resultName = "buffered-int24-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData24Packed(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 3)
    bw.writeData24Packed(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 3)
    bw.writeData24Packed(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 3)
    bw.writeData24Packed(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 3)
    bw.writeData24Packed(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int32, little-endian)
  test "buffered write (int32, little-endian)":
    var buf = createInt32TestData()

    let
      resultName = "buffered-int32-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int64, little-endian)
  test "buffered write (int64, little-endian)":
    var buf = createInt64TestData()

    let
      resultName = "buffered-int64-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint8, little-endian)
  test "buffered write (uint8, little-endian)":
    var buf = createUInt8TestData()

    let
      resultName = "buffered-uint8-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint16, little-endian)
  test "buffered write (uint16, little-endian)":
    var buf = createUInt16TestData()

    let
      resultName = "buffered-uint16-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 2)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 2)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 2)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 2)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint32, little-endian)
  test "buffered write (uint32, little-endian)":
    var buf = createUInt32TestData()

    let
      resultName = "buffered-uint32-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint64, little-endian)
  test "buffered write (uint64, little-endian)":
    var buf = createUInt64TestData()

    let
      resultName = "buffered-uint64-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (float32, little-endian)
  test "buffered write (float32, little-endian)":
    var buf = createFloat32TestData()

    let
      resultName = "buffered-float32-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (float64, little-endian)
  test "buffered write (float64, little-endian)":
    var buf = createFloat64TestData()

    let
      resultName = "buffered-float64-LE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}

  # {{{ buffered write (int8, big-endian)
  test "buffered write (int8, big-endian)":
    var buf = createInt8TestData()

    let
      resultName = "buffered-int8-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int16, big-endian)
  test "buffered write (int16, big-endian)":
    var buf = createInt16TestData()

    let
      resultName = "buffered-int16-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 2)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 2)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 2)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 2)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int24 unpacked, big-endian)
  test "buffered write (int24 unpacked, big-endian)":
    var buf = createInt24UnpackedTestData()

    let
      resultName = "buffered-int24-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData24Unpacked(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 3)
    bw.writeData24Unpacked(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 3)
    bw.writeData24Unpacked(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 3)
    bw.writeData24Unpacked(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 3)
    bw.writeData24Unpacked(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int24 packed, big-endian)
  test "buffered write (int24 packed, big-endian)":
    var buf = createInt24PackedTestData()

    let
      resultName = "buffered-int24-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData24Packed(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 3)
    bw.writeData24Packed(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 3)
    bw.writeData24Packed(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 3)
    bw.writeData24Packed(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 3)
    bw.writeData24Packed(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int32, big-endian)
  test "buffered write (int32, big-endian)":
    var buf = createInt32TestData()

    let
      resultName = "buffered-int32-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (int64, big-endian)
  test "buffered write (int64, big-endian)":
    var buf = createInt64TestData()

    let
      resultName = "buffered-int64-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint8, big-endian)
  test "buffered write (uint8, big-endian)":
    var buf = createUInt8TestData()

    let
      resultName = "buffered-uint8-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint16, big-endian)
  test "buffered write (uint16, big-endian)":
    var buf = createUInt16TestData()

    let
      resultName = "buffered-uint16-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 2)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 2)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 2)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 2)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint32, big-endian)
  test "buffered write (uint32, big-endian)":
    var buf = createUInt32TestData()

    let
      resultName = "buffered-uint32-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (uint64, big-endian)
  test "buffered write (uint64, big-endian)":
    var buf = createUInt64TestData()

    let
      resultName = "buffered-uint64-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (float32, big-endian)
  test "buffered write (float32, big-endian)":
    var buf = createFloat32TestData()

    let
      resultName = "buffered-float32-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 4)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 4)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 4)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 4)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
  # {{{ buffered write (float64, big-endian)
  test "buffered write (float64, big-endian)":
    var buf = createFloat64TestData()

    let
      resultName = "buffered-float64-BE"
      resultPath = joinPath(TEST_OUT_DIR, resultName)
      expectedPath = joinPath(TEST_DATA_DIR, resultName)

    var bw = createFile(resultPath, endianness=bigEndian)
    bw.writeData(buf)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=4096 * 8)
    bw.writeData(buf, 4096)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=3000 * 8)
    bw.writeData(buf, 1000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=1000 * 8)
    bw.writeData(buf, 1200)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

    bw = createFile(resultPath, endianness=bigEndian, bufSize=2000 * 8)
    bw.writeData(buf, 4000)
    bw.close()
    check diffFiles(resultPath, expectedPath, onlyResultNumBytes=true)

  # }}}
# }}}

#[
TODO

- read/write tests with multiple successive readData/writeData calls
- open/update/rewind test
- truncate file on create test (create with read access)
- no truncate on open test (open with write access)
- read/write test for mixed buffer sizes in the same file
- passing invalid buffer sizes
- buffered tests with pointers to data

]#

# vim: et:ts=2:sw=2:fdm=marker
