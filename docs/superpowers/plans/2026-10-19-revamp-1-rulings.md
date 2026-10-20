# Revamp 1 (realism and usability): decisions made during implementation

This revamp followed playtest feedback on v0.1: the room didn't look real, the POV felt wrong, there were no on-screen keys, pages felt separate rather than stapled, the clock was hard to read and the menu felt bad. Branch `revamp-1`, stacked on Plan 1.

This file lists every departure from the plan ("Ruling") and every deferred minor issue. Each ruling ends with what it costs if it turns out wrong.

## Assets
- **Fetch tool.** Ruling: `tools/fetch_assets.py` (Python, md5 manifest from the Poly Haven API via `tools/make_asset_manifest.py`) instead of a `fetch_assets.sh` with sha256. Python was already needed for the fixtures, and Poly Haven publishes md5. Cost if wrong: swap the hash type.
- **No ambientCG.** Ruling: no ambientCG downloads. Poly Haven's painted-brick, ceiling and floor textures read wrong in the room (teal brick, brown ceiling, checkerboard floor). The cinderblock, VCT floor and acoustic tile are procedural world-space shaders instead. Cost if wrong: swap a texture into one material.
- **Characters committed.** Ruling: Quaternius Universal Base Characters are committed (about 10 MB after downscaling textures to 1024 px). Itch.io downloads need a browser-style CSRF flow, which isn't reliable in CI. Two texture URIs in the gltf files were patched to match the shipped file names. Cost if wrong: repo size.

## Room
- **Desk height.** Ruling: the School Desk 01 model is scaled vertically so its top sits at 0.76 m. This is measured from the AABB, because a vertex-height filter picked the book box instead of the top. Cost if wrong: desks a few cm off.
- **GreyboxClassroom kept, not wired in.** Ruling: it stays in the repo but is no longer used. The Low preset uses MorningClassroom with SSAO/SSIL and shadows trimmed instead. Cost if wrong: a slower Low preset on very old GPUs.

## Students
- **Pose and clothing.** Ruling: seated pose is procedural, set through `Skeleton3D.set_bone_global_pose`, because the pack has no sitting animation. Clothing comes from a per-vertex colour mask built from the rest pose (torso, legs, feet and arm distance), which a shader colours and textures. Bodies are slimmed on x/z because the "superhero" base is bulky. Cost if wrong: the pose looks stiff close up; a real sit animation would replace `_pose()`.
- **Animation LOD.** Ruling: students farther from the camera update their bones less often. Cost if wrong: none.

## Seat, page and clock
- **Field of view.** Ruling: the FOV setting is vertical, with a default of 50 and a range of 40–70, instead of the plan's 70 (60–90). 70° vertical made the desk look like a fisheye. Settings now carry `meta/version` = 2, and an older file's `graphics/fov` is dropped on load (found when the installed settings kept 70 and zoomed the desk out). Cost if wrong: one constant.
- **Eye position.** Ruling: the desk eye is about 32 cm above and 25 cm behind the packet centre; leaning comes down to about 17 cm. This is closer than the planned 44 cm, so questions read without leaning. Cost if wrong: tune SeatPose constants.
- **Page curl math.** Ruling: PageCurl folds along the perpendicular bisector of grab→hand. The fold offset blends from a flat crease to a full cylinder wrap as the drag grows, which avoids a pop at the start of a drag. Turned pages drape over the far desk edge (`drape_z`) instead of floating past it. Cost if wrong: shader-only tweak.
- **Turning back.** Ruling: you go back by dragging down from the turned stack at the top of the packet. A/D still turn pages with the same curl along a default corner path. Cost if wrong: none.
- **Clock seconds.** Ruling: the digital clock shows H:MM with a blinking colon and a PM dot. The planned "seconds" option was left out: no real classroom clock shows them, and they would pull your eye. The 12/24-hour and no-clock choices live in Settings → Test. Cost if wrong: one argument already supported by `WallClockMath.digital`.

## UI
- **Settings tabs.** Ruling: Settings is tabbed (Test / Writing / Graphics / Controls) with a scroll area, instead of one long page. The pre-test card shows a summary line that expands into the same `TestSetupForm`, so both screens share one form. Cost if wrong: none.
- **Main menu.** Ruling: the main menu is a full-height left panel with a "Sit again" list of recent PDFs. The planned "last result" card was left out, because History already covers it and the right side is kept for the cards. Cost if wrong: one small card later.
- **First-run tips.** Ruling: they sit at the top centre, because at the bottom they covered the page corner you grab. Cost if wrong: none.

## Plan 1 deferred minors
- **Fixed:**
  - Esc during settling opens the menu, and the settle countdown pauses while it's open.
  - H is ignored while paused.
  - Typing is committed and input disabled at hand-in.
  - A timer saved in phase OVER now hands in on resume.
  - The pre-test warns above 60 pages.

## Performance
- **Unverified.** Ruling: frame rates per preset are unverified. `room_preview --fps` measurements on the dev machine (RTX 3060 Ti) varied 3–7× between identical runs while another game was running. Medium reached 176 fps and High 57–73 fps in the cleaner runs. GPU time stayed at 5–18 ms in every run. Cost if wrong: Low/Medium may need lighter shadows; re-measure on an idle machine.

## Deferred minors
- Graphics presets still don't change paper DPI (fixed at 150).
- `room_preview --fps` reads `Performance.TIME_PROCESS`, which includes the frame's idle wait. Use the GPU and fps numbers.
