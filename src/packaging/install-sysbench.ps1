# install-sysbench.ps1
# Installs the unpacked payload to "C:\sysbench"
# Adds C:\sysbench\bin to PATH (Machine if possible, else User).
# Repairs corrupted PATH strings (e.g. "...WindowsAppsC:\sysbench\bin...") and de-dupes sysbench entries.

$ErrorActionPreference = 'Stop'

# ---- Paths
$src  = Split-Path -Parent $PSCommandPath                    # unzipped package root (where this script lives)
$dest = Join-Path $env:SystemDrive 'sysbench'                # C:\sysbench
$bin  = Join-Path $dest 'bin'
Write-Host "Source: $src"
Write-Host "Destination: $dest"

# ---- Create destination and copy payload (exclude installer scripts)
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

# Use robocopy; treat exit codes 0..7 as success
$rcArgs = @(
  "`"$src`"", "`"$dest`"", "/E", "/R:3", "/W:1",
  "/XD", ".git",
  "/XF", "install-sysbench.ps1", "install-sysbench.bat"
)
$rc = Start-Process -FilePath robocopy -ArgumentList $rcArgs -NoNewWindow -Wait -PassThru
if ($null -ne $rc.ExitCode -and $rc.ExitCode -gt 7) {
  throw "robocopy failed with exit code $($rc.ExitCode)"
}

# ---- Sanity check
$exe = Join-Path $bin 'sysbench.exe'
if (-not (Test-Path $exe)) {
  Write-Error "sysbench.exe not found at $exe. Run this from the unzipped package root (the one containing 'bin')."
  exit 2
}

# ---- PATH helpers
function Normalize-Path([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  $p.Trim().Trim('"').TrimEnd('\')
}

function Repair-PathString([string]$s) {
  if ([string]::IsNullOrEmpty($s)) { return '' }

  # Insert missing ';' before concatenated drive-letter path:
  # "...WindowsAppsC:\sysbench\bin" -> "...WindowsApps;C:\sysbench\bin"
  $s = $s -replace '(?<!^)(?<!;)(?=[A-Za-z]:\\)', ';'

  # Optional: insert missing ';' before concatenated UNC path (rare)
  $s = $s -replace '(?<!^)(?<!;)(?=\\\\)', ';'

  # Collapse repeated separators and trim edges
  $s = $s -replace ';{2,}', ';'
  $s.Trim(';')
}

function Get-PathParts([string]$raw) {
  $fixed = Repair-PathString $raw
  $fixed -split ';' |
    ForEach-Object { Normalize-Path $_ } |
    Where-Object { $_ }
}

function Set-PathParts([string[]]$parts, [System.EnvironmentVariableTarget]$scope) {
  [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), $scope)
}

function Dedupe-PathParts([string[]]$parts) {
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($p in $parts) {
    if ($seen.Add($p)) { [void]$out.Add($p) }
  }
  ,$out.ToArray()
}

function Ensure-SinglePathEntry(
  [string]$entry,
  [System.EnvironmentVariableTarget]$scope,
  [bool]$AddEntry
) {
  $normEntry = Normalize-Path $entry
  $curRaw    = [Environment]::GetEnvironmentVariable('Path', $scope)
  $parts     = Get-PathParts $curRaw

  # Remove ALL sysbench bin occurrences that may be embedded in a corrupted token
  # (e.g. "C:\sysbench\binC:\sysbench\bin..." or "...WindowsAppsC:\sysbench\bin...")
  # First repair string to split correctly; then remove exact matches.
  $parts = $parts | Where-Object { $_ -ne $normEntry }

  # Remove obvious broken/truncated sysbench fragments if any (example: "C:\sysbench\binC")
  $parts = $parts | Where-Object { $_ -notmatch '^(?i)C:\\sysbench\\bin[A-Za-z]$' }

  if ($AddEntry) { $parts += $normEntry }

  $unique = Dedupe-PathParts $parts
  Set-PathParts $unique $scope
}

# ---- PATH policy:
# - Prefer Machine PATH if possible
# - If Machine contains sysbench already, remove sysbench from User (avoid duplicates across scopes)
# - If we successfully add to Machine, also remove from User
# - Otherwise add to User
$normBin = Normalize-Path $bin
$addedWhere = $null

$machineParts = Get-PathParts ([Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine))
$machineHas   = $machineParts -contains $normBin

if ($machineHas) {
  try { Ensure-SinglePathEntry -entry $bin -scope ([EnvironmentVariableTarget]::User) -AddEntry:$false } catch { }
  $addedWhere = 'Machine (already present); cleaned User'
} else {
  try {
    Ensure-SinglePathEntry -entry $bin -scope ([EnvironmentVariableTarget]::Machine) -AddEntry:$true
    try { Ensure-SinglePathEntry -entry $bin -scope ([EnvironmentVariableTarget]::User) -AddEntry:$false } catch { }
    $addedWhere = 'Machine'
  } catch {
    Ensure-SinglePathEntry -entry $bin -scope ([EnvironmentVariableTarget]::User) -AddEntry:$true
    $addedWhere = 'User'
  }
}

# ---- Ensure it's available in THIS process immediately (repair/dedupe session PATH too)
$sessionParts = Get-PathParts $env:Path | Where-Object { $_ -ne $normBin }
$sessionParts += $normBin
$sessionParts = Dedupe-PathParts $sessionParts
$env:Path = ($sessionParts -join ';')

# ---- Verify
& $exe --version

Write-Host "sysbench installed to: $dest"
Write-Host "PATH updated: $addedWhere -> $bin"
exit 0
