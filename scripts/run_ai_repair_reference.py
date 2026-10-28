"""Resumable paired reference trials on preselected distinct openings.

Each native trial gets one CPU, shared by its two engines. At most two trials
run together. Builds, Flutter tests and latency profiling must finish first.
"""
import argparse
from collections import defaultdict
import hashlib
import fcntl
import json
import math
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.ai_benefit_audit import sign_evidence
from scripts.ai_balance_report import balance_report, cluster_interval


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def opening_key(row):
    return json.dumps([[m["x"], m["y"], m["type"]] for m in row["moves"][:2]])


def valid_shard(path, task, study):
    summary = Path(str(path) + ".summary.json")
    if not path.exists() or not summary.exists():
        return None
    report = json.loads(summary.read_text())
    if report.get("complete") is not True:
        return None
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    meta = json.loads(Path(str(path) + ".manifest.json").read_text())
    if (len(rows) != 2 or {r["rotation"] for r in rows} != {0, 1}
            or any(r["seed"] != task["seed"] for r in rows)
            or meta["candidateSha256"] != study["candidateSha256"]
            or meta["opponentSha256"] != study["baselineSha256"]
            or meta["runnerSha256"] != study["runnerSha256"]
            or meta["checkpointSha256"] != study["checkpointSha256"]
            or meta["comparison"] != "same-tier-reference" or meta["policy"] != "deterministic"
            or meta["seedStart"] != task["seed"] or meta["seeds"] != 1
            or meta["tier"] != task["tier"] or not meta["seededOpening"]):
        raise ValueError(f"Wrong or mixed trial provenance: {path}")
    for row in rows:
        cfg = row["config"]
        if ((cfg["shape"], cfg["size"]) != (task["shape"], task["size"])
                or len(cfg["seats"]) != 2
                or cfg["aiEngine"] != "shared-search-v3"
                or row["target"] != cfg["seats"][row["rotation"]]["id"]
                or any(s["level"] != task["level"] or s["control"] != "ai" for s in cfg["seats"])
                or cfg["starter"] != "ivory"
                or opening_key(row) != task["openingKey"]
                or row["targetWon"] != (row["winner"] == row["target"])
                or not isinstance(row["finished"], bool)
                or (row["winner"] is not None and row["winner"] not in {s["id"] for s in cfg["seats"]})
                or (not row["finished"] and row["winner"] is not None)):
            raise ValueError(f"Trial differs from registered opening or profile: {path}")
    return rows


def aggregate(completed, tasks, study, root):
    groups = defaultdict(list)
    deltas = defaultdict(float)
    receipts = []
    for task in tasks:
        path, rows = completed[task["key"]]
        groups[task["profile"]].extend(rows)
        # The same seed stream supplies both boards and both levels. Keep all
        # those paired outcomes together rather than count them as independent.
        deltas[task["seed"]] += sum(0 if r["winner"] is None else
                                  1 if r["targetWon"] else -1 for r in rows)
        receipts.append({"data": str(path), "sha256": digest(path),
                         "manifestSha256": digest(str(path) + ".manifest.json")})
    reports = []
    for profile, rows in sorted(groups.items()):
        clusters = defaultdict(list)
        for row in rows:
            clusters[opening_key(row)].append(row)
        expected = 2 * study["distinctPerBoard"]
        finished = sum(r["finished"] for r in rows)
        decisive = sum(r["finished"] and r["winner"] is not None for r in rows)
        wins = sum(r["targetWon"] for r in rows)
        losses = decisive - wins
        share = wins / decisive if decisive else 0
        passed = (len(rows) == expected and len(clusters) >= 50
                  and finished >= math.ceil(expected * .8)
                  and decisive >= math.ceil(expected * .5) and share >= .5)
        reports.append({"profile": profile, "games": len(rows),
            "distinctOpenings": len(clusters), "finished": finished,
            "wins": wins, "losses": losses, "draws": finished - decisive,
            "unfinished": len(rows) - finished, "normalizedShare": share,
            "share95OpeningClusterInterval": cluster_interval(clusters.values(),
                lambda r: r["targetWon"],
                lambda r: r["finished"] and r["winner"] is not None),
            "passedNecessaryReferenceGates": passed, "initiative": balance_report(rows)})
    evidence = sign_evidence(deltas.values())
    improved = (evidence["oneSidedImprovementP"] is not None
                and evidence["oneSidedImprovementP"] <= .05
                and evidence["positive"] > evidence["negative"])
    passed = len(reports) == 4 and all(r["passedNecessaryReferenceGates"] for r in reports) and improved
    report = {"scope": "Selected Square-5/Hex-2 Hard/Expert paired-reference strength, not all-size/player qualification or human strength",
        "selectedReferenceStrengthGatesPassed": passed,
        "fullMatrixQualified": False, "groups": reports,
        "aggregateOpeningStreamSignEvidence": evidence,
        "study": study, "trials": receipts, "analysisSourceSha256": digest(__file__),
        "note": "Initial openings were selected before outcomes. Every opening has both seat assignments. Global inference clusters repeated seed streams across formats and tiers. Actual move-replacement proofs and runtime/platform qualification remain separate checks."}
    write_json(root / "report.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--openings", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--candidate", default="build/qa/ai-fix/bin12/G")
    parser.add_argument("--baseline", default="build/qa/ai-fix/bin12/R")
    parser.add_argument("--runner", default="build/qa/ai-fix/ai_strength-resumable")
    parser.add_argument("--ci-report", default="build/qa/ai-fix/ci12/report.json")
    args = parser.parse_args()
    if json.loads(Path(args.ci_report).read_text()).get("passed") is not True:
        raise ValueError("The unchanged required CI regression groups must pass first")
    openings = json.loads(Path(args.openings).read_text())
    if openings["distinctPerBoard"] < 50:
        raise ValueError("At least 50 distinct openings per board required")
    for binary in [args.candidate, args.baseline]:
        meta = json.loads(Path(binary + ".manifest.json").read_text())
        if digest(binary) != meta["binarySha256"]:
            raise ValueError("Binary checksum differs from sidecar")
    cpus = sorted(os.sched_getaffinity(0))[:2]
    if len(cpus) < 2:
        raise ValueError("Two available CPU affinities required for this run")
    tasks = []
    by_shape = {p["shape"]: p for p in openings["profiles"]}
    for index in range(openings["distinctPerBoard"]):
        for shape, level, tier in [("hex", "hard", 1), ("square", "hard", 1),
                                   ("hex", "expert", 2), ("square", "expert", 2)]:
            profile = by_shape[shape]
            selected = profile["selected"][index]
            name = f"{shape}-{profile['size']}-{level}"
            tasks.append({"shape": shape, "size": profile["size"], "level": level,
                "tier": tier, "seed": selected["seed"], "profile": name,
                "openingKey": opening_key(selected), "key": f"{name}/{selected['seed']}"})
    if any(len({t["openingKey"] for t in tasks if t["profile"] == name}) != openings["distinctPerBoard"]
           for name in {t["profile"] for t in tasks}):
        raise ValueError("Registered opening list contains duplicates")
    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    study_lock = (root / "study.lock").open("a")
    fcntl.flock(study_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    study = {"candidateSha256": digest(args.candidate), "baselineSha256": digest(args.baseline),
        "runnerBinarySha256": digest(args.runner), "runnerSha256": digest("tools/ai_strength.dart"),
        "checkpointSha256": digest("tools/ai_strength_checkpoint.dart"),
        "openingSelectionSha256": digest(args.openings), "ciReportSha256": digest(args.ci_report),
        "coordinatorSha256": digest(__file__),
        "runnerDependencySha256": digest("tools/ai_qualification.dart"),
        "cpuAffinities": cpus,
        "cpuQuota": Path("/sys/fs/cgroup/cpu.max").read_text().strip(),
        "distinctPerBoard": openings["distinctPerBoard"], "expectedTrials": len(tasks),
        "resourcePolicy": "At most two native trials; each trial and both engines pinned to one distinct CPU; no builds/tests/latency benchmarks concurrently",
        "gates": {"minDistinctOpenings": 50, "minFinished": .8,
                  "minDecisive": .5, "perProfileShareAtLeast": .5,
                  "aggregateOneSidedOpeningStreamSignPAtMost": .05}}
    manifest_path = root / "study.json"
    if manifest_path.exists() and json.loads(manifest_path.read_text()) != study:
        raise ValueError("Cannot resume with different binaries, openings, runner or gates")
    write_json(manifest_path, study)
    jobs = queue.Queue()
    completed, errors = {}, []
    lock = threading.Lock()
    active = {}
    processes = {}
    stopping = threading.Event()

    def stop(signum, frame):
        stopping.set()
        for process in list(processes.values()):
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    def progress():
        write_json(root / "progress.json", {"completedTrials": len(completed),
            "expectedTrials": len(tasks), "completedGames": len(completed) * 2,
            "active": dict(active), "errors": list(errors), "updatedUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})

    for task in tasks:
        directory = root / task["profile"]
        directory.mkdir(exist_ok=True)
        previous = list(directory.glob(f"seed-{task['seed']}.jsonl"))
        for path in previous:
            rows = valid_shard(path, task, study)
            if rows is not None:
                completed[task["key"]] = (path, rows)
                break
        else:
            jobs.put(task)
    progress()

    def work(cpu):
        while not errors and not stopping.is_set():
            try:
                task = jobs.get_nowait()
            except queue.Empty:
                return
            try:
                directory = root / task["profile"]
                path = directory / f"seed-{task['seed']}.jsonl"
                command = ["taskset", "-c", str(cpu), args.runner,
                    f"--candidate={args.candidate}", f"--opponent={args.baseline}",
                    f"--shape={task['shape']}", f"--size={task['size']}", "--players=2",
                    f"--tier={task['tier']}", "--seeds=1", f"--seed-start={task['seed']}",
                    "--explore", "--resume", f"--output={path}"]
                with lock:
                    active[str(cpu)] = {"trial": task["key"], "output": str(path)}
                    progress()
                with Path(str(path) + ".log").open("a") as log:
                    process = subprocess.Popen(command, stdout=log,
                        stderr=subprocess.STDOUT, start_new_session=True)
                    processes[cpu] = process
                    try:
                        if stopping.is_set():
                            os.killpg(process.pid, signal.SIGTERM)
                        result = process.wait(timeout=3600)
                        if result:
                            raise RuntimeError(f"Trial exited {result}: {path}")
                    finally:
                        if process.poll() is None:
                            os.killpg(process.pid, signal.SIGTERM)
                            process.wait(timeout=30)
                        processes.pop(cpu, None)
                rows = valid_shard(path, task, study)
                if rows is None:
                    raise ValueError(f"Incomplete trial after successful runner: {path}")
                with lock:
                    completed[task["key"]] = (path, rows)
                    active.pop(str(cpu), None)
                    progress()
                    print(json.dumps({"completedTrials": len(completed), "expectedTrials": len(tasks), "trial": task["key"]}), flush=True)
            except Exception as error:
                stop(None, None)
                with lock:
                    errors.append(str(error))
                    progress()
                return
            finally:
                jobs.task_done()
    workers = [threading.Thread(target=work, args=(cpu,)) for cpu in cpus]
    for thread in workers:
        thread.start()
    for thread in workers:
        thread.join()
    if errors:
        raise RuntimeError("; ".join(errors))
    if stopping.is_set():
        raise SystemExit(130)
    report = aggregate(completed, tasks, study, root)
    print(json.dumps({"selectedReferenceStrengthGatesPassed": report["selectedReferenceStrengthGatesPassed"]}))
    if not report["selectedReferenceStrengthGatesPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
