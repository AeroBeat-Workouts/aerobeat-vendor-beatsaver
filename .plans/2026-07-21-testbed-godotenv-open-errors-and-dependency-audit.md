# AeroBeat Vendor BeatSaver Testbed GodotEnv Open Errors and Dependency Audit

**Date:** 2026-07-21  
**Status:** In Progress  
**Last Updated:** 2026-07-21 17:15 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Confirm whether `aerobeat-vendor-beatsaver` is fully committed/pushed, verify the `.testbed` GodotEnv dependency shape needed for the intended BeatSaver -> AeroBeat conversion/preview workflow, and fix the project-open parse errors so the hidden testbed opens cleanly.

---

## Overview

Derrick reported that after syncing the repo and refreshing dependencies, opening `aerobeat-vendor-beatsaver/.testbed` produced `class_name hides a global script class` parse errors for several BeatSaver source classes. Derrick also noted that the expected addons for fully exercising the BeatSaver conversion pipeline and preview-audio flow do not appear present in the project, raising the question of whether the previous session’s changes were actually committed/pushed or whether the GodotEnv dependency shape is incomplete.

Initial truth check already establishes two important facts. First, the repo itself is currently clean and aligned to `origin/main` at `0bc414e`, so this is not a simple “forgot to commit/push” situation. Second, the hidden testbed currently mounts `aerobeat-vendor-beatsaver` as a self-dependency in `.testbed/addons.jsonc` while the testbed scripts also directly preload repo-root scripts through `res://../src/...`; that creates two visible import paths for the same `class_name` declarations and matches Derrick’s exact parse errors. In parallel, the testbed currently references `../../aerobeat-tool-content-authoring/...` directly for conversion services instead of mounting that repo as a GodotEnv dependency, which explains why the clean consumer-style addon set is incomplete for the prior conversion/preview goal.

This plan keeps the lane narrow and truthful: first audit and document the exact repo/dependency/open-state truth, then repair the hidden testbed’s dependency/import structure in the owning repo, then verify the project opens without those log errors and that the required conversion/preview dependencies are actually present in consumer-style addon form.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Derrick’s reported `.testbed` parse errors and missing-addon concern | This chat message on 2026-07-21 16:45 EDT |
| `REF-02` | BeatSaver repo launch memory confirming the repo was built and pushed on 2026-06-23 | `memory/2026-06-23.md#L1-L9` |
| `REF-03` | Current hidden testbed addon manifest showing self-dependency and current mounted dependencies | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/addons.jsonc` |
| `REF-04` | Current hidden testbed scripts that preload repo-root `../src` paths and direct cross-repo conversion services | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_browser_testbed.gd` |
| `REF-05` | Current hidden testbed scripts that preload repo-root `../src` paths and direct cross-repo conversion services | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_result_card.gd` |
| `REF-06` | Current hidden testbed scripts that preload repo-root `../src` paths and direct cross-repo conversion services | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_testbed_state.gd` |

---

## Tasks

### Task 1: Audit commit/push truth, dependency shape, and project-open error source

**Bead ID:** `aerobeat-vendor-beatsaver-lx5`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, audit the current truth for the hidden `.testbed` failure Derrick reported. Confirm whether the repo is committed/pushed, inspect the GodotEnv dependency shape, explain the exact root cause of the `class_name hides a global script class` errors, and identify which dependencies are actually missing for the previous conversion/preview goal. Update the plan with exact findings and recommend the narrowest truthful fix path.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/2026-07-21-testbed-godotenv-open-errors-and-dependency-audit.md`

**Status:** ✅ Complete

**Results:** Audit completed before execution handoff. Repo truth: `main` is clean and aligned to `origin/main` at `0bc414e`, so this is not a missing commit/push problem. The reported `class_name hides a global script class` failures are explained by hidden `.testbed` architecture drift: `.testbed/addons.jsonc` mounts `aerobeat-vendor-beatsaver` as a self-dependency while the hidden testbed scripts also preload repo-root `res://../src/...` paths for the same classes, creating duplicate visible import paths for `BeatSaverMapDetail`, `BeatSaverVersionRef`, `BeatSaverVendorFacade`, and `BeatSaverSearchQuery`. The prior conversion/preview workflow goal is also incomplete as GodotEnv consumer truth because `beatsaver_testbed_state.gd` directly loads `../../aerobeat-tool-content-authoring/...` service scripts instead of consuming that repo through a mounted dependency. A coder subagent has now been launched against beads `aerobeat-vendor-beatsaver-fu9` and `aerobeat-vendor-beatsaver-1r8` to repair the hidden-testbed import architecture and materialize the required GodotEnv dependency shape.

---

### Task 2: Repair hidden testbed dependency/import structure for clean consumer-style loading

**Bead ID:** `aerobeat-vendor-beatsaver-fu9`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** In the owning repo, repair the hidden `.testbed` dependency/import shape so the project does not load the same BeatSaver classes both from repo-root `../src` and from the mounted addon copy. Keep the fix consumer-truthful for GodotEnv-managed workbenches, and preserve the intended hidden-testbed workflow instead of patching generated addon output directly.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.testbed/addons.jsonc`
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_result_card.gd`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `src/acquisition/beatsaver_package_fetcher.gd`
- `src/acquisition/beatsaver_stage_manifest_builder.gd`
- `src/client/beatsaver_request_builder.gd`
- `src/client/beatsaver_response_parser.gd`
- `src/facade/beatsaver_vendor_facade.gd`
- `src/models/beatsaver_map_detail.gd`
- `src/models/beatsaver_version_ref.gd`
- this plan file

**Status:** ✅ Complete

**Results:** Repaired the hidden testbed so it now consumes BeatSaver code through the mounted addon surface instead of mixing repo-root `res://../src/...` imports with `.testbed/addons/aerobeat-vendor-beatsaver/...`. The first pass only changed hidden testbed imports, which exposed a deeper truth: the owning repo’s own source scripts still used absolute self-imports like `res://../src/...`, so loading the addon from `res://addons/aerobeat-vendor-beatsaver/...` created distinct class identities and failed typed calls. The durable fix was to convert those repo-owned source preloads to script-local relative paths, which makes the addon truthful both at repo root and when mounted as a GodotEnv dependency. After that change, `godot --headless --path .testbed --quit-after 3` opened cleanly with no reported parse/type errors, and the hidden validation script passed end-to-end.

---

### Task 3: Add/repair required conversion-preview dependencies for the prior workflow goal

**Bead ID:** `aerobeat-vendor-beatsaver-1r8`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-06`  
**Prompt:** Materialize the missing GodotEnv dependency shape required for the previous BeatSaver testbed conversion/preview goal, so the hidden `.testbed` can access the necessary conversion/package workflow services through mounted dependencies rather than brittle direct sibling paths. Keep scope tightly bounded to the missing dependency lane and any minimal import-path updates required.

**Folders Created/Deleted/Modified:**
- `.testbed/`

**Files Created/Deleted/Modified:**
- `.testbed/addons.jsonc`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- this plan file

**Status:** ✅ Complete

**Results:** Added `aerobeat-tool-content-authoring` to `.testbed/addons.jsonc` as a repo-root symlink-backed GodotEnv dependency and rewired the hidden testbed bridge to load `BeatSaverStageConversionService` and `SongPackageWorkflowService` from `res://addons/aerobeat-tool-content-authoring/...` instead of brittle sibling-repo paths under `../../aerobeat-tool-content-authoring/...`. Ran the canonical sync flow with `python3 /home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed`, which installed the required addon and left `.testbed/addons/aerobeat-tool-content-authoring` present as a symlink-backed mounted dependency.

---

### Task 4: QA project-open truth and required dependency presence

**Bead ID:** `aerobeat-vendor-beatsaver-52g`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Verify at the highest-fidelity repo-local level available that the hidden `.testbed` now opens without the reported parse/log errors, that the required conversion/preview dependencies are present in consumer-style addon form, and that the testbed no longer depends on duplicate class-loading paths.

**Folders Created/Deleted/Modified:**
- `.testbed/`

**Files Created/Deleted/Modified:**
- this plan file

**Status:** ✅ Complete

**Results:** Repo-local coder validation completed. Verification runs:
1. `python3 /home/derrick/.openclaw/workspace/scripts/godotenv-sync --repo /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed`
2. `godot --headless --path .testbed --quit-after 3`
3. `godot --headless --path .testbed --script res://scripts/validate_beatsaver_client_slice.gd`

Observed truth: after the source-import fix, the hidden `.testbed` project opened without the previously reported BeatSaver parse/type failures, the validation script printed `BeatSaver client/testbed validation passed.`, and `.testbed/addons/` now includes both `aerobeat-vendor-beatsaver` and `aerobeat-tool-content-authoring` as mounted dependencies. Family-wide duplicate scan remains non-blocking elsewhere: `scan-godot-class-names --repo aerobeat` reported `severity counts: blocker: 0, warn_embedded_overlap: 0, warn_root_nonruntime: 0, info_hidden_testbed: 21`.

---

### Task 5: Audit final repo/dependency/open-state truth

**Bead ID:** `aerobeat-vendor-beatsaver-3yh`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Independently audit the final repo state against Derrick’s report and the repaired hidden `.testbed` dependency shape. Confirm commit/push truth, confirm the parse-error root cause was actually removed, and confirm the project-open/dependency state is truthful rather than papered over.

**Folders Created/Deleted/Modified:**
- audit-only if needed

**Files Created/Deleted/Modified:**
- audit notes only if needed
- this plan file

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial (coder complete; QA/audit still pending)

**What We Built:** The hidden BeatSaver testbed now consumes both the BeatSaver addon and the content-authoring conversion bridge through mounted GodotEnv dependencies. Durable repo-owned source imports were normalized to script-local relative preloads so the addon can be loaded truthfully from either repo root or `res://addons/...` without creating duplicate class identities.

**Reference Check:** `REF-01` is satisfied at coder-validation level: the prior hidden-testbed open failure was reproduced as dependency/import-shape drift and removed by the fix. `REF-03` through `REF-06` are updated accordingly. `REF-02` remains true: this was never a missing-push problem. Remaining caveat: this plan is now accurate through coder completion, but independent QA/auditor stages still need to sign off before archival.

**Commits:**
- `95b3e8c` - `Fix BeatSaver testbed GodotEnv imports`

**Lessons Learned:** Hidden `.testbed` workbenches are only consumer-truthful when both sides agree: the workbench must import the mounted addon surface, and the source addon itself must avoid hard-coded repo-root self-imports like `res://../src/...` that fracture class identity when mounted.

---

*Started on 2026-07-21*