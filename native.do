export import class NativeSyntaxNode from "./native_syntax_tree.hpp" as doof_ts::NativeSyntaxNode {
  kind(): string
  startByte(): int
  endByte(): int
  startRow(): int
  endRow(): int
  childCount(): int
  child(index: int): NativeSyntaxNode
  childFieldName(index: int): string
  isNamed(): bool
  isMissing(): bool
  isError(): bool
  hasError(): bool
  text(source: string): string
}

export import function parseTypeScript(source: string): Result<NativeSyntaxNode, string>
  from "./native_syntax_tree.hpp" as doof_ts::parseTypeScript

export import function parseTsx(source: string): Result<NativeSyntaxNode, string>
  from "./native_syntax_tree.hpp" as doof_ts::parseTsx
