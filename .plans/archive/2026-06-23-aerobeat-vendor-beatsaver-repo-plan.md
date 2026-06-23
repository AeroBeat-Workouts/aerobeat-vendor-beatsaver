# AeroBeat Vendor BeatSaver

**Date:** 2026-06-23  
**Status:** Complete  
**Last Updated:** 2026-06-23 11:05 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Design and then implement a new `aerobeat-vendor-beatsaver` repo that matches the AeroBeat Godot polyrepo shape while providing a clean vendor seam for browsing, fetching, and eventually staging BeatSaver community maps for later AeroBeat conversion tooling.

---

## Overview

This lane should be treated as a **read-only vendor acquisition package**, not as an AeroBeat gameplay/content package and not as the final public product API. BeatSaver already exposes the key provider surface we need: direct map lookup by id/hash, bulk id/hash lookup, uploader listings, latest/deleted feeds, full-text search, user lookup, playlist discovery, per-version download URLs, preview/cover URLs, uploader metadata, and an optional websocket mirror/update feed (`wss://ws.beatsaver.com/maps`) (`REF-01`). That makes `aerobeat-vendor-beatsaver` a strong fit for provider-specific transport, DTO normalization, and selected map-package acquisition.

The clean AeroBeat polyrepo boundary is: **this repo owns BeatSaver transport + provider DTOs + normalized source-material staging; downstream repos own AeroBeat semantics**. Concretely, this repo should own request building, HTTP execution, response/error normalization, provider-side paging/cursor handling, version/package selection, and lightweight archive inspection/manifesting. It should not own Boxing/Flow authored chart conversion, canonical `workout.yaml` generation, durable AeroBeat content schema truth, or gameplay/runtime interpretation (`REF-02`, `REF-03`, `REF-06`). Derrick has now explicitly confirmed that Boxing/Flow conversion will happen in a **future separate repo**, so this repo should stay strictly provider-facing and stop at staged source-material manifests plus proving/testbed UX. A repo-local hidden testbed UI **does** belong here, but only as a proving surface for this vendor package rather than as product-facing AeroBeat UX. Those product-facing authoring/import/runtime responsibilities still fit better in later importer/converter/runtime/tool repos.

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
- `.testbed/scenes/beatsaver_browser_testbed.tscn`
- `.testbed/scenes/beatsaver_result_card.tscn`
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_remote_image.gd`
- `.testbed/scripts/beatsaver_result_card.gd`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `README.md`

**Status:** ✅ Complete

**Results:** Built the hidden proving surface as a basic but truthful BeatSaver browser under `.testbed/scenes/beatsaver_browser_testbed.tscn` (`REF-02`, `REF-03`). The scene now boots by default in `.testbed/project.godot`, queries the existing vendor facade for either latest maps or text search, applies local text/tag filters over normalized search text/tags, and renders clickable result cards with a real image slot + map naming metadata. Selecting a card resolves provider detail through the facade and reveals a persistent right-side detail panel with uploader/song/map metadata, version selection, and a large CTA that stages the selected ZIP via `BeatSaverVendorFacade.stage_selected_version_artifact(...)` into the already-gitignored `.testbed/.artifacts/` cache.

To keep the proving seam deterministic and headless-testable, the UI state machine was split into `.testbed/scripts/beatsaver_testbed_state.gd`, while the scene script stays focused on binding controls and rendering. The existing validator was extended rather than replaced: `.testbed/scripts/validate_beatsaver_client_slice.gd` now covers request building, parser behavior, façade search/detail/latest calls, package staging/manifesting, state-level latest/search/filter/select/download flows, and a scene smoke pass that instantiates the browser scene, verifies card rendering, simulates result selection, and triggers the download CTA against a synthetic ZIP fixture. Headless coverage proves the normalized UI/data flow and local staging contract; what remains for QA is a human/editor pass on live network image loading, visual layout feel, and real BeatSaver interactive browsing inside the opened `.testbed` project. Implementation landed in commit `dfbb5a6` and was pushed to `origin/main`.

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

**Status:** ✅ Complete (explicitly descoped from this repo)

**Results:** Derrick explicitly clarified on 2026-06-23 that Boxing/Flow conversion should **not** happen in `aerobeat-vendor-beatsaver` and instead belongs in a future separate repo. That decision resolves this task without additional implementation inside the current repo. The handoff seam for this repo is therefore now fixed and complete: it stops at normalized provider records plus staged source-package manifests in `.testbed/.artifacts/`, with no authored-chart conversion, no `workout.yaml` generation, and no gameplay-semantic transformation here.

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

**Status:** ✅ QA + audit complete; human review feedback pending

**Results:** QA executed on 2026-06-23 and found one real live-provider blocker, so this bead should stay open for a coder follow-up before independent audit.

Exact commands run during QA:
- `bd update openclaw-pico-97l --status in_progress --json` (from `/home/derrick/.openclaw/workspace/projects/openclaw-pico`)
- `godot --version`
- `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`
- `git check-ignore -v .testbed/.artifacts .testbed/.artifacts/validation .testbed/.artifacts/validation_ui`
- `find .testbed/.artifacts -maxdepth 4 -type f | sort`
- live QA harness run via temporary script: `godot --headless --path .testbed -s /home/derrick/.openclaw/workspace/.temp/beatsaver_live_qa.gd`
- `curl -sS 'https://api.beatsaver.com/search/text/0?q=fitbeat&pageSize=12&sortOrder=relevance'`
- `curl -sS 'https://api.beatsaver.com/maps/latest?pageSize=2'`
- `git status --short --ignored .testbed/.artifacts`

What was verified successfully:
- Repo-local deterministic validation passed end-to-end: request builder expectations, fixture parsing, facade search/detail/latest seams, acquisition/inspection/manifest persistence, testbed state flow, and scene smoke behavior all passed through `.testbed/scripts/validate_beatsaver_client_slice.gd`.
- `.testbed/.artifacts/` remains gitignored/local-only. `git check-ignore -v` and `git status --ignored` both confirm the ignore rule is active while staged outputs remain on disk.
- Live BeatSaver **latest** behavior is coherent: the real API returned 12 visible latest results through the package seam.
- Live BeatSaver **detail** behavior is coherent when selecting a latest result: QA verified a real latest map (`524BB`) resolved into a populated detail view model with title/subtitle/uploader/version metadata plus real cover/preview/download URLs.
- Live BeatSaver **CTA download/staging** behavior is coherent at the data seam: staging the selected latest result produced a real ZIP and `source_material_manifest.json` under `.testbed/.artifacts/qa_live/524bb/41921e46fa7b4b0d28085401af6a603bcae6f040/`.
- Live manifest content looked sane for the downloaded package: `Info.dat` was found, one referenced audio file was detected, three referenced difficulty files were detected, and the archive inspector reported six entries.

Blocking failure found:
- Live BeatSaver **search** is currently broken against the real provider. The repo issues `GET https://api.beatsaver.com/search/text/0?pageSize=12&q=fitbeat&sortOrder=relevance`, and both the Godot live harness and direct `curl` reproduction returned HTTP 500 with provider payload `{ "success": false, "errors": ["Bad request, check parameters"] }`.
- Because the hidden testbed's browse/search UX depends on this seam, QA cannot truthfully sign off the full latest/search/detail/download flow yet.

Visual / fidelity note:
- Full manual on-screen visual verification of the Godot UI was only partially achieved. Wayland host screenshot access was denied (`org.freedesktop.DBus.Error.AccessDenied: Screenshot is not allowed`), so QA relied on the highest-fidelity non-invasive checks available here: scene instantiation/signal smoke in Godot, live state-driven latest/detail/download execution, and inspection of the produced staged artifacts.
- Residual risk remains on purely visual presentation details during live interactive search mode (card layout feel, remote cover-image rendering timing, right-panel appearance polish, and manual CTA ergonomics), separate from the concrete live search API failure above.

QA disposition:
- **Not ready for independent audit yet.** The coder should fix the live search request compatibility issue first, then QA should rerun the same latest/search/detail/download pass including a live manual visual check if desktop capture/control becomes available.

Coder follow-up on 2026-06-23:
- Root cause confirmed against `REF-01` plus live provider behavior: this repo was still sending the legacy search query shape `sortOrder=relevance` with lower-case enum values, but the current `/search/text/{page}` endpoint accepts `order=<TitleCase enum>` (for example `order=Relevance`). The old request shape reproduced the provider's HTTP 500 `Bad request, check parameters`; the corrected shape returned HTTP 200 with 12 docs for `fitbeat`.
- Patched `src/models/beatsaver_search_query.gd` so search requests now emit `order` instead of `sortOrder` and normalize supported values to the provider's accepted TitleCase enum strings (`Latest`, `Relevance`, `Rating`, `Curated`, plus `Random`/`Duration` for parity with the documented endpoint).
- Expanded `.testbed/scripts/validate_beatsaver_client_slice.gd` so deterministic validation now explicitly asserts that request building uses `order=Latest` and no longer emits the legacy `sortOrder` parameter.
- Coder validation after the patch:
  - `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`
  - live provider smoke via `python3`/`urllib`: `https://api.beatsaver.com/search/text/0?q=fitbeat&pageSize=12&order=Relevance` → HTTP 200 with 12 docs
- QA retry guidance:
  - rerun `godot --headless --path .testbed -s /home/derrick/.openclaw/workspace/.temp/beatsaver_live_qa.gd`
  - rerun direct search reproduction with `curl -sS 'https://api.beatsaver.com/search/text/0?q=fitbeat&pageSize=12&order=Relevance'`
  - rerun the existing latest/detail/download checks to confirm this fix did not regress those already-good seams

QA retry on 2026-06-23 after commit `0afb9c9`:
- Exact commands run during the retry:
  - `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`
  - `godot --headless --path .testbed -s /home/derrick/.openclaw/workspace/.temp/beatsaver_live_qa.gd`
  - `curl -sS -D /tmp/beatsaver-search-headers.txt 'https://api.beatsaver.com/search/text/0?q=fitbeat&pageSize=12&order=Relevance' -o /tmp/beatsaver-search-body.json`
  - `curl -sS -D /tmp/beatsaver-latest-headers.txt 'https://api.beatsaver.com/maps/latest?pageSize=2' -o /tmp/beatsaver-latest-body.json`
  - `find .testbed/.artifacts -maxdepth 6 -type f | sort`
  - `git check-ignore -v .testbed/.artifacts .testbed/.artifacts/qa_live .testbed/.artifacts/validation .testbed/.artifacts/validation_ui`
  - `git status --short --ignored .testbed/.artifacts`
- What passed in the retry:
  - Repo-local deterministic validation still passed end-to-end after the search fix.
  - Live provider search now succeeds through the Godot package seam and direct provider reproduction. The live Godot harness returned `LIVE_SEARCH_COUNT=12`, and direct `curl` to `order=Relevance` returned HTTP 200 with 12 docs for `fitbeat`.
  - Latest/detail/download staging did not regress. The live harness still resolved latest map `524BB`, fetched populated detail metadata for uploader `Comyute`, and staged a real ZIP plus `source_material_manifest.json` under `.testbed/.artifacts/qa_live/524bb/41921e46fa7b4b0d28085401af6a603bcae6f040/`.
  - The staged manifest remained sane on the live artifact: `Info.dat` present, one audio file detected, three difficulty files detected, and six archive entries reported.
  - `.testbed/.artifacts/` remains gitignored/local-only. `git check-ignore -v` still resolves to `.gitignore:33:.testbed/.artifacts/`, and `git status --short --ignored .testbed/.artifacts` still reports only `!! .testbed/.artifacts/`.
- QA retry disposition:
  - **Ready for independent audit.** The concrete live search blocker is resolved and the latest/detail/download/staging seams remained healthy on rerun.
  - Residual risk is limited to manual visual polish/live interaction details that were not fully screen-verified under Wayland capture restrictions (remote cover-image timing, card/detail layout feel, CTA ergonomics), not to the provider contract or artifact-staging seam.
- Independent audit on 2026-06-23:
  - Verified repo boundary against `REF-01`, `REF-06`, `REF-07`, `REF-08`, and `REF-10` by inspecting `README.md`, `src/`, and `.testbed/`. The published code stays on the provider side: request building, HTTP transport, response parsing, selected-version ZIP staging, archive inspection, manifest emission, and proving UX. No `plugin.cfg` exists, and no Boxing/Flow conversion, `workout.yaml` generation, or AeroBeat runtime semantics were added.
  - Verified the hidden testbed contract is present and wired correctly: `.testbed/addons.jsonc` mounts this repo from `..` with only `aerobeat-tool-headless-manager` and `aerobeat-vendor-godot-unit-test`; `.testbed/project.godot` boots the hidden browser scene; the scene/scripts expose the expected result-card -> detail-panel -> version-select -> download-CTA flow; and the facade method used by the CTA is `stage_selected_version_artifact(...)`.
  - Verified `.testbed/.artifacts/` remains local-only through `.gitignore` plus direct `git check-ignore -v` / `git status --short --ignored .testbed/.artifacts` spot checks.
  - Verified the search compatibility fix is really present in code and tests: `src/models/beatsaver_search_query.gd` now emits `order=<TitleCase enum>` and `.testbed/scripts/validate_beatsaver_client_slice.gd` explicitly asserts `order=Latest` and the absence of legacy `sortOrder`.
  - Verified current validation evidence is credible: `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd` passed during audit, and direct provider reproduction of `https://api.beatsaver.com/search/text/0?q=fitbeat&pageSize=12&order=Relevance` returned HTTP 200 with 12 docs.
  - Verified published repo state / commits make sense for the implementation slice: `origin/main` is at `0afb9c9`, with the expected seam commits `693a647`, `bb2f103`, `dfbb5a6`, and `0afb9c9` in order.
  - Exact completion gap at audit time was Task 6 / bead `openclaw-pico-bpm` still being marked pending in markdown + Beads even though Derrick had already decided conversion belongs in a future separate repo. That gap is now resolved by explicitly descoping conversion out of this repo and fixing the plan to stop at provider records + staged source-material manifests.

---

### Task 8: Fix human-review UI layout defect and re-verify live CTA download

**Bead ID:** `openclaw-pico-2kg`  
**SubAgent:** `primary` (for `coder` then `qa`)  
**Role:** `coder` / `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Derrick's screenshot review found that the center results panel is not laying out correctly: thumbnails and names are collapsed into vertical slivers along the left side of the results region instead of rendering as readable cards. Fix the result-card layout/rendering in the hidden `.testbed` browser, then rerun a truthful verification that the CTA download button still fetches a real BeatSaver package and writes the ZIP + manifest into `/.testbed/.artifacts/`. Keep scope narrow: layout/rendering correction plus end-to-end download verification only.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/.artifacts/` (runtime verification only)

**Files Created/Deleted/Modified:**
- `.testbed/scenes/beatsaver_browser_testbed.tscn`
- `.testbed/scenes/beatsaver_result_card.tscn`
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_result_card.gd`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `.plans/2026-06-23-aerobeat-vendor-beatsaver-repo-plan.md`

**Status:** ✅ Complete

**Results:** Human screenshot feedback reproduced a narrow but real layout bug in the hidden `.testbed` browser: the center results grid was hard-coded to `columns = 2` while each `BeatSaverResultCard` advertised effectively zero minimum width (`custom_minimum_size.x = 0`). When the right-side detail panel reduced the available center-pane width, Godot's `GridContainer` compressed the cards to tiny widths, which forced the title/subtitle labels to wrap one character per line and made the thumbnail/name content appear as vertical slivers along the left edge of the panel.

The fix stayed strictly inside the result-card layout seam and preserved the existing detail panel + CTA flow:
- `.testbed/scenes/beatsaver_result_card.tscn` now gives each card a real minimum footprint (`Vector2(280, 248)`) and horizontal expand/fill flags so the grid cannot collapse a card into a near-zero-width strip.
- `.testbed/scenes/beatsaver_browser_testbed.tscn` now lets the `ResultsScroll` expand horizontally with the pane.
- `.testbed/scripts/beatsaver_browser_testbed.gd` now computes an adaptive `ResultsGrid.columns` value from the live scroll width, clamped to `1..2`. That preserves the intended two-column browse layout when space is available while automatically dropping to one readable column when the detail panel or window width would otherwise crush the cards.
- `.testbed/scripts/validate_beatsaver_client_slice.gd` now asserts the layout contract directly: bounded adaptive column count, card minimum width >= 280 px, and rendered card width >= 260 px both before and after the detail panel opens.

Deterministic validation rerun after the fix:
- `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`
- Result: **passed**.

Truthful live provider verification rerun after the fix:
- `godot --headless --path .testbed -s /home/derrick/.openclaw/workspace/.temp/beatsaver_live_qa.gd`
- Result: **passed**.
- Live evidence captured from the run:
  - `LIVE_SEARCH_COUNT=12`
  - `LIVE_LATEST_FIRST_ID=524B6`
  - `LIVE_DETAIL_HASH=e93accd8cfd9265c80141cead1c74dea2faf70ec`
  - `LIVE_ARCHIVE_ENTRY_COUNT=8`
  - `LIVE_INFO_DAT_PATH=Info.dat`
  - `LIVE_AUDIO_FILE_COUNT=1`
  - `LIVE_DIFFICULTY_FILE_COUNT=4`
  - real ZIP written to `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/.artifacts/qa_live/524b6/e93accd8cfd9265c80141cead1c74dea2faf70ec/524b6-e93accd8cfd9.zip`
  - manifest written to `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/.artifacts/qa_live/524b6/e93accd8cfd9265c80141cead1c74dea2faf70ec/source_material_manifest.json`
- `.testbed/.artifacts/` remained local-only during the rerun: `git check-ignore -v .testbed/.artifacts .testbed/.artifacts/qa_live` resolved to `.gitignore:33:.testbed/.artifacts/`, and `git status --short --ignored .testbed/.artifacts` still reported only `!! .testbed/.artifacts/`.

QA closeout note for the orchestrator/auditor: the concrete human-review UI defect is fixed, deterministic validation now guards against the sliver regression, and truthful live search/latest/detail/download staging still passes through the same CTA seam after the layout change. This repo should now be considered ready for final QA/audit closeout rather than blocked on additional coder work.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** A new `aerobeat-vendor-beatsaver` support package scaffold plus four completed seams: (1) a read-only BeatSaver client for search/detail/latest metadata, (2) an artifact-acquisition seam that stages selected version ZIPs into `.testbed/.artifacts/`, inspects archive contents, and emits normalized source-material manifests for downstream future-repo conversion work, (3) a hidden `.testbed` proving browser that exercises search/latest/detail/filtering/version-selection/download staging against that seam, and (4) a final human-review layout fix that keeps the center results grid readable while preserving the CTA-driven live download path. QA originally found a real live-provider search failure; coder follow-up patched the search request shape to match the current provider contract (`order=<TitleCase enum>` instead of legacy `sortOrder=<lowercase>`), and the retry QA pass confirmed live search/latest/detail/download staging all passed again. Independent audit confirmed the implemented repo slice is boundary-correct, and Derrick's final screenshot review approved the corrected UI layout before closeout.

**Reference Check:**
- `REF-01` reviewed for concrete BeatSaver endpoint coverage and payload fields.
- `REF-02` to `REF-05` reviewed for current AeroBeat repo/testbed/package layout conventions.
- `REF-06` reviewed for current AeroBeat durable content ownership boundaries.
- `REF-07` to `REF-10` reviewed for current vendor/tool/public-contract precedents inside the AeroBeat polyrepo.

**Commits:**
- `da7cea7` - Add initial BeatSaver client seam
- `bb2f103` - Add BeatSaver artifact staging seam
- `dfbb5a6` - Add BeatSaver proving testbed browser
- `0afb9c9` - Fix BeatSaver search query compatibility

**Lessons Learned:**
- BeatSaver already exposes a rich enough provider surface that this repo can stay narrow: provider reads, selected ZIP acquisition, and normalized staging are enough for the first useful slice.
- The cleanest architecture is `BeatSaver vendor repo -> staged source-material manifest -> downstream AeroBeat importer/converter/tooling`, not a monolith that also owns Boxing/Flow conversion.
- The target repo should be created before the plan migrates there; until then, the coordination plan belongs in `openclaw-pico`.
- A premature `plugin.cfg`/singleton would teach the wrong dependency pattern. First slice should stay a plain support package unless a later consumer seam proves a stable public facade is worth shipping.
- Human screenshot review matters even after headless QA/audit: the result-card sliver bug only surfaced clearly once Derrick inspected the rendered scene on mobile, and the final closeout now includes explicit screenshot approval plus a re-verification of the live CTA download path.

---

*Completed on 2026-06-23*