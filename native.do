export import class NativeSyntaxNode from "./native_syntax_tree.hpp" as doof_ts::NativeSyntaxNode {
  isolated kind(): string
  isolated startByte(): int
  isolated endByte(): int
  isolated startRow(): int
  isolated endRow(): int
  isolated childCount(): int
  isolated child(index: int): NativeSyntaxNode
  isolated childFieldName(index: int): string
  isolated isNamed(): bool
  isolated isMissing(): bool
  isolated isError(): bool
  isolated hasError(): bool
  isolated text(source: string): string
}

export import isolated function parseTypeScript(source: string): Result<NativeSyntaxNode, string>
  from "./native_syntax_tree.hpp" as doof_ts::parseTypeScript

export import isolated function parseTsx(source: string): Result<NativeSyntaxNode, string>
  from "./native_syntax_tree.hpp" as doof_ts::parseTsx
