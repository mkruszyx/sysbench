# install-sysbench.ps1
# Installs the unpacked payload to "C:\Program Files\sysbench"
# and adds ...\sysbench\bin to the *machine* PATH (admin required).

$ErrorActionPreference = 'Stop'

# ---- Admin check (required for Program Files + machine PATH)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Administrator privileges are required. Right-click PowerShell and 'Run as administrator', or run this via an elevated process."
  exit 1
}

# ---- Paths
$src = Split-Path -Parent $PSCommandPath
$progX86 = $env:ProgramFilesx86
if ([string]::IsNullOrWhiteSpace($progX86)) { $progX86 = $env:ProgramFiles }
$dest = Join-Path $progX86 'sysbench'
$bin  = Join-Path $dest 'bin'

Write-Host "Source: $src"
Write-Host "Destination: $dest"

if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

$rcArgs = @(
  "`"$src`"", "`"$dest`"", "/E", "/R:3", "/W:1",
  "/XD", ".git",
  "/XF", "install-sysbench.ps1", "install-sysbench.bat", "uninstall-sysbench.ps1", "uninstall-sysbench.bat"
)
$null = Start-Process -FilePath robocopy -ArgumentList $rcArgs -NoNewWindow -Wait -PassThru

# ---- Sanity check
$exe = Join-Path $bin 'sysbench.exe'
if (-not (Test-Path $exe)) {
  Write-Error "sysbench.exe not found at $exe. Make sure you ran this script from the unzipped package root (the one containing 'bin')."
  exit 2
}

# ---- Add to machine PATH (idempotent)
function Normalize-Path([string]$p) { ($p.TrimEnd('\') ) }
$binNorm = Normalize-Path $bin
$machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
$parts = $machinePath -split ';' | Where-Object { $_ -and $_.Trim() } | ForEach-Object { Normalize-Path $_ }

if ($parts -notcontains $binNorm) {
  $newPath = ($parts + $binNorm) -join ';'
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
  Write-Host "Added to machine PATH: $binNorm"
} else {
  Write-Host "Machine PATH already contains: $binNorm"
}

# Make it available immediately in this session, too
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine')

# ---- Verify
& $exe --version
Write-Host "sysbench installed to: $dest"
exit 0
