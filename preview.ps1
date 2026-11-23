#Requires -Version 5.1
<#
.SYNOPSIS
  Render an .excalidraw file to PNG and open it in the current Zed window.

.DESCRIPTION
  Invoked by the Zed task "Excalidraw: Preview" with $ZED_FILE.
  Writes <stem>.png next to the source and opens it with `zed -e` so it
  appears as an image tab. Exits non-zero on any failure without opening Zed.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$File
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("excalidraw-preview: $Message")
    exit 1
}

# Resolve the input path and validate it.
if (-not [IO.Path]::IsPathRooted($File)) {
    Fail "expected an absolute path, got: $File"
}
if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    Fail "file does not exist: $File"
}
if ([IO.Path]::GetExtension($File).ToLowerInvariant() -ne '.excalidraw') {
    Fail "expected a .excalidraw file, got: $File"
}

$png = [IO.Path]::ChangeExtension($File, '.png')

# Locate exv.
$exv = Get-Command exv -ErrorAction SilentlyContinue
if (-not $exv) {
    Fail 'exv not found on PATH (install excalidraw-tui)'
}

# Render. exv writes the PNG directly to $png.
& $exv.Source $File -f png -o $png
if ($LASTEXITCODE -ne 0) {
    Fail "exv failed to render $File (exit $LASTEXITCODE)"
}
if (-not (Test-Path -LiteralPath $png -PathType Leaf)) {
    Fail "exv reported success but did not create $png"
}

# Locate Zed's CLI. Prefer PATH; fall back to the standard Windows install path.
$zed = Get-Command Zed.exe -ErrorAction SilentlyContinue
if (-not $zed) {
    $zedFallback = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\Zed.exe'
    if (Test-Path -LiteralPath $zedFallback -PathType Leaf) {
        $zed = $zedFallback
    }
}
if (-not $zed) {
    Fail 'Zed.exe not found on PATH or at the default install location'
}

# -e opens in the existing window instead of creating a new one.
$zedPath = if ($zed -is [System.Management.Automation.CommandInfo]) { $zed.Source } else { $zed }
& $zedPath -e $png
if ($LASTEXITCODE -ne 0) {
    Fail "failed to open preview in Zed (exit $LASTEXITCODE)"
}
