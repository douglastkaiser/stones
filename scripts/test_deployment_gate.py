"""Exercise Deploy Main's actual qualifier with GitHub API fixtures."""
import json
from pathlib import Path
import subprocess
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'a' * 40
BROWSERS = ('chromium', 'firefox', 'webkit')
REQUIRED_JOBS = ['Browser player journeys'] + [
    f'{suite} ({browser})' for browser in BROWSERS
    for suite in ('Account checks', 'Production auth recovery')]


class DeploymentGateTests(unittest.TestCase):
    def qualify(self, **changes):
        fixture = {
            'source': SOURCE,
            'ciSource': SOURCE,
            'ciConclusion': 'success',
            'rulesConclusion': 'success',
            'attempt': 2,
            'previousConclusion': 'success',
            'jobs': [{'name': name, 'conclusion': 'success'} for name in REQUIRED_JOBS],
        }
        fixture.update(changes)
        workflow = (ROOT / '.github/workflows/deploy-main.yml').read_text()
        script = textwrap.dedent(workflow.split('          script: |\n', 1)[1]
                                 .split('\n  publish:', 1)[0])
        prelude = """
import {readFileSync} from 'node:fs';
const fixture = JSON.parse(readFileSync(0, 'utf8'));
process.env.SELECTED_SOURCE = fixture.source;
const context = {repo: {owner: 'owner', repo: 'stones'}};
const outputs = {};
const core = {setOutput: (key, value) => { outputs[key] = value; }};
const listJobsForWorkflowRun = Symbol('listJobsForWorkflowRun');
const github = {
  rest: {
    repos: {
      getBranch: async () => ({data: {commit: {sha: fixture.source}}}),
      compareCommitsWithBasehead: async () => ({data: {status: 'identical'}}),
    },
    actions: {
      listWorkflowRuns: async ({workflow_id}) => ({data: {workflow_runs: [{
        id: 123, status: 'completed', run_attempt: fixture.attempt,
        head_repository: {full_name: 'owner/stones'},
        head_sha: workflow_id === 'ci.yml' ? fixture.ciSource : fixture.source,
        conclusion: workflow_id === 'ci.yml'
          ? fixture.ciConclusion : fixture.rulesConclusion,
      }]}}),
      getWorkflowRunAttempt: async ({attempt_number}) => ({data: {
        status: 'completed', conclusion: attempt_number === fixture.attempt
          ? fixture.ciConclusion : fixture.previousConclusion,
      }}),
      listJobsForWorkflowRun,
    },
  },
  paginate: async (method) => {
    if (method !== listJobsForWorkflowRun) throw new Error('Unexpected API');
    return fixture.jobs;
  },
};
"""
        program = prelude + '\ntry {\n' + script + """
  console.log(JSON.stringify({outputs}));
} catch (error) {
  console.log(JSON.stringify({error: error.message}));
}
"""
        result = subprocess.run(['node', '--input-type=module', '-e', program],
                                input=json.dumps(fixture), capture_output=True,
                                text=True, check=True)
        return json.loads(result.stdout)

    def test_complete_non_tournament_ci_qualifies_its_exact_artifact(self):
        self.assertEqual(self.qualify(), {'outputs': {
            'run': '123', 'artifact': f'web-build-{SOURCE}-2', 'source': SOURCE}})

    def test_missing_or_failed_required_browser_cannot_qualify(self):
        for name in REQUIRED_JOBS:
            for conclusion in (None, 'failure'):
                jobs = [{'name': job, 'conclusion': conclusion if job == name else 'success'}
                        for job in REQUIRED_JOBS if job != name or conclusion is not None]
                with self.subTest(name=name, conclusion=conclusion):
                    self.assertIn(f'Missing successful qualification job: {name}',
                                  self.qualify(jobs=jobs)['error'])

    def test_failed_ci_or_rules_cannot_qualify(self):
        for changes in ({'ciConclusion': 'failure'}, {'rulesConclusion': 'failure'}):
            with self.subTest(changes=changes):
                self.assertIn('has not qualified', self.qualify(**changes)['error'])

    def test_previous_attempt_must_also_have_succeeded(self):
        self.assertIn('CI attempt 1 has not qualified',
                      self.qualify(previousConclusion='failure')['error'])
        self.assertIn('Require two consecutive successful CI attempts',
                      self.qualify(attempt=1)['error'])

    def test_another_commits_ci_cannot_qualify_this_source(self):
        self.assertIn('ci.yml has not qualified',
                      self.qualify(ciSource='b' * 40)['error'])


if __name__ == '__main__':
    unittest.main()
