# install-sysbench.ps1
# Installs the unpacked payload to "C:\sysbench"
# Adds C:\sysbench\bin to PATH (Machine if possible, else User). No admin required for install path.

$ErrorActionPreference = 'Stop'

# ---- Paths
$src  = Split-Path -Parent $PSCommandPath                    # unzipped package root (where this script lives)
$dest = Join-Path $env:SystemDrive 'sysbench'                # C:\sysbench
$bin  = Join-Path $dest 'bin'
Write-Host "Source: $src"
Write-Host "Destination: $dest"

# ---- Create destination and copy payload (exclude installer scripts)
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

# Use robocopy; ignore its nonzero 'success' exit codes
$rcArgs = @(
  "`"$src`"", "`"$dest`"", "/E", "/R:3", "/W:1",
  "/XD", ".git",
  "/XF", "install-sysbench.ps1", "install-sysbench.bat"
)
$null = Start-Process -FilePath robocopy -ArgumentList $rcArgs -NoNewWindow -Wait -PassThru

# ---- Sanity check
$exe = Join-Path $bin 'sysbench.exe'
if (-not (Test-Path $exe)) {
  Write-Error "sysbench.exe not found at $exe. Run this from the unzipped package root (the one containing 'bin')."
  exit 2
}

# ---- PATH helpers
function Normalize-Path([string]$p) { $p.TrimEnd('\') }
function Add-ToPath([string]$p, [System.EnvironmentVariableTarget]$scope) {
  $norm = Normalize-Path $p
  $cur  = [Environment]::GetEnvironmentVariable('Path', $scope)
  if ([string]::IsNullOrEmpty($cur)) { $cur = '' }
  $parts = $cur -split ';' | Where-Object { $_ -and $_.Trim() } | ForEach-Object { Normalize-Path $_ }
  if ($parts -notcontains $norm) {
    $new = ($parts + $norm) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, $scope)
    return $true
  }
  return $false
}

# ---- Try Machine PATH; if denied, fall back to User PATH
$addedWhere = $null
try {
  if (Add-ToPath $bin ([EnvironmentVariableTarget]::Machine)) { $addedWhere = 'Machine' }
} catch { }

if (-not $addedWhere) {
  if (Add-ToPath $bin ([EnvironmentVariableTarget]::User)) { $addedWhere = 'User' }
}

# Ensure it's available in THIS process immediately
if (-not ($env:Path -split ';' | ForEach-Object { Normalize-Path $_ } | Where-Object { $_ -eq (Normalize-Path $bin) })) {
  $env:Path = "$env:Path;$bin"
}

# ---- Verify
& $exe --version

if ($addedWhere) {
  Write-Host "Added to $addedWhere PATH: $bin"
} else {
  Write-Host "PATH unchanged (already contained): $bin"
}
Write-Host "sysbench installed to: $dest"
exit 0
