# AeroBeat Vendor - BeatSaver

Provider-specific **BeatSaver acquisition/support package** for the AeroBeat polyrepo.

This repo is intentionally **not** the AeroBeat product-facing browse/install API, and it is **not** the place where Beat Saber maps become authored AeroBeat Boxing/Flow content. It exists to keep BeatSaver-specific transport, provider DTOs, and future source-material staging local to a replaceable vendor seam.

## Current scope of the first implementation slice

This repo now provides the first sharable **read-only BeatSaver client seam**:

- sharable package boundary at the repo root
- hidden Godot proving project under `.testbed/`
- narrow facade for search, detail-by-id, detail-by-hash, and latest-map listing
- isolated request-building, HTTP execution, and response-parsing classes under `src/`
- truthful lightweight BeatSaver JSON fixtures under `assets/fixtures/beatsaver_api/`
- planning + Beads homes inside the owning repo

Still intentionally **out of scope for this slice**:

- ZIP acquisition/staging
- archive inspection / manifest building
- Boxing/Flow conversion
- `plugin.cfg`

## Ownership boundary

### This repo should own

- BeatSaver-specific request building and transport
- provider DTO parsing and normalization
- selected-version package acquisition
- lightweight source-material staging for downstream tools

### This repo should not own

- AeroBeat public product UX
- canonical AeroBeat authored content schemas
- Boxing/Flow gameplay conversion logic
- `workout.yaml` generation or final content packaging policy

Those downstream responsibilities belong in later importer/converter/runtime/tool repos.

## Repo layout

- `src/` — sharable package source (currently scaffold only)
- `assets/` — sharable package assets (currently scaffold only)
- `.testbed/` — hidden Godot workbench used for local proving and tests
- `.plans/` — active repo-local plans
- `.beads/` — repo-local Beads state

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

Headless validation for this slice:

```bash
godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd
```

This script exercises request building, fixture-driven parsing, and the facade through an injected fake transport so the slice stays deterministic and repo-local.

## Content / legal note

Do not commit downloaded third-party BeatSaver song packages, audio payloads, or other redistributed community content by default. This repo should prefer synthetic, tiny, or metadata-only fixtures unless redistribution rights are explicitly clear.

## License

Mozilla Public License 2.0 (MPL 2.0)
