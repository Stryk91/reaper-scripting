<#
.SYNOPSIS
  Run a ReaScript in a throwaway REAPER instance - optionally fully off-screen.

.DESCRIPTION
  Never test a script in the live REAPER instance, especially not when its title says
  [modified]. This launches an isolated instance via -newinst -cfgfile, which keeps its
  own settings file and leaves the real one alone.

  VST scanning is disabled by blanking vstpath/vstpath64 in the sandbox ini. Without
  that, a fresh instance re-scans the whole plugin set on first launch (minutes). With
  it, launch is ~12 s. Built-in Cockos FX such as ReaSamplOmatic5000 are NOT VSTs on
  disk and are still available.

  -Headless runs REAPER on a SEPARATE WINDOWS DESKTOP created with CreateDesktop().
  REAPER has no -nogui switch and always builds a GUI, but a process launched against
  another desktop draws only there. Since that desktop is never switched to, nothing
  appears on your display, nothing steals focus, and no window shows in the taskbar or
  Alt-Tab. The script still runs completely - verified building 8 RS5K instances and
  importing MIDI with no visible window.

.PARAMETER Script
  Path to the .lua to run. REAPER runs trailing .lua arguments in order.

.PARAMETER Headless
  Run on a hidden desktop so nothing appears on screen.

.PARAMETER KeepOpen
  Leave the sandbox instance running instead of killing it when done.

.PARAMETER StageEffects
  Copy Effects\stryk and FXChains from the real profile into the sandbox.
  Required to test anything that loads an on-disk JSFX: -cfgfile moves the whole
  resource path, so without this TrackFX_AddByName returns -1 for every JSFX and
  looks exactly like a broken effect.

.EXAMPLE
  .\Invoke-ReaperSandbox.ps1 -Script .\tools\check_reascript.lua -Headless
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Script,
  [string]$ReaperExe   = 'E:\Reaper\reaper.exe',
  [string]$SourceIni   = "$env:APPDATA\REAPER\reaper.ini",
  [string]$DesktopName = 'ReaperHeadless',
  [switch]$Headless,
  [switch]$KeepOpen,
  [switch]$StageEffects,
  [int]$TimeoutSec = 25
)

if (-not (Test-Path $ReaperExe)) { throw "REAPER not found at $ReaperExe" }
if (-not (Test-Path $Script))    { throw "Script not found at $Script" }
$Script = (Resolve-Path $Script).Path

$sandboxDir = Join-Path $env:TEMP 'reaper-sandbox'
if (-not (Test-Path $sandboxDir)) { New-Item -ItemType Directory -Path $sandboxDir | Out-Null }
$ini = Join-Path $sandboxDir 'sandbox.ini'

# Copy the real ini so prefs are realistic, then kill VST scanning.
if (Test-Path $SourceIni) {
  (Get-Content $SourceIni) -replace '^vstpath64=.*', 'vstpath64=' -replace '^vstpath=.*', 'vstpath=' |
    Set-Content $ini -Encoding ASCII
} else {
  "[REAPER]`nvstpath=`nvstpath64=" | Set-Content $ini -Encoding ASCII
}

# -cfgfile relocates REAPER's ENTIRE resource path to the ini's folder, not just
# its settings. GetResourcePath() in the sandbox returns this directory, so the
# real profile's Effects, FXChains and Scripts are all invisible. Built-in Cockos
# FX still work (ReaSamplOmatic5000 is not a file on disk), which is why script
# tests passed for months without anyone noticing - but an on-disk JSFX resolves
# to -1 from TrackFX_AddByName, indistinguishable from "your JSFX is broken".
if ($StageEffects) {
  foreach ($sub in @('Effects\stryk', 'FXChains')) {
    $src = Join-Path (Split-Path $SourceIni -Parent) $sub
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $sandboxDir $sub
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item (Join-Path $src '*') $dst -Recurse -Force
    Write-Host "sandbox: staged $sub ($((Get-ChildItem $dst -File).Count) files)"
  }
}

# Only ever kill instances we started.
$before = @((Get-Process -Name reaper* -ErrorAction SilentlyContinue).Id)
$pidStarted = $null

if ($Headless) {
  Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class ReaperNat{
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
 public struct STARTUPINFO{public int cb;public string lpReserved;public string lpDesktop;public string lpTitle;
  public int dwX;public int dwY;public int dwXSize;public int dwYSize;public int dwXCountChars;public int dwYCountChars;
  public int dwFillAttribute;public int dwFlags;public short wShowWindow;public short cbReserved2;public IntPtr lpReserved2;
  public IntPtr hStdInput;public IntPtr hStdOutput;public IntPtr hStdError;}
 [StructLayout(LayoutKind.Sequential)]
 public struct PROCESS_INFORMATION{public IntPtr hProcess;public IntPtr hThread;public int dwProcessId;public int dwThreadId;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 public static extern IntPtr CreateDesktop(string d,IntPtr dev,IntPtr dm,int flags,uint access,IntPtr sa);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 public static extern bool CreateProcess(string app,string cmd,IntPtr pa,IntPtr ta,bool inherit,uint flags,
  IntPtr env,string cwd,ref STARTUPINFO si,out PROCESS_INFORMATION pi);
}
'@ -ErrorAction SilentlyContinue

  $hDesk = [ReaperNat]::CreateDesktop($DesktopName, [IntPtr]::Zero, [IntPtr]::Zero, 0, 0x10000000, [IntPtr]::Zero)
  if ($hDesk -eq [IntPtr]::Zero) {
    throw "CreateDesktop failed: $(([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())).Message)"
  }

  $si = New-Object ReaperNat+STARTUPINFO
  $si.cb = [Runtime.InteropServices.Marshal]::SizeOf($si)
  $si.lpDesktop = $DesktopName
  $pi = New-Object ReaperNat+PROCESS_INFORMATION
  $cmd = '"' + $ReaperExe + '" -newinst -cfgfile "' + $ini + '" "' + $Script + '"'

  # lpApplicationName and lpCurrentDirectory must be real values here - passing $null
  # for the working directory fails with ERROR_INVALID_NAME (123).
  $ok = [ReaperNat]::CreateProcess($ReaperExe, $cmd, [IntPtr]::Zero, [IntPtr]::Zero, $false, 0,
        [IntPtr]::Zero, (Split-Path $ReaperExe -Parent), [ref]$si, [ref]$pi)
  if (-not $ok) {
    throw "CreateProcess failed: $(([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())).Message)"
  }
  $pidStarted = $pi.dwProcessId
  Write-Host "sandbox: running headless on desktop '$DesktopName', pid $pidStarted"
} else {
  Write-Host "sandbox: launching $ReaperExe (no VST scan)"
  Start-Process -FilePath $ReaperExe -ArgumentList @('-newinst', '-cfgfile', "`"$ini`"", "`"$Script`"") | Out-Null
}

Start-Sleep -Seconds $TimeoutSec

if (-not $KeepOpen) {
  if ($pidStarted) {
    Stop-Process -Id $pidStarted -Force -ErrorAction SilentlyContinue
    Write-Host "sandbox: stopped pid $pidStarted"
  } else {
    foreach ($p in (Get-Process -Name reaper* -ErrorAction SilentlyContinue)) {
      if ($before -notcontains $p.Id) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Host "sandbox: stopped pid $($p.Id)"
      }
    }
  }
}
Write-Host 'sandbox: done'
