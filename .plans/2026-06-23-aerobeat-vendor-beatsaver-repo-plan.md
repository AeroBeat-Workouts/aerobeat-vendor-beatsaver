# AeroBeat Vendor BeatSaver

**Date:** 2026-06-23  
**Status:** In Progress  
**Last Updated:** 2026-06-23 07:14 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Design and then implement a new `aerobeat-vendor-beatsaver` repo that matches the AeroBeat Godot polyrepo shape while providing a clean vendor seam for browsing, fetching, and eventually staging BeatSaver community maps for later AeroBeat conversion tooling.

---

## Overview

This lane should be treated as a **read-only vendor acquisition package**, not as an AeroBeat gameplay/content package and not as the final public product API. BeatSaver already exposes the key provider surface we need: direct map lookup by id/hash, bulk id/hash lookup, uploader listings, latest/deleted feeds, full-text search, user lookup, playlist discovery, per-version download URLs, preview/cover URLs, uploader metadata, and an optional websocket mirror/update feed (`wss://ws.beatsaver.com/maps`) (`REF-01`). That makes `aerobeat-vendor-beatsaver` a strong fit for provider-specific transport, DTO normalization, and selected map-package acquisition.

The clean AeroBeat polyrepo boundary is: **this repo owns BeatSaver transport + provider DTOs + normalized source-material staging; downstream repos own AeroBeat semantics**. Concretely, this repo should own request building, HTTP execution, response/error normalization, provider-side paging/cursor handling, version/package selection, and lightweight archive inspection/manifesting. It should not own Boxing/Flow authored chart conversion, canonical `workout.yaml` generation, durable AeroBeat content schema truth, or gameplay/runtime interpretation (`REF-02`, `REF-03`, `REF-06`). A repo-local hidden testbed UI **does** belong here, but only as a proving surface for this vendor package rather than as product-facing AeroBeat UX. Those product-facing authoring/import/runtime responsibilities still fit better in later importer/converter/runtime/tool repos.

Repo shape should follow the current AeroBeat package convention: sharable package code at the root, hidden proving project under `/.testbed/`, and explicit GodotEnv dependencies via `.testbed/addons.jsonc`. Unlike vendored raw-plugin lanes such as `aerobeat-vendor-gdgs`, this BeatSaver repo should begin as a **support package mounted from the repo root** rather than a third-party payload mirrored under `src/` (`REF-02`, `REF-03`, `REF-04`, `REF-05`). The strongest initial slice is a deterministic read-only client plus acquisition/staging seam that can hand a selected BeatSaver ZIP and a normalized manifest to later authoring/import tooling. The hidden testbed's goal is to showcase the provider API fully via a searchable, filterable catalog UI: search results should render as clickable image/name cards, selecting a card should reveal a right-side detail panel with richer metadata, and a large CTA download button should stage the selected map ZIP into `/.testbed/.artifacts/` for local testing only.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | BeatSaver Swagger API surface | `https://api.beatsaver.com/docs/swagger.json` |
| `REF-02` | AeroBeat Environment Loader repo shape and GodotEnv conventions | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/README.md` |
| `REF-03` | AeroBeat Input Camera Tracking hidden testbed + addon conventions | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/README.md` |
| `REF-04` | Example `.testbed/addons.jsonc` dependency contract | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-loader/.testbed/addons.jsonc` |
| `REF-05` | Example `.testbed/addons.jsonc` with vendor/tool stack dependencies | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.testbed/addons.jsonc` |
| `REF-06` | Shared AeroBeat content-domain contract scope | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/README.md` |
| `REF-07` | Vendor template guidance for facade-vs-provider structure | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-template-vendor/README.md` |
| `REF-08` | Existing provider adapter precedent: `aerobeat-vendor-modio` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/README.md` |
| `REF-09` | Raw vendored payload precedent: `aerobeat-vendor-gdgs` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/README.md` |
| `REF-10` | AeroBeat-owned API/tool boundary precedent | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-api/README.md` |

Use these IDs later in execution prompts, QA notes, and audit notes.

---

## Tasks

### Task 1: Repo lane definition and dependency contract

**Bead ID:** `openclaw-pico-c9v`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** Research and document the exact lane boundaries for `aerobeat-vendor-beatsaver`. Compare BeatSaver capabilities against current AeroBeat polyrepo conventions. Define what belongs in this repo vs. later importer/converter/runtime repos. Include explicit recommendations for repo root layout, GodotEnv `.testbed/` dependencies, likely sibling dependencies, and legal/content-boundary notes. Claim the bead on start.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/` (future)
- `/home/derrick/.openclaw/workspace/projects/openclaw-pico/.plans/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/openclaw-pico/.plans/2026-06-23-aerobeat-vendor-beatsaver-repo-plan.md`

**Status:** ✅ Complete

**Results:**
- `REF-01` confirms this lane can truthfully cover BeatSaver **read/acquire** responsibilities without inventing private contracts:
  - map reads: `/maps/id/{id}`, `/maps/ids/{ids}`, `/maps/hash/{hash}`
  - discovery feeds: `/maps/latest`, `/maps/deleted`, `/maps/uploader/{id}/{page}`, `/maps/collaborations/{id}`
  - full-text search: `/search/text/{page}`, plus older `/search/v1/{page}`
  - related provider reads: `/users/*`, playlist search/latest, optional websocket update feed
  - provider payload fields needed for first slice include `MapDetail.id`, `name`, `description`, `tags`, `metadata.songName`, `metadata.songSubName`, `metadata.songAuthorName`, `metadata.levelAuthorName`, `metadata.bpm`, `metadata.duration`, `uploader`, `versions[].hash`, `versions[].key`, `versions[].downloadURL`, `versions[].coverURL`, `versions[].previewURL`, `versions[].diffs[]`, plus timestamps/status fields.
- Recommended ownership boundary:
  - **Own here:** BeatSaver request building, HTTP transport, provider DTO parsing, provider error normalization, normalized search/detail models, selected-version acquisition, lightweight ZIP inspection, and a conversion-ready **source-material manifest**.
  - **Do not own here:** Beat Saber chart-to-AeroBeat Boxing/Flow semantic conversion, canonical `workout.yaml`/`songs/`/`charts/` authored package emission, product-facing browse/install UX, official library/entitlement policy, or gameplay runtime interpretation (`REF-06`, `REF-10`).
- Recommended repo type: **support/vendor package mounted from repo root**, closer to `aerobeat-vendor-modio` than to the raw payload pinning pattern in `aerobeat-vendor-gdgs` (`REF-08`, `REF-09`).
- **plugin/public entrypoint decision:** first implementation slice should **not** expose a user-facing `plugin.cfg` or autoload singleton yet. This lane is not the AeroBeat-owned public contract. Start as a pure support package with preloadable classes under `src/`. Add `plugin.cfg` later only if a real consuming tool/runtime repo proves a stable package-facing facade is needed. This keeps the vendor seam narrow and avoids teaching downstream repos to depend on a premature singleton.
- Recommended root layout for the new repo:
  ```text
  aerobeat-vendor-beatsaver/
  ├── src/
  │   ├── facade/
  │   │   └── beatsaver_vendor_facade.gd
  │   ├── client/
  │   │   ├── beatsaver_http_client.gd
  │   │   ├── beatsaver_request_builder.gd
  │   │   └── beatsaver_response_parser.gd
  │   ├── models/
  │   │   ├── beatsaver_search_query.gd
  │   │   ├── beatsaver_map_ref.gd
  │   │   ├── beatsaver_map_detail.gd
  │   │   ├── beatsaver_version_ref.gd
  │   │   ├── beatsaver_difficulty_ref.gd
  │   │   └── beatsaver_source_package_manifest.gd
  │   ├── acquisition/
  │   │   ├── beatsaver_package_fetcher.gd
  │   │   ├── beatsaver_archive_inspector.gd
  │   │   └── beatsaver_stage_manifest_builder.gd
  │   └── mapping/
  │       └── beatsaver_source_material_mapper.gd
  ├── assets/
  │   └── fixtures/
  ├── .testbed/
  │   ├── addons.jsonc
  │   ├── project.godot
  │   ├── assets/
  │   ├── fixtures/
  │   ├── scenes/
  │   ├── scripts/
  │   └── tests/
  ├── .plans/
  ├── .beads/
  ├── README.md
  ├── LICENSE.md
  └── .gitignore
  ```
- Recommended hidden `.testbed/` layout:
  - `assets/` for tiny local placeholder media/icons only
  - `fixtures/api/` for sanitized BeatSaver JSON payloads
  - `fixtures/packages/` for **tiny legal-safe ZIP fixtures** containing metadata-only or synthetic placeholder payloads, not redistributed community songs
  - `scenes/beatsaver_browser_testbed.tscn` for search/detail/download-staging proving
  - `scripts/` for harness glue and local config loading
  - `tests/` for fixture-driven parser + mapper + acquisition tests
- Likely first `.testbed/addons.jsonc` dependencies:
  - `aerobeat-vendor-beatsaver` → `..` via symlink, `subfolder: "/"`
  - `aerobeat-tool-headless-manager` for headless proving consistency (`REF-04`, `REF-05`)
  - `aerobeat-vendor-godot-unit-test` for GUT-based repo-local tests (`REF-04`, `REF-05`)
  - defer adding `aerobeat-content-core`, `aerobeat-tool-content-authoring`, or feature repos until the converter/import handoff is actually implemented; they are not required for the first pure vendor slice.
- Minimum viable source files/classes for the first implementation slice:
  - `src/facade/beatsaver_vendor_facade.gd` — narrow convenience seam for search/detail/latest/download-staging calls
  - `src/client/beatsaver_http_client.gd` — executes GET/download requests and normalizes HTTP failures/rate-limit details
  - `src/client/beatsaver_request_builder.gd` — owns URL/query construction for search/latest/id/hash/uploader/deleted
  - `src/client/beatsaver_response_parser.gd` — converts raw provider JSON into typed dictionaries/objects
  - `src/models/beatsaver_search_query.gd` — query object for q/page/pageSize/order/tag/filters
  - `src/models/beatsaver_map_detail.gd` — normalized map record with provider fields preserved where useful
  - `src/models/beatsaver_version_ref.gd` — selected version + URLs/hash/state/difficulty summaries
  - `src/models/beatsaver_source_package_manifest.gd` — staged archive manifest for downstream converter/importer use
  - `src/acquisition/beatsaver_package_fetcher.gd` — downloads selected ZIP to caller-provided staging dir
  - `src/acquisition/beatsaver_archive_inspector.gd` — enumerates ZIP entries and basic package facts without claiming semantic conversion
  - `src/acquisition/beatsaver_stage_manifest_builder.gd` — emits a clean intermediate manifest containing archive paths, discovered Beat Saber info files, audio filename hints, and difficulty file inventory
- Legal/content boundary notes for coder follow-up:
  - do **not** commit downloaded community map/audio payloads into the repo by default
  - committed fixtures should stay synthetic, tiny, or metadata-only unless redistribution rights are explicit
  - download caches/staging dirs should remain local/testbed/runtime artifacts and be gitignored
  - repo docs should clearly state that this lane fetches user-selected third-party content and that downstream import/conversion policy remains separate from provider acquisition
- Coordination note: the target owning repo now exists at `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/`. The active working copy of this plan has been **copied** to `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/2026-06-23-aerobeat-vendor-beatsaver-repo-plan.md`. This coordination copy remains in `openclaw-pico` as the orchestration record and should point follow-on repo work at the owning-repo plan path.
- Crisp next action for the coder: create the repo scaffold exactly to the support-package layout above, omit `plugin.cfg` for the first slice, wire a `.testbed` with only self + headless-manager + unit-test dependencies, and implement search/detail/latest plus selected-version ZIP staging before touching any AeroBeat chart conversion logic.

---

### Task 2: Create the new repo scaffold and package boundary

**Bead ID:** `openclaw-pico-b9y`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** Create the initial `aerobeat-vendor-beatsaver` repo scaffold matching AeroBeat polyrepo conventions. Root must contain `/src/` and `/assets/`; hidden workbench must live under `/.testbed/` with `.addons/`, `addons/`, `addons.jsonc`, `/assets/`, `/fixtures/`, `/scripts/`, `/scenes/`, and `/tests/`. Start this repo as a **support package without `plugin.cfg`** unless the orchestrator explicitly changes that decision. Add baseline repo files (`README.md`, `LICENSE.md`, `.gitignore`, `.plans/`, `.beads/`). Claim the bead on start and commit/push on completion unless the orchestrator overrides.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/assets/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.beads/`

**Files Created/Deleted/Modified:**
- `README.md`
- `.gitignore`
- `LICENSE.md`
- `.testbed/project.godot`
- `.testbed/addons.jsonc`

**Status:** ✅ Complete

**Results:** Created `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver` as a new git repo scaffold with root `src/`, `assets/`, `.plans/`, `.beads/`, and hidden `.testbed/` workbench folders. Added baseline `README.md`, `LICENSE.md`, `.gitignore`, `.testbed/project.godot`, and `.testbed/addons.jsonc`; kept the repo intentionally minimal and **did not create `plugin.cfg`** per the approved boundary. `.testbed/addons.jsonc` mounts this repo from `..` with `subfolder: "/"` and limits dependencies to `aerobeat-tool-headless-manager` + `aerobeat-vendor-godot-unit-test`. Copied the active plan into this repo at `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/2026-06-23-aerobeat-vendor-beatsaver-repo-plan.md` so ongoing work can continue from the owning repo while leaving the coordination copy in `openclaw-pico` with a handoff note.

---

### Task 3: Implement the BeatSaver client seam

**Bead ID:** `openclaw-pico-lgf`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-07`, `REF-08`  
**Prompt:** Implement the first sharable runtime seam in `/src/` for BeatSaver access. Target a clean read-only vendor facade with search maps, fetch map details by id/hash, enumerate latest results, and surface version download/preview/cover URLs plus uploader/metadata fields. Keep HTTP specifics and provider DTO parsing isolated from future AeroBeat importer logic. Do not implement Boxing/Flow conversion or `workout.yaml` generation here. Claim the bead on start and commit/push on completion unless the orchestrator overrides.

**Folders Created/Deleted/Modified:**
- `src/`
- `assets/`

**Files Created/Deleted/Modified:**
- `src/facade/beatsaver_vendor_facade.gd`
- `src/client/beatsaver_http_client.gd`
- `src/client/beatsaver_request_builder.gd`
- `src/client/beatsaver_response_parser.gd`
- `src/models/beatsaver_search_query.gd`
- `src/models/beatsaver_difficulty_ref.gd`
- `src/models/beatsaver_version_ref.gd`
- `src/models/beatsaver_map_detail.gd`
- `assets/fixtures/beatsaver_api/map_detail_id_1.json`
- `assets/fixtures/beatsaver_api/search_fitbeat_page_0.json`
- `assets/fixtures/beatsaver_api/latest_page_size_2.json`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `README.md`
- `.testbed/project.godot`

**Status:** ✅ Complete

**Results:** Implemented the first sharable read-only BeatSaver vendor seam under `src/` (`REF-01`, `REF-07`, `REF-08`) with a narrow facade, isolated request builder, isolated HTTP client, isolated response parser, and typed-ish normalized models for map detail, versions, and difficulties. The public surface now covers search by text/page, map detail by id, map detail by hash, and latest-map enumeration. Normalized outputs expose uploader fields, map/song metadata, timestamps, tags, stats, and version download/preview/cover URLs while preserving raw provider payloads for downstream seams when useful. After Derrick clarified the hidden `.testbed` goal, Task 3 was further shaped to expose future Task 5 catalog/detail fields cleanly: `card_title`, `card_subtitle`, `card_image_url`, `detail_title`, `detail_subtitle`, `search_text`, `uploader_name`, `cover_image_url`, `preview_audio_url`, and `primary_download_url` are now available through the normalized map/detail seam without pulling ZIP acquisition into this slice.

Validation for this slice is deterministic and fixture-friendly: committed truthful lightweight JSON fixtures were sourced from live BeatSaver API responses and trimmed to metadata-only examples, then exercised through `.testbed/scripts/validate_beatsaver_client_slice.gd`. That headless script verifies request construction, fixture parsing, and end-to-end facade behavior using an injected fake transport instead of live network calls. To keep validation repo-local before the future testbed/UI slice lands, `.testbed/project.godot` was also simplified so it does not depend on currently uninstalled generated addons/autoload state just to run this seam check.

Execution refinement revealed a clean Task 4/5 seam split:
- **Task 4** should start at selected-version ZIP acquisition + archive inspection + normalized source-package manifesting only.
- **Task 5** should then consume that seam to build the hidden browser/detail/download proving UI and any broader unit harness integration.

---

### Task 4: Add map package acquisition + safe fixture strategy

**Bead ID:** `openclaw-pico-a9f`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-06`  
**Prompt:** Add the repo's first artifact-acquisition seam: given a selected BeatSaver version, download the map package into a local/testbed staging area, inspect package contents, and expose a normalized **source-material manifest** needed for later AeroBeat conversion. Wire this so the hidden testbed can trigger downloads from a large CTA button and stage downloaded artifacts under `/.testbed/.artifacts/`. Keep committed fixtures lightweight and legally safe; do not silently vendor third-party song payloads into the repo. Ensure `/.testbed/.artifacts/` is gitignored because it is a local testing cache only. Claim the bead on start and commit/push on completion unless the orchestrator overrides.

**Folders Created/Deleted/Modified:**
- `src/acquisition/`
- `src/models/`
- `.testbed/.artifacts/` (local-only gitignored runtime cache)
- `.testbed/fixtures/packages/`
- `.testbed/scripts/`

**Files Created/Deleted/Modified:**
- `src/acquisition/beatsaver_package_fetcher.gd`
- `src/acquisition/beatsaver_archive_inspector.gd`
- `src/acquisition/beatsaver_stage_manifest_builder.gd`
- `src/models/beatsaver_source_package_manifest.gd`
- `src/facade/beatsaver_vendor_facade.gd`
- `src/client/beatsaver_http_client.gd`
- `src/models/beatsaver_map_detail.gd`
- `.testbed/fixtures/packages/synthetic_training_pack.zip`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `.gitignore`
- `README.md`

**Status:** ✅ Complete

**Results:** Implemented the first artifact-acquisition seam without crossing into AeroBeat conversion (`REF-01`, `REF-06`). The repo can now resolve a selected BeatSaver version, download its ZIP to a deterministic stage folder under `.testbed/.artifacts/<map-id>/<version-hash>/`, inspect ZIP entries, parse `Info.dat` when present, and emit a normalized `source_material_manifest.json` beside the staged archive for downstream importer/converter work. The public package-facing hook is a narrow facade method, `BeatSaverVendorFacade.stage_selected_version_artifact(...)`, which future hidden testbed UI work can call directly for CTA-driven staging.

Validation stayed repo-local and legal-safe: `.gitignore` now excludes `.testbed/.artifacts/`, no downloaded community payloads were committed, and deterministic coverage uses a tiny synthetic metadata-only ZIP fixture (`.testbed/fixtures/packages/synthetic_training_pack.zip`) rather than third-party map content. The headless validator was expanded so the same script now verifies request building, fixture parsing, facade calls, staged ZIP acquisition, archive inspection, and persisted manifest output in one pass.

This slice also refined the clean Task 5 seam: the next step should consume `stage_selected_version_artifact(...)` from a hidden browse/detail/download proving scene, render the returned manifest/archive facts to the user, and keep all staged artifacts local-only under `.testbed/.artifacts/` rather than inventing any conversion logic here.

---

### Task 5: Build the Godot testbed proving scene and unit harness

**Bead ID:** `openclaw-pico-dff`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Build a hidden `.testbed/` proving surface that exercises root `/src/` and `/assets/` truthfully. The goal is to showcase the BeatSaver API via a searchable, filterable UI that renders song search results as clickable image/name cards. Clicking a result should reveal a right-side pop-out detail panel with fuller song/map/uploader/version metadata and a large CTA download button at the bottom. That CTA should place the selected downloaded song ZIP into `/.testbed/.artifacts/` for local testing only. Include repo-local unit tests and any helper scripts/assets needed under `.testbed/`. The workbench must validate the package the same way sibling AeroBeat repos do, and `/.testbed/.artifacts/` must be gitignored. Claim the bead on start and commit/push on completion unless the orchestrator overrides.

**Folders Created/Deleted/Modified:**
- `.testbed/.artifacts/`
- `.testbed/assets/`
- `.testbed/scripts/`
- `.testbed/scenes/`
- `.testbed/tests/`

**Files Created/Deleted/Modified:**
- `.testbed/project.godot`
- `.testbed/scenes/*`
- `.testbed/scripts/*`
- `.testbed/tests/*`
- `.gitignore`

**Status:** ⏳ Pending

**Results:** Pending execution.

---

### Task 6: Define the conversion handoff seam for Boxing and Flow

**Bead ID:** `openclaw-pico-bpm`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-06`, `REF-10`  
**Prompt:** Define the exact handoff seam between BeatSaver source material and AeroBeat authored content. Recommend how Beat Saber note/difficulty/package data should be staged for future conversion into AeroBeat Boxing and Flow chart formats without muddying this vendor repo's ownership boundary. Claim the bead on start.

**Folders Created/Deleted/Modified:**
- `docs/` (future optional)
- `src/` (future optional)

**Files Created/Deleted/Modified:**
- conversion contract notes / README sections / source interface files

**Status:** ⏳ Pending

**Results:** Pending execution. Initial stance now sharpened: this repo should output normalized provider records + a staged source-package manifest, while actual Boxing/Flow semantic transformation should live in a downstream importer/converter lane or AeroBeat authoring tool layer.

---

### Task 7: QA and independent audit

**Bead ID:** `openclaw-pico-97l`  
**SubAgent:** `primary` (for `qa` then `auditor`)  
**Role:** `qa` / `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-10`  
**Prompt:** QA should verify the hidden testbed, headless tests, and at least one truthful BeatSaver metadata/search/detail flow plus selected-version ZIP staging. Auditor should independently confirm repo shape, dependency contract, ownership boundaries, no-premature-plugin stance, and validation evidence against the plan and references. QA does not close the bead; auditor closes it if complete.

**Folders Created/Deleted/Modified:**
- Entire repo as needed for final fixes

**Files Created/Deleted/Modified:**
- QA logs / plan updates / final repo files

**Status:** ⏳ Pending

**Results:** Pending execution.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** A new `aerobeat-vendor-beatsaver` support package scaffold plus two implemented seams: (1) a read-only BeatSaver client for search/detail/latest metadata and (2) a first artifact-acquisition seam that stages selected version ZIPs into `.testbed/.artifacts/`, inspects archive contents, and emits normalized source-material manifests for downstream conversion work. The proving UI, independent conversion handoff notes, QA, and audit remain for later tasks.

**Reference Check:**
- `REF-01` reviewed for concrete BeatSaver endpoint coverage and payload fields.
- `REF-02` to `REF-05` reviewed for current AeroBeat repo/testbed/package layout conventions.
- `REF-06` reviewed for current AeroBeat durable content ownership boundaries.
- `REF-07` to `REF-10` reviewed for current vendor/tool/public-contract precedents inside the AeroBeat polyrepo.

**Commits:**
- `da7cea7` - Add initial BeatSaver client seam
- No remote configured in this repo, so push is not available yet

**Lessons Learned:**
- BeatSaver already exposes a rich enough provider surface that this repo can stay narrow: provider reads, selected ZIP acquisition, and normalized staging are enough for the first useful slice.
- The cleanest architecture is `BeatSaver vendor repo -> staged source-material manifest -> downstream AeroBeat importer/converter/tooling`, not a monolith that also owns Boxing/Flow conversion.
- The target repo should be created before the plan migrates there; until then, the coordination plan belongs in `openclaw-pico`.
- A premature `plugin.cfg`/singleton would teach the wrong dependency pattern. First slice should stay a plain support package unless a later consumer seam proves a stable public facade is worth shipping.

---

*Completed on 2026-06-23*