<#
.SYNOPSIS
  Copy scripts/*.lua into REAPER's Scripts folder, backing up anything replaced.
#>
[CmdletBinding()]
param([string]$Dest = "$env:APPDATA\REAPER\Scripts")

$src = Join-Path $PSScriptRoot 'scripts'
if (-not (Test-Path $Dest)) { throw "REAPER Scripts folder not found: $Dest" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Get-ChildItem -Path $src -Filter *.lua | ForEach-Object {
  $target = Join-Path $Dest $_.Name
  if (Test-Path $target) {
    if ((Get-FileHash $target).Hash -eq (Get-FileHash $_.FullName).Hash) {
      Write-Host "same     $($_.Name)"; return
    }
    Copy-Item $target "$target.bak-$stamp"
    Write-Host "backup   $($_.Name) -> $($_.Name).bak-$stamp"
  }
  Copy-Item $_.FullName $target -Force
  Write-Host "install  $($_.Name)"
}
Write-Host "done -> $Dest"
