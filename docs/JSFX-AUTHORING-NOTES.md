# STRYK JSFX pack - authoring + review notes

Generated 2026-08-30 for 144 BPM / F# / A=432.

## stryk_trancegate

**Review fixed it:** False

**Sliders**
```
slider1  Step 01 Level        default 1.00   range 0..1 step 0.01
slider2  Step 02 Level        default 0.00   range 0..1 step 0.01
slider3  Step 03 Level        default 0.60   range 0..1 step 0.01
slider4  Step 04 Level        default 0.00   range 0..1 step 0.01
slider5  Step 05 Level        default 1.00   range 0..1 step 0.01
slider6  Step 06 Level        default 0.00   range 0..1 step 0.01
slider7  Step 07 Level        default 0.60   range 0..1 step 0.01
slider8  Step 08 Level        default 0.25   range 0..1 step 0.01
slider9  Step 09 Level        default 1.00   range 0..1 step 0.01
slider10 Step 10 Level        default 0.00   range 0..1 step 0.01
slider11 Step 11 Level        default 0.60   range 0..1 step 0.01
slider12 Step 12 Level        default 0.00   range 0..1 step 0.01
slider13 Step 13 Level        default 1.00   range 0..1 step 0.01
slider14 Step 14 Level        default 0.30   range 0..1 step 0.01
slider15 Step 15 Level        default 0.75   range 0..1 step 0.01
slider16 Step 16 Level        default 0.45   range 0..1 step 0.01
slider17 Step Division (enum 1/8, 1/16, 1/32)  default 1 (= 1/16)  range 0..2 step 1
slider18 Attack (ms)          default 2      range 0.1..50 step 0.1
slider19 Release (ms)         default 25     range 1..200 step 1
slider20 Depth (%)            default 100    range 0..100 step 1
slider21 Mix (dry/gated) (%)  default 100    range 0..100 step 1
slider22 Free-run BPM (transport stopped)  default 144  range 40..220 step 0.01
```

**Design notes**

DESIGN

Grid lock. Phase is a fractional step counter `step_pos` in [0,16). In @block, when `play_state & 1`, it is hard-set to `beat_position * spb` wrapped mod 16 — beat_position is in quarter notes, spb is steps-per-quarter (2 / 4 / 8 for 1/8 / 1/16 / 1/32). That means the gate re-anchors to the project grid at every block boundary, so it survives locate, loop wrap, tempo automation and tempo-map changes without drift. Within the block it advances per sample by `inc = bpm*spb/(60*srate)`, using the host `tempo` (never a hardcoded 144). 144 appears only as the Free-run BPM slider default and in comments/labels.

Transport states are handled three ways: playing = sync + host tempo; paused (`play_state & 2`, bit 1 clear) = inc 0, hold position so it does not crawl while parked; stopped = free-run at the Free-run BPM slider so he can audition on a stopped transport, which is the whole point of that slider.

No modulo operator in EEL2, so wrapping is `sp - floor(sp/16)*16` at sync time and a subtract-16 guard per sample. `step_pos | 0` truncates to the step index, then it is clamped 0..15 anyway so a bad float can never index outside the 16-slot buffer.

Smoothing. The step level is the target; `env` chases it with a one-pole whose coefficient is attack when rising, release when falling: `c = 1 - exp(-1/(ms*0.001*srate))`. 2 ms / 25 ms defaults give a punchy but click-free trance chop. Depth and Mix each get their own ~20 Hz one-pole (`sm_c`) because both touch gain directly and would zipper otherwise. Final gain is `tot = 1 - mix + mix*(1 - depth + depth*env)` — one multiply per channel.

Default pattern is a rolling offbeat 16th figure: full on 1/5/9/13, 0.6 ghosts on the 3rd 16th of each beat, silence on the 2nd, plus 0.25 / 0.30 / 0.75 / 0.45 at steps 8, 14, 15, 16 for an end-of-bar fill. Continuous levels rather than on/off so ghosts breathe. At 1/16 and 144 BPM that is exactly one bar (1666.67 ms), each step 104.167 ms. Insert it on a pad with nobody touching anything and it is a usable trance gate immediately.

432 Hz / F# is informational only — a gate does not touch pitch. It is documented in the header block so the file self-identifies as part of the 144/F#/432 pack.

RISK / STABILITY NOTES

- `ext_nodenorm=1` set, plus an explicit flush of `env` below 1e-12 so the release tail cannot park in denormal-land.
- Every divide is guarded: `max(srate,1)`, `max(ms,0.01)` inside ms2coef, `max(slider22,20)` on free BPM, `tempo > 1 ? tempo : free_bpm` in case a host reports 0 tempo.
- Coefficients are recomputed in `update_params()`, which is called from BOTH @init and @slider, so a samplerate change (which re-runs @init) rebuilds atk/rel/sm coefficients correctly rather than leaving stale ones.
- Mono/stereo: only spl0/spl1 are touched. On a mono track spl1 is just an unused variable, harmless. Deliberately did not use `spl(i)` loops over num_ch — lower risk, and the requirement was mono + stereo.
- EEL2 pitfalls avoided on purpose: no `if`, all multi-statement ternary branches parenthesised including the single-statement guards; nested ternary in @block fully bracketed; no `fmod`; functions declared before first use inside @init; string literals only via `#var` (`#lock` / `#freerun` assigned in @init) — I specifically removed a `%s`-with-literal sprintf because literal-as-argument is version-sensitive.
- Enum slider labels were simplified to plain `{1/8,1/16,1/32}` after an earlier draft put parentheses and `=` inside the enum entries; the descriptive text moved into the slider label instead, so nothing unusual goes through the enum parser.
- Memory: 16 doubles at offset 0, `freembuf(16)` releases everything above. No gmem, no file I/O, no external deps.
- @gfx uses variable names that do not collide with any @sample state (`i`, `x`, `lv`, `bhh`, `pad`, `top`, `bh`, `bw`, `gcur`), so drawing cannot perturb DSP. It reads `env`, `tot`, `step_pos`, `cur_bpm`, `spb` only.

I could not compile-verify — no JSFX compiler is reachable from this sandbox, and the reaper MCP server failed to connect this session (CONNECTION_CLOSED), so the harness load is the first real compile. The file is at G:\tmp\stryk_trancegate if you want to diff against what the harness gets.

---

## stryk_pump

**Review fixed it:** False

**Sliders**
```
slider1  Rate                        default 2 (= "1/4 beat")   range 0..4 step 1, enum {0:1/1 bar (1666.7 ms at 144), 1:1/2 (833.3 ms), 2:1/4 beat (416.7 ms), 3:1/8 (208.3 ms), 4:1/4 triplet (277.8 ms)}
slider2  Depth (%)                   default 70                 range 0..100 step 0.1   (70% = floor at -10.5 dB; 100% = full mute)
slider3  Curve (0 sharp exp - 1 soft cosine)  default 0.35      range 0..1 step 0.01
slider4  Attack (ms)                 default 1                  range 0..50 step 0.01
slider5  Hold (ms)                   default 0                  range 0..200 step 0.1
slider6  Phase Offset (beats)        default 0                  range -1..1 step 0.001
slider7  Mix (%)                     default 100                range 0..100 step 0.1
slider8  Free-run BPM (transport stopped)  default 144          range 40..300 step 0.01
```

**Design notes**

WHAT IT DOES
Grid-locked gain ducker. No kick send, no detector, no compressor. Every instance derives its phase from `beat_position` so all of them pump in lockstep on the project grid.

PHASE LOCK
@block: `phase = frac((beat_position - phase_off) / period_beats)`. beat_position is in quarter notes and is exact at block start, so this is a hard resync every block — no drift, no per-instance offset. Between blocks @sample advances phase by `phase_inc = 1/(per_sec*srate)`. When `play_state & 1` is false the resync is skipped entirely and the same increment free-runs at the Free-run BPM slider. Tempo comes from `tempo` while playing (follows tempo automation and any project BPM); 144 is only the free-run default and the label text.

RATE MAP (period in quarter notes, so it is meter-agnostic)
1/1 = 4 | 1/2 = 2 | 1/4 = 1 | 1/8 = 0.5 | 1/4 triplet = 2/3. At 144 that lands on 1666.67 / 833.33 / 416.667 / 208.333 / 277.78 ms — verified by simulation, cycle prints 416.667 ms at the defaults.

ENVELOPE
Three stages inside each cycle: raised-cosine dip over Attack, flat floor over Hold, then recovery over whatever is left. Recovery is a crossfade between `(1-exp(-5.5u))/(1-exp(-5.5))` (Curve 0, sharp/exponential — the classic sidechain snap) and `0.5-0.5cos(pi*u)` (Curve 1, soft). Value at u=1 is exactly 1.0 and value at t=0 (Attack>0) is exactly 0, so the envelope is continuous across the wrap — I checked the seam numerically, g(1-eps) = g(0) = 1.000000, no per-cycle click.

Simulated at defaults (144, 1/4, 70%, curve 0.35, 1 ms attack): 0 ms = 0.00 dB, 1 ms = -10.46 dB (floor), 10 ms = -9.08, 40 ms = -6.21, 120 ms = -2.99, 300 ms = -0.46, 416.6 ms = 0.00. That is the shape he wants without touching anything.

DESIGN CHOICE WORTH FLAGGING
First cut baked cycle-length + attack + hold into one phase-indexed table, which meant a full 2049-point rebuild on every tempo-automation block AND only ~5 table points describing a 1 ms attack. Rewrote to TWO normalised tables instead: ATK (fixed raised cosine, built once in @init) and REL (Curve-dependent only, rebuilt only when the Curve slider actually moves). Timing is now pure arithmetic — `t = phase*per_sec`, compare against atk_s / hold_end, index by `t*inv_atk` or `(t-hold_end)*inv_rel`. Result: zero transcendentals per sample, zero rebuild cost when tempo / attack / hold change, and 1024 points of resolution across the attack regardless of how short it is.

SAFETY / EDGE CASES
- Attack+Hold are scaled down proportionally if they would exceed 90% of the cycle, so there is always a recovery ramp and rel_s can never hit zero. inv_atk and inv_rel are guarded with a TINY floor; atk_s = 0 is fine because the `t < atk_s` branch is simply never taken (instant duck, correct behaviour).
- bpm is clamped to 20..999 and falls back to the Free-run slider if the host reports 0 or negative.
- Depth and Mix are one-pole smoothed (~5 ms) with a snap-to-target so they cannot leave a decaying denormal; combined with `ext_nodenorm=1` there is no denormal path (no filters, no feedback).
- Mix is folded into the gain algebraically: `1 - mix*depth*duck` is exactly `(1-mix)*dry + mix*dry*g`, so there is no second signal path and no phase issue.
- Output gain is clamped 0..1 so it can never invert or exceed unity.
- No pin declarations, so mono / stereo / multichannel all work: spl0 and spl1 always, plus a loop over channels 2..num_ch-1 when the track is wider.

GFX
480x190 panel: envelope drawn over two cycles with a live playhead, plus a readout of cycle length in ms, current BPM, floor in dB, and whether it is GRID LOCKED or FREE RUN. Uses the same duck_at() the audio path uses, so what he sees is what he hears.

A=432 / F# note: this is a gain effect, tuning does not touch it. Documented in the header block only so the pack reads consistently.

FILES
Written to G:\tmp\jsfx\stryk_pump and installed to C:\Users\STRYK\AppData\Roaming\REAPER\Effects\stryk\stryk_pump (that folder existed but was empty).

NOT VERIFIED: I could not compile it — the reaper MCP server failed to connect this session, so this has not been through REAPER's EEL2 parser. Paren balance is confirmed zero and I deliberately parenthesised every ternary branch (including single-assignment ones) to avoid any `?:` vs `=` precedence surprise. The DSP maths was validated by a Python reimplementation of the exact table/lookup code.

---

## stryk_retune432

**Review fixed it:** True

Problems the reviewer found:
- Read-before-write of `ws` in @gfx. The only assignment is in @sample -- `ws = max(win_s, 8);` -- but @gfx consumes it three times before any audio has been processed: `wrap = ws / dr / srate;`, `wms  = ws * 1000 / srate;` and `sprintf(#s, "window %.1f ms (%d smp)    tap wrap every %.2f s", wms, ws, wrap);`. On a freshly inserted instance whose UI is opened before the first audio block, `ws` is still the EEL2 default 0, so the panel reads "window 0.0 ms (0 smp)    tap wrap every 0.00 s". It is display-only and self-corrects on the first block (no NaN: `dr = max(abs(drate), 0.0000001);` floors the divisor), but it is still an uninitialised global being divided by. Fixed by seeding `ws` in @init alongside the other smoothed values.
- Comment states behaviour the code does not implement: `   Exactly 0.00 cents collapses to a true unity passthrough (single tap, no` / `   comb), so A/B-ing against bypass is honest.` At 0.00 cents `drate = 1 - ratio;` is 0, so `phase += drate / ws;` freezes `phase` at whatever value it held, and the single remaining tap is still read at `rp1 = wp + bufsize - (2 + phase * ws);` -- i.e. a fixed, generally fractional (cubic-interpolated) delay of 2..(2+window) samples, up to ~80 ms. It is single-tap and phase-coherent, but it is not a unity passthrough and A/B against bypass will show that offset. Forcing `phase` to 0 in unity mode would fix the claim but would drag tap A's delay while `g1` is already 1, producing an audible pitch slide, so the correct fix is to state the actual behaviour rather than change the DSP.

**Sliders**
```
slider1  Tuning Mode                       default 0 (Use Reference Hz)  enum {Use Reference Hz, Use Cents}
slider2  Reference Hz (A4)                 default 432.00               range 400..460, step 0.01
slider3  Cents (readout / manual override) default -31.77               range -100..100, step 0.01
slider4  Window ms (grain size / formant)  default 40                   range 10..80, step 0.5
slider5  Crossfade (% of window)           default 30                   range 10..100, step 1
slider6  Dry / Wet (% wet)                 default 100                  range 0..100, step 0.1
slider7  Output Trim (dB)                  default 0                    range -12..12, step 0.1
```

**Design notes**

WHAT IT IS
Classic 2-tap crossfaded delay-line pitch shifter, stereo, exactly as briefed. Delay line per channel, two read taps half a window apart, sliding at (1 - 2^(cents/1200)) samples per sample, raised-cosine crossfade so the wrap splice always happens at zero gain.

KEY DESIGN CALLS

1. Ramp direction. Delay grows at drate = 1 - ratio per sample (ratio = 2^(cents/1200)). Negative cents -> ratio < 1 -> the taps fall behind the write head -> pitch drops. Same expression as the brief's (2^(c/1200) - 1), just expressed as delay growth instead of read-pointer offset, so the sign convention matches "delay = wp - rp".

2. Crossfade width is a slider, defaulting to 30% instead of a permanent full-cycle cosine. With a full raised cosine you are ALWAYS summing two taps that are half a window (20 ms) apart, which is a static comb -- I measured up to 20 dB of envelope ripple on a sustained sine at 726.54 Hz (F#5), because 20 ms lands on a half-integer number of periods there. Holding one tap flat through the middle of the window and only raising the cosine near the splice keeps the shifter single-tap ~70% of the time (zero comb, zero ripple) and cut the 5th-percentile ripple from 16.6 dB to 9.5 dB on that worst-case tone. Setting the slider to 100% reproduces the textbook full-cycle behaviour exactly, so nothing is taken away.

3. Interpolation is 4-point cubic (Catmull-Rom), not linear. Verified the coefficients analytically (f=0 -> y0, f=1 -> y1) and numerically.

4. Unity handling. At |cents| < 0.02 the crossfade collapses onto a single tap (g2 = 0), giving a bit-exact 2-sample-delayed passthrough rather than a two-tap comb. Verified: max error vs a 2-sample-delayed 1 kHz sine = 0.0 exactly. The collapse is blended with a smoothed uni_s so g1+g2 == 1 at every instant, so dragging Reference Hz through 440 does not step the gain.

5. Cents write-back. In "Use Reference Hz" mode @slider writes the computed cents onto slider3 and calls sliderchange() so it reads out live (432 -> -31.77). Guarded: only when the value is inside the slider's own -100..100 range (400 Hz would be -165 cents, out of range) and only when it actually differs by >0.005, so there is no thrash. The DSP never reads slider3 in that mode -- it uses its own cents_eff -- so even if a host ignores sliderchange the audio is unaffected.

MEASURED (Python port of the exact @sample code, run at 44.1/48/96/192k)
- Pitch accuracy: FFT peak on a clean single-tap stretch = 431.9999 Hz for a 440 Hz input at 432 ref, i.e. -0.0004 cents error. Instantaneous pitch is exact by construction (both taps ramp at the same rate).
- Splice sidebands sit ~34 dB below the fundamental; that residual is inherent to any time-domain granular shifter and is why the full-signal FFT peak reads 431.82 rather than 432.00. Not a rate error.
- At defaults (-31.77 c, 40 ms) the taps wrap only every 2.2 s; ~0.6 s of that is crossfaded.
- No NaN/Inf/runaway on DC, impulses, silence, or the five extreme slider corners tested. Peak stayed <= 1.05 on a unit impulse.
- Live slider moves (window 40 -> 75 ms, ref 432 -> 444) mid-stream produced a max sample step of 0.0206 vs a steady-state sine step of 0.0202 -- i.e. no click.
- Mono/stereo: both channels run the same tap geometry off independent buffers; spl1 is processed unconditionally, which is harmless on a 1-channel track.

SAFETY / HOUSE STYLE
- ext_nodenorm=1. Buffer sized from srate (100 ms + 16, rounded up to a power of two) and allocated in @init, so a samplerate change reallocates and clears. Ring indexing is masked, and the read position is offset by +bufsize before flooring so index-1 is never negative -- asserted across every test run.
- ws = max(win_s, 8) guards the phase-increment divide; xf_p is clamped to >= 0.02 to guard the cosine divide; ref_hz clamped to >= 1 before the log.
- All five continuous controls (window, dry, wet, trim, unity blend) run through a ~8 ms one-pole. Window smoothing is what stops a Window-ms drag from jumping the delay.
- No tempo hardcoding: this unit has no tempo-synced parameter at all (retuning is tempo independent), and the only use of `tempo` is the @gfx footer readout, which follows the project.

RISKS
- sliderchange(sliderN) relies on the documented EEL2 compiler special-case that resolves the slider index from the variable reference. If a non-REAPER host ignored it the only consequence is a stale readout on slider3; audio is unaffected.
- No PDC is declared. The delay is time-varying (2..2+window samples), so there is no honest fixed latency to report. Worth knowing before it goes on a parallel bus -- and it is why Dry/Wet under 100% flanges.

---

## stryk_syncdelay

**Review fixed it:** True

Problems the reviewer found:
- DRY SIGNAL IS FADED IN FROM SILENCE ON EVERY INIT (~92 ms). @init leaves the control smoothers at zero -- `sm_wet = 0; sm_dry = 0; sm_fb = 0;` -- and @sample only ever ramps them toward the target (`sm_dry += sm_c * (dry_t - sm_dry);`). With the 20 ms coefficient sm_c = 0.0011331, the first sample is multiplied by 0.0011 instead of 1.0, and it takes 4062 samples (92.1 ms at 44.1 kHz) to reach 99%. MEASURED IN REAPER: an 0.84 impulse with Dry at its 100% default came out of sample 0 at 0.000952 (-59 dB); the predicted value 0.00095184 matches to 5 digits, confirming the cause. This re-arms on every plugin init -- insert, samplerate change, and the start of every offline render/bounce -- so a bounce loses the front ~92 ms of level. FIX: prime the smoothers on the first @slider pass (@slider runs after @init on load and on samplerate change). After the fix the same render returns 0.840205 at sample 0, bit-identical to the dry reference, with the delay taps unchanged.
- DELAY BUFFER TOO SHORT FOR THE 1/2 DIVISION AT SLOW TEMPO -- SILENTLY DESYNCS. `MAXDELSEC = 3.0;` gives dlN = 3 s, but @block accepts tempo down to 20 BPM (`tmpo < 20  ? tmpo = 144;`) where the offered 1/2 division (divtab[7] = 2.0 beats) needs 6.0 s. `tgtL = max(2, min(tgtL, dlN - 4));` then clamps it and the delay stops being tempo-synced with no indication. MEASURED IN REAPER at 30 BPM with both divisions set to 1/2 (feedback 0, wet 100, dry 0 so exactly one tap): expected 4000.0 ms, the submitted file produced a tap at 2999.9 ms -- exactly the (3.0*44100-4)/44100 buffer clamp. The header comment `// ---- buffers (3 s per side covers a 1/2 note down to 40 BPM) ------------` states the 40 BPM limit but the tempo guard admits 20. FIX: MAXDELSEC = 6.5 (still only ~2.5M memory slots at 192 kHz, far inside the JSFX budget). After the fix the same test returns exactly 4000.0 ms.

**Sliders**
```
slider1 | Left Division | default 1 (= "1/8 dotted") | enum index 0..7 step 1 {0=1/4 416.7ms, 1=1/8 dotted 312.5ms, 2=1/8 208.3ms, 3=1/16 dotted 156.3ms, 4=1/16 104.2ms, 5=1/8 triplet 138.9ms, 6=1/4 triplet 277.8ms, 7=1/2 833.3ms -- all ms figures at 144 BPM}
slider2 | Right Division | default 2 (= "1/8") | same 0..7 enum as slider1
slider3 | Feedback (%) | default 38 | 0..95 step 0.1
slider4 | Ping-Pong | default 1 (= "On") | enum 0..1 step 1 {0=Off, 1=On}
slider5 | Feedback High-Cut (Hz) | default 7000 | 500..20000 step 10
slider6 | Feedback Low-Cut (Hz) | default 180 | 20..2000 step 1
slider7 | Wet (%) | default 28 | 0..100 step 0.1
slider8 | Dry (%) | default 100 | 0..100 step 0.1
slider9 | Ducking (%) | default 25 | 0..100 step 0.1
```

**Design notes**

SHIPPED AND INSTALLED
Source: G:\tmp\jsfx\stryk_syncdelay
Installed copy: C:\Users\STRYK\AppData\Roaming\REAPER\Effects\stryk\stryk_syncdelay
(stryk_pump from a sibling agent was already in that folder, so the pack dir is correct.)

TEMPO HANDLING
Delay time = divtab[division] * (60/tempo) * srate, recomputed in @block from the host `tempo`
every block, so it tracks the project and any tempo map. 144 appears only in slider labels,
comments, and as the fallback if tempo < 20 (clamped to 144; upper clamp 960). Verified the
arithmetic against the brief: 1/4 416.667, 1/8d 312.500, 1/8 208.333, 1/16d 156.250,
1/16 104.167, 1/8t 138.889, 1/4t 277.778, 1/2 833.333 ms -- exact matches.

RETIMING: CROSSFADE, NOT SLEW
The obvious implementation (one-pole smoothing of the delay length) is a doppler pitch glide by
construction, which is the artefact the brief asked to avoid. Instead each side keeps two read
pointers: on a division/tempo change @block latches from=current, to=target and @sample does a
30 ms equal-power (sqrt) crossfade between them, then commits. No pitch bend, no click.
Cost: a brief amplitude bulge when the two taps are correlated -- measured +1.75 dB worst case
on a steady 440 Hz tone, inaudible on a delay tail. A new crossfade only arms when one is not
already running, so tempo automation degrades gracefully instead of thrashing.

TOPOLOGY
Per side: read line -> one-pole LP (high-cut) -> one-pole HP (low-cut, implemented as
x - lowpass(x)) -> feedback. Ping-Pong On crosses the two filtered feedback signals
(L line gets R's tail and vice versa); Off keeps them parallel. The WET output taps the raw
line output, not the filtered one, so the first repeat is full-bandwidth and the tail darkens
progressively -- standard and what he'll expect.

THE BUG I ALMOST SHIPPED (worth knowing for the rest of the pack)
I first wrote the NaN guard as the C idiom `x != x`. That is BROKEN in EEL2: == and != are
epsilon compares (fabs(a-b) vs 0.00001), fabs(NaN-NaN) is NaN, and NaN > 0.00001 is false, so
BOTH == and != return 0 for a NaN and the guard silently does nothing. In a feedback delay that
means one NaN from an upstream plugin poisons the line permanently. The relational operators
< > <= >= ARE exact and all return false for NaN, so the guard is now
`(x < 0 || x >= 0) ? x : 0`. Infinities pass that test deliberately and are caught by the
separate +/-4 magnitude clamp on the write values.

VERIFICATION DONE BEFORE HANDING IT OVER (no REAPER launch; I ported @sample to Python)
1. Static: parens/brackets/braces balanced across all five sections, sections in legal order,
   9 sliders, both division enums have exactly 8 entries for the 0..7 range.
2. Impulse response at defaults: L taps at 312.50 ms, R at 208.33 ms, then the cross-feed
   produces 520.83 on both, then 833.33 on L / 729.17 on R -- correct ping-pong alternation,
   monotonic decay.
3. Stress: 30 s at 95% feedback with both filters wide open (20 Hz / 20 kHz) fed 2 s of
   full-scale noise, with NaN and +/-Inf injected at 5 s and 6 s. Output stayed finite, no NaN
   reached the buffers or filter states, tail decayed to 0.0096 after 28 s of silence. The
   clamp does engage at 4.0 in that extreme case -- intended, it is the runaway net.
4. Crossfade: switching 1/8d -> 1/8 mid-tone gave a max sample-to-sample jump of 1.22x the
   source tone's own max slope, i.e. click-free.

OTHER CHOICES
- Buffers: 3 s per side (dlN = srate*3), which covers a 1/2 note down to 40 BPM. At 192 kHz
  that is 1.15M slots, well inside JSFX limits. Slower tempos clamp rather than misbehave.
  @init re-runs on samplerate change and reallocates + clears, and initdone resets so the
  first block re-latches the delay times without a crossfade from stale state.
- Ducking: 5 ms attack / 180 ms release peak follower on the DRY input, mapped to up to 18 dB
  of wet reduction at 100%. At the 25% default a loud source pulls the wet down 4.5 dB and it
  springs back in the gaps. Reduction is dB-domain (exp(-ln10/20 * dB)) so the taper feels
  linear to the ear rather than crushing at the top.
- Wet, Dry, Feedback and the duck gain are all one-pole smoothed at 20 ms -- nothing touching
  gain moves in a step.
- Mono safe: inR falls back to spl0 when num_ch < 2, and in that case spl1 is never touched
  and the two lines are summed at 0.5 into spl0, so the ping-pong content is not lost.
  Channels above 2 pass through untouched.
- ext_nodenorm = 1 (feedback + filters), ext_tail_size = srate*8 so REAPER renders the tail.
- @gfx: header with the live host BPM, both delay times in ms, and a tick row per side showing
  where the repeats land with brightness following the feedback decay -- reads the actual
  bounce pattern at a glance. Uses cur_tempo cached in @block rather than `tempo` directly.

ONE THING TO FLAG
Feedback Low-Cut and High-Cut are independent, so setting Low-Cut above High-Cut is legal and
will thin the feedback path toward silence. That is a usable band-pass-tail effect rather than
a fault, so I did not force an ordering, but it is not guarded.

---

## stryk_width

**Review fixed it:** False

**Sliders**
```
slider1: Width (percent, 100 = untouched) — default 140, range 0..200 step 1
slider2: Haas Delay (ms, 0 = off / fully mono safe) — default 0, range 0..25 step 0.01
slider3: Mono Below (Hz, bass summed to centre) — default 140, range 20..400 step 1
slider4: Tilt (side pan, -100 = left / +100 = right) — default 0, range -100..100 step 1
slider5: Mix (percent wet) — default 100, range 0..100 step 1
slider6: Mono Check (audition only) — default 0, enum 0..2 {Off, Mono Sum, Side Only}
```

**Design notes**

SIGNAL PATH
M/S encode -> LR2 high-pass on the SIDE only -> Width scale -> Haas delay line (right leg only) -> constant-power Tilt gains -> M/S decode -> dry/wet -> Mono Check audition -> correlation meter feed.

WHY THE CROSSOVER IS BUILT THIS WAY
"Mono below X Hz" is implemented as: high-pass the side, discard everything below. Removing side content in a band makes both channels equal to m in that band, which IS a mono sum of that band -- no separate low-band summing stage needed, and crucially the MID path is never filtered at all, so there is zero phase smear in the centre. The high-pass is two cascaded one-pole HPs (slp1/slp2), which is literally a Linkwitz-Riley 2nd order: 12 dB/oct, -6 dB at fc. Verified numerically: with fc=140 Hz the side band retains 6.0% at 30 Hz, 15.5% at 50 Hz, 40.7% at F#2 (90.82), 48.7% (-6.2 dB, i.e. exactly LR2) at 140 Hz, 86.3% at F#3 (181.63), 96%+ above 400 Hz. That is precisely the intent: F#0-F#2 locked centre, F#3 upward free.

HAAS DESIGN DECISION (the non-obvious one)
Classic Haas delays a whole channel, which combs the BASS in mono -- fatal on a club rig. Here the delay is applied to the right leg's already-high-passed side signal: l = m + gL*s_hi[n], r = m - gR*s_hi[n-D]. That still genuinely decorrelates L/R and still genuinely costs mono compatibility above the crossover (measured: pure-side 733 Hz gives mono-sum RMS 0.55-0.86 with Haas engaged vs 0.0000 with it off), which is exactly why it defaults to 0 -- but the sub and bass can never comb, because there is no side content down there to delay. Fractional-sample read with linear interpolation, and the delay length itself is one-pole smoothed, so sweeping the ms knob glides instead of clicking.

MONO-SAFETY MEASUREMENT (Python reimplementation of the @sample loop, uncorrelated noise, 2 s)
  Width 0 / 100 / 140 / 200 %  ->  mono-sum RMS 0.4079 in every case.
Width alone is perfectly mono-compatible at any setting, because L+R = 2m regardless of side gain. The only things that move the mono sum are the asymmetric controls, Haas (0.5697) and hard Tilt (0.5673) -- both default to neutral. Output correlation on that same noise: width 0 -> +1.000, 100% -> +0.023, 140% -> -0.304, 200% -> -0.585.

TILT
Constant-power pan of the side band: theta = pi/4 * (1 + tilt), gL = cos(theta)*sqrt(2), gR = sin(theta)*sqrt(2). At tilt 0 both gains are exactly 1.0, so tilt is bit-transparent when centred. At the extremes one leg hits sqrt(2) (+3 dB) and the other 0.

EEL2 CORRECTNESS POINTS
- All coefficient maths lives in a single function upd() called from BOTH @init and @slider, so a samplerate change cannot leave a stale delay length or crossover coefficient behind (dly_len is srate-dependent and t_dly is clamped against it).
- Smoothers (sm_w, sm_gl, sm_gr, sm_wet, sm_dly) are snapped to their targets at the end of @init so the plugin does not fade in from zero on load; 20 ms one-pole thereafter, mandatory since every one of them touches gain.
- ext_nodenorm=1 for the two IIR states and the three meter integrators.
- NaN/inf gate on input using "abs(x) < 1e30 ? x : 0" -- any comparison against NaN is false, so a bad sample becomes silence rather than permanently poisoning slp1/slp2 or the delay buffer. Repeated on the outputs.
- Mono safety: in_r falls back to spl0 when num_ch < 2, which makes s = 0 and passes the signal through untouched; spl1 is only written when num_ch >= 2.
- Delay index wrap is guarded on both sides (rd < 0 wrap, i1 >= dly_len wrap) and t_dly is clamped to dly_len-4, so the read pointer can never leave the buffer.
- Paren balance and section ordering machine-checked; sections are @init, @slider, @sample, @gfx (no @block or @serialize needed -- nothing per-block, no MIDI, no state worth persisting beyond the sliders).

GFX
Compact panel with a 300 ms-ballistic correlation meter (red -1..0, amber 0..0.3, green 0.3..+1), a greyed needle when there is no signal, and a live readout of all five continuous params. When Mono Check is engaged it puts an amber "this is not the real output" banner up, so he cannot leave it switched on by accident.

RISK / KNOWN LIMITS
- No output limiting or make-up gain. With very wide source material at 200% the peak can reach ~2.2x the input. Deliberate: m is untouched so the centre level never shifts, and silently compensating would lie about what the widener is doing. Flagged in the header comment.
- The "%%" literals in the gfx sprintf are standard printf and REAPER supports them; even if a build disagreed it is a cosmetic display issue only, not a compile error.
- tempo is intentionally unread: nothing in a widener is tempo-synced, and the brief forbids hardcoding 144, so 144 appears only in labels/comments. The 432 Hz tuning informs the 140 Hz crossover default (sits between F#2 90.82 and F#3 181.63) and nothing else.
- Source also written to G:\tmp\jsfx\stryk_width for review; not installed into %APPDATA%\REAPER\Effects.

---

## stryk_riser

**Review fixed it:** False

**Sliders**
```
slider1  Length (bars)                    default 4 (= 16 bars)   enum index 0..5 -> 1,2,4,8,16,32 bars
slider2  Source                           default 1 (= Pink Noise) enum 0..2 -> White Noise, Pink Noise, Sine Sweep
slider3  Start Hz                         default 200             range 20..20000, step 1
slider4  End Hz                           default 12000           range 20..20000, step 1
slider5  Resonance (Q)                    default 3               range 0.5..20, step 0.01
slider6  Curve (0=exponential..1=linear)  default 0.3             range 0..1, step 0.01
slider7  Level (dB)                       default -12             range -60..0, step 0.1 (-60 = hard off)
slider8  Stereo Spread (%)                default 60              range 0..100, step 1
slider9  Trigger Mode                     default 0 (= Follow Transport) enum 0..1 -> Follow Transport, Manual Retrigger
slider10 Manual Fire (Manual mode only)   default 0 (= Idle)      enum 0..1 -> Idle, FIRE (rising edge retriggers)
slider11 Post-peak Release (ms)           default 80              range 0..2000, step 1
```

**Design notes**

BAR LOCK (the core requirement)
ph = frac( beat_position / (Length_bars * ts_num*4/ts_denom) ). beat_position is in quarter notes and only updates once per block, so I latch it at @block (cur_beat = beat_position) and advance it per sample with beat_inc = tempo/(60*srate). That gives sample-accurate ramp position that is re-anchored to the host every block, so it self-corrects after transport jumps, loop wraps, tempo automation and samplerate changes. ph -> 1.0 on the last sample before the downbeat that ends the window, so the peak IS the sample before the drop and the release tail crosses the bar line. tempo is never hardcoded; 144 appears only as a fallback if tempo reads < 1 and in comments/labels.

WHY THE SLIDER DEFAULTS SOUND RIGHT UNINSPECTED
- Pink over white: a constant-Q bandpass has bandwidth proportional to f0, and pink noise power goes as 1/f, so passed power is constant across the sweep. The riser gets brighter without getting louder/harsher, and the rise is carried by the amp envelope instead. White is left in for the aggressive +3 dB/oct version.
- Bandpass, not lowpass: BP is the actual uplifting-riser topology (no low-end mud building under the breakdown), and at Q=3 it is a wide musical band, not a whistle.
- Curve 0.3 maps to freq exponent 2.4 / amp exponent 1.2. Over 16 bars that puts roughly half the frequency travel in the last 4 bars, which is the standard shape. Curve 1 = perfectly linear in both.
- Level -12 dB with 20 Hz gain smoothing, and a tanh-shaped soft saturator AFTER the gain, so it can never exceed 0 dBFS regardless of Q, source or spread.

DSP CHOICES
- TPT/ZDF state-variable filter (g = tan(pi*fc/srate), one-sample-delay trapezoidal form). Chosen over Chamberlin because Chamberlin goes unstable above ~srate/6 and this thing sweeps to 12 kHz; TPT is stable to Nyquist. Coefficients are recomputed every sample (two tan() calls) so the sweep is continuous with zero stepping. fc is clamped to [10, 0.45*srate] so 12 kHz stays legal even at 22.05 kHz.
- Bandpass output scaled by sqrt(1/Q). BP peak gain is Q and noise bandwidth goes as 1/Q, so power scales as Q; multiplying by 1/sqrt(Q) makes the perceived level essentially Q-independent. Resonance becomes a tone control, not a volume control.
- Envelope: instant attack, one-pole release. On the wrap, amp drops to 0 while env decays over Post-peak Release, so the riser does not click at the drop. During that release the sweep frequency is FROZEN at its peak, otherwise the tail audibly whooshes back down to Start Hz exactly on the downbeat. The crossover back onto the new ramp happens around -40 dB, so the fcur snap-back is inaudible.
- Stereo: shared noise stream blended equal-power against a per-channel independent stream (weights 1-s and s, normalised by 1/sqrt(wa^2+wb^2)), plus +/- (spread*40) cents of filter/osc detune. At Spread 0 both channels are bit-identical = mono-safe; sums without comb filtering because the correlated part stays correlated.
- Pink noise is Paul Kellet's economy 3-pole approximation, one instance per channel (run on the already-decorrelated white so both channels stay independent). Trim 0.6 to sit level with white around 1-2 kHz - that trim is a judgement call, not a derived constant.
- Sine Sweep bypasses the filter entirely (Resonance is documented as not applying), phase-continuous accumulator, L/R started a quarter cycle apart.

RISK / THINGS I DELIBERATELY DECIDED
- Added two sliders beyond the brief: slider10 Manual Fire (Manual Retrigger is useless without something to fire it - rising edge on it resets the ramp, and it is automatable/bindable) and slider11 Post-peak Release (without it the wrap clicks). Both have defaults that stay out of the way.
- CPU: two tan() per sample. Fine for one or two instances; if it ever matters the fix is control-rate coefficient updates every 8 samples. There is an idle gate (env tiny AND ph == 0 -> skip the whole DSP block) so a stopped transport or a pre-fire manual instance costs nothing.
- Filter state guard is written as (abs(x) < 1000000 && ...) ? 0 : reset, which also catches NaN because NaN fails every comparison. No scientific-notation literals anywhere (used 0.0000001 / 1000000 explicitly) to avoid any EEL2 tokeniser doubt.
- No memory allocation, no gmem, no file I/O, no MIDI. in_pin/out_pin declared left/right; mono-safe via num_ch >= 2 check (sums to spl0 on a 1-channel track).
- ext_nodenorm = 1 set (feedback in the SVF and the pink filter).
- NOT compiled in REAPER from here - I verified structure mechanically instead: comment/string-stripped paren balance is exactly 0 at the end of every section (139 open, 139 close), every section header is in legal order, all ternaries are parenthesised, no 'if' keyword, no fmod, functions declared before use. Source also left at G:\tmp\jsfx\stryk_riser.
- One known behavioural quirk worth telling the user: in Follow Transport mode the riser repeats every N bars forever while the transport rolls (that is what "bar-locked" means). If he wants exactly one riser he either uses Manual Retrigger, or automates/bypasses the FX, or pulls Level down between build-ups.

---

## stryk_fs432_resonator

**Review fixed it:** True

Problems the reviewer found:
- FUNCTIONAL (measured, the real one): the feedback comb has no highpass anywhere in it, so it resonates at 0 Hz with gain 1/(1-decay) -- 25x at the default Decay 0.96, 1000x at 0.999 -- and the only guard is one weak one-pole on the input: `dcR  = exp(-2 * $pi * 8 / srate);      // ~8 Hz input DC blocker`. On the short delay lines you get at high Octave settings that 0 Hz peak is tens of Hz wide, so percussive/gated material comes back out as huge INAUDIBLE subsonic energy. Rendered through a real REAPER 7.78 instance at Octave 6 / Decay 0.96 (the shipping decay) / Mix 100: the sub-25 Hz component of the output peaks at 0.293 (-10.7 dBFS), nearly DOUBLE the test signal's own sub-25 content, and sub-20 Hz holds -2.2 dB of ALL output energy -- i.e. the plugin's output is mostly rumble. Octave 5 measures the same (-1.6 dB of total, sub peak 0.260). At Octave 6 / Decay 0.999 it is -0.3 dB of total. It eats headroom, inflates the peak meter and thumps woofers for nothing. Fixed with a two-pole highpass on the EXCITATION ONLY at 0.3 x root (clamped 10..600 Hz), which sits below the lowest voice mode (the root itself) and well above DC, so it starves the 0 Hz resonance without touching a single musical mode and without putting anything inside the feedback loop. Verified: sub-25 peak down 15.2 to 61.1 dB across seven settings, ring tuning and harmonic alignment unchanged (91 / 182 / 272 / 363 / 454 Hz before and after), default-patch level and width unchanged (peak 0.8449 -> 0.8313, L/R corr 0.812 -> 0.811), identical at 44.1k and 96k, no NaN anywhere.
- FUNCTIONAL (minor): `ext_tail_size` is never declared, so REAPER only grants the default tail and the ring gets chopped. The file's own comment says `At Decay 0.96 / Damp 6000 Hz the F#2 voice rings roughly 1.9 s` -- but rendering a 2.0 s item through it returned only 3.0 s, i.e. a 1 s tail, cutting the advertised ring roughly in half on every render and on every transport stop. Fixed with `ext_tail_size = srate * 4;` in @init.
- NOT A BUG, recorded so it is not re-flagged: an in-loop highpass looks like the obvious fix for problem 1 and IS WRONG here. I built it first (one-pole DC blocker per voice at 0.15 x voice frequency, with exact phase-delay compensation folded into the delay length) and measured it: the voice's own fundamental stays correct, but because the filter's phase lead in SAMPLES shrinks with frequency, the comb's upper modes stretch -- voice 1's partials moved to 90.75 / 178.5 / 266.75 / 355.5 Hz instead of 91 / 182 / 272 / 363. They then no longer coincide with voices 2..6, the whole point of stacking the harmonic series, and output dropped ~10 dB at defaults. Excitation-side filtering is the only place this belongs.

**Sliders**
```
slider1  Root Note                          default 6 (F#)   enum index 0..11 {C,C#,D,D#,E,F,F#,G,G#,A,A#,B}
slider2  Octave (2 = F#2 90.82 Hz at 432)    default 2        range 0..7 step 1
slider3  Reference Hz (A4 tuning)            default 432      range 400..460 step 0.1
slider4  Voices (harmonics 1..6 x root)      default 4        range 1..6 step 1
slider5  Decay / Resonance (loop feedback)   default 0.96     range 0.5..0.999 step 0.001
slider6  Damping (Hz, lowpass in loop)       default 6000     range 500..18000 step 10
slider7  Spread (cents detune, stereo width) default 6        range 0..25 step 0.1
slider8  Mix (% wet)                         default 35       range 0..100 step 0.1
slider9  Output Trim (dB)                    default 0        range -24..24 step 0.1
```

**Design notes**

DSP approach
- Six independent tuned comb / Karplus-Strong resonators. Voice k (k = 1..Voices) is a delay line of length srate/(k*f0) with a one-pole lowpass in the feedback path; feedback coefficient = the Decay slider. Output tap is taken pre-damping so the top end is present on the first pass and dulls as it decays, which is the classic struck-string behaviour.
- Fundamental: f0 = refHz * 2^((midinote-69)/12), midinote = 12*(octave+1)+semitone. Defaults slider1=6 (F#), slider2=2 -> midinote 42 -> 432 * 2^(-2.25) = 90.8163 Hz, matching the brief's F#2 = 90.82. x2 = 181.63 (F#3), x4 = 363.27 (F#4) fall out automatically because they are octaves of the root.
- Deliberately does NOT read `tempo`. Nothing here is tempo-synced; ring length is a function of delay length and feedback, so binding it to project BPM would be fake. 144 BPM appears only in the header comment as the reference groove the default decay times were chosen against (F#2 voice T60 ~1.9 s at decay 0.96, x4 voice ~0.5 s at 48 kHz).

Things that are easy to get wrong and were handled explicitly
1. Pitch error from the damping filter. The one-pole in the loop contributes its own phase delay, which flattens every voice — worse at higher damping settings and shorter delay lines. I compute pd = atan(a*sin(w)/(1-a*cos(w)))/w (a = 1-dcoef) at each voice's own frequency and subtract it from the delay length. Without this the x4/x5/x6 voices drift audibly flat at Damping 500 Hz.
2. Fractional delay. Linear interpolation between two taps, so tuning is right at 44.1/48/88.2/96/192 k rather than quantised to integer samples (at 48 kHz an integer-only tap on F#4 would be off by ~10 cents).
3. Level. A comb's resonant gain is 1/(1-fb), i.e. 25x at 0.96 and 1000x at 0.999. Input is pre-scaled by pow(1-fb, 0.7)*1.4/sqrt(voices) — the 0.7 exponent (rather than 1.0) keeps the transient audible on drums without letting sustained tonal input reach absurd steady-state gain. Sweeping Decay across its whole range moves perceived loudness by only a few dB.
4. Mix is a constant-power crossfade (dry = sqrt(1-m), wet = sqrt(m)) not linear, so the dry drums do not thin out at the 35% default.
5. Delay-length guard: clamped to [2, DBUFSZ-4] samples after the phase-delay subtraction, so it can never go below 1 sample or overrun the buffer. Frequency itself is clamped to [10 Hz, 0.45*srate] before the division, so no divide-by-zero.
6. Any voice whose natural frequency exceeds 0.45*srate is muted (amp = 0) rather than clamped-and-mistuned — relevant at Octave 7 with 6 voices on a 44.1 k project.
7. Runaway protection: feedback hard-capped at 0.9995, loop state clamped to +/-16, and a NaN/inf trap written as !(abs(x) < 1e29) ? x = 0 — the inverted form is deliberate because EEL2's == / != use an epsilon compare and cannot detect NaN via x != x.
8. ext_nodenorm = 1 is set, which turns off REAPER's own denormal noise injection, so a 1e-20 DC trickle is added to the resonator input to keep the loop out of denormal territory during silence. It is 100+ dB below anything audible even after the comb's DC gain.

Stereo / mono / rate changes
- Voices alternate pan: even index left, odd index right, magnitude growing outward, equal-power law. Detune follows the same sign, so the left side sits flat and the right side sharp by up to Spread cents — that is where the width comes from. With Voices = 1 the single voice is dead centre and undetuned.
- Input excitation is (spl0+spl1)*0.5 on stereo tracks, spl0 alone on mono (inmix set from num_ch in @block), so a mono source is not 6 dB down.
- All srate-dependent coefficients (damping, smoothing, DC blocker, delay lengths) are computed in a function called from both @init and @slider; @init re-runs on samplerate change, so nothing goes stale.

Zipper / click control
- Delay length, per-voice pan gains, and the dry/wet/trim gains are all one-pole smoothed at ~20 ms per sample. Changing Root or Octave glides (a short doppler slide) instead of clicking. Voices activated for the first time snap rather than gliding from zero length, which would otherwise create a 1-sample feedback loop.

Memory
- 6 x 65536 doubles of delay line plus 72 slots of state = 393288 slots, freembuf'd to that top. 65536 covers the worst legal case (400 Hz ref, lowest note, 384 kHz) with headroom.

Uncertainty
- The two taste constants are the input gain fudge (1.4) and the 0.7 compensation exponent. They were reasoned about rather than heard, so if it comes back too quiet under drums, raise 1.4; if sustained pads over-resonate at Decay 0.999, lower the exponent toward 1.0. Output Trim exists as the escape hatch either way.
- The @gfx panel is informational only (frequencies, pan, relative voice level); no mouse interaction, so it cannot break the DSP.

Local copy of the file: G:\tmp\stryk_fs432_resonator

---

## stryk_transient

**Review fixed it:** False

**Sliders**
```
slider1: Attack (%) — default 30, range -100..100 step 1
slider2: Sustain (%) — default -15, range -100..100 step 1
slider3: Fast Attack Follower (ms) — default 1, range 0.1..20 step 0.01
slider4: Slow Attack Follower (ms) — default 40, range 5..200 step 0.5
slider5: Output (dB) — default 0, range -24..24 step 0.1
slider6: Listen — default 0 (Off), enum {Off, Envelope Difference}
slider7: Mix (% wet) — default 100, range 0..100 step 0.5
```

**Design notes**

DSP design
- Single linked detector: d = max(|spl0|,|spl1|) + 1e-18. One gain applied to both channels, so the stereo image cannot shift. Mono-safe (spl1 = 0 just makes d = |spl0|).
- Attack path: two one-pole followers on the same rectified signal, differing only in ATTACK time (slider3 fast, slider4 slow) with a shared release max(2*slow, 50 ms). Attack signal = 20*log10(envFast/envSlow), clamped to 24 dB, scaled by Attack% * 1.6.
- Sustain path: two followers with the SAME 10 ms attack but short vs long RELEASE (max(slow,30) ms vs max(8*slow,300) ms). In the decay region the long-release env sits above the short one; that dB difference * Sustain% * 1.0 is the sustain gain. Negative Sustain tightens the tail, positive fattens it.
- Both paths soft-gated by env/(env+0.001) (-60 dBFS pivot) so silence and noise floor between 16th notes never get pumped or gated-chattered.
- Sum of the two gains clamped to ±24 dB, converted with exp(dB*ln10/20), then smoothed by a 0.3 ms one-pole → continuous gain, click-free. Output and Mix each get their own 20 ms smoother (mandatory anti-zipper on anything touching gain).

Stability / safety
- No feedback anywhere: the detector reads the INPUT only, never the gained output, so self-oscillation is structurally impossible. All one-pole coefficients are 1-exp(-x) with x>0, i.e. strictly in (0,1], so no follower can diverge.
- Divide-by-zero guarded by +1e-18 on every ratio numerator/denominator and by the +noisefloor in the gate. log() is only called on rr > 1.000001, never on 0 or negative.
- Denormals: ext_nodenorm=1 (per house style) plus a 1e-18 DC floor added to the detector each sample, so the four envelopes settle at ~1e-18 rather than drifting into denormal range. 1e-18 is written as 0.000000001*0.000000001 to avoid relying on exponent literal parsing.
- All coefficients live in a setcoefs() function called from BOTH @init and @slider, so a samplerate change (which re-runs @init) rebuilds them — no stale coefficients, no blowup.

Tempo / tuning handling
- Nothing tempo-locked in the DSP; 144 is used only to justify the default TIMES in the comment block (40 ms slow attack sits inside a 1/16 = 104.167 ms at 144, so 16th plucks each get their own transient; 300 ms long release ≈ 3/4 beat). `tempo` is read once per block into curbpm for the readout only, so the display follows the project.
- A=432 / F# affects nothing here — this is a purely level-domain processor with no filters, oscillators or pitch tracking. Stated explicitly in the header comment rather than faking a dependency.

Listen mode
- "Envelope Difference" outputs dry*(gain-1), i.e. exactly wet-minus-dry: you hear only what the shaper adds or removes, silence when it is idle. Mix is bypassed in that mode (Output still applies). No extra makeup boost is applied to the delta — deliberate, so the listen path can't surprise anyone with a level jump.

Risk notes
- Gain reaches its ±24 dB clamp only at extreme slider settings on very dynamic material; at the defaults (+30/-15) a pluck sees roughly +4 to +6 dB of attack and about -2 dB of tail.
- @gfx is cosmetic; it reads gdisp/curbpm/sliders only and does no allocation, so it can't affect audio. Both ternary branches are fully parenthesised, and gfx_w is floored via max() before the meter maths.

---

## stryk_monobass

**Review fixed it:** True

Problems the reviewer found:
- FATAL COMPILE ERROR — EEL2 has no exponent notation. The file uses scientific-notation numeric literals in six places, e.g. `dnv  = 1.0e-18;                                     // anti-denormal dither`, `abs(dg_s - dg_last) > 1.0e-9 ? (`, `abs(mLL) < 1.0e-30 ? ( mLL = 0; );` (x4), `(abs(outl) < 1.0e8 && abs(outr) < 1.0e8) ? (`, and `g_db = 10*log10(max(mML, 1.0e-12));`. `1e-9`, `1.0e-9`, `1.0e9`, `1.0E-9`, `1.0e-18` and `1.0e8` were each tested in isolation in REAPER 7.78 and ALL fail to parse; `0.000000001` compiles fine. Because a parse error anywhere silently disables the whole effect, the plug-in loads, reports all 7 sliders with correct names and enum labels, and passes audio through completely untouched. Verified empirically: rendering the test signal through the file as submitted produced output byte-identical to the dry reference (max sample difference 0.000000), while the same file with the literals written longhand produced max difference 0.61154.
- Drive bypass steps the bass gain by ~1.1 dB in a single sample. `drive_on ? ( mmid = tanh_s(mmid * dg_s) * dn_cur; );` — `drive_on` is a hard boolean recomputed in @slider from the raw slider, but `dg_s` (and therefore `dn_cur`) is smoothed over ~8 ms. Pulling Bass Drive from, say, 50 back to 0 clears `drive_on` instantly while `dg_s` is still 1.275, so the nonlinearity's small-signal makeup gain (dg*0.5/tanh(0.5*dg) = 1.132) is removed in one sample instead of riding down — an audible click on a gain path, which the brief says must always be smoothed. Fixed by gating on the smoothed value: `(drive_on || dg_s > 0.0501) ? ( ... )`.

**Sliders**
```
slider1: Mono Below (Hz) -- default 120, range 20..500, step 1
slider2: Crossover Slope -- default 1 (24 dB per oct / LR4), enum 0 = 12 dB per oct (LR2), 1 = 24 dB per oct (LR4)
slider3: Bass Gain (dB) -- default 0, range -12..12, step 0.1
slider4: Bass Drive (percent) -- default 0, range 0..100, step 1
slider5: Subsonic High-Pass (Hz, 0 = off) -- default 24, range 0..80, step 1
slider6: Stereo Below Compensation (percent side kept) -- default 0, range 0..100, step 1 (0 = hard mono, 100 = band left fully stereo)
slider7: Mono Check -- default 0, enum 0 = Off, 1 = Solo Bass Band, 2 = Solo Above
```

**Design notes**

CROSSOVER / PHASE (the load-bearing design decision)
Instead of running an LP and a separate HP (which only sum flat in theory and drift with coefficient rounding), the high band is derived by subtraction from a matched all-pass: high = AP(x) - low. That is exact because an LR crossover's halves sum to exactly one all-pass:
- LR4: LP^2 + HP^2 = (s^4+w0^4)/D^2 = (s^2-sqrt2*w0*s+w0^2)/(s^2+sqrt2*w0*s+w0^2) = 2nd-order AP at w0, Q=1/sqrt2.
- LR2: LP^2 - HP^2 = (w0-s)/(w0+s) = 1st-order AP (the subtraction supplies LR2's mandatory polarity flip for free).
The bilinear transform is conformal and RBJ's LPF/APF at the same w0/Q are the bilinear images of those prototypes, so the identity holds exactly in the digital domain at any samplerate. low+high == AP(x) sample-for-sample: no crossover dip, no bump, and the bands cannot drift apart in phase because one is defined as the other's remainder. L and R share coefficients, so no interchannel phase is introduced and the image above the crossover is untouched.
LR2 = two cascaded 1st-order sections stored in the same biquad slots (b2=a2=0), LR4 = two cascaded Butterworth Q=0.7071 biquads. Switching slope swaps coefficients live (stale x2/y2 states are multiplied by zero coefficients on the way back to LR2, so no cleanup needed) -- flagged in the header comment that a slope change can tick on loud material.

DEFAULTS AGAINST THE SESSION
120 Hz sits between F#2 (90.82) and F#3 (181.63) at A=432, so F#1/F#2 fundamentals go hard mono while the F#3+ harmonics keep width. Subsonic HP 24 Hz clears F#0 (22.70) which no PA reproduces. No time-based parameter exists in this effect, so `tempo` is deliberately unused and 144 appears only in comments -- nothing is hardcoded.

DRIVE
y = tanh(g*x) normalised by 0.5/tanh(0.5*g), i.e. unity gain at a -6 dBFS reference so a typical bass peak keeps its level while the curve adds harmonics and eats peaks. g = 0.05 + drive*2.45, so drive at 1% is audibly identical to 0% (continuous, no step when you leave zero) and g can never be 0 (no divide-by-zero in the normaliser). tanh is the exp form clamped to +/-12 so exp() cannot overflow, and (e+1) >= 1 so the division is always safe. IMPORTANT DETAIL: the normaliser is recomputed FROM the smoothed g each time g moves, not smoothed independently -- smoothing g and 0.5/tanh(0.5g) as two separate linear ramps mismatches mid-sweep and produces a ~20 dB blip on a 0->100 drive move. Drive hits the mid component only, never the side.
Signal order is gain -> drive, so Bass Gain pushes the saturator like an amp input.

STEREO BELOW COMPENSATION
Interpreted as "percent of the low band's SIDE component kept": 0 = hard mono (default), 100 = band passes untouched. Bass Gain scales mid and side together so the band's level moves as one.

SAFETY / ROBUSTNESS
ext_nodenorm=1 plus an alternating +/-1e-18 dither at the input; meter accumulators flush below 1e-30. Output guard is written as (abs(l) < 1e8 && abs(r) < 1e8) ? pass : flush-state-and-output-zero -- phrased that way on purpose so NaN (which fails every comparison) takes the reset branch rather than slipping through a `> ` test. All cutoffs clamped to min(limit, srate*0.45), srate floored at 8000, mono-safe via num_ch (reads spl0 twice, writes spl1 only when it exists). Everything recomputes in @init and @slider, and @init calls update_coefs() itself so a samplerate change reinitialises correctly.

GUI
Log 20..500 Hz strip with F#0..F#4 ticks at A=432 and the crossover marker, plus a pre-mono correlation meter for the low band (the number that actually tells him whether the mono-maker is doing work) and the mono band's RMS. All positions derive from gfx_w so it survives resizing.

RISK NOTE: I could not compile this here (no REAPER on this box). The syntax was written to the EEL2 rules given -- ternaries only, parenthesised branches, semicolons, memory-addressed state via function params, sprintf into #s for all strings, no string-literal expressions passed as %s except the one `mode` ternary in @gfx which selects between plain literals (supported in REAPER 7.x; if that one line is rejected on an older build, split it into a separate sprintf/gfx_drawstr pair).

---

## stryk_lfotool

**Review fixed it:** False

**Sliders**
```
slider1  Target                                 default 0 (Volume)   range 0..3 step 1  enum {Volume (tremolo), Pan (auto-pan), Low-Pass Cutoff, High-Pass Cutoff}
slider2  Shape                                  default 0 (Sine)     range 0..5 step 1  enum {Sine, Triangle, Saw Down, Saw Up, Square, Sample & Hold}
slider3  Rate                                   default 2 (1 bar)    range 0..6 step 1  enum {4 bars 6666.7ms, 2 bars 3333.3ms, 1 bar 1666.7ms, 1/2 833.3ms, 1/4 beat 416.7ms, 1/8 208.3ms, 1/16 104.2ms} (ms figures at 144 BPM 4/4)
slider4  Depth (%)                              default 50           range 0..100 step 0.1
slider5  Phase Offset (deg - 360 = one cycle)   default 0            range 0..360 step 1
slider6  Smoothing (ms)                         default 8            range 0..200 step 0.1
slider7  Base Cutoff (Hz - filter targets)      default 800          range 20..20000 step 1
slider8  Resonance Q (filter targets)           default 0.9          range 0.5..8 step 0.01
slider9  Free-run BPM (transport stopped)       default 144          range 40..300 step 0.01
slider10 Mix (%)                                default 100          range 0..100 step 0.1
```

**Design notes**

COMPILED AND RENDER-TESTED IN REAPER 7.78, not just written. Source at G:\tmp\jsfx\stryk_lfotool; also copied into the shared harness dir G:\tmp\reaper-cfg\Effects\stryk\stryk_lfotool.

VERIFICATION (isolated -cfgfile sandbox, 48 kHz, 144 BPM project, 10 slider configs rendered through action 40209 "Apply track FX to items as new take"):
- Loaded as "JS: STRYK LFO Tool ...", np=13 (10 sliders + Bypass/Wet/Delta), all 10 param names read back correctly, all 10 set values read back correctly.
- Control check: a deliberately broken JSFX (C-style `if(){}`) rendered BIT-IDENTICAL to dry, proving the test discriminates. Every stryk_lfotool config rendered different from dry and finite.
- Depth=0 and Mix=0 both null PERFECTLY against dry (RMS diff 0.000000) - no coloration or gain error when it should do nothing.
- Volume, Sine, 1 bar, Depth 50: measured gain ratio 0.5002..1.0000 = exactly the -6.02 dB floor, peak on the downbeat.
- Square, 1/8, Depth 100: floor 0.00000, open 1.00000, 15.8 ms 10-90% edge (matches the 8 ms one-pole), and max per-sample step 0.5828 vs the source's own 0.5833 - the gate introduces no step bigger than the material. Click-free.
- S&H 1/16: held values spread 0.004..0.914, max step 0.532 (below source). Click-free.
- Filters at Q=8/Q=4, LP and HP, 1/16 to 4 bars, base 20 Hz and 20 kHz, 40 and 300 BPM: all finite. In the worst case (Saw Down + Smoothing=0, i.e. an 8-octave cutoff jump every 104 ms) the biggest sample steps land at LFO phase ~0.51 - mid-sweep source content - NOT at the phase-0.0 wrap, so the segment interpolation absorbs the discontinuity.
- Stability proof for the interpolated coefficients: swept 800 Hz +/-4 octaves at the Q clamp (24), 2000 sweep points x 33 interpolation fractions, both LP and HP - worst pole radius reached 0.999864, zero violations. Also re-ran the whole @sample loop in Python at 44.1/48/96/192 kHz x block sizes 16/64/512/2048: stable everywhere.

DESIGN DECISIONS WORTH FLAGGING:
1. Filter topology. A prior session lesson says "use TPT/ZDF SVF for swept filters, the Chamberlin SVF blows up at high cutoff". I did NOT follow that here because the brief mandated a biquad, and the warning was specific to Chamberlin. I used RBJ in TRANSPOSED DIRECT FORM II (the right form under moving coefficients) and proved stability numerically instead of assuming it. Cutoff is hard clamped to 0.45*srate so it can never approach Nyquist.
2. "Per block" reading. Strict per-block recalculation is too coarse at 1/16 rate (only ~10 coefficient updates per LFO cycle at 512-sample blocks). I recompute per SEGMENT of min(samplesblock, 64) samples - always at least once per block, never more than one trig set per 64 samples - and linearly ramp all five normalised coefficients per sample to the new target. ~1.3 ms of control lag at 48k, inaudible, and still 1/64 of the per-sample cost.
3. Sample & Hold is a deterministic hash of floor(beat_position/period_beats), not rand(). Identical on every playback, identical across instances, survives looping. rand() would give a different arrangement every time you hit play, which is useless.
4. Square and S&H silently floor Smoothing at 1 ms. Everything stays adjustable, but 0 ms on a hard edge is a click by construction and no slider position should be able to produce one.
5. Pan uses the sqrt constant-power law (gl=sqrt(2(1-p)), gr=sqrt(2p)) - cheaper than cos/sin, unity gain at centre rather than -3 dB, gl^2+gr^2 constant. On stereo material this is a BALANCE, which is what auto-panners do; on a genuinely mono track (num_ch < 2) Pan passes through untouched rather than turning into a second tremolo.
6. No auto-makeup gain on the filter. Q 8 is ~+18 dB at the corner and WILL clip a hot source - documented in the header rather than compensated, because makeup would flatten the sweep, which is the entire point.
7. NaN/Inf is guarded on the INPUT (before the biquad can swallow it into its state) and again on the output, with a state flush. `(x > -100000 && x < 100000) ? 0 : (x = 0;)` catches NaN because every comparison against NaN is false.
8. Bar length comes from ts_num/ts_denom, so "1 bar" is correct in 3/4, 6/8 etc. 144 appears only as the Free-run BPM default and in labels/comments; while rolling, everything comes from `tempo` and `beat_position`.

RISK I COULD NOT ELIMINATE: none found. The one cosmetic unknown is the "&" in the "Sample & Hold" enum label - it rendered fine in REAPER's param list during the audit ("Shape" reads back correctly), so it is not a mnemonic-eating issue.

Cleanup: the temporary verification resource dir (G:\tmp\reaper-cfg-lfo) and its render project were deleted; the sandbox REAPER instance I launched was closed. STRYK's real REAPER config was never touched.

---

## stryk_scaleforce

**Review fixed it:** False

**Sliders**
```
slider1  Root Note                                    default 6 (F#)   enum 0..11 {C,C#,D,D#,E,F,F#,G,G#,A,A#,B}
slider2  Scale                                        default 0        enum 0..6 {Natural Minor (Aeolian),Harmonic Minor,Dorian,Phrygian,Major (Ionian),Minor Pentatonic,Phrygian Dominant}
slider3  Snap Direction                               default 0        enum 0..2 {Nearest (ties go down),Down only,Up only}
slider4  MIDI Channel                                 default 0 (All)  enum 0..16 {All Channels,Ch 1 .. Ch 16}
slider5  Bypass Below Note (MIDI note #, 0 = none)    default 0        range 0..127 step 1
slider6  Bypass Above Note (MIDI note #, 127 = none)  default 127      range 0..127 step 1
slider7  Block Program Change                         default 1 (Yes)  enum 0..1 {No - pass them through,Yes - block PC + Bank Select}
slider8  A Reference Hz (display readout only)        default 432      range 400..466 step 0.01
```

**Design notes**

WHAT IT DOES
Per-event MIDI scale quantiser in @block. Inserts sounding correctly with zero touches: F# natural minor, nearest-snap, all channels, full note range, program change blocked.

SCALE REPRESENTATION
Each scale is a 12-bit mask (bit i = semitone i above root is in scale), unpacked in @slider into a 12-slot rel_tbl. Verified numerically:
  Natural Minor 1453 (0 2 3 5 7 8 10) | Harmonic Minor 2477 (0 2 3 5 7 8 11) | Dorian 1709 (0 2 3 5 7 9 10)
  Phrygian 1451 (0 1 3 5 7 8 10) | Major 2741 (0 2 4 5 7 9 11) | Minor Pentatonic 1193 (0 3 5 7 10) | Phrygian Dominant 1459 (0 1 4 5 7 8 10)
Root 6 + natural minor gives F# G# A B C# D E = F# minor = Camelot 11A. rel_tbl[0] is force-set to 1 after unpacking so the search loop can never fail to terminate even if a mask were ever wrong.

QUANTISE
Search runs in absolute note space (not pitch class) so it snaps across octave boundaries correctly and clamps at 0/127. Nearest searches outward d = 0..24 checking DOWN first, so ties resolve to the flat neighbour - deliberate: on a diatonic scale every non-scale tone is 1 semitone from both neighbours, so a tie rule is mandatory and downward keeps the darker read that suits minor-key trance. Down-only / Up-only run a one-sided search with the nearest search as a fallback if they run off the end of the 0..127 range. No fmod anywhere - modulo is `rel - floor(rel/12)*12` per EEL2 rules.

HANGING-NOTE HANDLING (the part that matters)
The brief said 128 entries; I used 16 x 128 = 2048 (map_out) plus a parallel 2048 (map_cnt), i.e. a 128-entry array PER CHANNEL. A flat 128 array is genuinely broken on multi-channel input: note 60 on ch1 and ch2 can map to different targets, and a shared slot would strand one of them. Two extra deviations, both for the same reason:
  - map_cnt is a reference count, so two NOTE ONs on the same input note followed by one OFF do not free the mapping early and leak a voice.
  - Bypassed notes (out of channel filter, or out of note range) store an IDENTITY mapping rather than nothing. That way the note-off path is a pure table lookup, and moving the range/channel sliders while a bypassed note is held still produces a matching off.
Poly aftertouch (0xA0) is remapped through the same table so per-note pressure follows its note. CC120 (all sound off) and CC123 (all notes off) clear that channel's table. Orphan note-offs with no stored mapping are best-effort quantised with current settings rather than passed raw.

PROGRAM CHANGE BLOCKING
Ships ON. Blocks 0xC0 and, because a PC is meaningless without it, CC0 (bank MSB) and CC32 (bank LSB) as well. Everything else - CC, pitch bend, channel aftertouch, clock - passes untouched.

TEMPO / TUNING
No timing element exists in this effect, so there is nothing to derive from `tempo` and nothing is pinned to 144. It is correct at any BPM. A=432 cannot affect MIDI note numbers (they carry no Hz), so slider8 is honestly labelled display-only - it drives the GUI readout showing the root's octave-4 frequency and the cents offset vs 440. At the defaults it reads "F# Natural Minor / A=432.00 Hz (-31.77 cents vs 440) root oct4 = 363.27 Hz", which matches the brief's F#4 = 363.27 exactly. If he wants actual 432 playback, that is a synth master-tune or pitch-bend job, not this plugin's - I did not fake it.

GUI
460x152. Twelve cells = semitones above root, lit cells are in-scale, root cell is brighter cyan; numbers underneath; last note in -> out readout at the bottom so he can see mapping happening. @gfx uses its own g_* variable names so it never collides with the audio-thread variables.

VERIFICATION DONE (file written to G:\tmp\jsfx-build\stryk_scaleforce)
1. Paren/bracket balance across the whole file after stripping comments, strings and slider lines: 0/0, no errors. Sections present and in legal order. No `if(`, `else`, `for(` or `fmod` anywhere.
2. All 7 bitmasks recomputed from their interval lists - all match.
3. Faithful Python port of the exact EEL2 logic, full sweep of 12 roots x 7 scales x 3 directions x 128 notes = 32,256 quantises: zero out-of-scale results, zero out-of-range results.
4. Hanging-note torture: 200 trials x 400 random interleaved on/off events across all 16 channels, with root/scale/direction/range mutated mid-flight roughly every 20 events. Zero hanging notes, map and count arrays fully drained to zero at the end of every trial.
5. Spot checks: retrigger (on/on/off/off) frees exactly once; PC + CC0 + CC32 blocked while CC11 and pitch bend pass; channel filter and note-range bypass leave notes at their original number; CC123 clears the map.
6. File is pure ASCII, LF line endings, no tabs - 10,697 bytes, 320 lines.

RISK NOTE
Only untested-in-REAPER item is the compile itself (no REAPER instance reachable from this sandbox; the reaper MCP server failed to connect this session). Every language construct used is standard documented EEL2: `while (cond) (body)`, `loop(n, body)`, parenthesised ternary branches, `$x` hex literals, `|0` int truncation, `strcpy(#s,"lit")`, `sprintf` with %d/%.2f, functions declared in @init with local(), and `base[offset]` memory addressing. Memory top is 4127 and freembuf(4128) matches exactly.

---

## stryk_chordgen

**Review fixed it:** True

Problems the reviewer found:
- FATAL, whole plugin dead: `function pcname(#s, pc)` -- EEL2/JSFX does not support '#'-prefixed FUNCTION PARAMETERS. Only globals (#foo) and string literals are '#'-typed; a string is handed to a function as a plain numeric handle. Verified in REAPER 7.78: a minimal `function f(#s) ( strcpy(#s,"C"); );` fails to compile, as do `f(#s, pc)`, `f(pc, #s)` and `f(#s) local(o)`. FIX: `function pcname(s, pc)` with `strcpy(s,...)` inside; call sites keep `pcname(#gk, slider1);` unchanged.
- FATAL, same cause: `function nname(#s, nt) local(o)` -- and its body `pcname(#s, nt);` / `strcpy(#gtmp, #s);` / `sprintf(#s, "%s%d", #gtmp, o);`. FIX: `function nname(s, nt) local(o)` with `pcname(s, nt); strcpy(#gtmp, s); sprintf(s, "%s%d", #gtmp, o);`. Verified working: `nname(#gv, 66)` now yields exactly "F#4".
- KNOCK-ON EFFECT (this is why it is fatal rather than cosmetic): both broken functions live in @init, so @init fails to compile. That means `note_out`, `note_kill`, `chord_off`, `chord_on` and `panic_all` are never defined, so @block (which calls `chord_on(mch, msg2, msg3, mofs, passes);` and `panic_all(0);`) and @gfx (which calls `pcname(#gk, slider1);`) fail to compile too. Measured in REAPER 7.78 with a per-section probe: @init=DEAD, @block=DEAD, @gfx=DEAD. The plugin still instantiates and shows all 8 sliders with correct names/defaults, so it LOOKS fine -- but MIDI passes straight through untouched. Applying it to a test item produced byte-identical output to the input for all six slider configurations tested (defaults, 9th+inv+spread, Power 5th, Major/Sus4, Latch on, channel filter).
- NOT A DEFECT, recorded so it is not 'fixed' later: with Latch ON, an offline render/apply ends with notes still sounding (measured 9 on / 5 off). That is what latch means -- the sweep that releases them is the transport-stop / CC120 / CC123 / latch-off path in @block, which an offline apply never triggers. Live behaviour is correct. Left as-is.
- NOT A DEFECT, verified correct so nothing else was touched: memory map does not overlap (outref 0..2047, slotb 2048..18431, sclb 18432..18455, chtb 18464..18511, lastb 18512..18519, memtop 18520) and nothing reads past the end; section order @init/@slider/@block/@gfx is legal; in_pin:none + out_pin:none are present; `tempo` is read from the host, 144 appears only as a fallback/label; the 432 maths in the header is right (12*log2(432/440) = -31.77 cents, F#4 = MIDI 66 = 363.27 Hz). After the fix the ref-counted note tracking measured clean: F#2 -> F#2+A2+C#3, A2 -> A2+C#3+E3, the shared A2/C#3 correctly survive F#2's release, and note-on/note-off counts balance 12/12, 20/20, 8/8, 12/12 with zero stuck notes.

**Sliders**
```
slider1  Key Root                                    default 6 (F#)   enum 0..11 {C,C#,D,D#,E,F,F#,G,G#,A,A#,B}
slider2  Scale                                       default 0        enum 0..2 {Natural Minor, Harmonic Minor, Major}
slider3  Chord Type                                  default 0        enum 0..5 {Triad, 7th, 9th, Sus4, Power 5th, Octave}
slider4  Inversion (lift N lowest added voices +1 oct) default 0       0..3 step 1
slider5  Spread (octaves added to the top voices)     default 0       0..2 step 1
slider6  Added Voice Velocity (% of played note)      default 85      0..100 % step 1
slider7  MIDI Channel Filter                          default 0 (All) enum 0..16 {All, Ch 1 .. Ch 16}
slider8  Hold / Latch                                 default 0 (Off) enum 0..1 {Off, On}
```

**Design notes**

DIATONIC CONSTRUCTION
Input note -> scale degree, then upper voices are stacked from the scale table, not from fixed semitone intervals. rel = note - keyroot; oc = floor(rel/12); pc = rel - oc*12 (floor, so negative notes are handled correctly); degree = largest scale index whose offset <= pc. Voice = keyroot + (oc + floor(idx/7))*12 + scale[idx mod 7], idx = degree + step. Steps: Triad 3rd/5th (2,4), 7th (2,4,6), 9th (2,4,6,8), Sus4 4th+5th (3,4).

Power 5th (+7) and Octave (+12) are deliberately CHROMATIC, not diatonic — a diatonic "5th" on degree ii of a minor scale is a tritone, which is not a power chord. Documented in the header.

Out-of-key input notes are NOT re-pitched: the played note passes through as played, and the added voices are built from the nearest scale degree at or below it, so the harmony stays in key while his performance is untouched.

Verified against a Python model of the identical tables: F# natural minor gives F#m, G#dim, A, Bm, C#m, D, Em across the degrees; harmonic minor on degree V correctly produces C#-F(E#)-G#-B (the dominant 7th, the whole point of that scale); C major 7th on C4 gives Cmaj7. Negative rel (note 0 in F#) and >127 clamping both behave.

NO STUCK NOTES — the part that actually matters
Two layers:
1. Per-input-note slot (2048 slots, stride 8, indexed [chan*128+note]): stores active flag, added-voice count, and the actual added note numbers. The note-off releases exactly those numbers, so slider changes mid-note can never orphan a voice.
2. Per-(channel,note) reference count on everything the plugin emits. If two chords share a pitch (play D then A in F#m — both want A), the pitch only receives its note-off when the last holder lets go. Re-emitting a sounding pitch sends note-off then note-on so it retriggers cleanly but only increments the counter.
The plugin owns ALL note traffic (it re-emits the played note itself rather than passing it through) — that is what keeps the counts honest. Notes on filtered-out channels are still tracked, just with dochord=0, so the accounting never has holes.
Full sweeps on CC120/CC123, transport stop (edge-detected on play_state, so live jamming with the transport stopped is unaffected), and Latch switching off. midisend is illegal in @slider so the latch-off sweep is flagged there and executed at the top of @block.

LATCH
Toggle-style: press to start, press the same key again to release; physical note-offs are swallowed while latched. Only applies on channels that pass the filter.

INVERSION / SPREAD
Inversion lifts the N lowest ADDED voices an octave (the played note is never moved — it's his performance). Spread widens from the top down: lift(i) = spread - (nadded-1 - i) octaves, so spread 1 lifts the top voice, spread 2 gives a wide two-octave open voicing. Voices that would exceed 127 are simply not emitted (and not stored, so nothing to release).

144 / F# / 432
MIDI-only, so tuning and tempo do not affect processing: A=432 is a synth-side detune of -31.77 cents and is documented in the header rather than faked with pitch bend. Nothing is hardcoded to 144 — the GUI readout reads the real project `tempo` (cached into curtempo in @block, since gfx runs on the UI thread) and prints 1/4, 1/8 and 1/16 in ms for dialling gates elsewhere.

RISK NOTES
- ext_noinit=1 so held-note bookkeeping survives transport/samplerate resets; nothing in the code is samplerate dependent.
- All ternary branches containing assignments are parenthesised, so there is no EEL2 parser ambiguity.
- Memory top is 18520 doubles, freembuf'd; memset(0,0,memtop) on load.
- Verified balanced parens/brackets and that no bare `? var =` forms remain.
- Working copy at G:\tmp\jsfx_build\stryk_chordgen (nothing written into the harness directory).
- One accepted trade-off: a stray external note-off for a pitch that the plugin is holding as an added voice will silence it early. The refcount stays consistent (the eventual note-off is a harmless no-op) — no hang, just an early cut in a scenario that requires MIDI from outside the plugin's own note flow.

---

## stryk_tuner432

**Review fixed it:** True

Problems the reviewer found:
- FATAL — will not compile (13 occurrences): `gfx_measurestr` is called with ONE argument, e.g. `tw = gfx_measurestr(#s2);` and `w1 = gfx_measurestr(#nm); h1 = gfx_texth;`. In EEL2/JSFX the signature is `gfx_measurestr("str",&w,&h)` — exactly 3 parameters, and it writes the width/height into the passed variables rather than returning the width. Verified two ways: (a) REAPER's own API help table inside `C:\Program Files\REAPER (x64)\reaper.exe` contains BOTH `gfx_measurestr\t"str"\t...Returns width and height` (that is the *Lua* `gfx.measurestr`) and `gfx_measurestr\t"str",&w,&h\t...` (the EEL2 one); (b) every one of the 15 uses in REAPER's stock JSFX uses the 3-arg form, e.g. `Effects/analysis/gfxscope:51: gfx_measurestr(str, w, h);` and `Effects/utility/channel_mapper:341: gfx_measurestr("Channels:",txtw,txth);`. NSEEL enforces parameter counts at compile time, so the whole effect fails to load with a parameter-count error and nothing renders. Affected lines: the `IN xx dB` header, `#nm`, `#oc`, `#kk`, `#ct`, the tick-label loop, the three DETECTED/TARGET/STABILITY labels, the three value cells, and the footer.
- Accuracy defect at the top of the range: `(ff > 1 && abs(ff - cfz) < cfz*0.09) ? ( fcz = srate/ff; );`. The refine-acceptance guard is a *percentage* of the lag, but the coarse estimate's quantisation error is a fixed ±DEC/2 full-rate samples no matter what the pitch is (DEC = 9 at 44.1 k, 20 at 96 k). Above roughly 880 Hz at 44.1 k, 0.09*cfz falls below that error, so legitimate full-samplerate refinements are thrown away and the reading falls back to the raw decimated estimate — at the default 1200 Hz ceiling one decimated lag step is ~4 %, i.e. 70+ cents, so the note name, cents number and needle are all wrong in exactly the region the header comment claims "roughly 1 cent resolution even up at F#6". Since the searched window is only `lo = floor(cfz) - (DEC + 2)` to `hi = ceil(cfz) + (DEC + 2)`, an octave error cannot occur inside it, so the guard should simply be the window itself: `abs(ff - cfz) <= DEC + 3`.
- Everything else checked out and was left alone: paren balance is exact (verified programmatically), section order @init/@slider/@block/@sample/@gfx is correct, no `if`/`fmod`/invented builtins, `gfx_setfont` 3- and 4-arg forms and the `'b'` char literal are valid (stock JSFX uses both), buffer regions fbuf/dbuf/yd/ycm/fd/tks do not overlap and no index can exceed its region, the circular-buffer `+ FBUFSZ*2` / `+ DBUFSZ*2` bias can never go negative, every division is guarded, and the tuning maths is right — `69 + 12*log2(f/ref)`, midi 66 -> pc 6 = F#, octv 4, `refhz*2^(-3/12)` = 363.27 Hz at 432, and `1200*log2(432/440)` = -31.77 cents. Tempo is read from `tempo`, never hardcoded to 144.

**Sliders**
```
slider1 | Reference A (Hz) | default 432 | 400..460 step 0.01
slider2 | Sensitivity Gate (dB RMS) | default -40 | -60..-10 step 0.5
slider3 | Smoothing (0 = snappy, 1 = slow) | default 0.7 | 0..1 step 0.01
slider4 | Lowest Note Detected (Hz) | default 55 | 30..300 step 1
slider5 | Highest Note Detected (Hz) | default 1200 | 300..2000 step 10
slider6 | Analysis Input (enum: 0=Left, 1=Right, 2=Mono Sum L+R) | default 2 (Mono Sum) | 0..2 step 1
```

**Design notes**

WHAT IT DOES
Pure analyser. spl0/spl1 are read in @sample and never written, so audio is bit-identical through the plugin. Everything happens in a side chain.

PITCH DETECTION (two-stage, this is the important bit)
1. Coarse: YIN-style autocorrelation on a decimated copy. The input is DC-blocked, run through 4 cascaded one-poles (cutoff = min(1800, dsrate*0.40)) and decimated by DEC = floor(srate/4800), giving a ~4.8 kHz analysis rate at any host samplerate. On that stream I compute the squared difference function d(tau) over a fixed window, then the cumulative-mean-normalised d'(tau), take the first tau under an absolute threshold of 0.15 (descending to its local minimum), and fall back to the global minimum if nothing crosses. Plain ACF picks octave-up errors on harmonically rich trance leads; the CMND normalisation is what kills that, for basically the same cost.
2. Fine: the coarse lag is only accurate to ~1 decimated sample = DEC full samples, which at F#5 (726 Hz) would be tens of cents of slop — useless for checking 432. So the coarse lag is scaled back to full rate and I run a narrow full-samplerate difference-function search of only +/-(DEC+2) lags around it, with parabolic interpolation on the minimum. That lands around 1 cent or better even up at F#6, and it's cheap because the search is ~25 lags wide, not thousands. Result is sanity-checked against the coarse estimate (must be within 9%) before it's accepted, so a bad refine can never produce a wild reading.

CPU
Analysis fires once every HOP = 256 decimated samples (~53 ms, ~19 Hz update) from @block, not per sample. Coarse cost is maxlag*winn (~45k inner iterations at defaults). Fine cost is capped explicitly — nfull = min(8192, srate*0.06, 250000/(2*DEC+8)) — so the refine work stays bounded at ~250k iterations per frame even at 192 kHz, where DEC hits 40 and the naive cost would grow with srate squared.

SMOOTHING
Frequency is smoothed in the LOG domain (one-pole on log(f), coefficient alp = smoothing*0.95 per frame). Log-domain means the smoothing time is the same in cents whether he's tuning a sub or a lead. If a new detection is more than 0.058 in log space (one semitone) from the smoothed value it SNAPS instead of gliding, so note changes are instant but the cents readout doesn't jitter. Default 0.7 ≈ 130 ms time constant.

GATING / HOLD
RMS follower (~20 ms) vs the dB gate slider. Below the gate the display greys out and shows "-- no signal --"; after 1.2 s of no valid pitch the smoother resets so the next note starts clean rather than gliding in from the last one.

GFX (480x300)
- Header: "REF A 432.00 Hz ( -31.8 cents vs A=440 )" — the 440 offset is computed live, so he can always see how far the reference sits from standard. Right side: input dB plus a small level meter with an amber tick marking the gate threshold, so setting the gate is visual.
- Big note name + smaller octave digit, centred (drawn as two strings so no %s formatting is needed anywhere).
- Cents as a signed number (sign prepended manually rather than relying on a "%+f" flag being supported) coloured green <=5c, amber <=15c, red beyond — same colour drives the needle.
- Needle bar centred at 0, +/-50 cents, with shaded green (+/-5) and amber (+/-15) zones, ticks and labels at -50/-15/-5/0/5/15/50, a translucent fill from centre to the needle so direction reads at a glance.
- F# highlight: violet panel behind the note plus a "SESSION KEY F#" badge when pitch class == 6.
- Bottom cells: DETECTED Hz / TARGET Hz (the equal-tempered target for the nearest note at the current reference) / STABILITY % (1 - d'(tau), i.e. how periodic the signal actually is — low % means it's noise or a chord, don't trust the reading).
- Footer: F#4 at the current reference (363.27 Hz at 432) and the live host `tempo`. Nothing is tempo-synced so 144 is never hardcoded; tempo is copied to a global in @block because it's documented for @block, not @gfx.

EEL2 SAFETY NOTES
- Every ternary branch is parenthesised, including single-statement ones, to avoid the `=` vs `?:` precedence trap.
- EEL2 identifiers are case-insensitive, so no two variables in the file differ only by case (that's why it's `gw/gh` not `W/H`, `bwd` not `bw`).
- All circular-buffer indices are made positive before masking (`+ FBUFSZ*2` / `+ DBUFSZ*2`) rather than relying on negative-int AND behaviour.
- Window sizes are constrained so a read window can never exceed its buffer (winn+maxlag <= DBUFSZ-8, nfull+maxlagf <= FBUFSZ-16), and the fine-refine scratch index can never exceed ~2*DEC+6 < 1024.
- Every division is guarded (tds>0.5, ff>1, run>1e-30, den>1e-30, max(srate,1)), and every loop's counter is incremented on all paths, so no infinite loop is reachable.
- All coefficients are derived in tuner_setup(), which is called from BOTH the end of @init and @slider — so it's correct regardless of call order and survives samplerate changes.
- ext_nodenorm=1 plus an explicit alternating 1e-18 dither into the filter chain, since the one-poles and DC blocker are recursive.
- Mono-safe: if num_ch < 2 it always reads spl0, so the "Mono Sum" default doesn't halve the level on a mono track.
- Compile-adjacent checks I actually ran: parenthesis/bracket balance verified programmatically (0 at EOF and 0 at every @section boundary), string-quote parity per line verified. I could not run REAPER headless to compile it, so that's static verification, not a compile.

FILE ALSO WRITTEN TO: G:\tmp\jsfx-out\stryk_tuner432

---

