export class TsError {
  readonly kind: string
  readonly message: string
  readonly line: int
  readonly column: int
}

export enum EditKind {
  Erase = 0,
  EraseStatement = 1,
}

export class Edit {
  readonly start: int
  readonly end: int
  readonly kind: EditKind
}

export class Span {
  readonly start: int
  readonly end: int
}

export class ErasurePlan {
  edits: Edit[]
  comments: Span[]
}

export enum SyntaxDialect {
  TypeScript = 0,
}

export class TsxOptions {
  readonly jsxImportSource: string = "react"
}
