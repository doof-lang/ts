# std/ts Guide

`std/ts` converts erasable TypeScript to JavaScript. It parses one source string,
removes TypeScript-only syntax, and preserves JavaScript syntax, value imports,
and value exports.

## Transform Guarantees

`transpile` replaces removed TypeScript bytes with spaces. This preserves line
and column positions for code that remains, which helps stack traces line up
without source maps.

The module does not type-check, resolve imports, downlevel JavaScript, read
`tsconfig.json`, or emit source maps.

## Unsupported Syntax

Syntax that requires JavaScript generation returns `unsupported-syntax` instead
of being approximated. Examples include enums, runtime namespaces, constructor
parameter properties, import assignments, and export assignments.

Errors are reported as `TsError` with kind, message, one-based line, and Unicode
column. Kinds are `syntax`, `unsupported-syntax`, and `internal`.

## TSX

`transpileTsx` supports the production automatic JSX runtime. The default
`jsxImportSource` is `react`; helpers are imported from
`<jsxImportSource>/jsx-runtime`.

The transform emits only helpers that are used:

- `_jsx` for zero or one child
- `_jsxs` for multiple children
- `Fragment` for fragments

Development mode and the classic JSX transform are not supported. Generated
columns and byte offsets are not stable, but user-code line endings are
preserved and the runtime import is appended after transformed user code.

## API Map

Top-level helpers:

- `transpile`
- `transpileTsx`
- `transpileWithDialect`

Options and diagnostics:

- `TsError`
- `TsxOptions`
- diagnostic and erasure-plan helper types

Implementation files:

- [index.do](../index.do)
- [tsx.do](../tsx.do)
- [eraser.do](../eraser.do)
- [diagnostics.do](../diagnostics.do)
- [types.do](../types.do)
