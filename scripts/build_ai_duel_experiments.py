"""Build immutable R/RT/F/S/E/SE/G executables with checked reference and build settings."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
import subprocess


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def settings(arm, weight):
    if arm not in ("R", "F", "S", "E", "SE", "G") or weight not in (0, 8, 16, 24):
        raise ValueError("Unknown arm or development weight")
    result = {"fullWidthDuels": arm in ("S", "SE"),
            "roadResilienceWeight": weight if arm in ("E", "SE") else 0}
    if arm == "G":
        result["tacticalSafety"] = True
    return result


def verify_reference():
    manifest = Path("tools/ai_duel_reference/dependencies.sha256")
    for line in manifest.read_text().splitlines():
        expected, name = line.split("  ", 1)
        if digest(name) != expected:
            raise ValueError(f"Frozen duel reference dependency changed: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dart", default="dart")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--budgets", default="", help="Optional v3-duel milliseconds, four comma-separated tiers")
    parser.add_argument("--weight", type=int, choices=(0, 8, 16, 24), default=16)
    args = parser.parse_args()
    budgets = [int(n) for n in args.budgets.split(",")] if args.budgets else None
    if budgets is not None and (len(budgets) != 4 or min(budgets) < 0):
        parser.error("Four nonnegative budgets required")
    verify_reference()
    directory = Path(args.output_dir).resolve()
    # Never replace a frozen executable/evidence set, including a partial build.
    directory.mkdir(parents=True, exist_ok=False)
    source_files = [str(p) for p in sorted(Path("lib/game").glob("*.dart"))]
    source_files += ["lib/models/piece.dart", "lib/models/player.dart",
                     "lib/services/ai/search_budget.dart", "tools/ai_worker.dart",
                     "tools/ai_worker_protocol.dart", __file__]
    source_files = [str(Path(p).relative_to(Path.cwd())) if Path(p).is_absolute()
                    else p for p in source_files]
    source_files += [str(p) for p in sorted(Path("tools").glob("ai_*.dart"))]
    source_files += [str(p) for p in sorted(Path("scripts").glob("ai_*.py"))]
    candidate_sources = {p: digest(p) for p in source_files}
    frozen_sources = {name: expected for expected, name in
                      (line.split("  ", 1) for line in
                       Path("tools/ai_duel_reference/dependencies.sha256").read_text().splitlines())}
    # Retain reviewable source bytes alongside hashes, not just ephemeral binaries.
    snapshot_files = set(candidate_sources) | set(frozen_sources) | {"tools/ai_timed_reference.dart"}
    for name in sorted(snapshot_files):
        target = directory / "source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(name, target)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    runtime = subprocess.check_output([args.dart, "--version"], text=True).strip()
    reports = {}
    for arm in (("R", "RT", "F", "S", "E", "SE", "G") if budgets is not None else
                ("R", "F", "S", "E", "SE", "G")):
        selected = settings("R" if arm == "RT" else arm, args.weight)
        if arm != "R" and budgets is not None:
            selected["duelBudgetsMs"] = budgets
        binary = directory / arm
        source = ("tools/ai_duel_reference/worker.dart" if arm == "R" else
                  "tools/ai_timed_reference.dart" if arm == "RT" else "tools/ai_worker.dart")
        flags = [] if arm == "R" else [
            f"-DSTONES_FULL_WIDTH={str(selected['fullWidthDuels']).lower()}",
            f"-DSTONES_RESILIENCE_WEIGHT={selected['roadResilienceWeight']}",
            f"-DSTONES_TACTICAL_SAFETY={str(arm == 'G').lower()}"]
        if arm != "R" and budgets is not None:
            flags.append("-DSTONES_DUEL_BUDGETS=" + ":".join(map(str, budgets)))
        subprocess.run([args.dart, "compile", "exe", *flags, source, "-o", str(binary)], check=True)
        # Verify the compiled worker reports the settings it will actually use.
        # dart compile exe treats commas inside -D values as separators.
        if arm not in ("R", "RT"):
            replay = json.loads(Path("docs/qa/ai-balance-hex-counterexample.jsonl").read_text())
            request = dict(id="build-settings", config=replay["config"], moves=[], level="easy")
            response = json.loads(subprocess.check_output([str(binary)],
                input=json.dumps(request) + "\n", text=True, timeout=30))
            if response.get("experiment") != selected:
                raise ValueError(f"Compiled settings differ for {arm}: {response}")
        sources = ({**frozen_sources, source: digest(source)} if arm in ("R", "RT")
                   else candidate_sources)
        report = {
            "arm": arm, "buildSettings": selected, "compilerFlags": flags,
            "sourceSnapshot": str(directory / "source"),
            "binarySha256": digest(binary), "runtime": runtime,
            "checkoutRevision": revision,
            "sourceRevision": "ec5d3dcef52d5e7c5d6f995819b7cd179b49b8fc" if arm == "R" else None,
            "sourceSha256": sources["tools/ai_duel_reference/engine.dart"] if arm in ("R", "RT")
            else sources["lib/game/match_ai_engine.dart"],
            "workerSha256": sources[source], "sourceFiles": sources,
        }
        Path(str(binary) + ".manifest.json").write_text(json.dumps(report, indent=2) + "\n")
        reports[arm] = report
    for name in snapshot_files:
        if digest(name) != digest(directory / "source" / name):
            raise ValueError(f"Source changed during build: {name}")
    (directory / "manifest.json").write_text(json.dumps(reports, indent=2) + "\n")
    print(directory)


if __name__ == "__main__":
    main()
