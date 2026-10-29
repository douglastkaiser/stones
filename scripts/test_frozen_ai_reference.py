import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from scripts.frozen_ai_reference import MANIFEST, materialize_reference, verify_materialized_reference, verify_shared_contract


class FrozenReferenceTest(unittest.TestCase):
    def test_original_rule_apis_cannot_drift_behind_an_additive_query(self):
        verify_shared_contract()
        with tempfile.TemporaryDirectory() as directory:
            rules = Path(directory) / "changed_rules.dart"
            original = Path("lib/game/match_rules.dart").read_text()
            changed = original.replace(
                "if (game.finished || !game.geometry.contains(move.from)) return null;",
                "if (false) return null;", 1)
            self.assertNotEqual(changed, original)
            rules.write_text(changed)
            with self.assertRaisesRegex(ValueError, "Canonical game rules changed"):
                verify_shared_contract(rules)

    def test_archived_dependencies_are_exact_original_bytes(self):
        manifest = json.loads(MANIFEST.read_text())
        for source in manifest["sources"]:
            original = subprocess.check_output([
                "git", "show", f"{manifest['preservedAt']}:{source['source']}"])
            self.assertEqual(Path(source["snapshot"]).read_bytes(), original)
            self.assertEqual(hashlib.sha256(original).hexdigest(), source["sha256"])

    def test_reference_package_alias_and_materialized_bytes_are_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "original" / "package_config.json"
            config.parent.mkdir()
            config.write_text(json.dumps(dict(configVersion=2, packages=[
                dict(name="stones", rootUri="../production", packageUri="lib/"),
                dict(name="other", rootUri="../other", packageUri="lib/"),
            ])))
            destination = root / "reference"
            result = materialize_reference(destination, config)
            packages = {p["name"]: p for p in json.loads(result.read_text())["packages"]}
            self.assertEqual(packages["stones"]["rootUri"], destination.as_uri() + "/")
            self.assertEqual(packages["other"]["rootUri"], (root / "other").as_uri())
            verify_materialized_reference(destination)
            rules = destination / "lib/game/match_rules.dart"
            rules.write_text(rules.read_text() + "// changed\n")
            with self.assertRaisesRegex(ValueError, "Materialized frozen dependency changed"):
                verify_materialized_reference(destination)
            with self.assertRaisesRegex(ValueError, "Materialized frozen dependency changed"):
                materialize_reference(destination, config)


if __name__ == "__main__":
    unittest.main()
