import { NativeSyntaxNode } from "./native"
import { decodeEntities, normalizeJsxText, padToRow, quoteJs } from "./jsx_text"

export class JsxRuntimeUsage {
  readonly jsxAlias: string
  readonly jsxsAlias: string
  readonly fragmentAlias: string
  usesJsx = false
  usesJsxs = false
  usesFragment = false
}

class RenderedChild {
  readonly text: string
  readonly row: int
  readonly spread: bool = false
}

export function renderJsx(
  node: NativeSyntaxNode,
  source: string,
  usage: JsxRuntimeUsage,
): string {
  if node.kind() == "jsx_self_closing_element" {
    return renderElement(node, null, source, usage)
  }
  openTag := fieldChild(node, "open_tag")
  return renderElement(node, openTag, source, usage)
}

function renderElement(
  node: NativeSyntaxNode,
  openTag: NativeSyntaxNode | null,
  source: string,
  usage: JsxRuntimeUsage,
): string {
  tagNode := fieldChild(if openTag != null then openTag! else node, "name")
  let tag = ""
  if tagNode == null {
    usage.usesFragment = true
    tag = usage.fragmentAlias
  } else {
    tag = renderTag(tagNode!, source)
  }

  attributes: NativeSyntaxNode[] := []
  tagContainer := if openTag != null then openTag! else node
  for index of 0..<tagContainer.childCount() {
    child := tagContainer.child(index)
    if tagContainer.childFieldName(index) == "attribute" {
      attributes.push(child)
    }
  }

  children: RenderedChild[] := []
  if openTag != null {
    let pendingText = ""
    let pendingTextRow = 0
    for index of 0..<node.childCount() {
      child := node.child(index)
      kind := child.kind()
      if kind == "jsx_text" || kind == "html_character_reference" {
        text := normalizeJsxText(child.text(source))
        if text.length > 0 {
          if pendingText.length == 0 { pendingTextRow = child.startRow() }
          pendingText += text
        }
        continue
      }
      if pendingText.length > 0 {
        children.push(RenderedChild { text: quoteJs(pendingText), row: pendingTextRow })
        pendingText = ""
      }
      if kind == "jsx_expression" {
        expression := jsxExpression(child, source, usage)
        if expression.length > 0 {
          children.push(RenderedChild {
            text: expression,
            row: child.startRow(),
            spread: isSpreadExpression(child),
          })
        }
      } else if kind == "jsx_element" || kind == "jsx_self_closing_element" {
        children.push(RenderedChild {
          text: renderJsx(child, source, usage),
          row: child.startRow(),
        })
      }
    }
    if pendingText.length > 0 {
      children.push(RenderedChild { text: quoteJs(pendingText), row: pendingTextRow })
    }
  }

  let needsArray = children.length > 1
  for child of children {
    if child.spread { needsArray = true }
  }
  let helper = usage.jsxAlias
  if needsArray {
    usage.usesJsxs = true
    helper = usage.jsxsAlias
  } else {
    usage.usesJsx = true
  }

  let output = helper + "(" + tag + ", {"
  let propertyCount = 0
  let key = ""
  for attribute of attributes {
    output = padToRow(output, node, attribute.startRow(), source)
    if attribute.kind() == "jsx_expression" {
      spread := jsxExpression(attribute, source, usage)
      if spread.length > 0 {
        if propertyCount > 0 { output += ", " }
        output += spread
        propertyCount += 1
      }
      continue
    }

    nameNode := firstNamedChild(attribute)
    name := nameNode.text(source)
    valueNode := lastAttributeValue(attribute, nameNode)
    let value = "true"
    if valueNode != null {
      value = renderAttributeValue(valueNode!, source, usage)
    }
    if name == "key" {
      key = value
      continue
    }
    if propertyCount > 0 { output += ", " }
    output += quoteJs(name) + ": " + value
    propertyCount += 1
  }

  if children.length == 1 && !needsArray {
    output = padToRow(output, node, children[0].row, source)
    if propertyCount > 0 { output += ", " }
    output += "children: " + children[0].text
  } else if children.length > 0 {
    if propertyCount > 0 { output += ", " }
    output += "children: ["
    for index of 0..<children.length {
      output = padToRow(output, node, children[index].row, source)
      if index > 0 { output += ", " }
      output += children[index].text
    }
    output += "]"
  }
  output += "}"
  if key.length > 0 { output += ", " + key }
  output = padToRow(output, node, node.endRow(), source)
  return output + ")"
}

function renderTag(node: NativeSyntaxNode, source: string): string {
  text := node.text(source)
  if node.kind() == "jsx_namespace_name" {
    return quoteJs(text)
  }
  first := text.charAt(0)
  if (first >= 'a' && first <= 'z') || text.contains("-") {
    return quoteJs(text)
  }
  return text
}

function renderAttributeValue(
  node: NativeSyntaxNode,
  source: string,
  usage: JsxRuntimeUsage,
): string {
  if node.kind() == "string" {
    raw := node.text(source)
    return quoteJs(decodeEntities(raw.substring(1, raw.length - 1)))
  }
  if node.kind() == "jsx_expression" {
    value := jsxExpression(node, source, usage)
    return if value.length > 0 then value else "undefined"
  }
  if node.kind() == "jsx_element" || node.kind() == "jsx_self_closing_element" {
    return renderJsx(node, source, usage)
  }
  return node.text(source)
}

function jsxExpression(
  node: NativeSyntaxNode,
  source: string,
  usage: JsxRuntimeUsage,
): string {
  for index of 0..<node.childCount() {
    child := node.child(index)
    kind := child.kind()
    if !child.isNamed() || kind == "comment" { continue }
    if kind == "jsx_element" || kind == "jsx_self_closing_element" {
      return renderJsx(child, source, usage)
    }
    return child.text(source)
  }
  return ""
}

function isSpreadExpression(node: NativeSyntaxNode): bool {
  for index of 0..<node.childCount() {
    if node.child(index).kind() == "spread_element" { return true }
  }
  return false
}

function fieldChild(node: NativeSyntaxNode, field: string): NativeSyntaxNode | null {
  for index of 0..<node.childCount() {
    if node.childFieldName(index) == field { return node.child(index) }
  }
  return null
}

function firstNamedChild(node: NativeSyntaxNode): NativeSyntaxNode {
  for index of 0..<node.childCount() {
    child := node.child(index)
    if child.isNamed() { return child }
  }
  panic("expected ${node.kind()} to have a named child")
}

function lastAttributeValue(
  attribute: NativeSyntaxNode,
  name: NativeSyntaxNode,
): NativeSyntaxNode | null {
  let result: NativeSyntaxNode | null = null
  for index of 0..<attribute.childCount() {
    child := attribute.child(index)
    if child.isNamed() && child.startByte() != name.startByte() {
      result = child
    }
  }
  return result
}
