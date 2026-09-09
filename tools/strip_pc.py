#!/usr/bin/env python
r"""strip_pc.py -- remove MIDI program-change and bank-select messages from .mid files.

Why: a Program Change (status 0xCn) tells the synth "load patch N". REAPER feeds a track's
whole MIDI stream into the FX chain, so an imported .mid carrying one will overwrite the Spire /
sforzando preset you picked by hand -- and REAPER's "chase" re-sends it on every playback start.
Guitar Pro 8 stamps one on every exported track (two per tab track, once per allocated channel),
and downloaded GM/console rips are full of them. PatternForge output is clean.

Bank Select (CC 0 / CC 32) is stripped too: it is a separate event that pairs with the program
change, and leaving it behind makes the Bank/Program lane still draw a marker after you delete
the program change -- which reads as "the delete didn't work".

Safe by default: DRY RUN unless you pass --apply. With --apply every file is copied to a
timestamped backup dir first (override with --backup-dir, disable with --no-backup).

    python strip_pc.py "G:\path\file.mid"                     # dry run, one file
    python strip_pc.py "G:\dir" --recursive                   # dry run, whole tree
    python strip_pc.py "G:\dir" --recursive --apply           # do it, with backups
    python strip_pc.py "G:\dir" -r --apply --no-backup        # do it in place, no backups

Requires mido (already installed on this machine).
"""
import argparse
import shutil
import sys
import time
from pathlib import Path

try:
    import mido
except ImportError:
    sys.exit("mido not installed:  pip install mido")

DROP_CC = (0, 32)  # Bank Select MSB / LSB


def scan(track):
    """Return (kept_messages, n_removed) with delta times preserved."""
    out, carry, removed = [], 0, 0
    for msg in track:
        drop = msg.type == "program_change" or (
            msg.type == "control_change" and msg.control in DROP_CC
        )
        if drop:
            carry += msg.time
            removed += 1
        else:
            msg.time += carry
            carry = 0
            out.append(msg)
    if carry and out:          # nothing should follow end_of_track, but never lose time
        out[-1].time += carry
    return out, removed


def process(path, apply_changes, backup_dir):
    try:
        mid = mido.MidiFile(path)
    except Exception as exc:
        return ("error", 0, f"{type(exc).__name__}: {exc}")

    total = 0
    for track in mid.tracks:
        kept, n = scan(track)
        total += n
        if apply_changes and n:
            track[:] = kept
    if not total:
        return ("clean", 0, "")
    if not apply_changes:
        return ("would-strip", total, "")
    if backup_dir:
        dest = Path(backup_dir) / Path(path).name
        i = 1
        while dest.exists():
            dest = Path(backup_dir) / f"{Path(path).stem}__{i}{Path(path).suffix}"
            i += 1
        Path(backup_dir).mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
    mid.save(path)
    return ("stripped", total, "")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="files and/or directories")
    ap.add_argument("-r", "--recursive", action="store_true", help="recurse into directories")
    ap.add_argument("--apply", action="store_true", help="actually write (default is a dry run)")
    ap.add_argument("--backup-dir", default=None, help="where backups go (default: ./_strip_pc_backup_<stamp>)")
    ap.add_argument("--no-backup", action="store_true", help="skip backups (with --apply)")
    ap.add_argument("-q", "--quiet", action="store_true", help="only print files that change")
    args = ap.parse_args()

    files = []
    for p in args.paths:
        p = Path(p)
        if p.is_dir():
            files += sorted(p.rglob("*.mid") if args.recursive else p.glob("*.mid"))
            files += sorted(p.rglob("*.MID") if args.recursive else p.glob("*.MID"))
        elif p.is_file():
            files.append(p)
        else:
            print(f"  ?? not found: {p}")
    files = sorted(set(files))
    if not files:
        sys.exit("no .mid files found")

    backup_dir = None
    if args.apply and not args.no_backup:
        backup_dir = args.backup_dir or Path.cwd() / f"_strip_pc_backup_{time.strftime('%Y%m%d_%H%M%S')}"

    tally = {"clean": 0, "would-strip": 0, "stripped": 0, "error": 0}
    events = 0
    for f in files:
        status, n, msg = process(str(f), args.apply, backup_dir)
        tally[status] += 1
        events += n
        if status == "clean" and args.quiet:
            continue
        mark = {"clean": "  ok      ", "would-strip": "  WOULD   ", "stripped": "  STRIPPED", "error": "  ERROR   "}[status]
        print(f"{mark} {n:>4}  {f}{('  ' + msg) if msg else ''}")

    print(f"\n{len(files)} file(s): {tally['clean']} already clean, "
          f"{tally['would-strip'] + tally['stripped']} with program/bank events "
          f"({events} events), {tally['error']} unreadable")
    if not args.apply and tally["would-strip"]:
        print("DRY RUN -- nothing written. Re-run with --apply to strip them.")
    if backup_dir and tally["stripped"]:
        print(f"backups: {backup_dir}")


if __name__ == "__main__":
    main()
