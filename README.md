# AeroBeat Vendor - BeatSaver

Provider-specific **BeatSaver acquisition/support package** for the AeroBeat polyrepo.

This repo is intentionally **not** the AeroBeat product-facing browse/install API, and it is **not** the place where Beat Saber maps become authored AeroBeat Boxing/Flow content. It exists to keep BeatSaver-specific transport, provider DTOs, and future source-material staging local to a replaceable vendor seam.

## Current scope of the implemented slices

This repo now provides two sharable seams:

- sharable package boundary at the repo root
- hidden Godot proving project under `.testbed/`
- narrow facade for search, detail-by-id, detail-by-hash, and latest-map listing
- isolated request-building, HTTP execution, and response-parsing classes under `src/`
- selected-version package acquisition into local staged artifacts under `.testbed/.artifacts/`
- ZIP archive inspection plus normalized source-material manifest emission for downstream conversion lanes
- truthful lightweight BeatSaver JSON fixtures under `assets/fixtures/beatsaver_api/`
- synthetic metadata-only ZIP fixture under `.testbed/fixtures/packages/` for deterministic validation
- planning + Beads homes inside the owning repo

Still intentionally **out of scope for this slice**:

- Boxing/Flow conversion
- final authored AeroBeat content generation
- `plugin.cfg`
- the full browse/detail/download UI workbench scene

## Ownership boundary

### This repo should own

- BeatSaver-specific request building and transport
- provider DTO parsing and normalization
- selected-version package acquisition
- lightweight source-material staging for downstream tools
- archive inspection and manifesting

### This repo should not own

- AeroBeat public product UX
- canonical AeroBeat authored content schemas
- Boxing/Flow gameplay conversion logic
- `workout.yaml` generation or final content packaging policy

Those downstream responsibilities belong in later importer/converter/runtime/tool repos.

## Repo layout

- `src/` — sharable package source
- `assets/` — sharable package assets and truthful API fixtures
- `.testbed/` — hidden Godot workbench used for local proving and tests
- `.plans/` — active repo-local plans
- `.beads/` — repo-local Beads state

## Acquisition seam

The new acquisition seam is exposed via `BeatSaverVendorFacade.stage_selected_version_artifact(...)`.

Given a normalized `BeatSaverMapDetail` and selected version (hash, key, or `BeatSaverVersionRef`), it will:

1. download the package ZIP into a local staging folder
2. place the ZIP under `.testbed/.artifacts/<map-id>/<version-hash>/`
3. inspect the archive contents
4. parse `Info.dat` when present
5. emit a normalized `source_material_manifest.json` next to the staged ZIP

Downloaded third-party packages are **local-only cache artifacts** and must not be committed.

## GodotEnv development flow

This repo follows the AeroBeat package-repo convention:

- package source lives at the repo root
- `.testbed/addons.jsonc` mounts this repo from `..` with `subfolder: "/"`
- `.testbed/addons/` is generated install output
- `.testbed/.addons/` is GodotEnv cache state

Restore dependencies from the repo root:

```bash
cd .testbed
godotenv addons install
```

Open the hidden workbench:

```bash
godot --editor --path .testbed
```

## Local validation

Headless validation for the current slices:

```bash
godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd
```

This script exercises request building, fixture-driven parsing, the facade through an injected fake transport, and the acquisition/inspection/manifest seam through a synthetic metadata-only ZIP fixture.

## Content / legal note

Do not commit downloaded third-party BeatSaver song packages, audio payloads, or other redistributed community content by default. This repo should prefer synthetic, tiny, or metadata-only fixtures unless redistribution rights are explicitly clear.

## License

Mozilla Public License 2.0 (MPL 2.0)
