"""Audit a necessary latency gate and opening-paired strength evidence.

This report can reject a rollout. A single timing profile and pilot games cannot
certify an upgrade; no amount of successful unit tests substitutes for strength.
"""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import random


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def opening_key(row):
    config = row["config"]
    count = len(config["seats"])
    moves = row["moves"][:count]
    if len(moves) != count:
        raise ValueError("Incomplete opening")
    # Color/starter mirrors and worker assignments are repeated observations of
    # the same underlying opening, not extra independent opening samples.
    return json.dumps([config["shape"], config["size"], config.get("profile"),
                       [{k: v for k, v in move.items() if k != "seat"}
                        for move in moves]], sort_keys=True)


def sign_evidence(deltas):
    values = list(deltas)
    positive = sum(value > 0 for value in values)
    negative = sum(value < 0 for value in values)
    informative = positive + negative

    def tail(successes):
        return (sum(math.comb(informative, n)
                    for n in range(successes, informative + 1)) / 2 ** informative
                if informative else None)

    return {"openingClusters": len(values), "positive": positive,
            "negative": negative, "tied": len(values) - informative,
            "oneSidedImprovementP": tail(positive),
            "oneSidedRegressionP": tail(negative),
            "method": "Exact opening-pair sign test, ties omitted; tests tendency, not perfect-play strength"}


def percentile(values, proportion=.95):
    if not values:
        raise ValueError("Empty timing sample")
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * proportion) - 1)]


def timing_audit(path, resamples=4000):
    path = Path(path)
    manifest = json.loads(Path(str(path) + ".manifest.json").read_text())
    if manifest.get("heldOut") is not True:
        raise ValueError("Held-out timing data required")
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    groups = defaultdict(list)
    identities = set()
    for row in rows:
        if len(row['config']['seats']) != 2:
            raise ValueError('Only duel pairs can be audited here')
        identity = row["profile"], row["level"], row["seed"], row["case"]
        if identity in identities:
            raise ValueError("Duplicate timing decision")
        identities.add(identity)
        responses = row["responses"]
        if set(responses) != {"R", "S", "E", "SE"}:
            raise ValueError("Four matched arms required")
        if len({response["position"] for response in responses.values()}) != 1:
            raise ValueError("Arms received different positions")
        for arm, response in responses.items():
            if response["elapsedMs"] < 0:
                raise ValueError("Invalid timing")
            if arm != "R" and response["experiment"] != manifest["arms"][arm]["buildSettings"]:
                raise ValueError("Experiment settings differ from manifest")
        groups[row["profile"], row["level"]].append(row)
    reports = []
    for (profile, level), data in sorted(groups.items()):
        by_opening = defaultdict(list)
        for row in data:
            by_opening[opening_key(row)].append(row)
        # Deterministic duplicate removal, chosen without inspecting timings.
        # Keep all nonterminal sampled positions of the lowest seed for each
        # distinct opening; never count identical opening replays as extra N.
        clusters = []
        for key in sorted(by_opening):
            cluster = by_opening[key]
            seed = min(row["seed"] for row in cluster)
            clusters.append([row for row in cluster if row["seed"] == seed])
        data = [row for cluster in clusters for row in cluster]
        for candidate, reference in [("S", "R"), ("E", "R"), ("SE", "R"), ("SE", "S")]:
            def p95(sample, arm):
                return percentile([row["responses"][arm]["elapsedMs"] for row in sample])
            candidate_time, reference_time = p95(data, candidate), p95(data, reference)
            raw_candidate = p95(groups[profile, level], candidate)
            raw_reference = p95(groups[profile, level], reference)
            if reference_time <= 0:
                raise ValueError("Positive reference p95 required")
            rng = random.Random(99173)
            ratios = []
            for _ in range(resamples):
                sample = [row for cluster in rng.choices(clusters, k=len(clusters)) for row in cluster]
                denominator = p95(sample, reference)
                if denominator:
                    ratios.append(p95(sample, candidate) / denominator)
            reports.append({"profile": profile, "level": level,
                "comparison": f"{candidate}-{reference}",
                "seedStreams": len({row["seed"] for row in groups[profile, level]}),
                "distinctOpenings": len(clusters), "deduplicatedPositions": len(data),
                "candidateP95Ms": candidate_time, "referenceP95Ms": reference_time,
                "rawCandidateP95Ms": raw_candidate, "rawReferenceP95Ms": raw_reference,
                "p95Ratio": candidate_time / reference_time,
                "openingClusterBootstrap95RatioCI": [percentile(ratios, .025), percentile(ratios, .975)],
                "candidateEmergencyFallbacks": sum(row["responses"][candidate].get("emergencyFallback", False) for row in data),
                "requiredSampleCovered": len(clusters) >= 50,
                "noWorseP95GatePassed": len(clusters) >= 50 and raw_candidate <= raw_reference})
    return {"data": str(path), "dataSha256": digest(path),
            "manifestSha256": digest(str(path) + ".manifest.json"),
            "manifest": manifest, "comparisons": reports,
            "method": "Nearest-rank p95; 4000 percentile-bootstrap resamples of whole distinct-opening clusters; deterministic lowest-seed representatives",
            "scope": "One or more necessary timing groups; does not certify the full matrix"}


def game_audit(path):
    rows = [json.loads(line) for line in Path(path).read_text().splitlines()]
    deltas = defaultdict(int)
    identities = set()
    for row in rows:
        if len(row['config']['seats']) != 2:
            raise ValueError('Only duel pairs can be audited here')
        identity = row["seed"], row["rotation"], row["config"]["starter"]
        if identity in identities:
            raise ValueError("Duplicate game")
        identities.add(identity)
        if not row["finished"]:
            raise ValueError("Unfinished games cannot be treated as draws")
        if row['targetWon'] != (row['winner'] == row['target']):
            raise ValueError('Incorrect candidate outcome')
        deltas[opening_key(row)] += (0 if row["winner"] is None else 1 if row["targetWon"] else -1)
    for row in rows:
        if {r["rotation"] for r in rows if r["seed"] == row["seed"]} != {0, 1}:
            raise ValueError("Both seat assignments required")
    return {"data": str(path), "dataSha256": digest(path), "games": len(rows),
            "candidateWins": sum(r["targetWon"] for r in rows),
            "candidateLosses": sum(r["winner"] is not None and not r["targetWon"] for r in rows),
            "draws": sum(r["winner"] is None for r in rows),
            "openingPairEvidence": sign_evidence(deltas.values()),
            "strengthProven": False,
            "scope": "Pilot sign evidence only; all required profiles, tiers and gates remain necessary"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timing", required=True)
    parser.add_argument("--games", nargs="*", default=[])
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    output = Path(args.output)
    if output.exists():
        parser.error("Output must be new")
    timing = timing_audit(args.timing)
    failed = [r["comparison"] for r in timing["comparisons"]
              if r["comparison"].endswith("-R") and r["requiredSampleCovered"] and not r["noWorseP95GatePassed"]]
    report = {"overallBenefitProven": False,
              "decision": "reject current rollout: necessary latency gate failed" if failed else "insufficient evidence for overall benefit",
              "failedLatencyComparisons": failed, "timing": timing,
              "gamePilots": [game_audit(path) for path in args.games],
              "auditSourceSha256": digest(__file__),
              "note": "Counterexample checks show selected moves leave a defense against the bounded quick win. They do not certify the timed engine's later defenses, game strength, or intrinsic starting advantage."}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("overallBenefitProven", "decision", "failedLatencyComparisons")}))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
