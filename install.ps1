<#
.SYNOPSIS
  Install this repo's ReaScripts, JSFX and FX chains into REAPER.

.DESCRIPTION
  Copies, with a timestamped backup of anything it would overwrite:

    scripts\*.lua              -> <REAPER>\Scripts\
    jsfx\<genre>\*             -> <REAPER>\Effects\stryk\
    fxchains\<genre>\*.RfxChain-> <REAPER>\FXChains\

  Files whose contents already match are skipped and reported as "same", so
  re-running is cheap and shows only real changes.

  JSFX are flattened into one Effects\stryk folder on purpose: REAPER's FX
  browser keys off the `desc:` line and the folder is only a filing detail, so
  the genre split is for the repo's benefit, not REAPER's. Renaming the
  installed folder would orphan every FX chain that references stryk\<name>.

.PARAMETER Genre
  Which jsfx\ and fxchains\ subfolder to install. Defaults to all of them.

.PARAMETER WhatIf
  Show what would change without writing anything.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Genre 'trance130+'
  .\install.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$ReaperDir = "$env:APPDATA\REAPER",
  [string]$Genre
)

if (-not (Test-Path $ReaperDir)) { throw "REAPER resource folder not found: $ReaperDir" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$counts = @{ install = 0; same = 0; backup = 0 }

function Install-Tree {
  # $Include: JSFX have no extension so they cannot be filtered by one, but
  # scripts\ must be limited to *.lua or build artefacts like
  # stryk_build_rs5k_from_slices.lua.check.txt get installed into REAPER too.
  param([string]$Src, [string]$Dest, [string]$Label, [string]$Include)

  if (-not (Test-Path $Src)) { return }
  if (-not (Test-Path $Dest)) {
    if ($PSCmdlet.ShouldProcess($Dest, 'create folder')) {
      New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }
  }

  $items = if ($Include) { Get-ChildItem -Path $Src -File -Filter $Include }
           else          { Get-ChildItem -Path $Src -File }
  $items | ForEach-Object {
    $target = Join-Path $Dest $_.Name
    if (Test-Path $target) {
      if ((Get-FileHash $target).Hash -eq (Get-FileHash $_.FullName).Hash) {
        Write-Host ("same     [{0}] {1}" -f $Label, $_.Name)
        $script:counts.same++
        return
      }
      if ($PSCmdlet.ShouldProcess($target, 'backup')) {
        Copy-Item $target "$target.bak-$stamp"
      }
      Write-Host ("backup   [{0}] {1} -> {1}.bak-{2}" -f $Label, $_.Name, $stamp)
      $script:counts.backup++
    }
    if ($PSCmdlet.ShouldProcess($target, 'install')) {
      Copy-Item $_.FullName $target -Force
    }
    Write-Host ("install  [{0}] {1}" -f $Label, $_.Name)
    $script:counts.install++
  }
}

# --- ReaScripts -----------------------------------------------------------
Install-Tree -Src (Join-Path $PSScriptRoot 'scripts') `
             -Dest (Join-Path $ReaperDir 'Scripts') -Label 'script' -Include '*.lua'

# --- JSFX and FX chains, per genre ---------------------------------------
foreach ($kind in @(
    @{ Dir = 'jsfx';     Dest = Join-Path $ReaperDir 'Effects\stryk'; Label = 'jsfx' },
    @{ Dir = 'fxchains'; Dest = Join-Path $ReaperDir 'FXChains';      Label = 'chain' }
)) {
  $root = Join-Path $PSScriptRoot $kind.Dir
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem -Path $root -Directory | ForEach-Object {
    if ($Genre -and $_.Name -ne $Genre) { return }
    Install-Tree -Src $_.FullName -Dest $kind.Dest -Label ("{0}:{1}" -f $kind.Label, $_.Name)
  }
}

Write-Host ""
Write-Host ("{0} installed, {1} unchanged, {2} backed up -> {3}" -f `
  $counts.install, $counts.same, $counts.backup, $ReaperDir)
Write-Host "JSFX and FX chain changes need a REAPER rescan (Options > Show REAPER resource path"
Write-Host "is not enough): reload the FX, or restart REAPER."
Write-Host ""
Write-Host "The MIDI program-change stripper also needs its startup hook wired:"
Write-Host "  python tools\install_midi_strip_pc.py"
