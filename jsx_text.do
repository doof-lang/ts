import { BlobBuilder, BlobReader } from "std/blob"
import { NativeSyntaxNode } from "./native"

export function padToRow(
  output: string,
  node: NativeSyntaxNode,
  targetRow: int,
  source: string,
): string {
  let result = output
  needed := targetRow - node.startRow()
  let present = lineEndings(result).length
  if present >= needed { return result }
  endings := lineEndings(node.text(source))
  while present < needed && present < endings.length {
    result += endings[present]
    present += 1
  }
  return result
}

export function normalizeJsxText(raw: string): string {
  decoded := decodeEntities(raw)
  lines := decoded.replaceAll("\r\n", "\n").replaceAll("\r", "\n").split("\n")
  if lines.length == 1 { return lines[0] }
  let result = ""
  for index of 0..<lines.length {
    let line = lines[index].replaceAll("\t", " ")
    if index > 0 { line = line.trimStart() }
    if index + 1 < lines.length { line = line.trimEnd() }
    if line.length == 0 { continue }
    if result.length > 0 { result += " " }
    result += line
  }
  return result
}

export function decodeEntities(value: string): string {
  return value
    .replaceAll("&quot;", "\"")
    .replaceAll("&apos;", "'")
    .replaceAll("&#39;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&")
}

export function quoteJs(value: string): string {
  return "\"" + value
    .replaceAll("\\", "\\\\")
    .replaceAll("\"", "\\\"")
    .replaceAll("\r", "\\r")
    .replaceAll("\n", "\\n")
    .replaceAll("\t", "\\t") + "\""
}

function lineEndings(value: string): string[] {
  result: string[] := []
  builder := BlobBuilder()
  builder.writeString(value)
  reader := BlobReader(builder.build())
  let index = 0L
  while index < reader.length() {
    reader.setPosition(index)
    c := reader.readByte()
    if c == byte(13) {
      if index + 1L < reader.length() { reader.setPosition(index + 1L) }
      if index + 1L < reader.length() && reader.readByte() == byte(10) {
        result.push("\r\n")
        index += 2L
      } else {
        result.push("\r")
        index += 1L
      }
    } else if c == byte(10) {
      result.push("\n")
      index += 1L
    } else {
      index += 1L
    }
  }
  return result
}
