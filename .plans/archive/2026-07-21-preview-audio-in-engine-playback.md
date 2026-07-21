# AeroBeat Vendor BeatSaver Preview Audio In-Engine Playback

**Date:** 2026-07-21
**Status:** Complete
**Last Updated:** 2026-07-21 19:30 EDT
**Blocked Reason:** None
**Agent:** `pico`

---

## Goal

Make the BeatSaver hidden `.testbed` Preview action play preview audio inside the Godot scene/engine instead of opening the system web browser.

---

## Overview

Derrick manually validated the newly repaired BeatSaver hidden `.testbed` and found a product-truth bug: the Preview button currently routes through `OS.shell_open(...)`, which launches the external web browser for remote preview URLs instead of previewing audio in-engine. That breaks the intended testbed workflow because preview-audio validation needs to happen inside the scene/runtime surface, not by handing off to the host browser.

This is a narrow repo-owned follow-up in `aerobeat-vendor-beatsaver`. The likely seam lives in the hidden testbed state/UI flow, especially the current `preview_selected_version()` path and whatever playback surface should exist in the scene for local/remote preview targets. The right fix is to keep the GodotEnv consumer truth we just restored, then add or repair an in-engine audio-preview path that works for the available preview target types without widening into unrelated BeatSaver package workflow changes.

Execution should stay disciplined: first audit the current preview path and identify the smallest truthful in-engine playback route, then implement it, then QA it at the highest-fidelity repo-local level available, then audit and close.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Derrick report that Preview opens the web browser instead of playing in scene/engine | This chat message on 2026-07-21 17:06 EDT |
| `REF-02` | Completed GodotEnv architecture/open-state fix plan for the same hidden `.testbed` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/2026-07-21-testbed-godotenv-open-errors-and-dependency-audit.md` |
| `REF-03` | Hidden testbed state logic that currently owns preview behavior | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_testbed_state.gd` |
| `REF-04` | Hidden testbed scene/controller that currently owns the Preview button wiring | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.testbed/scripts/beatsaver_browser_testbed.gd` |

---

## Tasks

### Task 1: Audit current Preview path and define the in-engine playback seam

**Bead ID:** `aerobeat-vendor-beatsaver-xyc`
**SubAgent:** `primary` (for `research`)
**Role:** `research`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver`, audit the hidden `.testbed` Preview path. Confirm exactly how Preview currently chooses targets, where it hands off to external browser/OS behavior, what playback support already exists in-scene if any, and what the narrowest truthful in-engine playback implementation seam is for remote and local preview audio. Update the plan with exact findings and likely touched files. Do not implement fixes yet unless a tiny inseparable proof probe is required.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-beatsaver/.plans/2026-07-21-preview-audio-in-engine-playback.md`

**Status:** ✅ Complete

**Results:** Audit complete. Current preview-target truth lives in `BeatSaverTestbedState.selected_preview_target()` (`.testbed/scripts/beatsaver_testbed_state.gd:411-425`): if a converted package exists, Preview prefers `local_preview_path`; if that file is missing, it falls back to `local_source_audio_path`; otherwise it falls back to the selected version’s `remote_preview_url`. The local-path truth is populated only after conversion by `_extract_local_audio_truth()` (`.testbed/scripts/beatsaver_testbed_state.gd:661-679`), which reads `songs[0].audio.previewFilePath`, `songs[0].audio.filePath`, and `songs[0].audio.previewUrl` from the authored package state.

The external handoff happens in exactly one place for Preview today: `preview_selected_version()` resolves the target and immediately calls `_open_external(target)` (`.testbed/scripts/beatsaver_testbed_state.gd:363-383`), and `_open_external()` is just `shell_opener.call(...)` when injected for tests or `OS.shell_open(target)` in production (`.testbed/scripts/beatsaver_testbed_state.gd:681-684`). The UI button is wired straight to that path via `_on_preview_pressed() -> state.preview_selected_version()` in `.testbed/scripts/beatsaver_browser_testbed.gd:94-95`. Validation explicitly asserts this shell-open behavior for both inspect and preview (`.testbed/scripts/validate_beatsaver_client_slice.gd:308-313`).

Existing in-scene playback support is effectively none. The scene (`.testbed/scenes/beatsaver_browser_testbed.tscn`) has no `AudioStreamPlayer*`, no playback controller node, and no transport/status UI. The only existing in-scene remote-media pattern is cover-art fetching via `BeatSaverRemoteImage`, which uses a scene-owned `HTTPRequest` to fetch bytes and decode them in-engine (`.testbed/scripts/beatsaver_remote_image.gd`). That means the current truthful seam is: state/model code already knows *which* preview target should be used, but scene/runtime code does not yet know how to *play* any preview target in-engine.

Recommendation for the narrowest truthful in-engine route: keep preview-target selection in `BeatSaverTestbedState.selected_preview_target()` as the source of truth, and move actual playback orchestration into the scene layer instead of further growing `RefCounted` state around `OS.shell_open`. Concretely, `BeatSaverBrowserTestbed` should own a tiny preview-player seam (either inline or via a small helper script/node) backed by one `AudioStreamPlayer` plus one `HTTPRequest`. For `local_preview` and `local_source_audio`, load/play the file directly in-engine on that player. For `remote_preview_url`, download the preview audio to a temp `user://` path (or decode from bytes if simpler/reliable for the actual codec served), then load/play it on the same player. That preserves existing local-vs-remote truth, avoids touching download/convert/package workflow seams, and keeps the fix bounded to the hidden testbed runtime surface.

Likely files to change for implementation: `.testbed/scripts/beatsaver_browser_testbed.gd` (replace Preview button handoff with scene-owned playback flow), `.testbed/scenes/beatsaver_browser_testbed.tscn` (add audio/player/request nodes or any minimal playback/status UI if not created dynamically), `.testbed/scripts/beatsaver_testbed_state.gd` (small change only if we rename/deprecate `preview_selected_version()` or add a playback-friendly result helper, but the main selection logic should stay here), and `.testbed/scripts/validate_beatsaver_client_slice.gd` (update assertions from shell-open preview to in-engine playback truth). A new helper such as `.testbed/scripts/beatsaver_preview_player.gd` is optional but would be a clean narrow extraction if the browser script starts to sprawl.

---

### Task 2: Implement in-engine preview audio playback in the hidden `.testbed`

**Bead ID:** `aerobeat-vendor-beatsaver-gyf`
**SubAgent:** `primary` (for `coder`)
**Role:** `coder`
**References:** `REF-01`, `REF-03`, `REF-04`
**Prompt:** Implement the narrowest truthful fix so the hidden BeatSaver `.testbed` Preview action plays audio inside the Godot scene/engine instead of launching the system browser. Preserve the existing preview-target truth from `BeatSaverTestbedState.selected_preview_target()` (local preview file → local source audio → remote preview URL fallback), move playback orchestration into the scene/runtime layer, and keep scope bounded to preview playback behavior, scene wiring, and necessary tests.

**Folders Created/Deleted/Modified:**
- `.testbed/`
- `.plans/`

**Files Created/Deleted/Modified:**
- `.testbed/scripts/beatsaver_browser_testbed.gd`
- `.testbed/scenes/beatsaver_browser_testbed.tscn`
- `.testbed/scripts/beatsaver_testbed_state.gd`
- `.testbed/scripts/validate_beatsaver_client_slice.gd`
- `.plans/2026-07-21-preview-audio-in-engine-playback.md`

**Status:** ✅ Complete

**Results:** Implemented the preview playback seam in-scene without widening the download/convert workflow. `BeatSaverTestbedState.preview_selected_version()` now preserves preview-target resolution truth without shell-opening audio targets, while `BeatSaverBrowserTestbed` owns actual playback using one `AudioStreamPlayer` plus one `HTTPRequest`. Local preview/local source audio now load directly in-engine from the selected target path; remote preview URLs now fetch to `user://beatsaver-preview-cache/<sha256>.<ext>` and play on the same player. Validation was updated truthfully to stop expecting Preview shell-open behavior, to exercise remote in-engine preview playback via an injected fetcher, and to use valid synthetic WAV fixture files for local playback coverage. Validation run: `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd` ✅. Caveat: the validation run still reports a Godot shutdown warning about leaked ObjectDB instances at exit, but the script exits 0 and the warning does not appear to be introduced by this slice alone.

---

### Task 3: QA in-engine preview playback truth

**Bead ID:** `aerobeat-vendor-beatsaver-7lj`
**SubAgent:** `primary` (for `qa`)
**Role:** `qa`
**References:** `REF-01`, `REF-03`, `REF-04`
**Prompt:** Verify at the highest-fidelity repo-local level available that Preview now plays inside the Godot scene/engine instead of opening the system browser, and that the testbed still handles the available preview target types truthfully.

**Folders Created/Deleted/Modified:**
- verification-only if needed

**Files Created/Deleted/Modified:**
- verification notes only if needed
- this plan file

**Status:** ✅ Complete

**Results:** QA evidence is present and consistent with the landed slice. The strongest repo-local validation for this lane is `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`, which covers scene-level remote preview playback before acquisition and scene-level local preview playback after conversion. That validation passes on Godot `4.6.2.stable.official.71f334935` with the expected success banner `BeatSaver client/testbed validation passed.` The run still emits `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).`, but it exits 0 and QA found no evidence that the warning was introduced by this preview slice.

---

### Task 4: Audit final preview playback truth

**Bead ID:** `aerobeat-vendor-beatsaver-dw9`
**SubAgent:** `primary` (for `auditor`)
**Role:** `auditor`
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`
**Prompt:** Independently audit the final hidden `.testbed` preview playback behavior against Derrick's report, the scene/runtime truth, diffs, and validation evidence. Confirm the fix stayed bounded to in-engine preview playback and close the lane if it passes.

**Folders Created/Deleted/Modified:**
- audit-only if needed

**Files Created/Deleted/Modified:**
- audit notes only if needed
- this plan file

**Status:** ✅ Complete

**Results:** Independent audit passed. I reran the strongest repo-local validation available from the repo root: `godot --headless --path .testbed -s res://scripts/validate_beatsaver_client_slice.gd`. Result: ✅ `BeatSaver client/testbed validation passed.` on Godot `4.6.2.stable.official.71f334935`. The run still emits `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` during shutdown, but it exits 0 and I found no preview-specific regression evidence tied to that warning.

Exact audit evidence:
- **Bounded scope stayed truthful.** Commit `0952a38` touches only the preview plan, `.testbed/scenes/beatsaver_browser_testbed.tscn`, `.testbed/scripts/beatsaver_browser_testbed.gd`, `.testbed/scripts/beatsaver_testbed_state.gd`, and `.testbed/scripts/validate_beatsaver_client_slice.gd`. I found no widened changes in BeatSaver download, staging, conversion, or non-testbed product code outside the small preview-target/state seam and scene playback wiring.
- **Preview no longer shell-opens audio.** `preview_selected_version()` now resolves and returns preview target truth without calling `_open_external(...)` (`.testbed/scripts/beatsaver_testbed_state.gd:363-372`). The only remaining production `OS.shell_open(...)` path under the hidden testbed is Inspect/package-open via `_open_external()` from `inspect_selected_version_package()` (`.testbed/scripts/beatsaver_testbed_state.gd:374-398, 670-673`). The validation also asserts Preview does not append a new shell-open target while Inspect still does (`.testbed/scripts/validate_beatsaver_client_slice.gd:376-381`).
- **Scene-owned in-engine playback is the active truth.** The scene now owns `PreviewAudioPlayer` and `PreviewHttpRequest` nodes (`.testbed/scenes/beatsaver_browser_testbed.tscn:195-199`), and `BeatSaverBrowserTestbed.play_selected_preview()` routes local targets through `_play_preview_path(...)` and remote URLs through `_fetch_remote_preview(...)` → `_cache_remote_preview(...)` → `_play_preview_path(...)` (`.testbed/scripts/beatsaver_browser_testbed.gd:111-168, 187-238`).
- **Strongest repo-local validation exercises both major playback branches.** The validation scene pass confirms remote preview playback succeeds before acquisition, preserves `kind == "remote_preview_url"`, writes a cache file, and sets `PreviewAudioPlayer.stream != null` (`.testbed/scripts/validate_beatsaver_client_slice.gd:440-444`). It also confirms local preview playback succeeds after conversion, preserves `kind == "local_preview"`, and keeps `PreviewAudioPlayer.stream != null` (`.testbed/scripts/validate_beatsaver_client_slice.gd:454-458`).
- **Fallback ordering is still correct, with one explicit caveat.** `selected_preview_target()` still prefers `local_preview` → `local_source_audio` → `remote_preview_url` (`.testbed/scripts/beatsaver_testbed_state.gd:400-414`). The validation preserves this truth at the selection/code-path level and explicitly allows converted local audio truth to surface as either `local_preview` or `local_source_audio` in the authoring-bridge path (`.testbed/scripts/validate_beatsaver_client_slice.gd:397-404`). However, the `local_source_audio` fallback is **not** exercised by a dedicated scene-playback fixture that removes only the preview file while leaving source audio intact; that caveat remains real and documented.

Audit conclusion: this slice satisfies `REF-01`, stays bounded to in-engine preview playback in the hidden `.testbed`, removes Preview's browser shell-open behavior for audio playback, and passes the strongest current repo-local validation. The remaining `local_source_audio` note is an acknowledged coverage caveat, not a failure.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The hidden BeatSaver `.testbed` now plays Preview audio in-engine through scene-owned playback (`PreviewAudioPlayer` + `PreviewHttpRequest`) instead of shell-opening preview URLs in the system browser. Remote preview playback is validated before acquisition; local preview playback is validated after conversion.

**Reference Check:** `REF-01` is satisfied: Preview no longer routes audio playback through browser shell-open behavior. `REF-03` remains the source of truth for preview-target selection order (`local_preview` → `local_source_audio` → `remote_preview_url`), and `REF-04` remains the source of truth for scene/runtime playback orchestration. `REF-02` stayed intact because the fix remained bounded to the hidden `.testbed` preview path rather than widening into unrelated GodotEnv/package workflow changes. Explicit caveat retained: `local_source_audio` fallback is code-path/selection-truth verified, not exercised by a dedicated scene-playback fixture.

**Commits:**
- `0952a38` - Play BeatSaver previews in-engine

**Lessons Learned:** For preview/media work, branch-order truth and scene-playback truth should be called out separately. A passing selection-order assertion is valuable, but it is not the same thing as an end-to-end playback fixture for every fallback branch.

---

*Completed on 2026-07-21*