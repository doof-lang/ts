import { NativeSyntaxNode } from "./native"
import { syntaxError, unsupportedError } from "./diagnostics"
import { typescriptDisposition } from "./grammar_coverage"
import {
  collectComments,
  collectCommentsAfter,
  enclosingExport,
  eraseDirectToken,
  eraseListItem,
  firstNamedChild,
  hasDirectNamedChild,
  hasDirectToken,
  isDirectEraseKind,
  isParameterProperty,
  isRejectedKind,
  isWholeTypeDeclaration,
  rejectedName,
} from "./rule_helpers"
import { Edit, EditKind, ErasurePlan, Span, TsError } from "./types"

export function buildTypeScriptPlan(source: string, root: NativeSyntaxNode): Result<ErasurePlan, TsError> {
  syntax := findSyntaxError(root)
  if syntax != null {
    return Failure { error: syntaxError(source, syntax!) }
  }

  edits: Edit[] := []
  comments: Span[] := []
  try collectNode(source, root, null, edits, comments)
  return Success {
    value: ErasurePlan {
      edits,
      comments,
    }
  }
}

function findSyntaxError(node: NativeSyntaxNode): NativeSyntaxNode | null {
  if node.isError() || node.isMissing() {
    return node
  }
  if !node.hasError() {
    return null
  }
  for index of 0..<node.childCount() {
    found := findSyntaxError(node.child(index))
    if found != null {
      return found
    }
  }
  return node
}

function collectNode(
  source: string,
  node: NativeSyntaxNode,
  parent: NativeSyntaxNode | null,
  edits: Edit[],
  comments: Span[],
): Result<void, TsError> {
  kind := node.kind()

  if kind == "comment" {
    comments.push(Span { start: node.startByte(), end: node.endByte() })
    return Success {}
  }

  if isRejectedKind(kind) {
    return Failure { error: unsupportedError(source, node, rejectedName(kind)) }
  }

  if kind == "internal_module" {
    return Failure { error: unsupportedError(source, node, "namespace or module declaration") }
  }

  if kind == "required_parameter" || kind == "optional_parameter" {
    if isParameterProperty(node) {
      return Failure { error: unsupportedError(source, node, "constructor parameter property") }
    }
    if hasDirectNamedChild(node, "this") {
      eraseListItem(node, parent, edits)
      collectComments(node, comments)
      return Success {}
    }
    eraseDirectToken(node, "?", edits)
  }

  if isWholeTypeDeclaration(kind) {
    target := enclosingExport(parent, node)
    collectComments(target, comments)
    edits.push(Edit { start: target.startByte(), end: target.endByte(), kind: .EraseStatement })
    return Success {}
  }

  if kind == "ambient_declaration" {
    target := enclosingExport(parent, node)
    collectComments(target, comments)
    edits.push(Edit { start: target.startByte(), end: target.endByte(), kind: .EraseStatement })
    return Success {}
  }

  if kind == "import_statement" && hasDirectToken(node, "type") {
    collectComments(node, comments)
    edits.push(Edit { start: node.startByte(), end: node.endByte(), kind: .EraseStatement })
    return Success {}
  }

  if kind == "export_statement" {
    if hasDirectToken(node, "=") {
      return Failure { error: unsupportedError(source, node, "export assignment") }
    }
    if hasDirectToken(node, "type") {
      collectComments(node, comments)
      edits.push(Edit { start: node.startByte(), end: node.endByte(), kind: .EraseStatement })
      return Success {}
    }
    if hasDirectNamedChild(node, "namespace_export") {
      collectComments(node, comments)
      edits.push(Edit { start: node.startByte(), end: node.endByte(), kind: .EraseStatement })
      return Success {}
    }
  }

  if kind == "import_specifier" || kind == "export_specifier" {
    if hasDirectToken(node, "type") {
      eraseListItem(node, parent, edits)
      collectComments(node, comments)
      return Success {}
    }
  }

  if kind == "as_expression" || kind == "satisfies_expression" {
    expression := firstNamedChild(node)
    edits.push(Edit { start: expression.endByte(), end: node.endByte(), kind: .Erase })
    try collectNode(source, expression, node, edits, comments)
    collectCommentsAfter(node, expression.endByte(), comments)
    return Success {}
  }

  if kind == "non_null_expression" {
    expression := firstNamedChild(node)
    edits.push(Edit { start: expression.endByte(), end: node.endByte(), kind: .Erase })
    try collectNode(source, expression, node, edits, comments)
    return Success {}
  }

  if isDirectEraseKind(kind) {
    collectComments(node, comments)
    edits.push(Edit { start: node.startByte(), end: node.endByte(), kind: .Erase })
    return Success {}
  }

  if kind == "abstract_class_declaration" {
    eraseDirectToken(node, "abstract", edits)
  }

  if kind == "public_field_definition" {
    if hasDirectToken(node, "declare") || hasDirectToken(node, "abstract") {
      collectComments(node, comments)
      edits.push(Edit { start: node.startByte(), end: node.endByte(), kind: .EraseStatement })
      return Success {}
    }
    eraseDirectToken(node, "!", edits)
    eraseDirectToken(node, "?", edits)
    eraseDirectToken(node, "readonly", edits)
  }

  if kind == "method_definition" {
    eraseDirectToken(node, "?", edits)
    eraseDirectToken(node, "override", edits)
    eraseDirectToken(node, "abstract", edits)
  }

  if kind == "variable_declarator" {
    eraseDirectToken(node, "!", edits)
  }

  disposition := typescriptDisposition(kind)
  if disposition == "reject" || disposition == "erase" || disposition == "type-interior" {
    return Failure {
      error: unsupportedError(source, node, "unclassified TypeScript syntax (${kind})")
    }
  }

  for index of 0..<node.childCount() {
    try collectNode(source, node.child(index), node, edits, comments)
  }
  return Success {}
}
