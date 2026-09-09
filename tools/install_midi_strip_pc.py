#!/usr/bin/env python
r"""install.py -- install the always-on MIDI program-change stripper into REAPER.

Copies two ReaScripts into REAPER's Scripts folder and wires the startup hook so the
stripper runs from every REAPER launch with no clicks:

    <resource>\Scripts\midi_strip_pc.lua          the worker (defer loop)
    <resource>\Scripts\midi_strip_pc_toggle.lua   on/off switch, bindable as an action
    <resource>\Scripts\__startup.lua              REAPER runs this natively at launch

Safe to re-run. If __startup.lua already exists it is backed up and the loader line is
APPENDED, never replacing what is already there.

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
WORKER = "midi_strip_pc.lua"
TOGGLE = "midi_strip_pc_toggle.lua"
STARTUP = "__startup.lua"
LOADER = 'dofile(reaper.GetResourcePath() .. "/Scripts/midi_strip_pc.lua")'
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

    sp = SCRIPTS / STARTUP
    if not sp.exists():
        shutil.copy2(SRC / STARTUP, sp)
        print(f"  created    {sp}")
    else:
        txt = sp.read_text(encoding="utf-8", errors="replace")
        if MARK in txt:
            print(f"  already wired  {sp}")
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
