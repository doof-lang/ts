import { BlobBuilder, BlobReader } from "std/blob"
import { NativeSyntaxNode } from "./native"
import { TsError } from "./types"

export function syntaxError(source: string, node: NativeSyntaxNode): TsError {
  let offset = node.startByte()
  let row = node.startRow()
  if node.isError() && node.endByte() > node.startByte() {
    offset = node.endByte() - 1
    row = node.endRow()
  }
  return errorAt(source, offset, row, "syntax", syntaxMessage(node, source))
}

export function unsupportedError(source: string, node: NativeSyntaxNode, construct: string): TsError {
  return errorAt(
    source,
    node.startByte(),
    node.startRow(),
    "unsupported-syntax",
    "${construct} is not allowed in erasable TypeScript",
  )
}

export function internalError(message: string): TsError {
  return TsError {
    kind: "internal",
    message,
    line: 1,
    column: 1,
  }
}

function syntaxMessage(node: NativeSyntaxNode, source: string): string {
  if node.isMissing() {
    return "Expected ${node.kind()}"
  }
  token := node.text(source)
  if token.length == 0 {
    return "Invalid TypeScript syntax"
  }
  if token.length > 32 {
    return "Invalid TypeScript syntax near ${token.substring(0, 32)}"
  }
  return "Invalid TypeScript syntax near ${token}"
}

function errorAt(source: string, byteOffset: int, row: int, kind: string, message: string): TsError {
  bytesBuilder := BlobBuilder()
  bytesBuilder.writeString(source)
  bytes := bytesBuilder.build()
  reader := BlobReader(bytes)

  let lineStart = byteOffset
  while lineStart > 0 {
    reader.setPosition(long(lineStart - 1))
    if reader.readByte() == byte(10) {
      break
    }
    lineStart -= 1
  }

  let column = 1
  for index of lineStart..<byteOffset {
    reader.setPosition(long(index))
    value := reader.readByte()
    if value < byte(128) || value >= byte(192) {
      column += 1
    }
  }

  return TsError {
    kind,
    message,
    line: row + 1,
    column,
  }
}
