import endians, os, strformat, terminal, unittest

import bufferedio


const TEST_OUT_DIR = "test_out"


proc cleanTestResults() =
  removeDir(TEST_OUT_DIR)
  discard existsOrCreateDir(TEST_OUT_DIR)


proc displayError(msg: string) =
  styledEcho(fgRed, msg, resetStyle)


proc diffFiles(resultPath, expectedPath: string): bool =
  var f1, f2: FILE
  if not f1.open(resultPath):
    displayError(fmt"Cannot open file '{resultPath}'")
    return false
  if not f2.open(expectedPath):
    displayError(fmt"Cannot open file '{expectedPath}'")
    return false

  let resultSize = f1.getFileSize
  let expectedSize = f2.getFileSize
  if resultSize != expectedSize:
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


# {{{ BufferedReader
suite "BufferedReader":

  test "open file - file not found":
    expect(BufferedReaderError):
      var br = openFile("does-not-exist")


  test "open file - file exists (empty file)":
    var br = openFile("testdata/empty-file")
    br.close()

    expect(BufferedReaderError):
      br.close()


  test "single-value reads (little-endian)":
    var br = openFile("testdata/readtest-single-values-LE")

    check:
      br.filename == "testdata/readtest-single-values-LE"
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


  test "single-value reads (big-endian)":
    var br = openFile("testdata/readtest-single-values-BE",
                      endianness=bigEndian)
    check:
      br.filename == "testdata/readtest-single-values-BE"
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

# {{{ BufferedWriter
suite "BufferedWriter":

  cleanTestResults()

  test "single-value writes (little-endian)":
    var fname = "writetest-single-values-LE"
    var path = joinPath(TEST_OUT_DIR, fname)
    var bw = createFile(path)

    check:
      bw.filename == path
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

    check:
      diffFiles(path, expectedPath = "testdata/readtest-single-values-LE")

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

    check:
      diffFiles(path, expectedPath = "testdata/readtest-single-values-LE")


  test "single-value writes (big-endian)":
    var fname = "writetest-single-values-BE"
    var path = joinPath(TEST_OUT_DIR, fname)
    var bw = createFile(path, endianness=bigEndian)

    check:
      bw.filename == path
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

    check:
      diffFiles(path, expectedPath = "testdata/readtest-single-values-BE")

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

    check:
      diffFiles(path, expectedPath = "testdata/readtest-single-values-BE")

# }}}


# vim: et:ts=2:sw=2:fdm=marker
