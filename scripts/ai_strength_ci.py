"""Generate the full AI matrix and aggregate complete, non-overlapping shards."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def matrix(shape="all", size=0, players=0, tier=-1):
    return [
        {"shape": s, "size": n, "players": p, "tier": t}
        for s, sizes in [("square", range(3, 9)), ("hex", range(2, 5))]
        if shape in ("all", s)
        for n in sizes if size in (0, n)
        for p in range(2, 5) if players in (0, p)
        for t in range(3) if tier in (-1, t)
    ]


def summarize(rows, seeds, players, full):
    expected = seeds * players
    identities = {(r["seed"], r["rotation"]) for r in rows}
    required = {(seed, rotation) for seed in range(100000, 100000 + seeds)
                for rotation in range(players)}
    finished = sum(r["finished"] is True for r in rows)
    wins = sum(r["targetWon"] is True for r in rows)
    decisive = sum(r["winner"] is not None for r in rows)
    losses = decisive - wins
    share = wins / (wins + losses / (players - 1)) if decisive else 0
    complete = len(rows) == expected and identities == required
    return {
        "games": len(rows), "expectedGames": expected, "complete": complete,
        "finished": finished, "wins": wins, "losses": losses,
        "draws": finished - decisive, "unfinished": len(rows) - finished,
        "normalizedShare": share,
        "passed": (complete and (not full or seeds >= 50)
                   and finished >= expected * .8
                   and decisive >= expected * .5 and share > (.6 if full else .5)),
    }


def aggregate(root, selected, seeds=50, full=True):
    expected = {tuple(p[k] for k in ("shape", "size", "players", "tier"))
                for p in selected}
    groups = {key: [] for key in expected}
    provenance = set()
    for path in Path(root).rglob("*.jsonl"):
        manifest = json.loads(Path(str(path) + ".manifest.json").read_text())
        key = tuple(manifest[k] for k in ("shape", "size", "players", "tier"))
        if key not in expected:
            raise ValueError(f"Unexpected profile: {key}")
        if manifest["comparison"] != "adjacent" or not manifest["seededOpening"]:
            raise ValueError("Only seeded adjacent-tier trials can qualify")
        provenance.add(tuple(manifest[k] for k in
                             ("engine", "runtime", "os", "sourceSha256",
                              "workerSha256", "runnerSha256", "policy")) +
                       (json.dumps(manifest["candidateSource"]["sourceFiles"], sort_keys=True),
                        json.dumps(manifest["candidateSource"].get("buildSettings", {}), sort_keys=True),
                        manifest.get("starter", "ivory")))
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        shard_ids = {(seed, rotation)
                     for seed in range(manifest["seedStart"],
                                       manifest["seedStart"] + manifest["seeds"])
                     for rotation in range(key[2])}
        if len(rows) != len(shard_ids) or {(r["seed"], r["rotation"]) for r in rows} != shard_ids:
            raise ValueError(f"Incomplete or duplicate shard: {path}")
        for row in rows:
            cfg = row["config"]
            if (cfg["shape"], cfg["size"], len(cfg["seats"])) != key[:3]:
                raise ValueError("Replay profile differs from manifest")
            target = cfg["seats"][row["rotation"]]["id"]
            levels = ["easy", "medium", "hard", "expert"]
            if any(s["level"] != levels[key[3] + (s["id"] == target)]
                   for s in cfg["seats"]):
                raise ValueError("Replay difficulty differs from manifest")
            if row["target"] != target or row["targetWon"] != (row["winner"] == target):
                raise ValueError("Incorrect target outcome")
            if not row["finished"] and row["winner"] is not None:
                raise ValueError("Unfinished game cannot have a winner")
        groups[key].extend(rows)
    if len(provenance) != 1:
        raise ValueError("Missing or mixed source/runtime/policy provenance")
    reports = []
    for key, rows in sorted(groups.items()):
        openings = {}
        for row in rows:
            opening = row["moves"][:key[2]]
            if len(opening) != key[2]:
                raise ValueError("Missing seeded opening")
            if openings.setdefault(row["seed"], opening) != opening:
                raise ValueError("Seat rotations must share identical openings")
        reports.append({"profile": list(key), **summarize(rows, seeds, key[2], full)})
    return {"scope": "full-matrix" if len(expected) == 81 else "partial-matrix",
            "groups": reports, "passed": all(r["passed"] for r in reports)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["matrix", "aggregate", "provenance"])
    parser.add_argument("--shape", choices=["all", "square", "hex"], default="all")
    parser.add_argument("--size", type=int, default=0)
    parser.add_argument("--players", type=int, choices=[0, 2, 3, 4], default=0)
    parser.add_argument("--tier", type=int, choices=[-1, 0, 1, 2], default=-1)
    parser.add_argument("--root", default="build/ai-full")
    parser.add_argument("--output")
    parser.add_argument("--binary")
    parser.add_argument("--source-ref")
    args = parser.parse_args()
    if args.command == "provenance":
        if not args.binary:
            parser.error("--binary is required")
        def digest(path):
            content = (subprocess.check_output(["git", "show", f"{args.source_ref}:{path}"])
                       if args.source_ref else Path(path).read_bytes())
            return hashlib.sha256(content).hexdigest()
        paths = [
                      "lib/game/match_ai_engine.dart", "lib/game/ai_material.dart",
                      "lib/game/ai_tactics.dart", "lib/game/ai_search_cache.dart",
                      "lib/game/ai_position.dart", "lib/game/match_config.dart",
                      "lib/game/match_state.dart", "lib/game/match_rules.dart",
                      "lib/game/board_geometry.dart", "lib/models/piece.dart",
                      "lib/models/player.dart",
                      "lib/services/ai/search_budget.dart", "tools/ai_worker.dart",
                      "tools/ai_worker_protocol.dart"]
        for path in ("lib/game/ai_duel_search.dart", "lib/game/ai_duel_tactics.dart",
                     "lib/game/ai_road_connections.dart", "lib/game/ai_duel_position.dart", "lib/game/ai_duel_safety.dart", "lib/game/ai_road_resilience.dart"):
            exists = (subprocess.run(["git", "cat-file", "-e", f"{args.source_ref}:{path}"],
                                     stderr=subprocess.DEVNULL).returncode == 0
                      if args.source_ref else Path(path).exists())
            if exists:
                paths.append(path)
        report = {"sourceSha256": digest("lib/game/match_ai_engine.dart"),
                  "workerSha256": digest("tools/ai_worker.dart"),
                  "sourceFiles": {p: digest(p) for p in paths}}
        Path(args.binary + ".manifest.json").write_text(json.dumps(report) + "\n")
        return
    selected = matrix(args.shape, args.size, args.players, args.tier)
    if not selected:
        parser.error("No supported profiles match the filters")
    report = ({"include": selected} if args.command == "matrix"
              else aggregate(args.root, selected))
    encoded = json.dumps(report)
    if args.output:
        Path(args.output).write_text(encoded + "\n")
    print(encoded)
    if args.command == "aggregate" and not report["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
