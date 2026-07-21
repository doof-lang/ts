import { NativeSyntaxNode } from "./native"
import { Edit, Span } from "./types"

export function isRejectedKind(kind: string): bool {
  return kind == "enum_declaration"
    || kind == "import_alias"
    || kind == "import_require_clause"
    || kind == "type_assertion"
}

export function rejectedName(kind: string): string {
  if kind == "enum_declaration" { return "enum declaration" }
  if kind == "type_assertion" { return "angle-bracket type assertion" }
  if kind == "import_alias" || kind == "import_require_clause" { return "import assignment" }
  return kind
}

export function isWholeTypeDeclaration(kind: string): bool {
  return kind == "interface_declaration"
    || kind == "type_alias_declaration"
    || kind == "function_signature"
    || kind == "method_signature"
    || kind == "abstract_method_signature"
    || kind == "property_signature"
    || kind == "index_signature"
    || kind == "call_signature"
    || kind == "construct_signature"
}

export function isDirectEraseKind(kind: string): bool {
  return kind == "type_annotation"
    || kind == "type_predicate_annotation"
    || kind == "asserts_annotation"
    || kind == "type_parameters"
    || kind == "type_arguments"
    || kind == "implements_clause"
    || kind == "accessibility_modifier"
    || kind == "override_modifier"
}

export function isParameterProperty(node: NativeSyntaxNode): bool {
  for index of 0..<node.childCount() {
    kind := node.child(index).kind()
    if kind == "accessibility_modifier" || kind == "override_modifier" || kind == "readonly" {
      return true
    }
  }
  return false
}

export function eraseDirectToken(node: NativeSyntaxNode, token: string, edits: Edit[]): none {
  for index of 0..<node.childCount() {
    child := node.child(index)
    if child.kind() == token {
      edits.push(Edit { start: child.startByte(), end: child.endByte(), kind: .Erase })
    }
  }
}

export function hasDirectToken(node: NativeSyntaxNode, token: string): bool {
  for index of 0..<node.childCount() {
    if node.child(index).kind() == token { return true }
  }
  return false
}

export function hasDirectNamedChild(node: NativeSyntaxNode, kind: string): bool {
  for index of 0..<node.childCount() {
    child := node.child(index)
    if child.isNamed() && child.kind() == kind { return true }
  }
  return false
}

export function firstNamedChild(node: NativeSyntaxNode): NativeSyntaxNode {
  for index of 0..<node.childCount() {
    child := node.child(index)
    if child.isNamed() { return child }
  }
  panic("expected ${node.kind()} to contain a named child")
}

export function enclosingExport(parent: NativeSyntaxNode | none, node: NativeSyntaxNode): NativeSyntaxNode {
  if parent != none && parent!.kind() == "export_statement" { return parent! }
  return node
}

export function eraseListItem(node: NativeSyntaxNode, parent: NativeSyntaxNode | none, edits: Edit[]): none {
  let start = node.startByte()
  let end = node.endByte()
  if parent != none {
    p := parent!
    for index of 0..<p.childCount() {
      child := p.child(index)
      if child.startByte() == node.startByte() && child.endByte() == node.endByte() {
        if index + 1 < p.childCount() && p.child(index + 1).kind() == "," {
          end = p.child(index + 1).endByte()
        } else if index > 0 && p.child(index - 1).kind() == "," {
          start = p.child(index - 1).startByte()
        }
      }
    }
  }
  edits.push(Edit { start, end, kind: .Erase })
}

export function collectComments(node: NativeSyntaxNode, comments: Span[]): none {
  if node.kind() == "comment" {
    comments.push(Span { start: node.startByte(), end: node.endByte() })
    return
  }
  for index of 0..<node.childCount() { collectComments(node.child(index), comments) }
}

export function collectCommentsAfter(node: NativeSyntaxNode, start: int, comments: Span[]): none {
  if node.kind() == "comment" && node.startByte() >= start {
    comments.push(Span { start: node.startByte(), end: node.endByte() })
    return
  }
  for index of 0..<node.childCount() { collectCommentsAfter(node.child(index), start, comments) }
}
