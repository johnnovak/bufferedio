import endians, math, os, strformat, terminal, unittest

import bufferedio


# TODO
proc printFloat64(p: ptr byte) =
  let a1 = (cast[ptr byte](cast[int](p)+0))[]
  let a2 = (cast[ptr byte](cast[int](p)+1))[]
  let a3 = (cast[ptr byte](cast[int](p)+2))[]
  let a4 = (cast[ptr byte](cast[int](p)+3))[]
  let a5 = (cast[ptr byte](cast[int](p)+4))[]
  let a6 = (cast[ptr byte](cast[int](p)+5))[]
  let a7 = (cast[ptr byte](cast[int](p)+6))[]
  let a8 = (cast[ptr byte](cast[int](p)+7))[]
  echo fmt"{a1:x} {a2:x} {a3:x} {a4:x} {a5:x} {a6:x} {a7:x} {a8:x}"

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
