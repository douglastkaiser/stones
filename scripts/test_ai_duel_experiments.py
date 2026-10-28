import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.ai_balance_report import cluster_interval
from scripts.build_ai_duel_experiments import settings, verify_reference


class DuelExperimentsTest(unittest.TestCase):
    def test_arms_separate_search_from_evaluation(self):
        self.assertEqual(settings("G", 16), dict(fullWidthDuels=False, roadResilienceWeight=0, tacticalSafety=True))
        self.assertEqual(settings("F", 24), dict(fullWidthDuels=False, roadResilienceWeight=0))
        self.assertEqual(settings("R", 24), dict(fullWidthDuels=False, roadResilienceWeight=0))
        self.assertEqual(settings("S", 24), dict(fullWidthDuels=True, roadResilienceWeight=0))
        self.assertEqual(settings("E", 16), dict(fullWidthDuels=False, roadResilienceWeight=16))
        self.assertEqual(settings("SE", 8), dict(fullWidthDuels=True, roadResilienceWeight=8))
        with self.assertRaises(ValueError):
            settings("SE", 999)

    def test_frozen_reference_is_verified_and_dependency_changes_rejected(self):
        verify_reference()
        with patch("scripts.build_ai_duel_experiments.digest", return_value="changed"):
            with self.assertRaisesRegex(ValueError, "Frozen duel reference dependency changed"):
                verify_reference()

    def test_repeats_do_not_increase_independent_opening_confidence(self):
        num = lambda row: row["win"]
        den = lambda row: 1
        openings = [[{"win": True}] * 2, [{"win": False}] * 2]
        self.assertEqual(cluster_interval(openings, num, den),
                         cluster_interval([r * 10 for r in openings], num, den))
        self.assertIsNone(cluster_interval(openings[:1], num, den))

    def test_aggregation_rejects_mixed_compile_time_settings(self):
        from scripts.ai_strength_ci import aggregate, matrix
        with tempfile.TemporaryDirectory() as directory:
            for index, weight in enumerate((8, 16)):
                path = Path(directory) / f"{index}.jsonl"
                row = dict(seed=100000, rotation=0, finished=True, winner="ivory",
                    targetWon=True, target="ivory", moves=[{}, {}],
                    config=dict(shape="square", size=5, seats=[
                        dict(id="ivory", level="expert"), dict(id="charcoal", level="hard")]))
                row2 = {**row, "rotation": 1, "target": "charcoal", "targetWon": False,
                        "config": dict(shape="square", size=5, seats=[
                            dict(id="ivory", level="hard"), dict(id="charcoal", level="expert")])}
                path.write_text(json.dumps(row) + "\n" + json.dumps(row2) + "\n")
                manifest = dict(shape="square", size=5, players=2, tier=2, seeds=1,
                    seedStart=100000, comparison="adjacent", seededOpening=True,
                    engine="v3", runtime="dart", os="linux", sourceSha256="a",
                    workerSha256="b", runnerSha256="c", policy="deterministic",
                    candidateSource=dict(sourceFiles={"engine": "a"},
                        buildSettings=dict(fullWidthDuels=True, roadResilienceWeight=weight)))
                Path(str(path) + ".manifest.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "mixed"):
                aggregate(directory, matrix("square", 5, 2, 2), seeds=1, full=False)


if __name__ == "__main__":
    unittest.main()
