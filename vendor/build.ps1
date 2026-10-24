# Builds lib\tree-sitter.lib with the TypeScript and TSX grammars and installs
# the public tree-sitter header into include\.
# Runs inside a private copy of vendor\ with CC, AR, and CFLAGS supplied by
# the Doof compiler from a Visual Studio developer environment.
$ErrorActionPreference = 'Stop'

$library = 'tree-sitter.lib'
$defines = @()
$includes = @('/Itree-sitter\lib\include', '/Itree-sitter\lib\src', '/Itree-sitter-typescript\typescript\src', '/Itree-sitter-typescript\tsx\src')
$sources = 'tree-sitter\lib\src\lib.c',
  'tree-sitter-typescript\typescript\src\parser.c', 'tree-sitter-typescript\typescript\src\scanner.c',
  'tree-sitter-typescript\tsx\src\parser.c', 'tree-sitter-typescript\tsx\src\scanner.c'

function Install-Headers {
  New-Item -ItemType Directory -Force -Path include\tree_sitter | Out-Null
  Copy-Item tree-sitter\lib\include\tree_sitter\api.h include\tree_sitter\
}

New-Item -ItemType Directory -Force -Path include, lib, obj | Out-Null
Install-Headers

$flags = @()
if ($env:CFLAGS) { $flags = $env:CFLAGS -split ' ' | Where-Object { $_ -ne '' } }
$objects = @()
foreach ($source in $sources) {
  $object = 'obj\' + ($source -replace '[\\/]', '_' -replace '\.c$', '.obj')
  & $env:CC @flags @defines @includes /TC /c $source "/Fo$object"
  if ($LASTEXITCODE -ne 0) { throw "Compiling $source failed" }
  $objects += $object
}

& $env:AR /nologo "/OUT:lib\$library" @objects
if ($LASTEXITCODE -ne 0) { throw "Archiving $library failed" }
