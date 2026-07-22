# AeroBeat Vendor BeatSaver Testbed Warning Cleanup

**Date:** 2026-07-21
**Status:** Complete
**Last Updated:** 2026-07-22 09:44 EDT
**Blocked Reason:** None
**Agent:** `pico`

---

## Goal

Remove the remaining `.testbed` warnings reported by Derrick when opening the BeatSaver project test scene, and stop the download-time warning pair from spamming the console indefinitely.

---

## Overview

This is a follow-up seam in the owning repo `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`. The previous July 21 lane already fixed the hidden `.testbed` GodotEnv import architecture so the workbench opens as a truthful consumer-style addon project. Derrick's new feedback establishes that the project is past the earlier parse-error stage but still emits a set of startup warnings, and that two warnings in `beatsaver_remote_image.gd` loop forever when the testbed attempts to download a song.

The work should stay narrowly scoped to warning truth. First reproduce and classify the current warnings against the actual `.testbed` scene/runtime path. Then repair the startup warnings in the owning source rather than silencing them superficially. After that, repair the download-time loop so image/request failures do not create infinite console churn. Finally, run independent QA and audit before calling the slice done.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Derrick's screenshot and report of current startup warnings plus infinite download-time warning loop | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/07/22/image-31dcdda9.png` |
| `REF-02` | Prior hidden testbed import/dependency cleanup plan completed on 2026-07-21 | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/archive/2026-07-21-testbed-godotenv-open-errors-and-dependency-audit.md` |
| `REF-03` | Hidden testbed project root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/project.godot` |
| `REF-04` | Hidden testbed runtime scene | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scenes/beatsaver_browser_testbed.tscn` |
| `REF-05` | Hidden testbed remote image script named directly in the looping warnings | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_remote_image.gd` |
| `REF-06` | Hidden testbed state/orchestration script likely involved in download flow | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_testbed_state.gd` |
| `REF-07` | Hidden testbed browser scene script likely involved in startup warnings | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_browser_testbed.gd` |
| `REF-08` | Hidden testbed result-card script likely involved in startup warnings | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_result_card.gd` |

---

## Tasks

### Task 1: Audit and reproduce the current warning set

**Bead ID:** `aerobeat-vendor-beatsaver-e2n`
**SubAgent:** `primary` (for `research`)
**Role:** `research`
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, claim bead `aerobeat-vendor-beatsaver-e2n`, reproduce the current `.testbed` warning set from Derrick's screenshot, classify which warnings are startup-only versus download-loop, identify the exact source lines/files, and leave a concrete fix map for the implementation lane. Use repo-local validation only; do not close over ambiguity. Claim the bead at start with `bd update aerobeat-vendor-beatsaver-e2n --status in_progress --json` and close it on completion with `bd close aerobeat-vendor-beatsaver-e2n --reason "Audited and reproduced current warning set" --json`.

**Folders Created/Deleted/Modified:**
- `.plans/`

**Files Created/Deleted/Modified:**
- `.plans/2026-07-21-testbed-warning-cleanup.md`

**Status:** ✅ Complete

**Results:** Reproduced the current warning set against the hidden `.testbed` sources and Derrick’s screenshot (`REF-01`). Repo-local checks used: `godot --headless --path .testbed --quit-after 3`, `godot --path .testbed --quit-after 3`, and static source/line audit with `nl -ba` + `rg -n`. Important truth: the startup warning block in the screenshot is an editor/script-reload warning set, so it does not re-emit under the headless runner even though the same source lines still map to the same warnings. The runtime/download-loop pair is executable behavior centered on `BeatSaverRemoteImage.set_image_url()` and is amplified by the current rerender strategy.

Exact warning map:
- **Startup-only / script-reload warnings**
  - Duplicate constant vs global class name: `.testbed/scripts/beatsaver_result_card.gd:4` declares `const BeatSaverMapDetail = preload(...)` while `src/models/beatsaver_map_detail.gd:1` already exports `class_name BeatSaverMapDetail`.
  - Duplicate constant vs global class name: `.testbed/scripts/beatsaver_browser_testbed.gd:4` declares `const BeatSaverVendorFacade = preload(...)` while `src/facade/beatsaver_vendor_facade.gd:1` already exports `class_name BeatSaverVendorFacade`.
  - Duplicate constant vs global class name: `.testbed/scripts/beatsaver_testbed_state.gd:4` declares `const BeatSaverVendorFacade = preload(...)` while `src/facade/beatsaver_vendor_facade.gd:1` already exports `class_name BeatSaverVendorFacade`.
  - Duplicate constant vs global class name: `.testbed/scripts/beatsaver_testbed_state.gd:5` declares `const BeatSaverSearchQuery = preload(...)` while `src/models/beatsaver_search_query.gd:1` already exports `class_name BeatSaverSearchQuery`.
  - Duplicate constant vs global class name: `.testbed/scripts/beatsaver_browser_testbed.gd:5` declares `const BeatSaverTestbedState = preload("res://scripts/beatsaver_testbed_state.gd")` while `.testbed/scripts/beatsaver_testbed_state.gd:1` already exports `class_name BeatSaverTestbedState`.
  - Parameter shadowing base `Node.name`: `.testbed/scripts/beatsaver_remote_image.gd:47` in `_extract_header(headers, name)`.
  - Parameter shadowing base `Node.name`: `.testbed/scripts/beatsaver_browser_testbed.gd:216` in `_extract_header(headers, name)`.
  - Integer division warning (first occurrence): `.testbed/scripts/beatsaver_remote_image.gd:76` for `x / 24` inside `int((x / 24) + (y / 24))`.
  - Integer division warning (second occurrence): `.testbed/scripts/beatsaver_remote_image.gd:76` for `y / 24` inside the same expression.
  - Parameter name matches built-in function: `.testbed/scripts/beatsaver_testbed_state.gd:575` in `_build_record_state(..., seed: Dictionary)`.
  - Unused parameter warning: `.testbed/scripts/beatsaver_browser_testbed.gd:300` in `_rebuild_versions(detail: Dictionary)`; `detail` is never read.
- **Runtime / download-loop-amplified warnings**
  - Engine/runtime warning at `.testbed/scripts/beatsaver_remote_image.gd:32` in `set_image_url()`: `_request.request(_current_url)` can surface `Out of resolver queries` when the image URL cannot be resolved/opened.
  - Follow-on script warning at `.testbed/scripts/beatsaver_remote_image.gd:34`: custom `push_warning("Failed to request BeatSaver cover image: %s" % error_string(request_error))`, which becomes `Can't connect` in Derrick’s screenshot.

Loop classification truth:
- The 11 `GDScript::reload` items are startup-only parser/reload warnings.
- The 2 `beatsaver_remote_image.gd` lines are not parser warnings; they are runtime warnings caused by failed cover-image requests.
- The repeating/spam behavior is not in the package downloader itself. It is caused by `.testbed/scripts/beatsaver_browser_testbed.gd:254-260` always calling `_rebuild_results_grid()`, which frees/recreates every result card at `.testbed/scripts/beatsaver_browser_testbed.gd:263-270`. Each new card runs `.testbed/scripts/beatsaver_result_card.gd:20-43`, which calls `cover_image.set_image_url(...)` again, re-entering `.testbed/scripts/beatsaver_remote_image.gd:20-34`. During download attempts, `BeatSaverTestbedState` emits frequent `state_changed` signals from progress/lifecycle paths at `.testbed/scripts/beatsaver_testbed_state.gd:291-305`, `308-321`, `353`, `602-612`, and `614-622`, so the browser rerenders repeatedly and reissues the same failing cover requests.

Narrowest truthful implementation path for the next lane:
1. Remove startup warning causes without changing behavior: rename the duplicate preload constants to non-class names (for example `_beatsaver_vendor_facade_script`, `_beatsaver_search_query_script`, `_beatsaver_map_detail_script`, `_beatsaver_testbed_state_script`) or, where safe, rely directly on the global class names instead of shadowing them.
2. Rename shadowing parameters `name` to `header_name` in both `_extract_header()` helpers; rename `seed` to `seed_record` or similar; either remove the unused `detail` parameter from `_rebuild_versions()` or actually consume it.
3. Make the placeholder checkerboard integer-safe by replacing the silent-truncation pattern at `.testbed/scripts/beatsaver_remote_image.gd:76` with explicit integer math so Godot no longer warns about discarded decimals.
4. Stop the warning spam at the UI layer first: avoid full result-grid teardown on every `state_changed`, or gate image re-requests so `BeatSaverRemoteImage.set_image_url()` is a no-op when the URL did not change and a request/result is already in flight/cached. That is the narrowest fix for the loop multiplier.
5. Then harden `BeatSaverRemoteImage` itself so request failures degrade once per URL/state instead of warning every rerender; if needed, log resolver/connect failures only on transition or cache failure state per URL.

---

### Task 2: Fix startup warnings in the hidden testbed and owning source

**Bead ID:** `aerobeat-vendor-beatsaver-6ok`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-04`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, claim bead `aerobeat-vendor-beatsaver-6ok`, fix the startup warnings reproduced in Task 1 in the owning source/testbed, keep edits narrowly scoped to truthful warning removal, run relevant repo-local validation, commit and push by default when the implementation is ready for QA, and close the bead only when coder work is actually complete. Start with `bd update aerobeat-vendor-beatsaver-6ok --status in_progress --json` and close with `bd close aerobeat-vendor-beatsaver-6ok --reason "Implemented startup warning cleanup" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_remote_image.gd`
- `.testbed/scripts/beatsaver_result_card.gd`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- `.plans/2026-07-21-testbed-warning-cleanup.md`

**Status:** ✅ Complete

**Results:** Implemented the narrowest truthful startup-warning cleanup in the hidden testbed without touching the separate download-loop seam. Exact code changes: removed the duplicate class-shadowing preload constants from `.testbed/scripts/beatsaver_result_card.gd`, `.testbed/scripts/beatsaver_browser_testbed.gd`, and `.testbed/scripts/beatsaver_testbed_state.gd` so those scripts rely on the existing global `class_name` registrations instead; renamed the `_extract_header(..., name)` parameters to `_extract_header(..., header_name)` in `.testbed/scripts/beatsaver_browser_testbed.gd` and `.testbed/scripts/beatsaver_remote_image.gd`; renamed `_build_record_state(..., seed)` to `_build_record_state(..., seed_record)` in `.testbed/scripts/beatsaver_testbed_state.gd`; renamed `_rebuild_versions(detail)` to `_rebuild_versions(_detail)` in `.testbed/scripts/beatsaver_browser_testbed.gd`; and made the placeholder checkerboard math in `.testbed/scripts/beatsaver_remote_image.gd` use explicit `floori(float(...)/24.0)` tile coordinates so the integer-division parser warnings stop cleanly.

Validation run:
- source-truth grep for the Task 1 warning signatures across `.testbed/scripts` / `src`
- `git diff --stat -- .testbed/scripts .plans/2026-07-21-testbed-warning-cleanup.md`
- `godot --headless --path .testbed --quit-after 3`
- `godot --path .testbed --quit-after 3`

Implementation commit for this coder slice: `53e4800` (`Fix BeatSaver testbed startup warnings`).

---

### Task 3: Fix the download-time warning loop

**Bead ID:** `aerobeat-vendor-beatsaver-xe2`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, claim bead `aerobeat-vendor-beatsaver-xe2`, fix the download-triggered infinite warning loop centered on `beatsaver_remote_image.gd` so network/image failures degrade truthfully without spamming the console forever, run relevant repo-local validation, commit and push by default when ready, and close the bead only when coder work is complete. Start with `bd update aerobeat-vendor-beatsaver-xe2 --status in_progress --json` and close with `bd close aerobeat-vendor-beatsaver-xe2 --reason "Implemented download-time warning loop cleanup" --json`.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `src/`

**Files Created/Deleted/Modified:**
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scripts/beatsaver_remote_image.gd`
- `.plans/2026-07-21-testbed-warning-cleanup.md`

**Status:** ✅ Complete

**Results:** Implemented the narrowest runtime-loop fix in the hidden testbed by stopping repeated result-card teardown/recreation during unrelated `state_changed` emissions and by deduping identical remote-image requests/failure warnings. Exact code changes: `.testbed/scripts/beatsaver_browser_testbed.gd` now tracks the visible result ID list and only rebuilds the results grid when that list actually changes; otherwise it updates the existing cards in place so download/progress/status churn no longer recreates cards and re-enters `set_image_url(...)` for every result on every state tick. `.testbed/scripts/beatsaver_remote_image.gd` now short-circuits unchanged URLs when the image is already loaded, already in flight, or already failed in the current state; tracks the in-flight URL separately from the current selection; and emits request/decode warnings once per URL instead of on every rerender.

Validation run:
- `godot --headless --path .testbed --script /tmp/validate_warning_loop.gd`
- `godot --headless --path .testbed --quit-after 3`
- `godot --path .testbed --quit-after 3`

Runtime truth: I did not reproduce Derrick’s exact resolver failure live against BeatSaver itself in this lane, but I did validate the actual loop multiplier locally with a headless Godot harness that instantiates the testbed, emits repeated non-result `state_changed` updates, and proves the result-card node identities stay stable instead of being rebuilt. That source/runtime check covers the rerender trigger identified in Task 1. The remote-image script now also guards the remaining warning path so an identical failed URL does not spam across repeated renders.

Implementation commit for this coder slice: `b4b089c` (`Fix BeatSaver warning loop rerenders`).

---

### Task 4: QA the warning cleanup against the test scene workflow

**Bead ID:** `aerobeat-vendor-beatsaver-t53`
**SubAgent:** `primary` (for `qa`)
**Role:** `qa`
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, claim bead `aerobeat-vendor-beatsaver-t53`, independently verify the startup warnings are gone or intentionally reduced with truthful reasoning, verify the download flow no longer produces an infinite warning loop, rerun the strongest repo-local validation available, and close the bead only if the slice is truly QA-ready. Start with `bd update aerobeat-vendor-beatsaver-t53 --status in_progress --json` and close with `bd close aerobeat-vendor-beatsaver-t53 --reason "QA passed for warning cleanup" --json`.

**Folders Created/Deleted/Modified:**
- validation-only as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-07-21-testbed-warning-cleanup.md`

**Status:** ✅ Complete

**Results:** Independent QA pass against the hidden `.testbed` scene/runtime truth. Exact commands run:
- `bd update aerobeat-vendor-beatsaver-t53 --status in_progress --json`
- `rg -n "const BeatSaverVendorFacade = preload\(|const BeatSaverSearchQuery = preload\(|const BeatSaverMapDetail = preload\(|const BeatSaverTestbedState = preload\(|func _extract_header\(headers: PackedStringArray, name: String\)|func _build_record_state\(version_identifier: String, action: String, progress_percent: int, seed: Dictionary\)|func _rebuild_versions\(detail: Dictionary\)|int\(\(x / 24\) \+ \(y / 24\)\)" .testbed/scripts/beatsaver_browser_testbed.gd .testbed/scripts/beatsaver_remote_image.gd .testbed/scripts/beatsaver_result_card.gd .testbed/scripts/beatsaver_testbed_state.gd`
- `rg -n "header_name|seed_record|_rebuild_versions\(_detail\)|_rendered_result_ids|_failed_request_urls|_failed_decode_urls|set_image_url\(url: String\)" .testbed/scripts/beatsaver_browser_testbed.gd .testbed/scripts/beatsaver_remote_image.gd .testbed/scripts/beatsaver_testbed_state.gd`
- `godot --headless --path .testbed --quit-after 3`
- `godot --path .testbed --quit-after 3`
- `godot --headless --path .testbed --script res://scripts/validate_beatsaver_client_slice.gd`
- `godot --path .testbed --script /tmp/qa_warning_cleanup_check.gd`

Findings:
- The Task 1 startup/editor warning signatures are gone from the target runtime scripts. The targeted `rg` absence check returned no matches for the duplicate preload/class-name shadows, old `name`/`seed`/`detail` warning signatures, or the old integer-division expression. The follow-up shape check confirms the intended replacements are present: `header_name`, `seed_record`, `_rebuild_versions(_detail)`, `_rendered_result_ids`, and the remote-image failed/in-flight dedupe state.
- `godot --headless --path .testbed --quit-after 3` and `godot --path .testbed --quit-after 3` both opened cleanly without reproducing the prior startup warning block.
- Repo-local validation remains green: the built-in headless harness `res://scripts/validate_beatsaver_client_slice.gd` passed end-to-end. It did emit one shutdown-time `ObjectDB instances leaked at exit` warning after success, but that is not the BeatSaver warning-cleanup regression under test and did not fail the harness.
- The focused GUI QA harness `/tmp/qa_warning_cleanup_check.gd` passed. It instantiates the actual browser scene with fixture-backed map data, emits repeated non-result `state_changed` churn, and proves the result-card node IDs and nested cover-image node IDs remain stable instead of being torn down/recreated. It also directly exercises the `BeatSaverRemoteImage.set_image_url(...)` short-circuit logic for unchanged in-flight and unchanged failed URLs, proving those repeated calls now no-op instead of re-entering the reset/request path.
- Truth boundary: I did not reproduce Derrick’s exact live BeatSaver resolver/network failure (`Out of resolver queries` / `Can't connect`) against the remote service during QA. So I cannot claim the external network condition itself disappeared. What I *did* verify is the local multiplier path is neutralized truthfully: unrelated `state_changed` churn no longer rebuilds cards, and the remote-image node now short-circuits repeated unchanged URLs in the relevant in-flight/failed states. That is the behavior needed to stop the infinite local warning loop rather than merely hiding logs.

QA verdict: **PASS**. The warning-cleanup slice is QA-ready for the auditor lane.

---

### Task 5: Audit final warning truth and closure readiness

**Bead ID:** `aerobeat-vendor-beatsaver-qgz`
**SubAgent:** `primary` (for `auditor`)
**Role:** `auditor`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, claim bead `aerobeat-vendor-beatsaver-qgz`, independently audit the final warning cleanup against Derrick's report and the actual runtime/testbed truth, confirm the slice is not papered over, and close the bead only if the work is genuinely done. Start with `bd update aerobeat-vendor-beatsaver-qgz --status in_progress --json` and close with `bd close aerobeat-vendor-beatsaver-qgz --reason "Audited BeatSaver warning cleanup" --json`.

**Folders Created/Deleted/Modified:**
- audit-only as needed

**Files Created/Deleted/Modified:**
- `.plans/2026-07-21-testbed-warning-cleanup.md`

**Status:** ✅ Complete

**Results:** Independent auditor pass. I verified the final state against Derrick’s warning report (`REF-01`), the prior repro map from Task 1, and the actual hidden testbed/runtime sources (`REF-03` through `REF-08`). Audit evidence run in this lane:
- `git status --short`, `git log --oneline --decorate -n 6`, `git branch -vv`, `git rev-list --left-right --count HEAD...@{u}`
- `git show --stat --oneline 53e4800` and `git show --stat --oneline b4b089c`
- targeted source-truth `rg` across `.testbed` / `src` to confirm the old startup-warning signatures are gone from the runtime scripts and the new behavioral state (`_rendered_result_ids`, `_failed_request_urls`, `_failed_decode_urls`, `header_name`, `seed_record`) is actually present
- `godot --headless --path .testbed --quit-after 3`
- `godot --path .testbed --quit-after 3`
- `godot --headless --path .testbed --script res://scripts/validate_beatsaver_client_slice.gd`
- `godot --headless --path .testbed --script /tmp/audit_beatsaver_warning_cleanup.gd`

Truth findings:
- Startup/editor warning cleanup is real, not suppressed. The prior duplicate class-shadowing preload constants and parser-warning signatures identified in Task 1 are removed from the affected `.testbed` scripts, and both headless and GUI startup open cleanly without recreating Derrick’s startup warning block.
- The runtime warning-loop cleanup is also real, not papered over. `BeatSaverRemoteImage` still calls `push_warning(...)`; it was not muted. Instead, it now memoizes failed request/decode URLs and short-circuits repeated unchanged URLs. `BeatSaverBrowserTestbed` now preserves result-card/cover-image node identity across unrelated `state_changed` churn by comparing `_rendered_result_ids` before rebuilding. The dedicated audit harness proved repeated non-result state changes no longer recreate the cards or nested cover-image nodes.
- Commit/push truth is clean: `53e4800` and `b4b089c` are present in `main`, `origin/main` matches `HEAD` (`0 0` ahead/behind), and the only working-tree modification during audit was this plan update.
- Remaining caveat, stated precisely: I did **not** reproduce Derrick’s exact live upstream resolver/network failure (`Out of resolver queries` / `Can't connect`) against BeatSaver during audit. So I cannot claim the upstream network condition vanished. I can truthfully claim the local spam loop is fixed, because the rerender multiplier path identified in Task 1 is gone and identical failed URLs are now deduped rather than warning on every repeated render.

Audit verdict: **PASS**. The slice is truthful and closure-ready, so this auditor lane may close bead `aerobeat-vendor-beatsaver-qgz`.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The hidden BeatSaver testbed now opens without the reproduced startup/editor warning block, and the download-time cover-image failure path no longer turns unrelated `state_changed` churn into an infinite local warning loop. The final fix is behavioral: startup parser/name warnings were removed at their source, result-card rerenders are gated by visible-result identity, and repeated failed image URLs are deduped once per URL instead of re-warning forever.

**Reference Check:** `REF-01` satisfied for the reproduced warning families and spam-loop diagnosis; `REF-02` preserved the prior hidden-testbed architecture context; `REF-03` through `REF-08` match the final audited source/runtime truth. Deliberate caveat: the exact external BeatSaver resolver/network failure from Derrick’s screenshot was not reproduced live in this audit lane, so the claim is limited to truthful local loop elimination rather than asserting the upstream network condition itself is gone.

**Commits:**
- `53e4800` - Fix BeatSaver testbed startup warnings
- `b4b089c` - Fix BeatSaver warning loop rerenders
- `1af336b` - Update BeatSaver warning cleanup plan

**Lessons Learned:** For warning cleanup, source-truth matters more than log silence. The durable fix came from removing the parser-warning causes and stopping unnecessary UI rebuilds, while preserving a once-per-URL warning path so real remote failures still surface truthfully.

---

*Completed on 2026-07-22*
