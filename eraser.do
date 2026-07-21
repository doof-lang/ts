import { BlobBuilder, BlobReader } from "std/blob"
import { NativeSyntaxNode, parseTypeScript } from "./native"
import { internalError } from "./diagnostics"
import { buildTypeScriptPlan } from "./typescript_rules"
import { Edit, EditKind, ErasurePlan, Span, SyntaxDialect, TsError } from "./types"

export function transpileWithDialect(source: string, dialect: SyntaxDialect): Result<string, TsError> {
  let root: NativeSyntaxNode | none = none
  case parseTypeScript(source) {
    s: Success -> { root = s.value }
    f: Failure -> { return Failure { error: internalError(f.error) } }
  }

  if dialect != .TypeScript {
    return Failure { error: internalError("unsupported syntax dialect") }
  }
  try plan := buildTypeScriptPlan(source, root!)
  return Success { value: applyErasurePlan(source, plan) }
}

export function applyErasurePlan(source: string, plan: ErasurePlan): string {
  edits := sortEdits(plan.edits)
  comments := sortSpans(plan.comments)

  inputBuilder := BlobBuilder()
  inputBuilder.writeString(source)
  bytes := inputBuilder.build()
  reader := BlobReader(bytes)
  output := BlobBuilder(bytes.length)

  let editIndex = 0
  let commentIndex = 0
  for offset of 0..<int(bytes.length) {
    while editIndex < edits.length && offset >= edits[editIndex].end {
      editIndex += 1
    }
    while commentIndex < comments.length && offset >= comments[commentIndex].end {
      commentIndex += 1
    }

    reader.setPosition(long(offset))
    value := reader.readByte()
    inEdit := editIndex < edits.length
      && offset >= edits[editIndex].start
      && offset < edits[editIndex].end
    inComment := commentIndex < comments.length
      && offset >= comments[commentIndex].start
      && offset < comments[commentIndex].end

    if !inEdit || inComment || value == byte(10) || value == byte(13) {
      output.writeByte(value)
    } else if edits[editIndex].kind == .EraseStatement && offset == edits[editIndex].start {
      output.writeByte(byte(59))
    } else {
      output.writeByte(byte(32))
    }
  }

  resultReader := BlobReader(output.build())
  return resultReader.readString(resultReader.length())
}

function sortEdits(source: Edit[]): Edit[] {
  result: Edit[] := []
  for edit of source {
    let index = 0
    while index < result.length && result[index].start <= edit.start {
      index += 1
    }
    result.push(edit)
    let cursor = result.length - 1
    while cursor > index {
      result[cursor] = result[cursor - 1]
      cursor -= 1
    }
    result[index] = edit
  }
  return mergeEdits(result)
}

function mergeEdits(sorted: Edit[]): Edit[] {
  result: Edit[] := []
  for edit of sorted {
    if result.length == 0 || edit.start >= result[result.length - 1].end {
      result.push(edit)
      continue
    }

    previous := result[result.length - 1]
    let end = previous.end
    if edit.end > end { end = edit.end }
    let kind = previous.kind
    if edit.kind == .EraseStatement { kind = .EraseStatement }
    result[result.length - 1] = Edit { start: previous.start, end, kind }
  }
  return result
}

function sortSpans(source: Span[]): Span[] {
  result: Span[] := []
  for span of source {
    let index = 0
    while index < result.length && result[index].start <= span.start {
      index += 1
    }
    result.push(span)
    let cursor = result.length - 1
    while cursor > index {
      result[cursor] = result[cursor - 1]
      cursor -= 1
    }
    result[index] = span
  }
  return result
}
