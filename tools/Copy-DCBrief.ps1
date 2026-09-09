<#
.SYNOPSIS
  Put the DC brief on the clipboard, ready to paste into an agent with no file access.

.DESCRIPTION
  DC (and any chat-only agent) cannot read the repo, cannot clone a remote, and cannot
  open a path. The only thing that always works is pasted text. This loads the brief
  straight onto the clipboard.

  -WithScript appends the full current source of stryk_build_rs5k_from_slices.lua, for when
  DC needs to review the code rather than just the findings.

.EXAMPLE
  .\tools\Copy-DCBrief.ps1
  .\tools\Copy-DCBrief.ps1 -WithScript
#>
[CmdletBinding()]
param([switch]$WithScript)

$root   = Split-Path $PSScriptRoot -Parent
$brief  = Join-Path $root 'docs\DC-BRIEF.md'
$script = Join-Path $root 'scripts\stryk_build_rs5k_from_slices.lua'

if (-not (Test-Path $brief)) { throw "Brief not found: $brief" }
$text = Get-Content $brief -Raw

if ($WithScript) {
  if (-not (Test-Path $script)) { throw "Script not found: $script" }
  $text += "`n`n---`n`n## Current source: scripts/stryk_build_rs5k_from_slices.lua`n`n" +
           '```lua' + "`n" + (Get-Content $script -Raw).TrimEnd() + "`n" + '```' + "`n"
}

Set-Clipboard -Value $text
$lines = ($text -split "`n").Count
$kb    = [math]::Round(($text.Length / 1KB), 1)
Write-Host "copied to clipboard: $lines lines, $kb KB$(if($WithScript){' (brief + full script)'}else{' (brief only)'})"
Write-Host 'paste it straight into DC.'
