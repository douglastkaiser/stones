"""Materialize byte-identical historical dependencies for reference-only builds."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urljoin


MANIFEST = Path("tools/ai_reference_sources/manifest.json")
SHARED_CONTRACT = {
    "lib/game/ai_position.dart", "lib/game/board_geometry.dart",
    "lib/game/match_config.dart", "lib/game/match_state.dart",
    "lib/models/piece.dart", "lib/models/player.dart",
}


# These exact setup-only changes broaden Court eligibility. Historical AI
# comparisons use court=False; keep the archived package and every other config
# byte pinned, including clocks, rules profiles, serialization and engine IDs.
COURT_CONFIG_CHANGES = (
    ("    if (court && !courtEligible) {\n"
     "      throw ArgumentError('Court Mode requires a human player');\n",
     "    if (court &&\n"
     "        (online ||\n"
     "            !seats.any((s) => s.control == SeatControl.ai) ||\n"
     "            !seats.any((s) => s.control == SeatControl.localHuman))) {\n"
     "      throw ArgumentError('Court Mode requires offline humans and AI');\n"),
    ("  bool get courtEligible => seats.any((seat) => seat.control != SeatControl.ai);\n", ""),
    ("        court: (court ?? this.court) &&\n"
     "            newSeats.any((s) => s.control != SeatControl.ai),\n",
     "        court: (court ?? this.court) &&\n"
     "            !newSeats.any((s) => s.control == SeatControl.onlineHuman) &&\n"
     "            newSeats.any((s) => s.control == SeatControl.ai) &&\n"
     "            newSeats.any((s) => s.control == SeatControl.localHuman),\n"),
)


def verify_shared_contract(rules_path=Path("lib/game/match_rules.dart"), *,
                           config_path=Path("lib/game/match_config.dart")):
    sources = {source["source"]: source for source in json.loads(MANIFEST.read_text())["sources"]}
    for name in SHARED_CONTRACT:
        data = Path(config_path if name == "lib/game/match_config.dart" else name).read_bytes()
        if name == "lib/game/match_config.dart":
            text = data.decode()
            for current, archived in COURT_CONFIG_CHANGES:
                text = text.replace(current, archived)
            data = text.encode()
        if hashlib.sha256(data).hexdigest() != sources[name]["sha256"]:
            raise ValueError(f"Shared reference game contract changed: {name}")
    rules = Path(rules_path).read_text()
    # The new, separately tested query is additive. Every byte of the original
    # transformer, adjudicator and other rule APIs must still match the reference.
    marker = "  /// Legality-only query for one top stone and one final drop."
    if marker in rules:
        start = rules.index(marker)
        end = rules.index("  /// Pure preview/application.", start)
        rules = rules[:start] + rules[end:]
    if hashlib.sha256(rules.encode()).hexdigest() != sources["lib/game/match_rules.dart"]["sha256"]:
        raise ValueError("Canonical game rules changed relative to the frozen reference")


def materialize_reference(destination, package_config=Path(".dart_tool/package_config.json")):
    verify_shared_contract()
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    for source in json.loads(MANIFEST.read_text())["sources"]:
        data = Path(source["snapshot"]).read_bytes()
        if hashlib.sha256(data).hexdigest() != source["sha256"]:
            raise ValueError(f"Frozen reference source changed: {source['snapshot']}")
        target = destination / source["source"]
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f"Materialized frozen dependency changed: {target}")
        target.write_bytes(data)
    package_config = Path(package_config).resolve()
    config = json.loads(package_config.read_text())
    found = False
    for package in config["packages"]:
        if package["name"] == "stones":
            package["rootUri"] = destination.as_uri() + "/"
            package["packageUri"] = "lib/"
            found = True
        else:
            package["rootUri"] = urljoin(package_config.as_uri(), package["rootUri"])
    if not found:
        raise ValueError("Missing stones package configuration")
    result = destination / "package_config.json"
    result.write_text(json.dumps(config, indent=2) + "\n")
    return result


def verify_materialized_reference(destination):
    for source in json.loads(MANIFEST.read_text())["sources"]:
        target = Path(destination) / source["source"]
        if hashlib.sha256(target.read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError(f"Materialized frozen dependency changed: {target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    print(materialize_reference(args.output_dir))


if __name__ == "__main__":
    main()
