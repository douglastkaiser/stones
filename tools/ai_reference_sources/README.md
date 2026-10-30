# Frozen reference dependencies

These are exact, unformatted source bytes formerly shared with production by the
historical AI references. `manifest.json` identifies their original commit and
hashes. Do not tune them or refresh their hashes to production versions.

The `.dart.txt` extension preserves original formatting and makes their archival
role explicit. `scripts/frozen_ai_reference.py` materializes a separate Dart
package and package configuration for reference-only compilation. Production
continues to resolve its normal package. Frozen engines, workers, protocols and
original dependency hash values remain unchanged; only dependency locations in
their manifests move to these snapshots.

The release-tool tests compare every snapshot byte with the original Git object,
verify the package alias, and reject changed materialized sources. Historical
executables and their provenance sidecars are never relabelled.

The live shared-contract guard permits the exact reviewed Court-only constructor,
eligibility getter and copy changes from 2026-10-30. It normalizes those three
blocks back to the archived bytes before hashing; every other byte remains
pinned. This does not refresh snapshots or change reference materialization.
Regressions reject altered clock limits, engine identity, Court policy and wire
version, and still verify the original archived configuration directly.
