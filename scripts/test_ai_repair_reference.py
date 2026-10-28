import copy
import json
from pathlib import Path
import tempfile
import unittest
from scripts.run_ai_repair_reference import aggregate, valid_shard


def rows(seed, shape, level, outcome):
    moves = [dict(x=seed, y=0, type='flat'), dict(x=0, y=1, type='flat')]
    result = []
    for rotation in (0, 1):
        target = ['ivory', 'charcoal'][rotation]
        winner = target if outcome == 'win' else ('ivory' if outcome == 'starter' else None)
        result.append(dict(seed=seed, rotation=rotation, target=target,
            targetWon=winner == target, winner=winner, finished=outcome != 'unfinished',
            config=dict(shape=shape, size=5 if shape == 'square' else 2,
                aiEngine='shared-search-v3', starter='ivory', seats=[
                    dict(id=s, level=level, control='ai') for s in ('ivory', 'charcoal')]), moves=moves))
    return result


class RepairReferenceTest(unittest.TestCase):
    def study(self, root, outcome='win'):
        tasks, completed = [], {}
        study = dict(distinctPerBoard=50)
        for seed in range(50):
            for shape in ('hex', 'square'):
                for level in ('hard', 'expert'):
                    profile = f'{shape}-{level}'
                    task = dict(key=f'{profile}-{seed}', seed=seed, profile=profile)
                    path = root / task['key']
                    data = rows(seed, shape, level, outcome)
                    path.write_text('\n'.join(map(json.dumps, data)) + '\n')
                    Path(str(path) + '.manifest.json').write_text('{}')
                    tasks.append(task)
                    completed[task['key']] = (path, data)
        return tasks, completed, study

    def test_starter_sweeps_are_not_engine_improvement(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            tasks, completed, study = self.study(root, 'starter')
            report = aggregate(completed, tasks, study, root)
            self.assertFalse(report['selectedReferenceStrengthGatesPassed'])
            self.assertTrue(all(g['normalizedShare'] == .5 for g in report['groups']))
            self.assertEqual(report['aggregateOpeningStreamSignEvidence']['positive'], 0)

    def test_repeated_profiles_and_swapped_seats_are_one_seed_cluster(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            tasks, completed, study = self.study(root)
            report = aggregate(completed, tasks, study, root)
            self.assertTrue(report['selectedReferenceStrengthGatesPassed'])
            self.assertEqual(report['aggregateOpeningStreamSignEvidence']['positive'], 50)
            self.assertFalse(report['fullMatrixQualified'])

    def test_one_bad_profile_fails_even_with_positive_aggregate(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            tasks, completed, study = self.study(root)
            for task in tasks:
                if task['profile'] == 'hex-hard':
                    for row in completed[task['key']][1]:
                        row['winner'] = 'charcoal' if row['target'] == 'ivory' else 'ivory'
                        row['targetWon'] = False
            self.assertFalse(aggregate(completed, tasks, study, root)['selectedReferenceStrengthGatesPassed'])

    def test_unfinished_games_are_not_draws_and_fail_completion(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            tasks, completed, study = self.study(root)
            for task in tasks[:44]:
                path, _ = completed[task['key']]
                completed[task['key']] = (path, rows(task['seed'], task['profile'].split('-')[0],
                    task['profile'].split('-')[1], 'unfinished'))
            report = aggregate(completed, tasks, study, root)
            self.assertFalse(report['selectedReferenceStrengthGatesPassed'])
            self.assertTrue(all(g['unfinished'] == 22 and g['draws'] == 0 for g in report['groups']))

    def test_shard_rejects_duplicate_seats_and_wrong_target(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'games'
            task = dict(seed=1, shape='hex', size=2, level='hard', tier=1,
                openingKey=json.dumps([[1, 0, 'flat'], [0, 1, 'flat']]))
            study = dict(candidateSha256='g', baselineSha256='r', runnerSha256='s', checkpointSha256='c')
            meta = dict(candidateSha256='g', opponentSha256='r', runnerSha256='s', checkpointSha256='c',
                comparison='same-tier-reference', policy='deterministic', seedStart=1, seeds=1, tier=1, seededOpening=True)
            Path(str(path) + '.manifest.json').write_text(json.dumps(meta))
            Path(str(path) + '.summary.json').write_text('{"complete": true}')
            data = rows(1, 'hex', 'hard', 'win')
            path.write_text('\n'.join(map(json.dumps, data)))
            self.assertEqual(valid_shard(path, task, study), data)
            for mutation in ('duplicate', 'target', 'engine', 'opening'):
                bad = copy.deepcopy(data)
                if mutation == 'duplicate': bad[1]['rotation'] = 0
                if mutation == 'target': bad[1]['target'] = 'ivory'
                if mutation == 'engine': bad[1]['config']['aiEngine'] = 'shared-search-v2'
                if mutation == 'opening': bad[1]['moves'][0]['x'] = 99
                path.write_text('\n'.join(map(json.dumps, bad)))
                with self.assertRaises(ValueError): valid_shard(path, task, study)


if __name__ == '__main__':
    unittest.main()
