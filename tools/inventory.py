"""
inventory.py - find every ReaScript, JSFX and FX chain on this box and group
them by CONTENT, not by name or timestamp.

Why hash-based: the same filename appears in up to nine places (source, live
REAPER install, sandbox configs, half a dozen G:\\tmp build dirs). Names and
mtimes do not tell you which copies agree - only the bytes do. This is the same
trap that made ten downloads of windows-mcp-server.exe look like ten builds when
they were five.

Usage:
    python inventory.py            # human summary
    python inventory.py --json     # machine-readable, for diffing later
"""
import hashlib
import json
import os
import sys
from collections import defaultdict

APPDATA = os.environ.get("APPDATA", r"C:\Users\STRYK\AppData\Roaming")
REAPER = os.path.join(APPDATA, "REAPER")

# Where things legitimately live, and where they have leaked to.
ROOTS = [
    # Since the 2026-09-10 consolidation this repo is the ONLY source tree.
    # jsfx-pack, midi-strip-pc and the beneath-redemption reaper folder were
    # merged in; nothing under audio-midi-music is authoritative any more.
    ("source",  r"G:\pipelines\reaper-scripting"),
    ("live",    os.path.join(REAPER, "Scripts")),
    ("live",    os.path.join(REAPER, "Effects")),
    ("live",    os.path.join(REAPER, "FXChains")),
    ("scratch", r"G:\tmp"),
]

# Stock Cockos content ships with REAPER; it is not ours to manage.
SKIP_DIRS = {".git", "__pycache__", "Cockos", ".claude"}

# REAPER also supports Python ReaScripts, but none are in use here and .py
# would match this repo's own tooling (which mentions `reaper.` in strings and
# would be miscounted as a ReaScript). Add ".py" back if that ever changes.
SCRIPT_EXT = {".lua", ".eel"}
CHAIN_EXT = {".rfxchain"}

# STRYK's naming convention IS the ownership marker: every custom JSFX and FX
# chain is prefixed. Without this filter the scan returns ~1100 JSFX, because
# REAPER's entire stock Effects tree is duplicated into every sandbox config
# under G:\tmp. Stock content is vendor code and not ours to reorganise.
OURS_PREFIXES = ("stryk", "144 ", "432 ")

# Pre-2026-09-10 names, from before the stryk_ prefix was applied to scripts.
# Kept so stale copies under G:\tmp, and a REAPER that has not been reinstalled
# yet, are still recognised as ours rather than counted as vendor files.
# __startup.lua keeps its bare name permanently: REAPER only auto-runs a file
# called exactly that.
OURS_NAMES = {
    "build_rs5k_from_slices.lua",
    "build_rs5k_from_slices.original-broken.lua",
    "check_reascript.lua",
    "render_variations_by_selected_track.lua",
    "midi_strip_pc.lua",
    "midi_strip_pc_toggle.lua",
    "build_session.lua",
    "__startup.lua",
}

# Anything under these trees is ours by construction.
OURS_ROOTS = (
    r"G:\pipelines\reaper-scripting",
)


def is_ours(path, name):
    low = name.lower()
    if low.startswith(OURS_PREFIXES):
        return True
    if low in OURS_NAMES:
        return True
    up = path.upper()
    return any(up.startswith(r.upper()) for r in OURS_ROOTS)


def classify(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in CHAIN_EXT:
        return "fxchain"
    if ext in SCRIPT_EXT:
        # A .lua is only a ReaScript if it calls the reaper API.
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                head = fh.read(8000)
        except OSError:
            return None
        return "reascript" if "reaper." in head else None
    if ext == "":
        # JSFX have no extension. They are identified by their descriptor lines.
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                head = fh.read(4000)
        except OSError:
            return None
        if "@sample" in head or "@block" in head or head.lstrip().startswith("desc:"):
            return "jsfx"
    return None


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def scan():
    seen = {}
    for kind, root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for fn in filenames:
                p = os.path.join(dirpath, fn)
                what = classify(p)
                if not what:
                    continue
                try:
                    digest = sha(p)
                    size = os.path.getsize(p)
                except OSError:
                    continue
                # A path can match two roots (G:\tmp nests); keep the first.
                if p in seen:
                    continue
                nm = os.path.basename(p)
                seen[p] = {"path": p, "role": kind, "type": what,
                           "sha": digest, "size": size, "name": nm,
                           "ours": is_ours(p, nm)}
    return list(seen.values())


def emit_markdown(files, report, n_stock):
    import datetime
    by_type = defaultdict(list)
    for f in files:
        by_type[f["type"]].append(f)

    print("# REAPER asset inventory")
    print()
    print("Generated by `tools/inventory.py --markdown` on %s. Regenerate rather"
          % datetime.date.today().isoformat())
    print("than hand-editing.")
    print()
    print("Ownership is decided by the `stryk_` / `144 ` / `432 ` naming convention plus")
    print("a handful of older names. Without that filter the scan returns ~1,100 JSFX,")
    print("because REAPER's entire stock Effects tree is copied into every sandbox")
    print("config under `G:\\tmp`. %d stock/vendor files were ignored." % n_stock)
    print()
    print("| type | files | distinct names |")
    print("|---|---|---|")
    for t in sorted(by_type):
        names = len({f["name"].lower() for f in by_type[t]})
        print("| %s | %d | %d |" % (t, len(by_type[t]), names))
    print()

    print("## Canonical location per asset")
    print()
    print("`source` = the tree it is authored in. `live` = the running REAPER install.")
    print("`scratch` = a throwaway copy under `G:\\tmp`; never edit these.")
    print()
    print("| name | type | source of truth | copies | versions |")
    print("|---|---|---|---|---|")
    for name in sorted(report["names"]):
        r = report["names"][name]
        src = ""
        for v in r["versions"]:
            for p in v["paths"]:
                if p.upper().startswith(r"G:\PIPELINES"):
                    src = p
                    break
            if src:
                break
        flag = "" if r["distinct_versions"] == 1 else " **diverged**"
        print("| `%s` | %s | `%s` | %d | %d%s |"
              % (name, r["type"], src or "(no pipelines copy)",
                 r["copies"], r["distinct_versions"], flag))


def main():
    all_files = scan()
    stock = [f for f in all_files if not f["ours"]]
    files = [f for f in all_files if f["ours"]]
    # stderr, so --markdown/--json output stays clean when redirected to a file
    sys.stderr.write("scanned %d REAPER files; %d ours, %d stock/vendor (ignored)\n\n"
                     % (len(all_files), len(files), len(stock)))

    # Group by logical name, then by content within that name.
    by_name = defaultdict(list)
    for f in files:
        by_name[f["name"].lower()].append(f)

    report = {"total": len(files), "names": {}}
    for name in sorted(by_name):
        entries = by_name[name]
        by_hash = defaultdict(list)
        for e in entries:
            by_hash[e["sha"]].append(e)
        report["names"][name] = {
            "type": entries[0]["type"],
            "copies": len(entries),
            "distinct_versions": len(by_hash),
            "versions": [
                {"sha": h[:12], "size": v[0]["size"],
                 "paths": sorted(x["path"] for x in v),
                 "roles": sorted({x["role"] for x in v})}
                for h, v in sorted(by_hash.items(),
                                   key=lambda kv: -len(kv[1]))
            ],
        }

    if "--json" in sys.argv:
        print(json.dumps(report, indent=2))
        return

    if "--markdown" in sys.argv:
        emit_markdown(files, report, len(stock))
        return

    counts = defaultdict(int)
    for f in files:
        counts[f["type"]] += 1
    print("=== totals ===")
    for k in sorted(counts):
        print("  %-10s %d files" % (k, counts[k]))
    print("  %-10s %d distinct names" % ("unique", len(by_name)))
    print()

    diverged = {n: r for n, r in report["names"].items()
                if r["distinct_versions"] > 1}
    print("=== DIVERGED (same name, different bytes) - %d ===" % len(diverged))
    for name in sorted(diverged):
        r = diverged[name]
        print("\n  %s  [%s]  %d copies / %d versions"
              % (name, r["type"], r["copies"], r["distinct_versions"]))
        for v in r["versions"]:
            print("    %s  %6d B  (%s)" % (v["sha"], v["size"], ",".join(v["roles"])))
            for p in v["paths"]:
                print("        %s" % p)

    dupes = {n: r for n, r in report["names"].items()
             if r["distinct_versions"] == 1 and r["copies"] > 1}
    print("\n=== IDENTICAL DUPLICATES - %d names ===" % len(dupes))
    for name in sorted(dupes):
        r = dupes[name]
        print("  %-42s %s x%d  (%s)"
              % (name, r["type"], r["copies"], ",".join(r["versions"][0]["roles"])))

    # Grouping by name alone hides identical content filed under different
    # names - stryk_retune432_fixed turned out to be byte-identical to
    # stryk_retune432 and looked like an unmerged fix until this was checked.
    by_sha = defaultdict(set)
    for f in files:
        by_sha[f["sha"]].add(f["name"])
    aliases = {h: n for h, n in by_sha.items() if len(n) > 1}
    print("\n=== SAME BYTES, DIFFERENT NAME - %d ===" % len(aliases))
    for h, names in sorted(aliases.items(), key=lambda kv: sorted(kv[1])):
        print("  %s  %s" % (h[:12], "  ==  ".join(sorted(names))))
        for f in sorted((x for x in files if x["sha"] == h),
                        key=lambda x: x["path"]):
            print("      %s" % f["path"])

    singles = {n: r for n, r in report["names"].items() if r["copies"] == 1}
    print("\n=== SINGLE COPY - %d ===" % len(singles))
    for name in sorted(singles):
        r = singles[name]
        print("  %-42s %s  %s" % (name, r["type"], r["versions"][0]["paths"][0]))


if __name__ == "__main__":
    main()
