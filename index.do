import { transpileWithDialect } from "./eraser"
import { transpileTsxSource } from "./tsx"
import { SyntaxDialect, TsError, TsxOptions } from "./types"

export { TsError, TsxOptions } from "./types"

export function transpile(source: string): Result<string, TsError> {
  return transpileWithDialect(source, SyntaxDialect.TypeScript)
}

export function transpileTsx(
  source: string,
  options: TsxOptions = TsxOptions {},
): Result<string, TsError> {
  return transpileTsxSource(source, options)
}
