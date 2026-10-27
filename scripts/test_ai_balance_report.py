import unittest
from scripts.ai_balance_report import balance_report


class BalanceReportTest(unittest.TestCase):
    def pair(self, winners, starter="ivory"):
        opening = [{"x": 0, "y": 0}, {"x": 1, "y": 1}]
        return [{"seed": 0, "rotation": i, "finished": True, "winner": winner,
                 "targetWon": winner == ["ivory", "charcoal"][i],
                 "config": {"starter": starter, "seats": [{}, {}]},
                 "moves": opening} for i, winner in enumerate(winners)]

    def test_separates_tier_sweep_from_starting_advantage(self):
        first = balance_report(self.pair(["ivory", "ivory"]))
        self.assertEqual(first["starterShare"], 1)
        self.assertEqual(first["pairedOutcomes"], {"starter-sweep": 1})
        tier = balance_report(self.pair(["ivory", "charcoal"]))
        self.assertEqual(tier["starterShare"], .5)
        self.assertEqual(tier["pairedOutcomes"], {"target-sweep": 1})
        reverse = balance_report(self.pair(["charcoal", "charcoal"], starter="charcoal"))
        self.assertEqual(reverse["pairedOutcomes"], {"starter-sweep": 1})

    def test_missing_and_drawn_games_are_inconclusive(self):
        rows = self.pair([None, None])
        report = balance_report(rows)
        self.assertIsNone(report["starterShare"])
        self.assertEqual(report["pairedOutcomes"], {"inconclusive": 1})
        self.assertEqual(balance_report(rows[:1])["pairedOutcomes"], {"inconclusive": 1})

    def test_different_ai_controlled_openings_are_identified(self):
        rows = self.pair(["ivory", "ivory"])
        rows[1]["moves"] = [{"x": 2, "y": 2}, {"x": 1, "y": 1}]
        self.assertFalse(balance_report(rows)["bySeed"][0]["sameOpening"])


if __name__ == "__main__":
    unittest.main()
