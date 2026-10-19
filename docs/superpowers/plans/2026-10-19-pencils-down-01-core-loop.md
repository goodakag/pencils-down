# Pencils Down — Plan 1: Core Test Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable end-to-end build in a greybox classroom. You load a PDF, sit at a desk, answer with pencil, eraser, Quick Fill and typed handwriting, look up at a working wall clock, hear the bells, get a grace period, hand in, and save the marked PDF from a review screen. It autosaves and resumes after a crash, and CI runs the tests.

**Architecture:** All rules live in small, pure `RefCounted` classes under `systems/` that GUT tests run headless (timer, session state machine, attempt data, ink geometry, handwriting layout, bubble detection, export). Thin autoloads in `autoload/` hold the single live instances and connect them to scenes. Scenes (`scenes/`) only display state and forward input. Every mark is stored in **PDF points, origin top-left, y down**.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), PDFium-GDE GDExtension (Zlib; PDFium Apache-2.0), GUT 9.x, Python 3 + reportlab + pypdf (fixture generation only), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-19-pencils-down-design.md`

### Where this plan sits
The v0.1 scope (spec §14) is split into four plans. Each one ends with working software:

| Plan | Delivers | Written |
|---|---|---|
| **1. Core test loop** (this file) | Everything above, in a greybox room with placeholder bell sounds | now |
| 2. Morning Classroom | Blender kit, CC0 materials, baked lighting, window view, graphics presets + auto-benchmark | after Plan 1 ships |
| 3. People | MPFB 2 students and teacher, procedural writing, proctor behaviors, player hand + pencil IK, fidgets, hand-in walk, forced pickup animation | after Plan 2 |
| 4. Sound & polish | 10 ambience layers + presets, speech bubbles, sticky note, settings folder (all tabs incl. key rebinding, accessibility subtitles), first-run hints, erase ghosts on paper, v0.1 release | after Plan 3 |

Plan 1 already saves settings that later plans use (writing hand, class size); they have no visible effect until Plans 2–3.

Plans 2–4 are written after the previous plan ships, because each depends on what the earlier one teaches us (rig scale, performance headroom, real asset sizes).

## Global Constraints

- Engine **Godot 4.7.2**, **GDScript only** with static types (`var x: int`, typed arrays, return types). No C#.
- Desktop targets: **Windows, macOS, Linux**. Forward+ is the default renderer.
- Licensing: code **MIT**; only **CC0, CC-BY or SIL OFL** assets, each listed in `CREDITS.md` with its source URL. No Mixamo or store assets.
- Ink coordinates: **PDF points, origin top-left, y down**, for both on-screen ink and export.
- Paper render DPI by quality: **Low 110, Medium 150, High 200, Ultra 250**. Export pencil layer: **300 DPI**.
- Graphite color **`#3B3A3C`**, exported at **92% opacity**.
- Timings: look-up ease **0.4 s**; edge-look dwell **0.35 s**; page flip **0.45 s**; Quick Fill animation **≈0.6 s**; glyph-to-glyph write delay **35 ms**; autosave every **20 s** and on each page turn; teacher-question clock hold cap **60 s** (used in v0.2, built into the timer now).
- Defaults: grace **1.5 min** (options 0 / 1 / 1.5 / 2); warnings **15 & 5 min**; scratch paper **1 sheet**; start time on clock **9:00 AM**; class size **normal (16)**; mode **Practice**.
- Handwriting jitter per glyph: rotation **±0.6°**, scale **±4%**, baseline **±0.3 pt**.
- Quick Fill fallback bubble: **9 mm (25.51 pt)** filled ellipse.
- Handwriting fonts (OFL): **Caveat, Kalam, Patrick Hand, Shadows Into Light, Indie Flower**. UI fonts: **Fraunces** (headings), **Atkinson Hyperlegible** (body).
- UI colors: paper `#F7F4EC`, card edge `#E6DFD0`, ink `#2E2B28`, muted `#6E675E`, accent `#E8B33A`, manila `#E3C98F`.
- No arrow cursor and no HUD during a test (spec §7.5).
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**Commands used throughout** (Git Bash):
```bash
export GODOT="/c/Users/aming/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
# all tests
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
# one file
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_exam_timer.gd -gexit
```
A run passes when GUT prints `---- All tests passed! ----` and exits with code 0.

## Review Focus

1. **Paths with non-ASCII characters** (e.g. `C:\Users\Zoë\OneDrive\Документы\test.pdf`, common on Windows with OneDrive): opening, autosave and Save PDF must all work. Test in Task 2 and Task 14.
2. **Mixed page sizes and landscape pages** in one PDF (A4 + Letter + a landscape page): each page renders at its own aspect ratio and exported marks land exactly where they were drawn. Test in Task 14 (golden export uses the mixed fixture).
3. **Characters missing from the handwriting font** (`é`, `√`, `²`, `π`, `θ`, `≤` in math answers): no tofu boxes on screen or in export; a fallback font fills gaps. Test in Task 8.
4. **The test ends while the player is mid-stroke or typing** (end of grace period, or forced pickup): the in-progress stroke and text are committed before the attempt is archived and exported. Test in Task 13.
5. **Very large PDFs** (100+ pages): only the current page ±1 is rendered at full DPI, the rest as thumbnails, and memory stays bounded. Test in Task 10.

---

## File structure

```
project.godot                     autoloads, input map, rendering defaults
export_presets.cfg                Windows / macOS / Linux presets
addons/gut/                       GUT (vendored)
addons/pdfium-gde/                PDFium-GDE (built from source, vendored binaries)
autoload/
  settings.gd                     Settings      — wraps SettingsStore
  session.gd                      Session       — owns SessionMachine, ExamTimer, current Attempt
  pdf_service.gd                  PdfService    — opens PdfDoc instances
systems/
  settings_store.gd               SettingsStore: defaults, get/set, ConfigFile I/O
  exam_timer.gd                   ExamTimer: elapsed/remaining, phases, warnings, suspend/pause
  session_machine.gd              SessionMachine: states + allowed transitions
  attempt/stroke.gd               Stroke
  attempt/text_mark.gd            TextMark
  attempt/page_ink.gd             PageInk
  attempt/attempt.gd              Attempt
  attempt/attempt_store.gd        AttemptStore: archive, history, autosave
  ink/ink_geometry.gd             InkGeometry: smoothing, width, erase splitting
  ink/undo_stack.gd               UndoStack
  ink/ink_rasterizer.gd           InkRasterizer: CPU stroke → transparent Image
  writing/handwriting_layout.gd   HandwritingLayout + GlyphPlacement
  writing/bubble_detector.gd      BubbleDetector
  writing/scribble_gen.gd         ScribbleGen
  pdf/pdf_doc.gd                  PdfDoc: adapter over PDFium-GDE
  pdf/pdf_exporter.gd             PdfExporter: vector+overlay export, falls back to images
  pdf/fallback_pdf_writer.gd      FallbackPdfWriter: pure-GDScript JPEG-page PDF
  room/wall_clock_math.gd         WallClockMath
  room/board_text.gd              BoardText
  player/edge_look.gd             EdgeLook
  player/page_mapper.gd           PageMapper
  review/page_time_tracker.gd     PageTimeTracker
  review/marking_prompt.gd        MarkingPrompt
scenes/
  main.tscn / main.gd             boot: menu, resume check
  ui/theme/cozy_theme.tres        Theme (fonts, colors, chips, cards)
  ui/main_menu.tscn/.gd
  ui/pre_test.tscn/.gd
  ui/review.tscn/.gd
  ui/history.tscn/.gd
  ui/settings_panel.tscn/.gd      minimal Plan-1 settings (General, Writing, Controls)
  player/player_rig.tscn/.gd      camera states, pencil-tip raycast, input dispatch
  packet/test_packet.tscn/.gd     pages, flip, overview, scratch, slide
  packet/paper_page.tscn/.gd      one page mesh + page/ink textures
  packet/paper_page.gdshader      page × fiber + ink, page curl
  packet/ink_layer.gd             live ink drawing into a SubViewport
  packet/handwriting_node.gd      typed text: caret, timed glyph reveal
  environments/greybox/greybox_classroom.tscn  CSG room + EnvironmentContract markers
  environments/environment_contract.gd         base script declaring required nodes
  room/wall_clock.tscn/.gd
  room/whiteboard.tscn/.gd
  flow/test_flow.gd               drives settling → bells → grace → hand-in
assets/
  fonts/                          OFL TTFs + OFL.txt
  audio/placeholder/bell_start.wav, bell_end.wav   generated by tools/make_bells.py
tests/
  unit/test_*.gd
  fixtures/                       generated PDFs + golden images
tools/
  make_fixtures.py, make_bells.py, requirements.txt
.github/workflows/test.yml, release.yml
README.md  LICENSE  CREDITS.md
```

---

### Task 1: Project scaffold, GUT, CI

**Files:**
- Create: `project.godot`, `.gitignore`, `.gitattributes`, `addons/gut/` (vendored), `tests/unit/test_smoke.gd`, `.github/workflows/test.yml`, `LICENSE` (MIT, copyright "Pencils Down contributors"), `README.md` (one paragraph + "build from source" stub)

**Interfaces:**
- Produces: the test commands in Global Constraints; `res://tests/unit/` as the test root.

- [ ] **Step 1:** Create `project.godot` for Godot 4.7: name `Pencils Down`, main scene `res://scenes/main.tscn` (empty `Node` for now), renderer `forward_plus`, window 1920×1080 with `stretch/mode = canvas_items`, `physics/common/physics_ticks_per_second = 60`. `.gitignore` excludes `.godot/`, `*.import` caches under `.godot`, `/build/`. `.gitattributes`: `* text=auto eol=lf`, binary for `*.png *.jpg *.wav *.ttf *.pdf *.dll *.so *.dylib *.glb`.
- [ ] **Step 2:** Vendor the latest GUT 9.x release that supports Godot 4.7 into `addons/gut/` and enable it in `project.godot`.
- [ ] **Step 3: Write the smoke test**

```gdscript
# tests/unit/test_smoke.gd
extends GutTest
func test_engine_version_is_4_7() -> void:
    var v := Engine.get_version_info()
    assert_eq(v.major, 4)
    assert_eq(v.minor, 7)
```

- [ ] **Step 4:** Run all tests. Expected: 1 passing test, exit code 0.
- [ ] **Step 5:** Add `.github/workflows/test.yml`: on push and pull_request, `ubuntu-latest`, download Godot 4.7.2 Linux headless editor, run the all-tests command (Linux binary name). Fail the job on non-zero exit.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "chore: scaffold Godot 4.7 project with GUT and CI"`

---

### Task 2: PDFium-GDE spike and `PdfDoc` adapter

This is the risk spike from spec §3.2. Until it passes on Windows, the rest of the PDF work is blocked.

**Files:**
- Create: `addons/pdfium-gde/` (built), `tools/requirements.txt` (`reportlab`, `pypdf`), `tools/make_fixtures.py`, `tests/fixtures/*.pdf`, `systems/pdf/pdf_doc.gd`, `autoload/pdf_service.gd`, `tools/introspect_pdfium.gd`, `docs/pdfium-gde-api.md`, `tests/unit/test_pdf_doc.gd`
- Modify: `project.godot` (autoload `PdfService`)

**Interfaces:**
- Produces:
  - `class_name PdfDoc extends RefCounted`
    - `static func open(path: String) -> PdfDoc`: returns null on failure and sets `PdfDoc.last_error: String` (static var) to one of `"not_found"`, `"encrypted"`, `"corrupt"`.
    - `func page_count() -> int`
    - `func page_size_pt(index: int) -> Vector2` (cached; see Step 4)
    - `func render_page(index: int, dpi: float) -> Image` (RGBA8)
    - `func text_boxes(index: int) -> Array[Rect2]` (points, top-left origin; empty array if the extension can't extract text)
    - `func title() -> String` (metadata `Title`, or the file name without extension)
    - `var path: String`, `var sha1: String`
    - `func native() -> Object` (the underlying `PDFDocument`, for `PdfExporter` only)
  - Autoload `PdfService` (`autoload/pdf_service.gd`): `func open(path: String) -> PdfDoc` and `var last_error: String`, which mirrors `PdfDoc.last_error`.

- [ ] **Step 1:** Build PDFium-GDE from source for `platform=windows target=template_debug` and `template_release` (clone recursively from `https://github.com/aliarcanakgun/pdfium-gde`, SCons, MSVC). Copy `pdfium.dll` next to the extension binary, copy `demo/addons/pdfium-gde/` into `addons/pdfium-gde/`, enable the plugin. If a prebuilt release for Windows exists and matches Godot 4.7, using it is acceptable for this step; CI builds from source in Task 19.
- [ ] **Step 2:** Write `tools/introspect_pdfium.gd` (`extends SceneTree`) that prints `ClassDB.class_get_method_list("PDFDocument")` and `("PDFPage")` with argument names and types. Run it: `"$GODOT" --headless --path . -s tools/introspect_pdfium.gd`. Record the real method names for page count, page size, text extraction, `render_to_image`, `add_image`, `add_text`, `save_to_file` in `docs/pdfium-gde-api.md`. **Every later task uses the names recorded there.** The documented `render_to_image(scale)` takes a scale relative to 72 DPI (scale = dpi / 72.0).
- [ ] **Step 3:** Write `tools/make_fixtures.py` (reportlab + pypdf) to produce into `tests/fixtures/`:
  - `mc_letter.pdf`: 2 Letter pages, title "Fixture Test", 10 questions each with bubbles drawn as circles **containing the letters A–D as real text** (circle diameter 14 pt).
  - `mixed_sizes.pdf`: page 1 A4 portrait, page 2 Letter portrait, page 3 Letter landscape, each with a 1-pt border rectangle inset 36 pt.
  - `scanned.pdf`: 1 Letter page that is a single grayscale image (noise + drawn circles, no text layer).
  - `big_120.pdf`: 120 Letter pages, page number text only.
  - `encrypted.pdf`: `mc_letter.pdf` encrypted with user password `x`.
  - `corrupt.pdf`: the first 1,000 bytes of `mc_letter.pdf`.
  - `unicode/Zoë Документы/mc.pdf`: a copy of `mc_letter.pdf` under a non-ASCII path.
  Run it: `python -m pip install -r tools/requirements.txt && python tools/make_fixtures.py`. Commit the generated PDFs.
- [ ] **Step 4: Write the failing tests**

```gdscript
# tests/unit/test_pdf_doc.gd
extends GutTest
const F := "res://tests/fixtures/"

func test_opens_and_counts_pages() -> void:
    var d := PdfDoc.open(ProjectSettings.globalize_path(F + "mc_letter.pdf"))
    assert_not_null(d)
    assert_eq(d.page_count(), 2)
    assert_eq(d.title(), "Fixture Test")

func test_page_sizes_in_points() -> void:
    var d := PdfDoc.open(ProjectSettings.globalize_path(F + "mixed_sizes.pdf"))
    assert_almost_eq(d.page_size_pt(0), Vector2(595.28, 841.89), Vector2(1, 1))
    assert_almost_eq(d.page_size_pt(1), Vector2(612, 792), Vector2(1, 1))
    assert_almost_eq(d.page_size_pt(2), Vector2(792, 612), Vector2(1, 1))

func test_render_dpi_controls_pixel_size() -> void:
    var d := PdfDoc.open(ProjectSettings.globalize_path(F + "mc_letter.pdf"))
    var img := d.render_page(0, 144.0)
    assert_almost_eq(img.get_width(), 1224, 2)
    assert_almost_eq(img.get_height(), 1584, 2)

func test_encrypted_reports_encrypted() -> void:
    assert_null(PdfDoc.open(ProjectSettings.globalize_path(F + "encrypted.pdf")))
    assert_eq(PdfDoc.last_error, "encrypted")

func test_corrupt_reports_corrupt() -> void:
    assert_null(PdfDoc.open(ProjectSettings.globalize_path(F + "corrupt.pdf")))
    assert_eq(PdfDoc.last_error, "corrupt")

func test_missing_reports_not_found() -> void:
    assert_null(PdfDoc.open("C:/nope/none.pdf"))
    assert_eq(PdfDoc.last_error, "not_found")

func test_unicode_path_opens() -> void:
    var d := PdfDoc.open(ProjectSettings.globalize_path(F + "unicode/Zoë Документы/mc.pdf"))
    assert_not_null(d)
    assert_eq(d.page_count(), 2)

func test_sha1_is_stable() -> void:
    var p := ProjectSettings.globalize_path(F + "mc_letter.pdf")
    assert_eq(PdfDoc.open(p).sha1, PdfDoc.open(p).sha1)
    assert_eq(PdfDoc.open(p).sha1.length(), 40)
```

- [ ] **Step 5:** Run `test_pdf_doc.gd`. Expected: FAIL (`PdfDoc` not declared).
- [ ] **Step 6: Implement `PdfDoc` and the `PdfService` autoload.** Notes: check `FileAccess.file_exists` first for `not_found`. To tell encrypted from corrupt: if the native load fails, read the file bytes and report `encrypted` when they contain `/Encrypt`, otherwise `corrupt`. `page_size_pt`: use the native size getter if Step 2 found one; otherwise render at scale 1.0 once and use the image size (1 px = 1 pt), cached per page. `sha1`: `HashingContext` with `HASH_SHA1` over the file bytes, hex-encoded.
- [ ] **Step 7:** Run `test_pdf_doc.gd`. Expected: all pass. If `text_boxes` is unsupported by the extension, document it in `docs/pdfium-gde-api.md` and leave it returning `[]` (Task 9 handles both).
- [ ] **Step 8: Commit** — `git add -A && git commit -m "feat: PDFium-GDE spike, fixtures and PdfDoc adapter"`

---

### Task 3: `ExamTimer`

**Files:**
- Create: `systems/exam_timer.gd`, `tests/unit/test_exam_timer.gd`

**Interfaces:**
- Produces: `class_name ExamTimer extends RefCounted`
  - `enum Phase { NOT_STARTED, TESTING, GRACE, OVER }`
  - `signal warning(minutes_left: int)`, `signal test_ended()`, `signal grace_ended()`
  - `func _init(duration_s: float, grace_s: float, warning_minutes: PackedInt32Array = PackedInt32Array([15, 5]))`
  - `func start() -> void`, `func advance(delta: float) -> void`
  - `func elapsed() -> float` (test time only, excludes holds and pauses), `func remaining() -> float` (never below 0), `func grace_remaining() -> float`, `func phase() -> Phase`
  - `func suspend(reason: StringName) -> void`, `func resume(reason: StringName) -> void`, `func is_suspended() -> bool`. A suspension auto-resumes after `suspend_cap_s` (60.0).
  - `var pausable: bool` (true in Practice mode), `func pause() -> void`, `func unpause() -> void` (no-ops when `pausable` is false)
  - `func to_dict() -> Dictionary`, `static func from_dict(d: Dictionary) -> ExamTimer` (for autosave)

- [ ] **Step 1: Write the failing tests**

```gdscript
extends GutTest
func _t(dur := 3600.0, grace := 90.0) -> ExamTimer:
    var t := ExamTimer.new(dur, grace)
    t.start()
    return t

func test_counts_down() -> void:
    var t := _t()
    t.advance(60.0)
    assert_eq(t.elapsed(), 60.0)
    assert_eq(t.remaining(), 3540.0)

func test_warnings_fire_once_each_at_15_and_5() -> void:
    var t := _t()
    watch_signals(t)
    t.advance(2700.0)   # 15 min left
    t.advance(1.0)
    t.advance(600.0)    # 5 min left
    assert_signal_emit_count(t, "warning", 2)
    assert_signal_emitted_with_parameters(t, "warning", [15], 0)
    assert_signal_emitted_with_parameters(t, "warning", [5], 1)

func test_end_enters_grace_then_over() -> void:
    var t := _t(100.0, 90.0)
    watch_signals(t)
    t.advance(100.0)
    assert_eq(t.phase(), ExamTimer.Phase.GRACE)
    assert_signal_emitted(t, "test_ended")
    t.advance(89.0)
    assert_almost_eq(t.grace_remaining(), 1.0, 0.001)
    t.advance(1.0)
    assert_eq(t.phase(), ExamTimer.Phase.OVER)
    assert_signal_emitted(t, "grace_ended")

func test_large_delta_crosses_both_boundaries() -> void:
    var t := _t(100.0, 90.0)
    watch_signals(t)
    t.advance(500.0)
    assert_eq(t.phase(), ExamTimer.Phase.OVER)
    assert_signal_emitted(t, "test_ended")
    assert_signal_emitted(t, "grace_ended")

func test_zero_grace_goes_straight_to_over() -> void:
    var t := _t(10.0, 0.0)
    t.advance(10.0)
    assert_eq(t.phase(), ExamTimer.Phase.OVER)

func test_suspend_holds_time_and_caps_at_60s() -> void:
    var t := _t()
    t.suspend(&"teacher")
    t.advance(30.0)
    assert_eq(t.elapsed(), 0.0)
    t.advance(40.0)     # 70 s suspended → auto-resume after 60, 10 s count
    assert_false(t.is_suspended())
    assert_almost_eq(t.elapsed(), 10.0, 0.001)

func test_pause_only_when_pausable() -> void:
    var t := _t()
    t.pausable = false
    t.pause()
    t.advance(5.0)
    assert_eq(t.elapsed(), 5.0)
    t.pausable = true
    t.pause()
    t.advance(5.0)
    assert_eq(t.elapsed(), 5.0)
    t.unpause()
    t.advance(1.0)
    assert_eq(t.elapsed(), 6.0)

func test_round_trip_dict() -> void:
    var t := _t()
    t.advance(1234.0)
    var u := ExamTimer.from_dict(t.to_dict())
    assert_eq(u.remaining(), t.remaining())
    assert_eq(u.phase(), t.phase())
```

- [ ] **Step 2:** Run. Expected: FAIL (`ExamTimer` not declared).
- [ ] **Step 3:** Implement `ExamTimer`. `advance` splits a delta across the suspension cap and the test/grace boundaries so a single large delta behaves the same as many small ones. Warnings already passed when restored from a dict must not re-fire (store fired minutes in the dict).
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: ExamTimer with grace, warnings, suspend cap and pause`

---

### Task 4: `SessionMachine`

**Files:**
- Create: `systems/session_machine.gd`, `tests/unit/test_session_machine.gd`

**Interfaces:**
- Produces: `class_name SessionMachine extends RefCounted`
  - `enum State { MENU, PRETEST, SETTLING, TESTING, GRACE, HANDING_IN, REVIEW }`
  - `signal state_changed(from: State, to: State)`
  - `var state: State` (starts at `MENU`), `func transition_to(to: State) -> bool` (false and no signal when not allowed)
  - Allowed: MENU→PRETEST; PRETEST→MENU; PRETEST→SETTLING; SETTLING→TESTING; TESTING→GRACE; TESTING→HANDING_IN (zero grace or early hand-in); GRACE→HANDING_IN; HANDING_IN→REVIEW; REVIEW→MENU; REVIEW→PRETEST (retake); MENU→TESTING (resume after crash); any state→MENU only from REVIEW, PRETEST, or via `abort()`.
  - `func abort() -> void`: forces MENU from any state (used by "Quit test").

- [ ] **Step 1: Write the failing tests**: `test_happy_path` (MENU→PRETEST→SETTLING→TESTING→GRACE→HANDING_IN→REVIEW→MENU, all true, 7 `state_changed` emissions); `test_rejects_skip` (`MENU→TESTING` is allowed only as resume, so assert `PRETEST→TESTING` returns false and state stays PRETEST); `test_early_hand_in_from_testing` (TESTING→HANDING_IN true); `test_retake` (REVIEW→PRETEST true); `test_abort_from_testing` (state becomes MENU and the signal fires with `[TESTING, MENU]`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement with a `const ALLOWED := { State.MENU: [State.PRETEST, State.TESTING], ... }` table.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: session state machine`

---

### Task 5: Attempt data model and `AttemptStore`

**Files:**
- Create: `systems/attempt/stroke.gd`, `text_mark.gd`, `page_ink.gd`, `attempt.gd`, `attempt_store.gd`, `tests/unit/test_attempt.gd`, `tests/unit/test_attempt_store.gd`

**Interfaces:**
- Produces (all `extends RefCounted`, each with `to_dict() -> Dictionary` and `static from_dict(d: Dictionary)`):
  - `class_name Stroke`: `enum Tool { PENCIL, ERASER }`, `var id: int`, `var tool: Tool`, `var points: PackedVector2Array`, `var widths: PackedFloat32Array` (pt, one per point), `var t_start: float` (exam elapsed seconds)
  - `class_name TextMark`: `var id: int`, `var origin: Vector2` (pt, baseline-left of the first line), `var size_pt: float`, `var font_id: StringName`, `var text: String`, `var seed: int`
  - `class_name PageInk`: `var strokes: Array[Stroke]`, `var texts: Array[TextMark]`, `func is_empty() -> bool`, `func next_id() -> int`
  - `class_name Attempt`: `var id: String` (`"%d-%s" % [unix_time, random 6 hex]`), `var pdf_path: String`, `var pdf_sha1: String`, `var test_title: String`, `var page_sizes_pt: Array[Vector2]`, `var pages: Array[PageInk]`, `var scratch: Array[PageInk]`, `var options: Dictionary` (pre-test options snapshot), `var created_unix: int`, `var timer_state: Dictionary` (from `ExamTimer.to_dict`), `var page_time_s: PackedFloat32Array`, `var erase_count: int`, `var finished: bool`; `static func create(doc: PdfDoc, options: Dictionary) -> Attempt` (one empty `PageInk` per PDF page and `options.scratch_sheets` empty scratch `PageInk`s; `page_time_s` sized to the page count)
  - `class_name AttemptStore`: `var root: String` (default `"user://"`), `func archive(a: Attempt) -> String` (writes `root/attempts/<id>.json`, returns path), `func load_attempt(path: String) -> Attempt`, `func list_history() -> Array[Dictionary]` (newest first; each `{path, id, test_title, created_unix, used_s}`), `func save_autosave(a: Attempt) -> void` (writes `root/autosave.json` via temp file + rename), `func load_autosave() -> Attempt` (null if none or unreadable), `func clear_autosave() -> void`
  - JSON encoding: `PackedVector2Array` as flat `[x0, y0, x1, y1, …]` arrays rounded to 0.01 pt.

- [ ] **Step 1: Write the failing tests**: in `test_attempt.gd`: `test_stroke_round_trip` (points and widths survive within 0.01), `test_text_round_trip_unicode` (text `"x² + √2 ≤ π"` survives exactly), `test_attempt_round_trip` (2 pages, 1 scratch, options and timer_state survive; `pages.size() == 2`). In `test_attempt_store.gd` (use `root = "user://test_store_%d/" % randi()` and delete it in `after_each`): `test_archive_and_history_newest_first` (archive two attempts with `created_unix` 100 and 200 → `list_history()[0].created_unix == 200`), `test_autosave_round_trip_and_clear`, `test_corrupt_autosave_returns_null` (write `"{"` to `autosave.json` → `load_autosave()` is null), `test_unicode_root_path` (root `"user://Zoë Документы/"` archives and loads).
- [ ] **Step 2:** Run both files. Expected: FAIL.
- [ ] **Step 3:** Implement the five classes.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: attempt data model and attempt store`

---

### Task 6: `InkGeometry` and `UndoStack`

**Files:**
- Create: `systems/ink/ink_geometry.gd`, `systems/ink/undo_stack.gd`, `tests/unit/test_ink_geometry.gd`, `tests/unit/test_undo_stack.gd`

**Interfaces:**
- Produces:
  - `class_name InkGeometry` (static only):
    - `static func smooth(points: PackedVector2Array, samples_per_segment: int = 4) -> PackedVector2Array`: centripetal Catmull-Rom through all input points; output starts and ends at the input endpoints; fewer than 3 points are returned unchanged.
    - `static func width_for_speed(speed_pt_s: float, base_w_pt: float = 0.9, pressure: float = 1.0) -> float`: `base_w * pressure * lerp(1.15, 0.7, clamp(speed / 400.0, 0, 1))`.
    - `static func erase(stroke: Stroke, center: Vector2, radius: float) -> Array[Stroke]`: removes the points within `radius` and splits the rest into contiguous runs of 2 or more points; the returned strokes get `id = -1` (caller assigns ids).
    - `static func text_hit(mark: TextMark, layout: Array, p: Vector2, radius: float) -> PackedInt32Array`: indices of glyphs (from a `HandwritingLayout` result) whose centers are within `radius`.
  - `class_name UndoStack`: `func push(op: Dictionary) -> void` (clears redo), `func undo() -> Dictionary` (empty dict if nothing), `func redo() -> Dictionary`, `func can_undo() -> bool`, `func can_redo() -> bool`. Op shape: `{"kind": "add"|"remove"|"replace", "page": int, "before": Array, "after": Array}` where arrays hold `Stroke`/`TextMark` dicts. No size limit.

- [ ] **Step 1: Write the failing tests**: `test_smooth_keeps_endpoints` (input `(0,0),(10,0),(10,10)` → first and last equal input), `test_smooth_passthrough_short` (2 points unchanged), `test_width_slower_is_thicker` (`width_for_speed(0) > width_for_speed(800)`, values `1.035` and `0.63` within 0.001), `test_erase_splits_middle` (11 points along x 0..100 step 10, erase at (50,0) r=8 → 2 strokes of 5 points each: x 0–40 and 60–100), `test_erase_removes_all` (radius 1000 → empty array), `test_erase_drops_single_point_runs`, `test_undo_redo_order` (push A, B; undo→B; undo→A; redo→A; push C clears redo so `can_redo()` is false).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: ink geometry and undo stack`

---

### Task 7: `InkRasterizer`

Used for the export overlay (Task 14) and the fallback exporter (Task 15). Pure CPU, so it works in headless tests.

**Files:**
- Create: `systems/ink/ink_rasterizer.gd`, `tests/unit/test_ink_rasterizer.gd`

**Interfaces:**
- Consumes: `PageInk`, `Stroke`.
- Produces: `class_name InkRasterizer`
  - `static func rasterize(ink: PageInk, page_size_pt: Vector2, dpi: float, color: Color = Color("#3B3A3C", 0.92)) -> Image`: an RGBA8 image of `ceil(page_size_pt * dpi / 72)` pixels, transparent except pencil strokes, which are stamped as anti-aliased discs every ≤ 0.5 px along each segment with radius `width_pt / 2 * dpi / 72`. Overlapping stamps use max-alpha (no darkening build-up). ERASER strokes are never stored (erasing edits strokes), so they are ignored here.

- [ ] **Step 1: Write the failing tests**: `test_size_matches_dpi` (Letter at 300 DPI → 2550×3300), `test_empty_is_transparent` (sampled pixel alpha 0), `test_stroke_pixels_land_at_point_coordinates` (horizontal stroke from (72,72) to (144,72) pt, width 4 pt, at 72 DPI → pixel (108,72) alpha ≥ 0.85, pixel (108,80) alpha 0), `test_max_alpha_not_additive` (the same stroke drawn twice → center alpha ≤ 0.92 + 0.01).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Precompute one disc alpha mask per distinct radius; blend by writing `max(existing_a, stamp_a)` into a `PackedByteArray`, then `Image.create_from_data`.
- [ ] **Step 4:** Run. Expected: PASS. Also add `test_perf_full_page` (200 strokes × 50 points on Letter at 300 DPI completes in under 1500 ms; use `Time.get_ticks_msec()`).
- [ ] **Step 5: Commit** — `feat: CPU ink rasterizer for export`

---

### Task 8: `HandwritingLayout` and fonts

**Files:**
- Create: `assets/fonts/` (Caveat, Kalam, PatrickHand, ShadowsIntoLight, IndieFlower, Fraunces, AtkinsonHyperlegible, and the fallbacks NotoSans + NotoSansMath; each with its `OFL.txt`), `systems/writing/handwriting_layout.gd`, `tests/unit/test_handwriting_layout.gd`
- Modify: `CREDITS.md` (create; list each font with its Google Fonts URL and license)

**Interfaces:**
- Produces:
  - `class_name GlyphPlacement extends RefCounted`: `var ch: String`, `var pos: Vector2` (pt, baseline-left), `var rot_deg: float`, `var scale: float`, `var font: Font` (the font that actually contains the glyph), `var line: int`
  - `class_name HandwritingLayout` (static):
    - `const FONTS := { &"caveat": "res://assets/fonts/Caveat-Regular.ttf", &"kalam": …, &"patrick_hand": …, &"shadows": …, &"indie_flower": … }`
    - `static func font_for(id: StringName) -> FontFile` (cached) and `static func fallback_font() -> FontFile` (`res://assets/fonts/NotoSansMath-Regular.ttf` + `NotoSans-Regular.ttf` chain, both OFL; add them to fonts and CREDITS)
    - `static func layout(text: String, origin: Vector2, size_pt: float, font_id: StringName, seed: int, max_x: float) -> Array[GlyphPlacement]`: advances with each glyph's real advance; wraps at word boundaries when the next word would pass `max_x`; `\n` forces a new line; line height `1.35 * size_pt`. Jitter is seeded by `seed + glyph index` (same input → same output): rotation uniform in ±0.6°, scale ±4%, baseline offset ±0.3 pt. A character missing from the chosen font uses the first fallback font that has it (`Font.has_char`).
    - `static func auto_size(line_spacing_pt: float) -> float`: `clamp(line_spacing_pt * 0.62, 9.0, 28.0)`; when no spacing is known, callers use 14.0.

- [ ] **Step 1:** Download the TTFs from `github.com/google/fonts` (`ofl/<family>/`) and Noto Sans / Noto Sans Math from `github.com/notofonts`. Add them and the CREDITS entries.
- [ ] **Step 2: Write the failing tests**: `test_deterministic` (two layouts of `"hello"` with seed 7 are equal in pos, rot and scale), `test_jitter_within_bounds` (200-char string: every `abs(rot_deg) <= 0.6`, `abs(scale - 1) <= 0.04`), `test_wraps_at_max_x` (long sentence with `max_x = origin.x + 150` → some glyph has `line == 1` and no glyph's `pos.x > max_x`), `test_newline_moves_down_one_line_height` (`"a\nb"` at 20 pt → `b.pos.y - a.pos.y` within 0.31 of 27.0), `test_missing_glyphs_use_fallback` (for each of `é √ ² π θ ≤`: the placement's `font.has_char(ch.unicode_at(0))` is true), `test_auto_size` (`auto_size(24) == 14.88`, `auto_size(4) == 9.0`, `auto_size(80) == 28.0`).
- [ ] **Step 3:** Run. Expected: FAIL.
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** Run. Expected: PASS.
- [ ] **Step 6: Commit** — `feat: handwriting layout with jitter, wrapping and glyph fallback`

---

### Task 9: Quick Fill (`BubbleDetector`, `ScribbleGen`)

**Files:**
- Create: `systems/writing/bubble_detector.gd`, `systems/writing/scribble_gen.gd`, `tests/unit/test_bubble_detector.gd`, `tests/unit/test_scribble_gen.gd`

**Interfaces:**
- Consumes: `PdfDoc.text_boxes`, `PdfDoc.render_page`, `Stroke`.
- Produces:
  - `class_name BubbleDetector` (static):
    - `const FALLBACK_DIAMETER_PT := 25.51`
    - `static func from_text_boxes(boxes: Array[Rect2], at_pt: Vector2) -> Rect2`: if a box of a single letter A–E (width and height 4–20 pt) is within 12 pt of `at_pt`, return a square centered on that box with side `max(w, h) * 1.6`; else `Rect2()`.
    - `static func from_image(img: Image, px_per_pt: float, at_pt: Vector2) -> Rect2`: scan a 40×40 pt window around `at_pt`; find the darkest-ring circle with radius 4–14 pt (test radii in 0.5 pt steps, score = mean darkness on the ring minus mean darkness 2 px inside); accept when the score > 0.25; return its bounding square in pt; else `Rect2()`.
    - `static func find(doc: PdfDoc, page: int, img: Image, px_per_pt: float, at_pt: Vector2) -> Rect2`: text boxes first, then image, then a fallback square of `FALLBACK_DIAMETER_PT` centered on `at_pt`. Never returns an empty rect.
  - `class_name ScribbleGen` (static): `static func scribble_for(rect: Rect2, seed: int) -> Stroke`: a PENCIL stroke of zig-zag loops that covers ≥ 85% of the inscribed ellipse at width 2.2 pt, staying inside `rect.grow(-0.5)`; deterministic per seed. `Stroke.t_start` is left for the caller.

- [ ] **Step 1: Write the failing tests**: `test_text_box_snap` (box for "B" at `Rect2(100,200,8,10)`, click at (103,204) → returned rect centered on (104,205) with side 16), `test_text_box_ignored_when_far` (click 40 pt away → `Rect2()`), `test_image_detects_drawn_circle` (create a 300×300 white image, draw a 1.5 px dark ring of radius 20 px at (150,150), `px_per_pt = 2.0`, click at (74,76) pt → rect center within 1.5 pt of (75,75), size within 2 pt of 20), `test_image_none_on_blank` (white image → `Rect2()`), `test_find_falls_back_to_9mm` (blank image, no boxes → size `Vector2(25.51, 25.51)` centered on the click), `test_scribble_stays_inside_and_covers` (rasterize the scribble with `InkRasterizer` at 144 DPI; ≥ 85% of pixels inside the inscribed ellipse have alpha > 0.5; none outside `rect.grow(1)`), `test_scribble_deterministic`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, including against the fixtures: add `test_fixture_mc_letter_snaps` (open `mc_letter.pdf`, click the center of the first bubble at the known reportlab coordinates → the rect is within 2 pt of the drawn circle via either path), and `test_fixture_scanned_uses_image` (`scanned.pdf` has no text boxes, but the circle is still found). Expected: PASS.
- [ ] **Step 5: Commit** — `feat: Quick Fill bubble detection and scribble generation`

---

### Task 10: Paper page and test packet

**Files:**
- Create: `scenes/packet/paper_page.tscn`, `paper_page.gd`, `paper_page.gdshader`, `scenes/packet/test_packet.tscn`, `test_packet.gd`, `systems/packet/packet_state.gd`, `systems/packet/page_cache.gd`, `assets/textures/paper_fiber.png` (CC0, from ambientCG, credited), `tests/unit/test_packet_state.gd`, `tests/unit/test_page_cache.gd`

**Interfaces:**
- Consumes: `PdfDoc`, `Attempt`.
- Produces:
  - `class_name PacketState extends RefCounted` (pure): `func _init(page_count: int, scratch_count: int)`, `var current: int`, `var showing_scratch: bool`, `var scratch_index: int`, `func turn(dir: int) -> bool` (false at the ends), `func jump(i: int) -> bool`, `func toggle_scratch() -> void` (no-op when `scratch_count == 0`), `func active_target() -> Dictionary` (`{"kind": "page"|"scratch", "index": int}`), `signal changed()`
  - `class_name PageCache extends RefCounted`: `func _init(doc: PdfDoc, full_dpi: float, thumb_dpi: float = 24.0)`, `func texture_for(i: int, current: int) -> Texture2D` (full DPI for `current ± 1`, thumbnail otherwise), `func resident_full_pages() -> PackedInt32Array`. Renders run on a `WorkerThreadPool` task; until done, the thumbnail is returned.
  - `test_packet.gd` (`class_name TestPacket extends Node3D`): `func setup(doc: PdfDoc, attempt: Attempt, paper_dpi: float) -> void`; `signal page_turned(index: int)`; methods `turn(dir: int)`, `toggle_scratch()`, `set_overview(on: bool)`, `slide(delta_pt: float)` (moves the paper on the desk up/down within the page height), `func page_node(kind: String, index: int) -> PaperPage`.
  - `paper_page.gd` (`class_name PaperPage extends MeshInstance3D`): `func set_page(tex: Texture2D, size_pt: Vector2) -> void` (mesh is 1 m = 2834.65 pt scale; Letter is 0.2159 × 0.2794 m); `func ink_viewport() -> SubViewport`; shader uniforms `page_tex`, `ink_tex`, `fiber_tex`, `curl` (0–1, page-flip bend), `lift` (corner lift).
- Behavior pinned by the spec: page flip **0.45 s** (tween `curl` 0→1 while rotating around the staple edge), stapled top-left; scratch sheets lie to the right and **Tab** swaps; **hold Q** fans pages out in a grid and clicking one jumps; a page turn emits `page_turned`, which Task 13 uses to trigger an autosave.

- [ ] **Step 1: Write the failing tests**: `test_turn_bounds` (3 pages: turn(-1) at 0 is false; turn(1) twice reaches 2; third turn false), `test_toggle_scratch_no_sheets` (scratch_count 0 → `showing_scratch` stays false), `test_active_target_scratch` (after toggle → `{"kind": "scratch", "index": 0}`), `test_page_cache_keeps_neighbors_only` (open `big_120.pdf`; call `texture_for(i, 60)` for every i; `resident_full_pages()` == `[59, 60, 61]`), `test_page_cache_moves_window` (then `texture_for(10, 10)` etc. → resident becomes `[9, 10, 11]` and 59–61 are released).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `PacketState` and `PageCache` (release full images outside the window).
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Build `paper_page` and `test_packet` scenes and the shader (`albedo = page × fiber`, then ink composited as `mix(albedo, graphite, ink.a)`, graphite roughness 0.55 vs paper 0.9 for the slight sheen; vertex curl around the staple-side edge).
- [ ] **Step 6:** Manual check: a temporary `scenes/dev/packet_preview.tscn` with a camera looking down at a packet of `mixed_sizes.pdf`. Run it with `"$GODOT" --path . res://scenes/dev/packet_preview.tscn`; confirm the landscape page shows landscape, flips take about half a second, Tab swaps to scratch, Q shows the overview. Delete the preview scene after.
- [ ] **Step 7: Commit** — `feat: paper page shader and test packet with flip, overview, scratch`

---

### Task 11: Player rig, input map, pencil-tip mapping

**Files:**
- Create: `systems/player/edge_look.gd`, `systems/player/page_mapper.gd`, `systems/ink/ink_input.gd`, `scenes/player/player_rig.tscn`, `player_rig.gd`, `scenes/packet/ink_layer.gd`, `tests/unit/test_edge_look.gd`, `tests/unit/test_page_mapper.gd`, `tests/unit/test_ink_input.gd`
- Modify: `project.godot` (input map)

**Interfaces:**
- Consumes: `TestPacket`, `PaperPage`, `InkGeometry`, `UndoStack`, `Stroke`, `PageInk`.
- Produces:
  - Input actions (rebindable later): `draw` (LMB), `erase` (RMB), `quick_fill_mod` (Shift), `type_mode` (T), `turn_next` (D), `turn_prev` (A), `overview` (Q), `scratch` (Tab), `look_up` (Space), `lean_mod` (Ctrl), `undo` (Ctrl+Z), `redo` (Ctrl+Y), `hand_in` (H), `menu` (Esc), `fidget` (F), `keys_note` (F1), `raise_hand` (R).
  - `class_name EdgeLook extends RefCounted`: `var enabled := true`, `const BAND := 0.03`, `const DWELL := 0.35`; `func update(mouse_y_norm: float, delta: float) -> bool` (true once the cursor has stayed in the top 3% for 0.35 s; resets as soon as it leaves); `func reset() -> void`.
  - `class_name PageMapper` (static): `static func uv_to_pt(uv: Vector2, size_pt: Vector2) -> Vector2` (uv (0,0) top-left), `static func pt_to_uv(p: Vector2, size_pt: Vector2) -> Vector2`.
  - `class_name InkInput extends RefCounted` (`systems/ink/ink_input.gd`): the stroke-building state machine, kept separate from rendering so it is testable. `func begin(page_key: String, p: Vector2, t: float, pressure: float) -> void`, `func move(p: Vector2, t: float, pressure: float) -> void`, `func end() -> Stroke` (null if fewer than 2 points), `func cancel() -> void`, `func is_active() -> bool`.
  - `player_rig.gd` (`class_name PlayerRig extends Node3D`): `enum View { DESK, LOOK_UP, LEAN_1, LEAN_2, STANDING }`; `signal ink_committed(page_key: String, op: Dictionary)`; `func set_view(v: View)` (camera tweens **0.4 s**, ease in-out sine); while in LOOK_UP, mouse gives ±25° yaw and ±10° pitch. In DESK view the OS cursor is hidden (`Input.MOUSE_MODE_HIDDEN`) and a small 3D pencil-tip marker follows the raycast hit on the paper.
  - `ink_layer.gd` (`class_name InkLayer extends Node`): owns one `SubViewport` per page (size = page pt × paper DPI / 72) and redraws strokes with `draw_polyline_colors` and width from `widths`; `func add(s: Stroke)`, `func remove_ids(ids: PackedInt32Array)`, `func redraw_all(ink: PageInk)`.
- Behavior: `PlayerRig` owns one `UndoStack` per page key (`"page:3"`, `"scratch:0"`); Ctrl+Z / Ctrl+Y apply to the page currently in front. Right-drag erases with radius 6 pt and counts one `erase_count` per drag; Ctrl+right-drag erases typed glyphs (`InkGeometry.text_hit`); Ctrl+wheel steps LEAN 0→1→2; wheel calls `TestPacket.slide(±18 pt)`.

- [ ] **Step 1: Write the failing tests**: `test_edge_look_needs_dwell` (update(0.01, 0.2) false, update(0.01, 0.2) true), `test_edge_look_resets_when_leaving` (0.2 in band, 0.1 at y=0.5, 0.2 in band → false), `test_edge_look_disabled` (enabled=false → always false), `test_uv_round_trip` (Letter: uv (0.5,0.25) → (306,198) and back), `test_ink_input_builds_stroke` (begin + 3 moves + end → 4 points, widths within `width_for_speed` bounds), `test_ink_input_single_click_is_null` (begin + end → null), `test_focus_loss_ends_stroke` (begin + 2 moves, then `PlayerRig.on_focus_lost(input)` → returns a 3-point stroke and `input.is_active()` is false). `PlayerRig` calls this static helper from `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` so alt-tabbing mid-stroke commits the stroke instead of losing it or leaving it stuck.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `EdgeLook`, `PageMapper`, `InkInput`, then `player_rig` and `ink_layer`. Mouse motion is sampled from every `InputEventMouseMotion` (not once per frame) and `pressure` is read from the event (pen tablets).
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: player rig views, edge look, pencil input and live ink`

---

### Task 12: Typed handwriting and Quick Fill in the scene

**Files:**
- Create: `scenes/packet/handwriting_node.gd`, `systems/writing/text_entry.gd`, `tests/unit/test_text_entry.gd`
- Modify: `scenes/player/player_rig.gd` (T / double-click, Shift+click, Shift+right-click), `scenes/packet/ink_layer.gd` (draw `TextMark` glyphs)

**Interfaces:**
- Consumes: `HandwritingLayout`, `GlyphPlacement`, `BubbleDetector`, `ScribbleGen`, `TextMark`, `UndoStack`.
- Produces:
  - `class_name TextEntry extends RefCounted` (pure editing model): `func _init(mark: TextMark)`, `var caret: int`, `func insert(s: String)`, `func backspace()`, `func newline()`, `func move_caret(delta: int)`, `func revealed_count(elapsed_since_last_input_s: float, typed_total: int) -> int` (glyphs appear one per **35 ms** behind the buffer; the count never exceeds `typed_total`).
  - `handwriting_node.gd` (`class_name HandwritingNode extends Node`): draws the caret as a graphite dot of 0.9 pt radius that blinks at 1.1 s; reveals glyphs per `revealed_count`; on finish (Esc, click elsewhere, or `commit_all()`) pushes one `UndoStack` op of kind `add` or `replace`. `func commit_all() -> void` reveals everything instantly (used when the test ends).
  - Text size: `HandwritingLayout.auto_size(spacing)` where `spacing` is the median vertical gap between `PdfDoc.text_boxes` lines within 60 pt of the click, or 14.0 pt when none; Ctrl+[ and Ctrl+] change the active mark by ±1 pt (8–32).
  - Quick Fill: Shift+click → `BubbleDetector.find` → `ScribbleGen.scribble_for(rect, randi())`, revealed over **0.6 s** by drawing a growing prefix of the stroke, then committed as one `add` op. Shift+right-click → remove every stroke whose bounding box center lies inside the found rect (one `remove` op).

- [ ] **Step 1: Write the failing tests**: `test_insert_and_backspace` ("ab|" backspace → "a"), `test_newline_inserts_lf`, `test_caret_moves_clamped`, `test_reveal_lags_35ms` (`revealed_count(0.07, 10)` when 10 typed at once → 2; `revealed_count(10.0, 10)` → 10), `test_unicode_editing` (insert `"√2"` then backspace → `"√"`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `TextEntry`, then the node and the rig hooks.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Manual check in the packet preview (re-create temporarily if deleted): type an answer under question 1 of `mc_letter.pdf`, Shift-click bubble B, Shift-right-click it, undo/redo both.
- [ ] **Step 6: Commit** — `feat: typed handwriting entry and Quick Fill in the packet`

---

### Task 13: Greybox classroom, wall clock, board, test flow

**Files:**
- Create: `systems/room/wall_clock_math.gd`, `systems/room/board_text.gd`, `scenes/environments/environment_contract.gd`, `scenes/environments/greybox/greybox_classroom.tscn`, `scenes/room/wall_clock.tscn/.gd`, `scenes/room/whiteboard.tscn/.gd`, `scenes/flow/test_flow.gd`, `tools/make_bells.py`, `assets/audio/placeholder/bell_start.wav`, `bell_end.wav`, `tests/unit/test_wall_clock_math.gd`, `tests/unit/test_board_text.gd`, `tests/unit/test_flow_end.gd`
- Modify: `autoload/session.gd` (create), `project.godot` (autoload `Session`)

**Interfaces:**
- Consumes: `SessionMachine`, `ExamTimer`, `Attempt`, `AttemptStore`, `TestPacket`, `PlayerRig`, `HandwritingNode.commit_all`, `InkInput`.
- Produces:
  - `class_name WallClockMath` (static): `static func hand_angles(seconds_of_day: float) -> Vector3` (x = hour, y = minute, z = second hand, radians clockwise from 12; all sweep continuously).
  - `class_name BoardText` (static): `static func format(start_minute_of_day: int, duration_s: float) -> String` → `"Start 9:00 · End 10:00"` (12-hour clock, no AM/PM, minutes zero-padded); `static func warning(minutes_left: int) -> String` → `"15 min left"`.
  - `class_name EnvironmentContract extends Node3D`: exported `player_seat: Marker3D`, `student_seats: Array[Marker3D]`, `teacher_desk: Marker3D`, `teacher_patrol: Path3D`, `handin_path: Path3D`, `wall_clock: WallClock`, `board: Whiteboard`; `func validate() -> PackedStringArray` (names of missing nodes; empty when complete).
  - Autoload `Session`: `var machine: SessionMachine`, `var timer: ExamTimer`, `var attempt: Attempt`, `var store: AttemptStore`, `var doc: PdfDoc`; `func begin(doc: PdfDoc, options: Dictionary) -> void`, `func resume(a: Attempt) -> void`, `func finish() -> void` (commits in-progress input via `signal finishing()`, marks `attempt.finished`, archives, clears autosave, → REVIEW), `func seconds_of_day() -> float` (`start_minute * 60 + timer.elapsed()`, plus `grace_s - timer.grace_remaining()` during GRACE and OVER so the wall clock keeps moving). `begin` builds the `ExamTimer` from the options (`duration_s`, `grace_s`, `warnings`, `pausable = mode == "practice"`). When options `clock == "none"`, the wall clock node is hidden.
  - `test_flow.gd` sequence: SETTLING for **20 s** (Space skips) → write board text → play `bell_start` → "You may begin" (placeholder `Label3D` until Plan 4's speech bubble) → TESTING; on `warning(m)` update the board; on `test_ended` play `bell_end` → GRACE (or straight to HANDING_IN when grace is 0); H during TESTING or GRACE → HANDING_IN (Plan 1: a 1.0 s fade instead of the walk) → `Session.finish()`; on `grace_ended` the same path runs as the forced pickup. Autosave every **20 s** of real time and on `page_turned`.
  - Greybox room per spec §6.1 dimensions (9 × 8 m, ceiling 2.9 m), CSG boxes, 5 × 5 desks, player seat middle row one column in from the window wall, a directional "sun" from the window side at ~15° elevation, wall clock centered above the board.
  - `tools/make_bells.py`: writes two 16-bit 44.1 kHz mono WAVs of a synthesized electric school bell (a 2.4 s burst of a 20 Hz-modulated sum of partials 850/1700/2550 Hz, exponential decay). Generated audio is ours: list it in CREDITS as "generated, CC0".

- [ ] **Step 1: Write the failing tests**: `test_clock_noon` (`hand_angles(43200)` → (0, 0, 0) mod TAU), `test_clock_9_30` (`hand_angles(34200)` → hour 285° and minute 180° in radians, within 1e-4), `test_board_format` (`format(540, 3600) == "Start 9:00 · End 10:00"`, `format(765, 4500) == "Start 12:45 · End 2:00"`), `test_board_warning`, and in `test_flow_end.gd`: `test_finish_commits_active_stroke_and_text` (set up a `Session` with an attempt; start an `InkInput` stroke and a `TextEntry` with `"abc"` revealed 1 of 3; call `Session.finish()`; the archived attempt has the stroke and the full `"abc"`), `test_contract_validate_lists_missing` (an empty `EnvironmentContract` returns all 7 names; the greybox scene returns none).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement the math, board text, contract, `Session` and flow; build the greybox scene and wire the clock and board; generate bells.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Manual run with a 2-minute test and 0.5-minute grace from a temporary debug entry point (`scenes/dev/quick_test.tscn` that calls `Session.begin(PdfService.open(<mc_letter path>), {duration_s: 120, grace_s: 30})`): the bell rings, the board shows times, the clock moves, the end bell rings, H moves to review (review is a stub until Task 16).
- [ ] **Step 6: Commit** — `feat: greybox classroom, wall clock, board and test flow`

---

### Task 14: `PdfExporter` (vector test + pencil overlay + text)

**Files:**
- Create: `systems/pdf/pdf_exporter.gd`, `tests/unit/test_pdf_exporter.gd`, `tests/fixtures/golden/` (generated in Step 4)

**Interfaces:**
- Consumes: `PdfDoc.native()`, the method names in `docs/pdfium-gde-api.md`, `InkRasterizer`, `HandwritingLayout`, `Attempt`.
- Produces: `class_name PdfExporter` (static): `static func export(doc: PdfDoc, attempt: Attempt, out_path: String) -> Dictionary` → `{"ok": bool, "mode": "vector"|"images", "error": String}`.
  - For each page with ink: `add_image(InkRasterizer.rasterize(page, size, 300.0), Rect2(Vector2.ZERO, size))`; for each `TextMark`, one `add_text` per glyph from `HandwritingLayout.layout` at its `pos` with size `size_pt * scale` and color `#3B3A3C` (rotation is not supported by the extension and is dropped in export; position and size jitter are kept). Glyphs drawn with a fallback font use that font's TTF path.
  - Scratch sheets with ink are appended as new Letter pages (`create_page(Vector2(612, 792))`) with their ink.
  - On any native failure, return `ok = false` with the error. Task 15 then changes this path to retry with `FallbackPdfWriter` and return `mode = "images"`.
  - Never modify the source file: write to `out_path` only; refuse when `out_path` equals `doc.path` (`error = "same_as_source"`).

- [ ] **Step 1: Write the failing tests** (write into `user://export_test/`):
  - `test_export_adds_no_pages_without_scratch` (mc_letter + ink on page 0 → re-opened export has 2 pages)
  - `test_export_appends_scratch_with_ink` (1 scratch with a stroke → 3 pages; an empty scratch sheet is not appended)
  - `test_mark_lands_at_same_point_on_mixed_pages` (for each page of `mixed_sizes.pdf`, a 4-pt-wide stroke from (100,100) to (140,100) pt; re-render export at 72 DPI; pixel (120,100) is darker than 0.5 luminance and pixel (120,110) is lighter than 0.9 on every page, including the landscape one)
  - `test_typed_text_is_real_text` (TextMark `"cm³ per second"` → `text_boxes` of the exported page is non-empty near the origin; skip with `pending()` if Task 2 found text extraction unsupported)
  - `test_unicode_out_path` (export to `user://export_test/Zoë Документы/out.pdf` → ok, file exists)
  - `test_refuses_overwriting_source`
  - `test_golden_page` (export a fixed attempt of `mc_letter.pdf`; render page 0 at 72 DPI; compare with `tests/fixtures/golden/mc_letter_p0.png`: mean absolute per-channel difference < 2.0/255)
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Generate the golden image once with a tool script `tools/make_golden.gd`, inspect it by eye (strokes and text where expected), commit it.
- [ ] **Step 5:** Run. Expected: PASS.
- [ ] **Step 6: Commit** — `feat: PDF export with pencil overlay and real text`

---

### Task 15: `FallbackPdfWriter`

**Files:**
- Create: `systems/pdf/fallback_pdf_writer.gd`, `tests/unit/test_fallback_pdf_writer.gd`
- Modify: `systems/ink/ink_rasterizer.gd` (add `rasterize_text`), `systems/pdf/pdf_exporter.gd` (fallback path)

**Interfaces:**
- Produces: `class_name FallbackPdfWriter` (static): `static func write(pages: Array[Image], sizes_pt: Array[Vector2], out_path: String, jpeg_quality: float = 0.85) -> Error`. Writes a valid PDF 1.4: catalog, pages tree, one page per image with `MediaBox [0 0 w h]`, the image as a `/DCTDecode` XObject (`Image.save_jpg_to_buffer`) drawn full-page, a correct `xref` table with 10-digit byte offsets and a trailer.
- Adds to `InkRasterizer` (Task 7's file): `static func rasterize_text(img: Image, placements: Array[GlyphPlacement], size_pt: float, dpi: float, color: Color) -> void`. It blits each glyph from the font's CPU glyph cache (`FontFile.render_glyph`, `get_glyph_texture_idx`, `get_texture_image`, `get_glyph_uv_rect`, `get_glyph_offset`), which works headless because FreeType rasterizes on the CPU. Glyph rotation is ignored; position and scale are kept.
- In fallback mode `PdfExporter` renders each source page at 200 DPI, then blends `InkRasterizer.rasterize` and `rasterize_text` output on top, and passes the images here.

- [ ] **Step 1: Write the failing tests**: `test_rasterize_text_draws_inside_line` (place `"Hi"` at (72,100) pt size 20 on a transparent Letter image at 72 DPI → some pixel in `Rect2(72, 80, 30, 24)` has alpha > 0.5 and pixel (300,300) has alpha 0), `test_writes_openable_pdf` (two 200×300 images, sizes Letter and A4 → re-open with `PdfDoc.open`: 2 pages, sizes match within 1 pt), `test_header_and_eof` (file starts with `%PDF-1.4` and ends with `%%EOF` plus optional newline), `test_xref_offsets_point_at_objects` (parse the xref; each offset starts with `"%d 0 obj" % n`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: pure-GDScript fallback PDF writer`

---

### Task 16: Settings, theme, main menu, pre-test

**Files:**
- Create: `systems/settings_store.gd`, `autoload/settings.gd`, `scenes/ui/theme/cozy_theme.tres`, `scenes/ui/main_menu.tscn/.gd`, `scenes/ui/pre_test.tscn/.gd`, `scenes/ui/settings_panel.tscn/.gd`, `scenes/main.tscn/.gd`, `tests/unit/test_settings_store.gd`, `tests/unit/test_pretest_options.gd`
- Modify: `project.godot` (autoload `Settings`)

**Interfaces:**
- Produces:
  - `class_name SettingsStore extends RefCounted`: `const DEFAULTS := {` `"writing/hand": "right", "writing/font": "caveat", "input/mouse_sensitivity": 1.0, "input/edge_look": true, "graphics/preset": "medium", "graphics/fov": 70, "test/duration_min": 60, "test/grace_s": 90, "test/scratch_sheets": 1, "test/warnings": [15, 5], "test/clock": "wall", "test/mode": "practice", "test/class_size": 16, "test/start_minute": 540, "recent/pdfs": [] }`; `func get_value(key: String) -> Variant`, `func set_value(key: String, v: Variant) -> void`, `func save(path: String = "user://settings.cfg") -> Error`, `func load(path: String = "user://settings.cfg") -> void` (unknown keys ignored, missing keys fall back to defaults), `func push_recent(path: String) -> void` (front, dedupe, max 5).
  - `class_name PretestOptions` (in `scenes/ui/pre_test.gd`'s helper `systems/pretest_options.gd`): `static func from_settings(s: SettingsStore) -> Dictionary` and `static func validate(d: Dictionary) -> String` (empty when ok; `"Choose a time between 5 and 300 minutes."` for custom times out of range).
  - Theme per Global Constraints (Fraunces headings, Atkinson body, paper card style with 4 px radius, pill chips with the yellow `on` state, primary button in ink on paper).
  - Main menu card: "New test", "Resume" (only when `AttemptStore.load_autosave()` is non-null), "History", "Settings", "Quit". The background is the greybox classroom with a slowly drifting camera and a 7 px blur post effect.
  - Pre-test card (spec §4.1): drop zone (accepts OS file drop via `get_window().files_dropped` and a native `FileDialog` with `use_native_dialog = true`, filter `*.pdf`), recent list (5), file name + page count + thumbnails (24 DPI), time chips 30/45/60/75/90/120/Custom, "Take your seat", collapsed "More options" with every option in spec §4.1. Errors from `PdfService.last_error` show on the card with the exact spec copy: encrypted → "This PDF is password-protected; remove the password and try again."; corrupt or missing → "Couldn't open this PDF." with a collapsible detail line.
  - Settings panel (Plan 1 subset): writing hand, handwriting font (live preview line), mouse sensitivity, edge look on/off. Saved on change.

- [ ] **Step 1: Write the failing tests**: `test_defaults` (fresh store → `get_value("test/grace_s") == 90`, `"writing/font" == "caveat"`), `test_save_load_round_trip` (temp path), `test_unknown_and_missing_keys` (a cfg with an unknown key and no `test/mode` → loads, mode `"practice"`), `test_recent_dedupe_max5` (push 7 paths with one repeat → 5 entries, newest first, no duplicates), `test_options_from_settings`, `test_validate_custom_time` (3 → error copy above; 90 → `""`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement the store, options helper and autoload; build the theme and the three UI scenes and `main.tscn`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Manual check: launch the project, drop `mc_letter.pdf` on the window, pick 30 min, press "Take your seat"; try `encrypted.pdf` and see the exact message.
- [ ] **Step 6: Commit** — `feat: settings store, cozy theme, main menu and pre-test`

---

### Task 17: Review, stats, marking prompt, history

**Files:**
- Create: `systems/review/page_time_tracker.gd`, `systems/review/marking_prompt.gd`, `scenes/ui/review.tscn/.gd`, `scenes/ui/history.tscn/.gd`, `tests/unit/test_page_time_tracker.gd`, `tests/unit/test_marking_prompt.gd`
- Modify: `scenes/flow/test_flow.gd` (tick the tracker), `autoload/session.gd` (store `page_time_s` on the attempt)

**Interfaces:**
- Consumes: `Attempt`, `AttemptStore`, `PdfExporter`, `PdfDoc`, `InkRasterizer`.
- Produces:
  - `class_name PageTimeTracker extends RefCounted`: `func _init(page_count: int)`, `func tick(delta: float, target: Dictionary) -> void` (counts only when `target.kind == "page"`), `func totals() -> PackedFloat32Array`.
  - `class_name MarkingPrompt` (static): `static func build(test_title: String, page_count: int) -> String`. Exact copy:
    ```
    I just finished a practice test called "{title}" ({pages} pages). I've attached my completed test as a PDF. My pencil work is drawn on the pages and my typed answers are real text. I've also attached the answer key.

    Please mark it question by question:
    1. For each question, say whether my answer is correct, partly correct, or wrong.
    2. For anything not fully correct, explain the mistake briefly and show the right method.
    3. Give my total score and percentage.
    4. List the topics I should review, most important first.
    ```
  - Review screen (spec §4.4): page viewer (page rendered at 110 DPI with the ink overlay from `InkRasterizer` at the same DPI), page strip, zoom (fit / 100% / 200%), stats (time used `mm:ss`, time per page, erasures), buttons **Save PDF…** (native save dialog, default name `<test-title>-attempt-<YYYY-MM-DD>.pdf`; shows "Exported as images" under the button when `mode == "images"`; on error shows the message and keeps the screen open), **Copy marking prompt** (`DisplayServer.clipboard_set`, button text changes to "Copied" for 2 s), **Retake**, **Back to menu**.
  - History list: test title, date, time used; clicking opens Review for that attempt (re-opening the PDF by path; if it moved, show "Can't find the original PDF at <path>." and offer "Locate…").

- [ ] **Step 1: Write the failing tests**: `test_tracks_only_pages` (tick 5 s on page 0, 3 s on scratch, 2 s on page 1 → `[5, 2]`), `test_prompt_copy` (`build("Unit 3", 4)` starts with `I just finished a practice test called "Unit 3" (4 pages).` and contains `4. List the topics I should review, most important first.`), `test_prompt_escapes_quotes` (title `Bob's "final"` appears verbatim).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement the tracker and prompt; build Review and History.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Manual check: finish a 2-minute test with a few marks, save the PDF, open it in a normal PDF reader (Edge or SumatraPDF): marks and typed text appear where they were made; select the typed text in the reader.
- [ ] **Step 6: Commit** — `feat: review screen, stats, marking prompt and history`

---

### Task 18: Crash resume and Strict mode

**Files:**
- Create: `tests/unit/test_resume.gd`
- Modify: `autoload/session.gd`, `scenes/main.gd`, `scenes/ui/main_menu.gd`, `scenes/flow/test_flow.gd`

**Interfaces:**
- Consumes: `AttemptStore.load_autosave`, `ExamTimer.from_dict`, `Session.resume`.
- Produces: "Resume test in progress" on the main menu restores the attempt (ink, text, page, timer) and goes straight to TESTING (or GRACE) without the settling sequence and without re-ringing the start bell. Esc in **Practice** pauses the timer and opens the settings panel; in **Strict** it opens the panel with the line "The clock is still running." and the timer keeps counting.

- [ ] **Step 1: Write the failing tests**: `test_resume_restores_remaining_time` (attempt with timer at 1,000 s elapsed of 3,600 saved → `Session.resume` → `timer.remaining() == 2600`), `test_resume_in_grace` (saved during GRACE → phase GRACE, grace remaining preserved), `test_resume_restores_ink` (strokes and texts counts match), `test_strict_mode_not_pausable` (options mode `strict` → `timer.pausable == false`).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Manual check: start a test, draw, wait 25 s, kill the process from Task Manager, relaunch → Resume restores the marks and time.
- [ ] **Step 6: Commit** — `feat: crash resume and strict mode`

---

### Task 19: Release builds, README, credits

**Files:**
- Create: `export_presets.cfg`, `.github/workflows/release.yml`, `tools/build_pdfium_gde.sh`
- Modify: `README.md`, `CREDITS.md`, `.github/workflows/test.yml` (build PDFium-GDE for Linux before tests)

**Interfaces:**
- Produces: tagged pushes (`v*`) build Windows (x86_64 `.zip`), macOS (universal `.zip`, unsigned) and Linux (x86_64 `.tar.gz`) and attach them to a GitHub Release. `tools/build_pdfium_gde.sh <platform>` clones PDFium-GDE at a pinned commit (record the hash in the script), builds `template_release`, and copies the PDFium library next to the binary.

- [ ] **Step 1:** Write `tools/build_pdfium_gde.sh`; use it in both workflows (Linux in `test.yml`; one job per OS in `release.yml` on `windows-latest`, `macos-latest`, `ubuntu-latest`).
- [ ] **Step 2:** Create the three export presets with the PDFium-GDE libraries included for each platform.
- [ ] **Step 3:** Write the README: what it is (one paragraph + a screenshot placeholder replaced in Plan 4), download links to Releases, how to play (the controls table from spec §5.8, marked "Plan 1 build" where features are still placeholders), adding your own tests ("use tests you have the right to use"), macOS Gatekeeper steps (right-click → Open), building from source, license.
- [ ] **Step 4:** Check `CREDITS.md` lists every font, the paper fiber texture, PDFium, PDFium-GDE, GUT and the generated bells.
- [ ] **Step 5:** Verify locally: run all tests (PASS), and export the Windows build with `"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/PencilsDown.exe`; launch it and complete a 2-minute test end to end, including Save PDF.
- [ ] **Step 6: Commit** — `build: export presets, release workflow, README and credits`
