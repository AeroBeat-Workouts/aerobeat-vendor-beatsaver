# AeroBeat Vendor BeatSaver Testbed Download / Convert / Preview

**Date:** 2026-07-21  
**Status:** In Progress  
**Last Updated:** 2026-07-21 12:20 EDT  
**Blocked Reason:** None  
**Agent:** `pico`

---

## Goal

Extend the hidden `aerobeat-vendor-beatsaver` `.testbed/` so it can stage a selected BeatSaver package, convert it into local AeroBeat package output for inspection, and preview audio from the best available source before or after download.

---

## Overview

The BeatSaver compatibility lane is now in a good place for Standard charts across the supported BeatSaver version range, including legacy v1/v2 with truthful bounds. The next useful seam is not gameplay yet — it is a proving/workbench seam in `aerobeat-vendor-beatsaver` so we can browse real BeatSaver content, download a selected package, run it through the existing authoring conversion flow, inspect the resulting AeroBeat package output, and quickly catch conversion errors without entering gameplay.

This repo owns the provider-facing browse/stage/testbed workflow, so it is the right home for the hidden operator UI that triggers download and conversion. The actual Boxing/Flow conversion logic must remain in `aerobeat-tool-content-authoring`; this repo should call into that downstream seam rather than duplicating conversion logic. The preview button belongs in the existing selected-song side panel because it is a source-browsing/testing affordance: before local download it should use the provider-exposed preview URL, and after local conversion/staging it should prefer the local preview/source audio truth instead of the web URL.

The existing bottom action in that same side panel should own the operator lifecycle for the selected package. Before local package output exists, it should read `Download` and trigger the full download -> stage -> convert -> inspect workflow. While work is in flight, that same control should stay disabled and reflect the latest package state text instead of remaining static: `0%` during active download progress, then `Staging`, then `Converting`. After local package output exists, the control should switch to `Inspect`, re-enable itself, and open the system file explorer directly to the converted package on disk. If the local package is later deleted and the song is selected again, the control should truthfully fall back to `Download` so the workflow can be retried and duplicate-request behavior can be exercised across download -> delete -> download cycles.

Because the panel can be closed and reopened during long-running work, the hidden testbed needs package-scoped persisted demo state for the selected BeatSaver version/package so the UI can restore and reflect the latest known operator phase on reselection rather than resetting visually.

We should also keep the non-Standard/accessibility discussion explicitly out of this slice. This plan is about proving the current Standard-only import lane end-to-end in the testbed and making preview plus inspect behavior truthful, not expanding the supported BeatSaver characteristic set.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | BeatSaver vendor repo boundary and current testbed scope | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/README.md` |
| `REF-02` | Current hidden testbed scene | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scenes/beatsaver_browser_testbed.tscn` |
| `REF-03` | Current hidden testbed state/controller | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_testbed_state.gd` |
| `REF-04` | Current hidden testbed UI driver | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_browser_testbed.gd` |
| `REF-05` | Vendor staging/acquisition facade | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/src/facade/beatsaver_vendor_facade.gd` |
| `REF-06` | Current BeatSaver converter truth and supported Standard-version range | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-content-authoring/.plans/archive/2026-07-21-beatsaver-legacy-v1-v2-normalization.md` |
| `REF-07` | Current converter docs | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-content-authoring/src/docs/beatsaver-converter-foundation.md` |

---

## Tasks

### Task 1: Add testbed side-panel download -> convert -> inspect flow

**Bead ID:** `aerobeat-vendor-beatsaver-7v1`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, extend the hidden `.testbed/` so a selected BeatSaver package version can be downloaded/staged and then converted into local AeroBeat package output for inspection, without moving conversion ownership out of `aerobeat-tool-content-authoring`. Claim the bead on start, keep conversion logic delegated to the existing downstream seam, and wire the existing selected-song side-panel bottom action so it reflects the package lifecycle with these exact operator states: `Download` when not downloaded yet, `0%`/progress percentage during active download, `Staging` during staging, `Converting` during conversion, and `Inspect` once ready for inspection. The button must stay disabled during the in-flight states and re-enable only at `Inspect`. When local package output exists, `Inspect` must open the system file explorer directly to the converted package on disk. If the converted package is deleted and the song is selected again, the control must truthfully fall back to `Download` so retry flows can be exercised. Persist package-scoped demo state so closing/reopening the side panel or reselecting the song restores the latest known state instead of resetting visually. Add the smallest truthful UI/state/output surfacing needed to inspect results/errors, and update validation coverage/docs as needed. Do not widen into gameplay or non-Standard characteristic support.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`
- `src/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/beatsaver_browser_testbed.tscn`
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- `src/facade/beatsaver_vendor_facade.gd`
- validation/tests/docs as needed

**Status:** ✅ Complete

**Results:** Coder completed the hidden `.testbed` selected-song side-panel workflow and left bead `aerobeat-vendor-beatsaver-7v1` open for QA. The bottom action now owns the package lifecycle with the exact UI states `Download`, download progress like `0%`, `Staging`, `Converting`, and `Inspect`; it stays disabled during in-flight states and re-enables only at `Inspect`. Before local output exists, pressing it runs the full download -> stage -> convert -> inspect flow; after local output exists, `Inspect` opens the converted package directory in the system file explorer; if the local package is deleted and the song is reselected, state falls back to `Download`. Package-scoped persisted demo state was added so reselecting/restoring the panel keeps the latest known package state. The implementation stayed bounded to the hidden operator workflow. Vendor repo commit: `585fd191e1330ffa6cacbb3ad0bcf0d8b55a316e` (`Add testbed package lifecycle and preview workflow`). A required downstream dependency fix was also landed in `aerobeat-tool-content-authoring` so the real conversion seam could load under strict Godot warnings-as-errors: `dc4b9aec2e621539ccffa8ad85ee340b24d2e4c0` (`Fix converter typing warnings under strict Godot compile`). After QA found one real preview-truth gap on delete -> reselect, coder retried the same bead and fixed it by preserving the BeatSaver version preview URL in the staged source manifest (`src/acquisition/beatsaver_stage_manifest_builder.gd`, `src/models/beatsaver_source_package_manifest.gd`). The strengthened validation now explicitly checks convert -> delete local package output -> reselect map -> preview falls back to `remote_preview_url`. Retry commit pushed: `58a16ac` (`Restore BeatSaver remote preview fallback truth`). Evidence from the newest staged bridge manifest now includes `preview_url`, and the converted song yaml contains `previewUrl` plus `previewMode: preview_url`.

---

### Task 2: Add truthful side-panel preview behavior before/after download

**Bead ID:** `aerobeat-vendor-beatsaver-7v1`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Extend the same hidden `.testbed/` side panel with a preview action. Before a package is downloaded, preview should use the provider-exposed web preview URL. After the package is downloaded/converted locally, preview should prefer the local preview/source audio truth instead of the remote URL. The preview control should coexist with the persisted package-state UI so reopening/reselecting a song continues to reflect the latest package lifecycle state alongside the appropriate preview source choice. Keep the seam narrowly focused on truthful source selection and operator testing; do not turn this into a gameplay or polished product-audio UX slice.

**Folders Created/Deleted/Modified:**
- `.testbed/scenes/`
- `.testbed/scripts/`
- `.testbed/tests/`

**Files Created/Deleted/Modified:**
- `.testbed/scenes/beatsaver_browser_testbed.tscn`
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- preview-related tests/docs as needed

**Status:** ✅ Complete

**Results:** The same coder bead landed the preview behavior in the side panel. Before download, preview uses the provider preview URL; after local download/conversion, it prefers local preview audio and then local source audio. Validation now explicitly covers preview fallback from remote -> local and keeps that choice aligned with the persisted package-state UI when the panel is reopened or the song is reselected.

---

### Task 3: QA the hidden BeatSaver testbed operator flow

**Bead ID:** `aerobeat-vendor-beatsaver-gai`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`, `REF-07`  
**Prompt:** Verify at the highest-fidelity repo-local level available that the hidden BeatSaver testbed can browse, stage, convert, inspect, and preview truthfully. Confirm download -> convert uses the downstream authoring seam instead of duplicating conversion logic, confirm preview chooses remote-before-download and local-after-download, and confirm the testbed surfaces failures honestly. Do not self-implement missing work; report exact evidence and whether the slice is ready for audit.

**Folders Created/Deleted/Modified:**
- verification-only if needed

**Files Created/Deleted/Modified:**
- verification notes only if needed

**Status:** ✅ Complete

**Results:** QA rerun passed and bead `aerobeat-vendor-beatsaver-gai` was force-closed after verification because Beads blocked normal closure while implementation bead `aerobeat-vendor-beatsaver-7v1` remained open for audit. Re-ran strongest repo-local deterministic validation with `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`; result: passed. The validator now explicitly covers fresh selection starting at `Download`, remote preview before download, workflow delegation through download -> stage -> convert -> inspect, CTA ending at `Inspect` and re-enabling there, local preview being preferred after conversion, CTA fallback back to `Download` after deleting local package output and reselecting, and preview fallback back to `remote_preview_url` after delete/reselect. QA also confirmed downstream seam reuse: the vendor testbed still calls `AeroContentAuthoring.convert_beatsaver_stage_to_current_package()` and `save_current_package()` in `aerobeat-tool-content-authoring` rather than duplicating conversion logic locally. Artifact inspection confirmed the manifest builder now writes preview URL truth and the produced bridge artifact preserves it in `.testbed/.artifacts/validation_ui/bridge/461fa/0de1befdfe30639c8b0feb6c32db948628690b0e/source_material_manifest.json`. Slice is now ready for audit.

---

### Task 4: Audit the hidden BeatSaver testbed operator flow

**Bead ID:** `aerobeat-vendor-beatsaver-4iy`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Independently audit the hidden BeatSaver testbed download/convert/preview seam against the approved scope, docs, diffs, validation evidence, and produced outputs. Confirm it stayed bounded to the operator/proving workflow, preserved repo boundaries, and remained truthful about source selection and conversion results. If it passes, close the relevant bead(s); if it fails, report the exact gap.

**Folders Created/Deleted/Modified:**
- audit-only if needed

**Files Created/Deleted/Modified:**
- audit notes only if needed

**Status:** ✅ Complete

**Results:** Audit passed. Independent verification re-ran `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd` successfully, confirmed the scope stayed bounded to the hidden operator/proving workflow in `.testbed`/README rather than gameplay or product UX, and confirmed the vendor repo still reuses downstream authoring via `ContentAuthoringBridge -> convert_beatsaver_stage_to_current_package()` and `save_current_package()` from `aerobeat-tool-content-authoring` rather than duplicating conversion logic. Audit also confirmed exact CTA lifecycle truth in state/UI (`Download` -> progress `%` -> `Staging` -> `Converting` -> `Inspect`) with correct disabled/enabled behavior, `Inspect` opening the local converted package directory, and preview-source truth across all required transitions: remote before download, local after download/convert, and remote again after deleting local package output and reselecting. Artifact checks confirmed `.testbed/.artifacts/validation_ui/bridge/.../source_material_manifest.json` now contains `preview_url`, and the produced authored song YAML preserves `previewUrl` plus `previewMode: preview_url`. Audit bead `aerobeat-vendor-beatsaver-4iy` and implementation bead `aerobeat-vendor-beatsaver-7v1` were both closed.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Completed the hidden `aerobeat-vendor-beatsaver` operator testbed seam for browsing, staging, converting, inspecting, and previewing BeatSaver packages through the existing downstream authoring flow. The selected-song side panel now truthfully drives the package lifecycle with exact operator states (`Download`, progress `%`, `Staging`, `Converting`, `Inspect`), opens the converted package directory at `Inspect`, persists package-scoped state across panel close/reopen, and preserves preview-source truth across remote-before-download, local-after-conversion, and remote-again-after-delete/reselect.

**Reference Check:** `REF-01`..`REF-07` satisfied. The repo boundary stayed clean: this vendor seam remained the browse/stage/testbed operator surface while delegating actual AeroBeat conversion to `aerobeat-tool-content-authoring`. The preview-fallback retry closed the only real QA gap without widening scope.

**Commits:**
- `585fd191e1330ffa6cacbb3ad0bcf0d8b55a316e` - Add testbed package lifecycle and preview workflow
- `58a16ac` - Restore BeatSaver remote preview fallback truth
- `dc4b9aec2e621539ccffa8ad85ee340b24d2e4c0` - Fix converter typing warnings under strict Godot compile

**Lessons Learned:** The operator proof surface paid off: live workflow testing caught a real source-truth bug that deterministic coverage alone had initially missed. Keeping the seam bounded made the fix surgical — preserve preview URL truth through the stage/bridge chain instead of rethinking the whole UI or conversion architecture.

---

*Started on 2026-07-21*
