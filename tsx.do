import { BlobBuilder, BlobReader } from "std/blob"
import { applyErasurePlan } from "./eraser"
import { internalError } from "./diagnostics"
import { JsxRuntimeUsage, renderJsx } from "./jsx_emitter"
import { NativeSyntaxNode, parseTsx } from "./native"
import { buildTypeScriptPlan } from "./typescript_rules"
import { TsError, TsxOptions } from "./types"

class Replacement {
  readonly start: int
  readonly end: int
  readonly text: string
}

export function transpileTsxSource(
  source: string,
  options: TsxOptions,
): Result<string, TsError> {
  let root: NativeSyntaxNode | null = null
  case parseTsx(source) {
    s: Success -> { root = s.value }
    f: Failure -> { return Failure { error: internalError(f.error) } }
  }

  try plan := buildTypeScriptPlan(source, root!)
  erased := applyErasurePlan(source, plan)
  usage := JsxRuntimeUsage {
    jsxAlias: availableAlias(source, "_jsx"),
    jsxsAlias: availableAlias(source, "_jsxs"),
    fragmentAlias: availableAlias(source, "_Fragment"),
  }
  replacements: Replacement[] := []
  collectReplacements(root!, erased, usage, replacements)
  if replacements.length == 0 { return Success { value: erased } }

  let output = applyReplacements(erased, replacements)
  runtimeImport := buildRuntimeImport(options.jsxImportSource, usage)
  if !output.endsWith("\n") && !output.endsWith("\r") { output += "\n" }
  output += runtimeImport
  return Success { value: output }
}

function collectReplacements(
  node: NativeSyntaxNode,
  source: string,
  usage: JsxRuntimeUsage,
  replacements: Replacement[],
): void {
  kind := node.kind()
  if kind == "jsx_element" || kind == "jsx_self_closing_element" {
    replacements.push(Replacement {
      start: node.startByte(),
      end: node.endByte(),
      text: renderJsx(node, source, usage),
    })
    return
  }
  for index of 0..<node.childCount() {
    collectReplacements(node.child(index), source, usage, replacements)
  }
}

function applyReplacements(source: string, replacements: Replacement[]): string {
  bytesBuilder := BlobBuilder()
  bytesBuilder.writeString(source)
  bytes := bytesBuilder.build()
  reader := BlobReader(bytes)
  output := BlobBuilder()
  let cursor = 0
  for replacement of replacements {
    writeRange(reader, output, cursor, replacement.start)
    output.writeString(replacement.text)
    cursor = replacement.end
  }
  writeRange(reader, output, cursor, int(bytes.length))
  result := BlobReader(output.build())
  return result.readString(result.length())
}

function writeRange(
  reader: BlobReader,
  output: BlobBuilder,
  start: int,
  end: int,
): void {
  reader.setPosition(long(start))
  for index of start..<end {
    output.writeByte(reader.readByte())
  }
}

function availableAlias(source: string, base: string): string {
  if !source.contains(base) { return base }
  let suffix = 2
  while source.contains(base + string(suffix)) { suffix += 1 }
  return base + string(suffix)
}

function buildRuntimeImport(importSource: string, usage: JsxRuntimeUsage): string {
  let result = "import { "
  let count = 0
  if usage.usesJsx {
    result += "jsx as " + usage.jsxAlias
    count += 1
  }
  if usage.usesJsxs {
    if count > 0 { result += ", " }
    result += "jsxs as " + usage.jsxsAlias
    count += 1
  }
  if usage.usesFragment {
    if count > 0 { result += ", " }
    result += "Fragment as " + usage.fragmentAlias
  }
  return result + " } from " + quoteModule(importSource + "/jsx-runtime") + ";"
}

function quoteModule(value: string): string {
  return "\"" + value
    .replaceAll("\\", "\\\\")
    .replaceAll("\"", "\\\"")
    .replaceAll("\r", "\\r")
    .replaceAll("\n", "\\n") + "\""
}
