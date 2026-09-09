# `build_rs5k_from_slices.lua` — failure diagnosis and fix

**Date:** 2026-09-10
**Subject:** `build_rs5k_from_slices.lua` "failing to execute" in REAPER v7.79
**Status:** Fixed, verified end-to-end, installed to all three copies

---

## Summary

The script was not broken in the way it appeared. It **did its entire job correctly** —
created the track, built all eight ReaSamplOmatic5000 instances, mapped the notes, and
imported the MIDI — and then threw a fatal error on the **second-to-last line**, before it
could show its success dialog. REAPER surfaced only the error, so it read as "did nothing".

The cause is a single call to a ReaScript function that does not exist.

---

## Root cause

`build_rs5k_from_slices.lua`, line 68 of 71:

```lua
reaper.TrackSelectionChanged(tr)
```

**`reaper.TrackSelectionChanged` is not part of the ReaScript API.** It is `nil`, so calling
it raises:

```
build_rs5k_from_slices.lua:68: attempt to call a nil value (field 'TrackSelectionChanged')
```

Because it sits at line 68 of 71, the error lands *after* all the real work:

```
tracks=1  track="slices" fx=8 items=1   <- the work WAS already done
```

Two further consequences of dying there:

- `reaper.Undo_EndBlock(...)` (line 69) never runs, so the operation is left without a
  clean undo point.
- `reaper.MB(...)` (line 70) never runs, so there is no confirmation dialog — which is
  what made it look like a total failure.

### A hypothesis that was wrong

The working theory going in was that the script was "dying before the file picker", and the
suggested fix was to replace the top of the script with a console-logging version that takes a
pasted folder path instead of using a file dialog, on the reasoning that the dialog was the one
thing that could fail silently.

That was not the problem. Measured, in REAPER's own Lua 5.4:

- the file **compiles clean** — it is not a syntax error, and it is not failing to load
- `reaper.GetUserFileNameForRead` **exists and works**
- the script reaches line 68, i.e. essentially the end

The console logging and pasted-path input were still worth adding, and are in the fix — but as
usability improvements, not as the repair.

---

## What was verified, rather than assumed

Everything below was measured by compiling and running against REAPER's real API table,
in an isolated sandbox instance. Nothing was tested in the live project.

| Check | Method | Result |
| --- | --- | --- |
| Syntax | `load(src)` in REAPER's Lua 5.4 | **Compiles clean** |
| All 28 `reaper.*` symbols | nil-check each against the `reaper` table | Only `TrackSelectionChanged` was nil |
| File encoding | byte inspection | No BOM, no CRLF — not an encoding issue |
| RS5K availability | `TrackFX_AddByName` | Returns `0`; `VSTi: ReaSamplOmatic5000 (Cockos)` |
| Parameter names | full 33-param dump | "Note range start" (3), "Note range end" (4), "Obey note-offs" (11) — **all correct as written** |
| `note / 127` mapping | `TrackFX_GetFormattedParamValue` readback | Reads back as exactly **36, 37, 38, 39 … 43** — correct |
| `InsertMedia` on `.mid` | full run | **Does not prompt** (`midiimport=7`); imported an 8-note item cleanly |
| Whole script, 8 test slices | sandbox run | 8 RS5K, 0 problems, MIDI item present |

The original failure was then **reproduced deliberately** to confirm the diagnosis rather than
infer it — see the error output above.

---

## Two other problems found

### 1. There were three copies of the script, and the fix has to reach all of them

| Path | Was |
| --- | --- |
| `…\beneath-redemption\reaper\SAGI-SYNCED\build_rs5k_from_slices.lua` | broken |
| `…\beneath-redemption\reaper\SAGI-SYNCED\sag-syncmix\build_rs5k_from_slices.lua` | broken (identical md5) |
| `%APPDATA%\REAPER\Scripts\build_rs5k_from_slices.lua` | broken — **this is the one REAPER actually loads** |

All three now carry the fixed version (md5 `79591457dab788ed24d90ef31379f050`).
Originals kept alongside as `.bak-20260910`.

### 2. The script is not registered in REAPER's action list

`%APPDATA%\REAPER\reaper-kb.ini` contains no entry for it. The only script registered from
that project is `build_session.lua`. So it cannot be found in the Actions list by name.

To register: **Actions → Show action list → New action → Load ReaScript…**, and point it at
`%APPDATA%\REAPER\Scripts\build_rs5k_from_slices.lua`.

Do not hand-edit `reaper-kb.ini` while REAPER is running — REAPER rewrites that file on exit
and will discard the change.

---

## The fix

Repaired:

- Removed `reaper.TrackSelectionChanged(tr)`. Replaced with the real API calls that do what it
  was reaching for: `reaper.TrackList_AdjustWindows(false)` and `reaper.UpdateArrange()`.
- Wrapped the whole body in `pcall`, so any future runtime error prints to the console and a
  dialog instead of vanishing, and `PreventUIRefresh` is always unwound.

Added (the console/paste-path changes originally requested):

- **Console logging throughout**, starting with `build_rs5k: started` as the first line, so the
  script's progress is always visible.
- **Folder by pasted path**, resolved in order: `ExtState "build_rs5k"/"folder"` → a text box you
  paste into → leaving the box blank falls back to the original file browser. The ExtState route
  also makes the script callable from another script, and is how it is driven under test.

Hardened:

- Case-insensitive `.wav` / `.mid` / `.midi` matching.
- Sorts on the **last** number in the filename, so `slice 2` precedes `slice 10`.
- Strips `"Copy as path"` quotes and trailing separators from pasted paths.
- Reports per-slice if a sample fails to load, or if an RS5K parameter name does not match.
- Remembers the last folder used and pre-fills the box with it.

---

## Verification of the fix

Run against a synthetic fixture of 8 slice wavs plus a test MIDI:

```
build_rs5k: started   (REAPER 7.79/x64, Lua 5.4)
folder = G:\tmp\rs5k-test\slices
scanned 9 entries -> 8 wav, 1 mid
track 0 created: slices
  [01] note  36  <- slice 001.wav
  …
  [08] note  43  <- slice 008.wav
built 8 RS5K instances (0 problems)
importing MIDI: …\testpattern.mid
  MIDI import returned OK
build_rs5k: DONE

track name="slices"  fx=8  items=1
  fx0 01 n36 slice 001.wav   noteStart=36  noteEnd=36  obeyOff=0
  fx1 02 n37 slice 002.wav   noteStart=37  noteEnd=37  obeyOff=0
  fx7 (last)                 noteStart=43
  item0 pos=0.000 len=2.518 midi=true notes=8
```

---

## Outstanding

**There is no slice folder yet.** Nothing named `slices` exists anywhere under
`beneath-redemption`. The only folder there holding wavs is
`…\SAGI-SYNCED\sag-syncmix\Media`, which contains `sagiloop.wav` and
`alphazone-intro-2bar-143t2 001.wav` — the latter being **214 bytes**, i.e. an empty render.

The script will now run and report correctly, but it has nothing to be pointed at until a slice
set is produced.

---

## Reusable lessons

1. **A ReaScript that calls a non-existent `reaper.*` function fails at runtime, not load time.**
   The script compiles, starts, does its work, and dies wherever the bad call sits. If that call
   is near the end, the symptom is "it did nothing" while it actually did everything. Check the
   *line number* in the error before theorising about the top of the file.

2. **Nil-check API symbols before debugging behaviour.** `tools/check_reascript.lua` compiles a
   target and nil-checks every `reaper.*` name it references, without running it. It found this
   bug in one pass.

3. **Never test in the live instance**, particularly when the title bar says `[modified]`.
   `tools/Invoke-ReaperSandbox.ps1` launches an isolated instance via `-newinst -cfgfile`.

4. **Always disable VST scanning on a sandbox launch.** A fresh instance that inherits real VST
   paths re-scans the whole plugin set. Blank `vstpath`/`vstpath64` in the sandbox ini and launch
   drops to ~12 s. Built-in Cockos FX like RS5K are unaffected — they are not VSTs on disk.

5. **Stub the modal calls to test headlessly.** Overriding `reaper.MB`, `reaper.ShowConsoleMsg`
   and `reaper.GetUserFileNameForRead` in a harness before `dofile` lets a dialog-driven script
   run unattended and have its output captured.
