#!/usr/bin/env python
r"""install.py -- install the always-on MIDI program-change stripper into REAPER.

Copies two ReaScripts into REAPER's Scripts folder and wires the startup hook so the
stripper runs from every REAPER launch with no clicks:

    <resource>\Scripts\stryk_midi_strip_pc.lua        the worker (defer loop)
    <resource>\Scripts\stryk_midi_strip_pc_toggle.lua on/off switch, bindable as an action
    <resource>\Scripts\__startup.lua              REAPER runs this natively at launch

Safe to re-run. __startup.lua is always backed up first. Its loader line is APPENDED if
absent; the one exception is a loader still pointing at the pre-2026-09-10 name
(midi_strip_pc.lua), which is rewritten in place -- that file no longer ships, so leaving
the stale dofile would make REAPER throw on every launch. Nothing else in the file is
touched either way.

    python install.py              install / update
    python install.py --uninstall  remove the scripts and the loader line
    python install.py --status     show what is currently installed

Takes effect on REAPER's next launch (the startup hook only runs at startup).
"""
import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent          # reaper-scripting/tools
SRC = HERE.parent / "scripts"         # reaper-scripting/scripts
RES = Path(os.environ["APPDATA"]) / "REAPER"
SCRIPTS = RES / "Scripts"
WORKER = "stryk_midi_strip_pc.lua"
TOGGLE = "stryk_midi_strip_pc_toggle.lua"

# Pre-2026-09-10 names, before the stryk_ prefix. Kept so an existing install
# can be migrated and cleaned up rather than left with a dofile pointing at a
# file this script is about to stop shipping.
OLD_WORKER = "midi_strip_pc.lua"
OLD_TOGGLE = "midi_strip_pc_toggle.lua"
STARTUP = "__startup.lua"
LOADER = 'dofile(reaper.GetResourcePath() .. "/Scripts/stryk_midi_strip_pc.lua")'
# Substring of the new worker name too, so it matches old AND new wiring.
MARK = "midi_strip_pc.lua"


def reaper_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq reaper.exe"],
                             capture_output=True, text=True).stdout.lower()
        return "reaper.exe" in out
    except Exception:
        return False


def status():
    print(f"REAPER resource dir : {RES}")
    print(f"  {WORKER:<30} {'installed' if (SCRIPTS/WORKER).exists() else 'MISSING'}")
    print(f"  {TOGGLE:<30} {'installed' if (SCRIPTS/TOGGLE).exists() else 'MISSING'}")
    sp = SCRIPTS / STARTUP
    if not sp.exists():
        print(f"  {STARTUP:<30} MISSING (stripper will not auto-start)")
    else:
        txt = sp.read_text(encoding="utf-8", errors="replace")
        print(f"  {STARTUP:<30} {'wired' if MARK in txt else 'exists but NOT wired'}")
    # Matches the LOG path in midi_strip_pc.lua, which now writes next to
    # REAPER's resources instead of into the source tree.
    log = RES / "midi_strip_pc_log.txt"
    if log.exists():
        lines = log.read_text(encoding="utf-8", errors="replace").strip().splitlines()
        print(f"\nstrip_log.txt: {len(lines)} line(s); last 5:")
        for l in lines[-5:]:
            print("   ", l)
    else:
        print("\nstrip_log.txt: not created yet (nothing stripped so far)")


def install():
    SCRIPTS.mkdir(parents=True, exist_ok=True)
    for name in (WORKER, TOGGLE):
        shutil.copy2(SRC / name, SCRIPTS / name)
        print(f"  installed  {SCRIPTS / name}")

    # Retire the pre-prefix copies. Leaving them behind means REAPER's action
    # list shows both, and the stale one still runs its own defer loop if it
    # was ever registered - two strippers sweeping the same project.
    for old in (OLD_WORKER, OLD_TOGGLE):
        p = SCRIPTS / old
        if p.exists():
            p.unlink()
            print(f"  retired    {p}  (renamed to stryk_ prefix)")

    sp = SCRIPTS / STARTUP
    if not sp.exists():
        shutil.copy2(SRC / STARTUP, sp)
        print(f"  created    {sp}")
    else:
        txt = sp.read_text(encoding="utf-8", errors="replace")
        lines = txt.splitlines()
        if LOADER in txt:
            print(f"  already wired  {sp}")
        elif any(MARK in l for l in lines):
            # Wired to the OLD filename. Rewrite that line rather than
            # appending: the old file has just been deleted, so leaving the
            # stale dofile there makes REAPER throw on every single launch.
            bak = sp.with_suffix(f".lua.bak-{time.strftime('%Y%m%d_%H%M%S')}")
            shutil.copy2(sp, bak)
            fixed = [LOADER if (MARK in l and "dofile" in l) else l for l in lines]
            sp.write_text("\n".join(fixed) + "\n", encoding="utf-8")
            print(f"  re-wired   {sp} to {WORKER}  (backup: {bak.name})")
        else:
            bak = sp.with_suffix(f".lua.bak-{time.strftime('%Y%m%d_%H%M%S')}")
            shutil.copy2(sp, bak)
            with sp.open("a", encoding="utf-8") as f:
                f.write("\n-- added by reaper-scripting/tools/install_midi_strip_pc.py\n")
                f.write(LOADER + "\n")
            print(f"  appended loader to existing {sp}  (backup: {bak.name})")

    print("\nInstalled. It starts with REAPER's next launch.")
    print("Turn it off any time: Actions > Show action list > New action > Load ReaScript >")
    print(f"  {SCRIPTS / TOGGLE}")
    print("Skip one track: put [keepPC] anywhere in that track's name.")
    print("It never edits a take whose source is a .mid on disk, and never sweeps while recording.")


def uninstall():
    for name in (WORKER, TOGGLE):
        p = SCRIPTS / name
        if p.exists():
            p.unlink()
            print(f"  removed    {p}")
    sp = SCRIPTS / STARTUP
    if sp.exists():
        lines = sp.read_text(encoding="utf-8", errors="replace").splitlines()
        # Match the current marker AND the pre-2026-09-10 one. An install done
        # before the repo reorg wrote the old absolute path into __startup.lua;
        # dropping that pattern would strand those lines forever, since
        # uninstall is the only thing that ever removes them.
        stale_markers = ("midi-strip-pc\\install.py",
                         "install_midi_strip_pc.py")
        kept = [l for l in lines
                if MARK not in l and not any(m in l for m in stale_markers)]
        rest = "\n".join(kept).strip()
        if rest:
            sp.write_text(rest + "\n", encoding="utf-8")
            print(f"  unwired    {sp} (other startup code kept)")
        else:
            sp.unlink()
            print(f"  removed    {sp} (it contained nothing else)")
    print("\nUninstalled. Takes effect on REAPER's next launch.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--status", action="store_true")
    a = ap.parse_args()

    if a.status:
        status()
        sys.exit(0)
    if not SRC.exists():
        sys.exit(f"source scripts not found: {SRC}")
    if reaper_running():
        print("NOTE: REAPER is running. The script files install fine, but the startup hook\n"
              "      only takes effect the next time you launch REAPER.\n")
    uninstall() if a.uninstall else install()
