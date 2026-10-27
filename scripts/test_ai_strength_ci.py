import json
from pathlib import Path
import tempfile
import unittest
from scripts.ai_strength_ci import aggregate, matrix, summarize


class StrengthCiTest(unittest.TestCase):
    def rows(self, wins=61):
        return [{"seed": 100000 + i // 2, "rotation": i % 2,
                 "finished": True, "winner": "ivory" if i < wins else "charcoal",
                 "targetWon": i < wins} for i in range(100)]

    def test_full_matrix_and_filters(self):
        self.assertEqual(len(matrix()), 81)
        self.assertEqual(len(matrix("hex", players=2)), 9)
        self.assertEqual(matrix("square", 5, 2, 2),
                         [{"shape": "square", "size": 5, "players": 2, "tier": 2}])
        self.assertEqual(matrix("hex", size=8), [])

    def test_gate_rejects_parity_missing_and_duplicate(self):
        self.assertTrue(summarize(self.rows(), 50, 2, True)["passed"])
        self.assertFalse(summarize(self.rows(60), 50, 2, True)["passed"])
        self.assertFalse(summarize(self.rows()[:-1], 50, 2, True)["passed"])
        self.assertFalse(summarize(self.rows()[:-1] + self.rows()[:1], 50, 2, True)["passed"])

    def test_aggregate_requires_artifacts_for_every_selected_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "games.jsonl"
            manifest = dict(shape="square", size=5, players=2, tier=2, seeds=50,
                            seedStart=100000, comparison="adjacent", seededOpening=True,
                            engine="v3", runtime="dart", os="linux", sourceSha256="a",
                            workerSha256="b", runnerSha256="c", policy="deterministic")
            manifest["candidateSource"] = {"sourceFiles": {"engine": "a"}}
            rows = self.rows()
            for r in rows:
                r["moves"] = [{"seat": "ivory", "x": 0, "y": 0},
                              {"seat": "charcoal", "x": 4, "y": 4}]
                r["target"] = ["ivory", "charcoal"][r["rotation"]]
                r["winner"] = r["target"] if r["targetWon"] else ["charcoal", "ivory"][r["rotation"]]
                r["config"] = {"shape": "square", "size": 5,
                               "seats": [{"id": "ivory", "level": "expert" if r["rotation"] == 0 else "hard"},
                                         {"id": "charcoal", "level": "expert" if r["rotation"] == 1 else "hard"}]}
            path.write_text("".join(json.dumps(r) + "\n" for r in rows))
            Path(str(path) + ".manifest.json").write_text(json.dumps(manifest))
            selected = matrix("square", 5, 2, 2)
            self.assertTrue(aggregate(root, selected)["passed"])
            self.assertFalse(aggregate(root, matrix("square", 5, 2))["passed"])
            duplicate = root / "duplicate.jsonl"
            duplicate.write_text(path.read_text())
            Path(str(duplicate) + ".manifest.json").write_text(json.dumps(manifest))
            self.assertFalse(aggregate(root, selected)["passed"])
            mixed = {**manifest, "runtime": "another-runtime"}
            Path(str(duplicate) + ".manifest.json").write_text(json.dumps(mixed))
            with self.assertRaisesRegex(ValueError, "mixed"):
                aggregate(root, selected)
            duplicate.unlink()
            Path(str(duplicate) + ".manifest.json").unlink()
            path.write_text(json.dumps(rows[0]) + "\n")
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                aggregate(root, selected)
            rows[1]["moves"] = [{"seat": "ivory", "x": 1, "y": 0},
                                {"seat": "charcoal", "x": 4, "y": 4}]
            path.write_text("".join(json.dumps(r) + "\n" for r in rows))
            with self.assertRaisesRegex(ValueError, "identical openings"):
                aggregate(root, selected)


if __name__ == "__main__":
    unittest.main()
