#!/bin/sh
# Builds lib/libtree-sitter.a with the TypeScript and TSX grammars and installs
# the public tree-sitter header into include/.
# Runs inside a private copy of vendor/ with CC, AR, CFLAGS, and DOOF_JOBS
# supplied by the Doof compiler.
set -eu

library=libtree-sitter.a
defines=""
includes="-Itree-sitter/lib/include -Itree-sitter/lib/src -Itree-sitter-typescript/typescript/src -Itree-sitter-typescript/tsx/src"
jobs=${DOOF_JOBS:-1}
sources="tree-sitter/lib/src/lib.c
  tree-sitter-typescript/typescript/src/parser.c tree-sitter-typescript/typescript/src/scanner.c
  tree-sitter-typescript/tsx/src/parser.c tree-sitter-typescript/tsx/src/scanner.c"

install_headers() { mkdir -p include/tree_sitter && cp tree-sitter/lib/include/tree_sitter/api.h include/tree_sitter/; }

mkdir -p include lib obj
install_headers

pids=''
active=0
status=0
objects=''
for source in $sources; do
  object="obj/$(echo "$source" | sed 's|/|_|g; s|\.c$|.o|')"
  objects="$objects $object"
  # shellcheck disable=SC2086
  $CC $CFLAGS $defines $includes -c "$source" -o "$object" &
  pids="$pids $!"
  active=$((active + 1))
  if [ "$active" -ge "$jobs" ]; then
    for pid in $pids; do wait "$pid" || status=1; done
    pids=''
    active=0
  fi
done
for pid in $pids; do wait "$pid" || status=1; done
[ "$status" -eq 0 ]

rm -f "lib/$library"
# shellcheck disable=SC2086
$AR rcs "lib/$library" $objects
