import json
from pathlib import Path
import tempfile
import unittest

from scripts.ai_benefit_audit import opening_key, percentile, sign_evidence, timing_audit


class BenefitAuditTest(unittest.TestCase):
    def test_three_wins_one_loss_over_two_pairs_is_not_four_independent_trials(self):
        result = sign_evidence([2, 0])
        self.assertEqual(result["openingClusters"], 2)
        self.assertEqual(result["positive"], 1)
        self.assertEqual(result["oneSidedImprovementP"], .5)

    def test_two_winning_pairs_still_cannot_establish_a_population_advantage(self):
        self.assertEqual(sign_evidence([4, 4])["oneSidedImprovementP"], .25)
        self.assertEqual(sign_evidence([1] * 5)["oneSidedImprovementP"], 1 / 32)

    def test_regression_and_ties_are_not_counted_as_improvement(self):
        evidence = sign_evidence([-2, -1, 0])
        self.assertEqual(evidence["oneSidedRegressionP"], .25)
        self.assertEqual(evidence["oneSidedImprovementP"], 1)
        self.assertEqual(evidence["tied"], 1)
        self.assertIsNone(sign_evidence([0, 0])["oneSidedImprovementP"])

    def test_percentile_matches_existing_nearest_rank_gate(self):
        self.assertEqual(percentile(list(range(1, 101))), 95)
        self.assertEqual(percentile([10, 20, 30]), 30)

    def test_timing_merges_duplicate_openings_and_resamples_whole_clusters(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'timing.jsonl'
            settings = {arm: {'fullWidthDuels': arm in ('S', 'SE'),
                             'roadResilienceWeight': 16 if arm in ('E', 'SE') else 0}
                        for arm in ('R', 'S', 'E', 'SE')}
            manifest = {'heldOut': True, 'arms': {arm: {'buildSettings': data}
                                                for arm, data in settings.items()}}
            rows = []
            for seed, x in [(200000, 1), (200001, 1), (200002, 2)]:
                rows.append({'seed': seed, 'profile': 'square-5-2', 'level': 'easy',
                    'case': 'ply-2', 'config': {'shape': 'square', 'size': 5, 'seats': [{}, {}]},
                    'moves': [{'seat': 'ivory', 'x': x, 'y': 0},
                              {'seat': 'charcoal', 'x': 4, 'y': 4}],
                    'responses': {arm: {'position': 'matched', 'elapsedMs': 10 if arm == 'R' else 20,
                                       'experiment': setting} for arm, setting in settings.items()}})
            path.write_text(''.join(json.dumps(row) + '\n' for row in rows))
            Path(str(path) + '.manifest.json').write_text(json.dumps(manifest))
            result = timing_audit(path, resamples=40)['comparisons'][0]
            self.assertEqual(result['distinctOpenings'], 2)
            self.assertEqual(result['seedStreams'], 3)
            self.assertEqual(result['deduplicatedPositions'], 2)
            self.assertEqual(result['openingClusterBootstrap95RatioCI'], [2, 2])
            self.assertFalse(result['requiredSampleCovered'])
            path.write_text(path.read_text() + json.dumps(rows[0]) + '\n')
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                timing_audit(path, resamples=40)

    def test_color_and_worker_mirrors_share_an_opening_cluster(self):
        row = {"config": {"shape": "square", "size": 5, "seats": [{}, {}]},
               "moves": [{"seat": "ivory", "x": 1, "y": 2},
                         {"seat": "charcoal", "x": 3, "y": 4}]}
        mirror = {**row, "moves": [{**m, "seat": "charcoal" if m["seat"] == "ivory" else "ivory"}
                                   for m in row["moves"]]}
        self.assertEqual(opening_key(row), opening_key(mirror))
        mirror["moves"][0]["x"] = 0
        self.assertNotEqual(opening_key(row), opening_key(mirror))


if __name__ == "__main__":
    unittest.main()
