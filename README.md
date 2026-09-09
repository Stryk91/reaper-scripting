# reaper-scripting

Version control and a test harness for the ReaScript work across `G:\pipelines`.

REAPER loads scripts from `%APPDATA%\REAPER\Scripts\`, which lives on `C:\` — and `C:\`
has already been wiped once (the 2026-08-01 reinstall). Anything that exists only there
is one boot failure from gone. This repo is the source of truth; `install.ps1` pushes
copies into REAPER.

## Layout

| Path | What |
| --- | --- |
| `scripts/` | The ReaScripts themselves. Source of truth. |
| `tools/check_reascript.lua` | Compiles a script and nil-checks every `reaper.*` symbol it calls, without running it. |
| `tools/Invoke-ReaperSandbox.ps1` | Runs a script in an isolated REAPER instance, optionally fully off-screen. |
| `docs/` | Diagnoses and post-mortems. |
| `install.ps1` | Copies `scripts/*.lua` into `%APPDATA%\REAPER\Scripts\`, backing up what it replaces. |

## The two rules that matter

**1. Nil-check before you theorise.** A ReaScript calling a `reaper.*` function that does
not exist compiles fine, starts fine, does its work, and *then* throws
`attempt to call a nil value` wherever the bad call sits. If that is near the end, the
symptom is "it did nothing" while it actually did everything. This exact bug cost a full
debugging session — see `docs/2026-09-10-build-rs5k-diagnosis.md`.

```powershell
.\tools\Invoke-ReaperSandbox.ps1 -Script .\tools\check_reascript.lua -Headless
```

**2. Never test in the live instance.** Especially not when the title bar says
`[modified]`. Use the sandbox. It always disables VST scanning — a fresh instance that
inherits the real VST paths re-scans every plugin (minutes); blanked, it launches in ~12 s.
Built-in Cockos FX like ReaSamplOmatic5000 are unaffected, they are not VSTs on disk.

## Headless

REAPER has no `-nogui` switch and always builds a GUI. `-Headless` works around that by
creating a separate Windows desktop with `CreateDesktop()` and launching REAPER against
it. That desktop is never switched to, so nothing is drawn on your display, nothing steals
focus, and no window appears in the taskbar or Alt-Tab. Verified running a full build of 8
RS5K instances plus a MIDI import with no visible window.

## Registering a script in REAPER

Actions → Show action list → New action → Load ReaScript…, pointing at the copy in
`%APPDATA%\REAPER\Scripts\`. Do not hand-edit `reaper-kb.ini` while REAPER is running —
it rewrites that file on exit and will discard the change.
