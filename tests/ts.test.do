import { JsEngine } from "std/js"
import { transpile, transpileTsx, TsxOptions } from "../index"
import { applyErasurePlan } from "../eraser"
import { Edit, EditKind, ErasurePlan, Span, TsError } from "../types"
import { typescriptDisposition, typescriptSpecificKinds } from "../grammar_coverage"

function requireTranspile(source: string): string {
  case transpile(source) {
    s: Success -> return s.value
    f: Failure -> assert(false, "expected transpile success: ${f.error.kind}: ${f.error.message}")
  }
  return ""
}

function requireFailure(source: string): TsError {
  case transpile(source) {
    s: Success -> assert(false, "expected transpile failure, received: ${s.value}")
    f: Failure -> return f.error
  }
  return TsError { kind: "internal", message: "unreachable", line: 1, column: 1 }
}

function requireTranspileTsx(source: string, options: TsxOptions = TsxOptions {}): string {
  case transpileTsx(source, options) {
    s: Success -> return s.value
    f: Failure -> assert(false, "expected TSX transpile success: ${f.error.kind}: ${f.error.message}")
  }
  return ""
}

function requireTsxFailure(source: string): TsError {
  case transpileTsx(source) {
    s: Success -> assert(false, "expected TSX transpile failure, received: ${s.value}")
    f: Failure -> return f.error
  }
  return TsError { kind: "internal", message: "unreachable", line: 1, column: 1 }
}

export function testErasesCommonTypeSyntaxAndRunsOutput(): void {
  source := `interface User { name: string }
type Identifier = string | number
const answer: number = (42 as number)!`
  output := requireTranspile(source)

  assert(output.length == source.length, "expected byte positions to remain stable for ASCII source")
  assert(!output.contains("interface"), "expected interfaces to be erased")
  assert(!output.contains("Identifier"), "expected type aliases to be erased")
  assert(!output.contains("number"), "expected annotations and assertions to be erased")

  engine := JsEngine()
  case engine.eval(output + "\nanswer") {
    s: Success -> {
      case s.value {
        value: int -> assert(value == 42, "expected emitted JavaScript to execute")
        _ -> assert(false, "expected integer JavaScript result")
      }
    }
    f: Failure -> assert(false, "expected valid JavaScript: ${f.error.message}")
  }
}

export function testPreservesVerbatimValueImports(): void {
  source := `import type DefaultType from "types"
import { type Shape, runtimeValue, type Other } from "pkg"
export { type Shape, runtimeValue }
export type { Other } from "pkg"`
  output := requireTranspile(source)

  assert(output.length == source.length, "expected module output positions to remain stable")
  assert(output.contains("runtimeValue"), "expected value imports and exports to remain")
  assert(!output.contains("DefaultType"), "expected whole type imports to be erased")
  assert(!output.contains("Shape"), "expected inline type specifiers to be erased")
  assert(!output.contains("Other"), "expected type exports to be erased")
}

export function testErasesClassTypesAndTypeOnlyMembers(): void {
  source := `abstract class Box<T> implements Container<T> {
  public readonly value!: T
  protected abstract read(): T
  get<U>(fallback?: U): T | U { return this.value }
}`
  output := requireTranspile(source)

  assert(output.contains("class Box"), "expected runtime class to remain")
  assert(!output.contains("abstract"), "expected abstract syntax to be erased")
  assert(!output.contains("implements"), "expected implements clauses to be erased")
  assert(!output.contains("readonly"), "expected readonly modifier to be erased")
  assert(!output.contains("protected"), "expected type-only member to be erased")
  assert(!output.contains("<U>"), "expected method generics to be erased")
  assert(!output.contains("fallback?"), "expected optional marker to be erased")
}

export function testErasesThisParametersAndFieldMarkers(): void {
  source := `class Example {
  optional?: string
  definite!: number
  declare ambient: boolean
  method?(this: Example, value?: number): void {}
}
let assigned!: string`
  output := requireTranspile(source)

  assert(!output.contains("this:"), "expected this parameters to be removed")
  assert(!output.contains("optional?"), "expected optional field markers to be erased")
  assert(!output.contains("definite!"), "expected definite field markers to be erased")
  assert(!output.contains("ambient"), "expected declared fields to be erased completely")
  assert(!output.contains("method?"), "expected optional method markers to be erased")
  assert(!output.contains("assigned!"), "expected variable definite assignment markers to be erased")

  engine := JsEngine()
  case engine.exec(output) {
    s: Success -> {}
    f: Failure -> assert(false, "expected field output to be valid JavaScript: ${f.error.message}: ${output}")
  }
}

export function testTypeOnlyStatementsRemainAsiSafe(): void {
  source := `const first = 1
type Hidden = string
(function () { return first })()`
  output := requireTranspile(source)
  assert(output.contains(";"), "expected an erased statement guard")

  engine := JsEngine()
  case engine.exec(output) {
    s: Success -> {}
    f: Failure -> assert(false, "expected ASI-safe JavaScript: ${f.error.message}: ${output}")
  }
}

export function testPreservesCommentsInsideErasedSyntax(): void {
  source := `type /* retained */ Name = string
const value /* annotation */: number = 1`
  output := requireTranspile(source)

  assert(output.contains("/* retained */"), "expected comments in erased declarations to remain")
  assert(output.contains("/* annotation */"), "expected comments beside annotations to remain")
  assert(output.length == source.length, "expected comment preservation not to move positions")
}

export function testRejectsRuntimeBearingTypeScript(): void {
  assert(requireFailure("enum Direction { Up, Down }").kind == "unsupported-syntax", "expected enum rejection")
  assert(requireFailure("namespace Runtime { export const value = 1 }").kind == "unsupported-syntax", "expected namespace rejection")
  assert(requireFailure("class Point { constructor(public x: number) {} }").kind == "unsupported-syntax", "expected parameter property rejection")
  assert(requireFailure("import value = require('value')").kind == "unsupported-syntax", "expected import assignment rejection")
  assert(requireFailure("export = value").kind == "unsupported-syntax", "expected export assignment rejection")
  assert(requireFailure("const value = <number>1").kind == "unsupported-syntax", "expected angle assertion rejection")
}

export function testReportsSyntaxLocationsWithUnicodeColumns(): void {
  error := requireFailure("const café: string = )")
  assert(error.kind == "syntax", "expected syntax error kind")
  assert(error.line == 1, "expected one-based line")
  assert(error.column == 22, "expected a one-based Unicode column: ${error.column}: ${error.message}")
}

export function testRejectsTsx(): void {
  error := requireFailure("const element = <div>Hello</div>")
  assert(error.kind == "syntax", "expected TSX to remain outside the TypeScript dialect")
}

export function testTsxAutomaticRuntimeUsesJsxAndJsxs(): void {
  source := `const single = <div id="one">hello</div>
const multiple = <Panel><span />{value}</Panel>`
  output := requireTranspileTsx(source)

  assert(output.contains("_jsx(\"div\", {\"id\": \"one\", children: \"hello\"})"), "expected single child JSX call: ${output}")
  assert(output.contains("_jsxs(Panel, {children: ["), "expected multiple child JSXS call: ${output}")
  assert(output.contains("_jsx(\"span\", {})"), "expected nested intrinsic JSX call")
  assert(output.contains("import { jsx as _jsx, jsxs as _jsxs } from \"react/jsx-runtime\";"), "expected production runtime import")
  assert(!output.contains("jsxDEV"), "expected production helpers only")
}

export function testTsxFragmentsAttributesKeysAndCustomRuntime(): void {
  source := `const view = <><Widget enabled key="item" {...props} label={name} />&amp;</>`
  output := requireTranspileTsx(source, TsxOptions { jsxImportSource: "preact" })

  assert(output.contains("_Fragment"), "expected fragment helper")
  assert(output.contains("\"enabled\": true"), "expected boolean attribute")
  assert(output.contains("...props"), "expected spread attribute")
  assert(output.contains("\"label\": name"), "expected expression attribute")
  assert(output.contains("}, \"item\")"), "expected key runtime argument")
  assert(output.contains("\"&\""), "expected JSX entity decoding")
  assert(output.endsWith("from \"preact/jsx-runtime\";"), "expected configurable runtime source")
  assert(requireTranspile(output) == output, "expected comprehensive TSX output to be valid JavaScript")
}

export function testTsxMergesTextEntitiesAndSupportsSpreadChildren(): void {
  source := `const text = <div>Hello &amp; goodbye</div>
const spread = <List>{...items}</List>`
  output := requireTranspileTsx(source)
  assert(output.contains("children: \"Hello & goodbye\""), "expected adjacent text and entities to form one child: ${output}")
  assert(output.contains("_jsxs(List, {children: [...items]})"), "expected spread children to use a JSXS array: ${output}")
}

export function testTsxErasesTypesInsideJsx(): void {
  source := `const value: number = 1
const view = <Box<string> count={(value as number)!} />`
  output := requireTranspileTsx(source)
  assert(output.contains("_jsx(Box, {\"count\": (value"), "expected generic component JSX emission: ${output}")
  assert(!output.contains("<string>"), "expected JSX type arguments to be erased")
  assert(!output.contains("as number"), "expected assertions inside JSX expressions to be erased")
}

export function testTsxPreservesUserCodeLines(): void {
  source := `const before = 1
const view = (
  <section>
    <span>{before}</span>
    {before + 1}
  </section>
)
const after = before + 2`
  output := requireTranspileTsx(source)
  importAt := output.indexOf("\nimport {")
  assert(importAt > 0, "expected appended runtime import")
  body := output.substring(0, importAt)
  assert(body.split("\n").length == source.split("\n").length, "expected user line count to remain stable: ${output}")
  assert(body.split("\n")[4].contains("before + 1"), "expected expression child to remain on its source line")
  assert(body.split("\n")[7].contains("const after"), "expected following code to retain its line")
}

export function testTsxPreservesCrLfLinesWithUnicode(): void {
  source := "const café = 1\r\nconst view = <div>\r\n  {café}\r\n</div>\r\nconst after = café"
  output := requireTranspileTsx(source)
  importAt := output.indexOf("\nimport {")
  assert(importAt > 0, "expected appended runtime import")
  body := output.substring(0, importAt)
  assert(body.split("\r\n").length == source.split("\r\n").length, "expected CRLF count to remain stable")
  assert(body.split("\r\n")[2].contains("café"), "expected Unicode expression to retain its line")
  assert(body.split("\r\n")[4].contains("const after"), "expected following CRLF code to retain its line")
}

export function testTsxAvoidsHelperNameCollisionsAndElidesUnusedImports(): void {
  source := `const _jsx = 1
const node = <div />`
  output := requireTranspileTsx(source)
  assert(output.contains("jsx as _jsx2"), "expected collision-safe JSX alias: ${output}")
  assert(!output.contains("jsxs as"), "expected unused JSXS helper to be omitted")
  assert(!output.contains("Fragment as"), "expected unused Fragment helper to be omitted")

  plain := requireTranspileTsx("const value: number = 1")
  assert(!plain.contains("jsx-runtime"), "expected no runtime import without JSX")
  assert(plain.length == "const value: number = 1".length, "expected ordinary erasure to retain its length")
}

export function testGeneratedTsxCallsExecute(): void {
  source := `const result = <Box>{21 + 21}</Box>`
  output := requireTranspileTsx(source)
  importAt := output.indexOf("\nimport {")
  body := output.substring(0, importAt)
  runtime := `function Box() {}
function _jsx(type, props, key) { return props.children }
`
  engine := JsEngine()
  case engine.eval(runtime + body + "\nresult") {
    s: Success -> {
      case s.value {
        value: int -> assert(value == 42, "expected transformed JSX to execute")
        _ -> assert(false, "expected integer JSX result")
      }
    }
    f: Failure -> assert(false, "expected generated JSX to be valid JavaScript: ${f.error.message}: ${body}")
  }
}

export function testTsxReportsSyntaxErrors(): void {
  error := requireTsxFailure("const view = <div>\n  <span />")
  assert(error.kind == "syntax", "expected TSX syntax error")
  assert(error.line == 2, "expected TSX syntax error line: ${error.line}")
}

export function testPlainJavaScriptAndEmptyInputAreUnchanged(): void {
  javascript := "const value = /type/.test('type') // type"
  assert(requireTranspile(javascript) == javascript, "expected JavaScript to remain unchanged")
  assert(requireTranspile("") == "", "expected empty input to remain empty")
}

export function testDialectNeutralErasureEngine(): void {
  source := "alpha\nbeta gamma"
  output := applyErasurePlan(
    source,
    ErasurePlan {
      edits: [
        Edit { start: 0, end: 5, kind: EditKind.EraseStatement },
        Edit { start: 11, end: 16, kind: EditKind.Erase },
      ],
      comments: [Span { start: 12, end: 14 }],
    },
  )
  assert(output == ";    \nbeta  am  ", "expected generic edits, statement guards, and protected spans")
}

export function testGrammarCoverageTableIsComplete(): void {
  kinds := typescriptSpecificKinds()
  assert(kinds.length == 75, "expected coverage for the pinned grammar's TypeScript-only named nodes")
  for kind of kinds {
    assert(typescriptDisposition(kind) != null, "expected a disposition for ${kind}")
  }
}
