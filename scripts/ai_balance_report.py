"""Separate tier sweeps from fixed opening/seat sweeps in native duel replays."""
import argparse
import json
import random
from collections import defaultdict
from pathlib import Path


def cluster_interval(clusters, numerator, denominator, resamples=2000):
    """Bootstrap openings, retaining paired seats/repeats within each cluster."""
    values = [(sum(numerator(row) for row in rows),
               sum(denominator(row) for row in rows)) for rows in clusters]
    if len(values) < 2:
        return None
    randomizer = random.Random(7331)
    estimates = []
    for _ in range(resamples):
        sample = randomizer.choices(values, k=len(values))
        total = sum(value[1] for value in sample)
        if total:
            estimates.append(sum(value[0] for value in sample) / total)
    if not estimates:
        return None
    estimates.sort()
    return [estimates[int((len(estimates) - 1) * p)] for p in (.025, .975)]


def balance_report(rows):
    if any(len(r["config"]["seats"]) != 2 for r in rows):
        raise ValueError("This report analyzes duels only")
    decisive = [r for r in rows if r["finished"] and r["winner"] is not None]
    starter_wins = sum(r["winner"] == r["config"]["starter"] for r in decisive)
    seeds = defaultdict(list)
    for row in rows:
        seeds[row["seed"]].append(row)
    def is_decisive(row):
        return bool(row["finished"] and row["winner"] is not None)
    counts = defaultdict(int)
    pairs = []
    for seed, games in sorted(seeds.items()):
        ordered = sorted(games, key=lambda r: r["rotation"])
        complete = len(ordered) == 2 and {r["rotation"] for r in ordered} == {0, 1}
        same_opening = (complete and
                        ordered[0]["moves"][:2] == ordered[1]["moves"][:2])
        if not complete or any(not r["finished"] or r["winner"] is None for r in ordered):
            outcome = "inconclusive"
        elif ordered[0]["winner"] == ordered[1]["winner"]:
            outcome = ("starter-sweep" if all(r["winner"] == r["config"]["starter"] for r in ordered)
                       else "second-seat-sweep")
        elif all(r["targetWon"] for r in ordered):
            outcome = "target-sweep"
        elif all(not r["targetWon"] for r in ordered):
            outcome = "opponent-sweep"
        else:
            outcome = "inconclusive"
        counts[outcome] += 1
        pairs.append({"seed": seed, "sameOpening": same_opening,
                      "winners": [r["winner"] for r in ordered], "outcome": outcome})
    return {
        "scope": "Exploratory agent/opening evidence, not perfect-play game balance",
        "games": len(rows), "openingSeeds": len(seeds),
        "decisive": len(decisive), "starterWins": starter_wins,
        "secondSeatWins": len(decisive) - starter_wins,
        "starterShare": starter_wins / len(decisive) if decisive else None,
        "starterShare95CI": cluster_interval(seeds.values(),
            lambda row: is_decisive(row) and row["winner"] == row["config"]["starter"],
            is_decisive),
        "targetShare95CI": cluster_interval(seeds.values(),
            lambda row: is_decisive(row) and row["targetWon"], is_decisive),
        "confidenceMethod": "Opening-cluster percentile bootstrap; 2000 resamples; descriptive, not perfect-play evidence",
        "pairedOutcomes": dict(counts), "bySeed": pairs,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("games", nargs="+")
    parser.add_argument("--output")
    args = parser.parse_args()
    reports = []
    for name in args.games:
        path = Path(name)
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        manifest_path = Path(str(path) + ".manifest.json")
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
        reports.append({"file": name, "manifest": manifest, **balance_report(rows)})
    encoded = json.dumps(reports, indent=2)
    if args.output:
        Path(args.output).write_text(encoded + "\n")
    print(encoded)


if __name__ == "__main__":
    main()
