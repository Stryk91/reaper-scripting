# build_rs5k_from_slices.lua — brief for an agent with no file access

Self-contained. Everything needed is inline; no paths need to be opened.

## What was wrong

`build_rs5k_from_slices.lua` line 68 of 71:

```lua
reaper.TrackSelectionChanged(tr)
```

**`reaper.TrackSelectionChanged` is not part of the ReaScript API.** It is `nil`. Calling it
raises, at runtime:

```
build_rs5k_from_slices.lua:68: attempt to call a nil value (field 'TrackSelectionChanged')
```

## Why it looked like it did nothing

The bad call is at line 68 of 71, so the error lands *after* all the real work. Reproduced
deliberately, with the file picker stubbed:

```
ORIGINAL SCRIPT: pcall ok=false
error: ...build_rs5k_from_slices.lua:68: attempt to call a nil value (field 'TrackSelectionChanged')
tracks=1  track="slices" fx=8 items=1   <- the work WAS already done
```

The track, all eight ReaSamplOmatic5000 instances, the note mapping and the MIDI import had
all completed. Dying at line 68 meant:

- line 69 `Undo_EndBlock` never ran — no clean undo point
- line 70 `reaper.MB(...)` never ran — **no success dialog**, which is what made it read as
  total failure

## The hypothesis that was wrong

The working theory was that the script was dying *before* the file picker, and that the dialog
was the one thing that could fail silently. Measured in REAPER's own Lua 5.4:

- the file **compiles clean** — not a syntax error, not a load failure
- `reaper.GetUserFileNameForRead` **exists and works**
- execution reaches line 68, i.e. essentially the end

Console logging and pasted-path input were still added, but as usability improvements, not as
the repair. The lesson: **check the line number in the error before theorising about the top of
the file.**

## What was verified rather than assumed

| Check | Result |
| --- | --- |
| Syntax (`load()` in REAPER Lua 5.4) | Compiles clean |
| All 28 `reaper.*` symbols nil-checked | Only `TrackSelectionChanged` was nil |
| Encoding | No BOM, no CRLF |
| `TrackFX_AddByName("ReaSamplOmatic5000")` | Returns 0 — loads fine |
| RS5K parameter names | "Note range start" (3), "Note range end" (4), "Obey note-offs" (11) — **all correct as originally written** |
| `note / 127` mapping | Read back via `GetFormattedParamValue` as exactly 36, 37, 38, 39 … 43 — correct |
| `InsertMedia` on a `.mid` | Does **not** prompt (`midiimport=7`); imported an 8-note item cleanly |
| Full run on 8 test slices | 8 RS5K, 0 problems, MIDI item present |

## The fix

- Removed `reaper.TrackSelectionChanged(tr)`; replaced with the real calls it was reaching for:
  `reaper.TrackList_AdjustWindows(false)` and `reaper.UpdateArrange()`.
- Wrapped the body in `pcall` so any future runtime error prints to console and a dialog
  instead of vanishing, and `PreventUIRefresh` is always unwound.
- Console logging throughout, first line `build_rs5k: started`.
- Folder resolved in order: ExtState `build_rs5k`/`folder` → a paste box → blank falls back to
  the original file browser. The ExtState route also makes it callable from another script and
  is how it is driven under test.
- Case-insensitive `.wav`/`.mid`/`.midi`; sorts on the **last** number in the filename so
  `slice 2` precedes `slice 10`; strips "Copy as path" quotes and trailing separators;
  per-slice warning if a sample fails to load or a parameter name does not match.

## Two other problems found

1. **Three copies of the script existed** — in `SAGI-SYNCED\`, in `SAGI-SYNCED\sag-syncmix\`,
   and in `%APPDATA%\REAPER\Scripts\`. The last is the one REAPER actually loads, and it was
   still the broken version. All three now carry the fix.
2. **The script is not registered in REAPER's action list.** `reaper-kb.ini` has no entry for
   it, so it cannot be found by name. Register via Actions → New action → Load ReaScript…
   Do not hand-edit `reaper-kb.ini` while REAPER is running; it rewrites that file on exit.

## Verification of the fix

```
build_rs5k: started   (REAPER 7.79/x64, Lua 5.4)
scanned 9 entries -> 8 wav, 1 mid
track 0 created: slices
  [01] note  36  <- slice 001.wav
  …
  [08] note  43  <- slice 008.wav
built 8 RS5K instances (0 problems)
importing MIDI: testpattern.mid
  MIDI import returned OK
build_rs5k: DONE

track name="slices"  fx=8  items=1
  fx0 01 n36 slice 001.wav   noteStart=36  noteEnd=36  obeyOff=0
  fx7 (last)                 noteStart=43
  item0 pos=0.000 len=2.518 midi=true notes=8
```

## Still outstanding

**There is no slice folder yet.** Nothing named `slices` exists under `beneath-redemption`.
The only folder there with wavs holds `sagiloop.wav` and `alphazone-intro-2bar-143t2 001.wav` —
the latter is **214 bytes**, an empty render. The script runs and reports correctly, but has
nothing to be pointed at until a slice set is produced.

## Environment notes

- REAPER v7.79, evaluation licence. ReaScript Lua 5.4.
- REAPER has no `-nogui` switch. Headless testing is done by creating a separate Windows
  desktop with `CreateDesktop()` and launching REAPER against it — nothing draws on screen.
- Sandbox instances must blank `vstpath`/`vstpath64` in their ini, or a fresh instance
  re-scans every plugin. Blanked, launch is ~12 s. Built-in Cockos FX are unaffected.
