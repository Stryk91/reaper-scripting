# STRYK JSFX pack — 144 BPM / F# / A=432

13 JSFX effects + 8 FX-chain templates, built 2026-08-30 for the 144 BPM, F#, A=432 session.

**Installed to:**
- `%APPDATA%\REAPER\Effects\stryk\` — the effects (FX browser → JS → `stryk`)
- `%APPDATA%\REAPER\FXChains\` — the chains (FX browser → FX Chains)

Source of truth is this folder; re-copy from `stryk/` and `FXChains/` after any reinstall.

## The numbers baked in

| | |
|---|---|
| 144 BPM | beat 416.667 ms · 1/8 208.333 · 1/16 104.167 · dotted 1/8 **312.5** · 1/8 triplet 138.889 · bar 1666.67 |
| A=432 | 440→432 = **−31.77 cents** · freq = `432 * 2^((midinote−69)/12)` |
| F# at 432 | F#1 45.41 · F#2 90.82 · F#3 181.63 · F#4 363.27 (midi 66) · F#5 726.54 Hz |

Tempo is read from the host (`tempo` / `beat_position`), so everything follows the project and any
tempo map. 144 only ever appears as a *free-run* default for auditioning with the transport stopped.

## The effects

| File | What it is | Defaults worth knowing |
|---|---|---|
| `stryk_trancegate` | 16-step tempo-locked gate, per-step levels, grid-locked to `beat_position` | rolling offbeat 16th pattern, 1/16 division = exactly 1 bar |
| `stryk_pump` | sidechain-style ducking with **no kick send needed**, phase-locked to the grid | 1/4 rate, 70% depth |
| `stryk_retune432` | retunes audio 440→432 (2-tap crossfaded delay-line shifter) | −31.77 cents, 40 ms window |
| `stryk_syncdelay` | tempo-synced stereo delay, HP+LP in the feedback path, ducking | L dotted-1/8 (312.5 ms), R 1/8 (208.3 ms) |
| `stryk_width` | M/S widener with mono-below crossover, optional Haas | 140% width, mono below 140 Hz, Haas off |
| `stryk_riser` | bar-synced build-up generator, peak lands on the downbeat | 16 bars, pink noise, 200→12 kHz |
| `stryk_fs432_resonator` | tuned comb bank on the F# harmonic series at A=432 | root F#, octave 2 (90.82 Hz), 4 voices |
| `stryk_transient` | attack/sustain shaper, stereo-linked gain | +18% attack, −15% sustain, −1.5 dB out |
| `stryk_monobass` | elliptical low end — mono below X, optional drive | mono below 120 Hz, 24 dB/oct |
| `stryk_lfotool` | tempo-synced LFO → volume / pan / LP / HP | 1 bar, sine, 50% |
| `stryk_scaleforce` | **MIDI** — forces notes into a scale | F# natural minor, nearest, blocks program change |
| `stryk_chordgen` | **MIDI** — diatonic chords from single notes | F# minor triads |
| `stryk_tuner432` | tuner with needle GUI, referenced to A=432 | shows "−31.8 cents vs A=440" |

## The chains

`144 Lead F-sharp` · `144 Pluck F-sharp` · `144 Bass F-sharp` · `144 Pad F-sharp` ·
`144 Riser FX` · `144 Master Check` · `144 MIDI F-sharp minor` · `432 Retune`

## How these were verified

**Loading a JSFX proves nothing.** A JSFX with a syntax error still loads, still shows every slider,
and is indistinguishable from a working one through every ReaScript API channel (probed
`jsfx_error`, `compile_error`, `fx_error`, `fx_type`, `fx_ident`, param get/set/format — all
identical for a deliberately-broken control plugin).

So each effect was **render-tested**: a 2-second test signal in his own tuning (F#4 = 363.27 Hz tone,
noise, a 40 Hz→16 kHz sweep, and F#2 transients spaced at 144 BPM eighths) pushed through the effect
via *Apply track FX to items as new take*, then diffed against a dry pass. A dead plugin gives
`maxdiff == 0.000000` exactly. A known-broken and a known-good plugin were kept in the run as live
controls. The two MIDI effects were tested by feeding a chromatic run through them and reading the
resulting notes back.

Two real defects were caught this way and fixed:

1. **`stryk_width` was completely dead.** REAPER's own error: `@sample:118: syntax error:
   'in_l = abs(in_l) < 1 <!> e30 ? in_l : 0;'` — **EEL2 has no scientific-notation literals**;
   `1e30` parses as `1` followed by garbage. 13 such literals across `stryk_width` and
   `stryk_tuner432` were rewritten longhand. `tuner432` is pass-through by design so the audio diff
   could never have caught it — it was confirmed separately by opening its GUI.
2. **`stryk_transient` clipped to exactly 1.0000** at its shipped defaults on a 0.52-peak signal.
   Attack eased 30→18%, output −1.5 dB; peak now 0.83.

Final audit: 13/13 behave correctly, no NaN or Inf in any output, nothing clipping at defaults.

## Notes / limits

- `stryk_riser` shows only a small change over a 2-second test because its default ramp is 16 bars —
  that is correct behaviour, not a weak effect.
- `stryk_scaleforce` ships with **Block Program Change = Yes**, matching the
  `midi_strip_pc` pipeline.
- No presets: JSFX defaults *are* the preset. Every effect is tuned to sound usable the instant it
  is inserted.
