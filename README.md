# std/ts

Whitespace-preserving conversion from erasable TypeScript to JavaScript.

```do
import { transpile } from "std/ts"

try javascript := transpile("const answer: number = 42")
```

`transpile` parses one source string, removes erasable TypeScript syntax, and
leaves JavaScript syntax and value imports/exports unchanged. Removed bytes are
replaced with spaces, retaining line and column positions for stack traces.

The module does not type-check, resolve imports, downlevel JavaScript, or read a
`tsconfig.json`. Syntax that needs JavaScript generation—such as enums, runtime
namespaces, constructor parameter properties, import assignments, and export
assignments—is returned as an `unsupported-syntax` error.

## Documentation

- [Guide and API reference](docs/API.md) explains erasable TypeScript, unsupported syntax, diagnostics, TSX runtime emission, and transform guarantees.
- Tests can be run with `doof test ts`.

## Errors

Failures return `TsError` with a `kind`, human-readable `message`, and one-based
`line` and Unicode `column`. Error kinds are `syntax`, `unsupported-syntax`, and
`internal`.

## TSX

Use `transpileTsx` for TSX and the production automatic JSX runtime:

```do
import { transpileTsx, TsxOptions } from "std/ts"

try javascript := transpileTsx("const view = <div>Hello</div>")
try preact := transpileTsx(
  "const view = <div>Hello</div>",
  TsxOptions { jsxImportSource: "preact" },
)
```

The default `jsxImportSource` is `react`. Runtime helpers are imported from
`<jsxImportSource>/jsx-runtime`; only the helpers used by the source are emitted.
The transform uses `_jsx` for zero or one child, `_jsxs` for multiple children,
and `Fragment` for fragments. Development mode and the classic JSX transform are
not supported.

TSX generation preserves the source's line endings within transformed user code,
so following statements and multiline expression children retain their original
line numbers. Generated columns and byte offsets are not stable, and source maps
are not produced. The runtime import is appended after the transformed source so
it does not shift user-code lines. `transpile` remains TypeScript-only and retains
its stronger whitespace-preserving byte-position guarantee.
