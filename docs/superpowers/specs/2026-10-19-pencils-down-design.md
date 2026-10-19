# Pencils Down — Design Document

*A realistic, first-person test-taking simulator.*

| | |
|---|---|
| **Status** | Draft for review |
| **Date** | 2026-10-19 |
| **Engine** | Godot 4.7 (GDScript), desktop: Windows, macOS, Linux |
| **License** | Code MIT; assets CC0 / CC-BY only (credited in `CREDITS.md`) |
| **Repo** | Public on GitHub, with prebuilt releases for all three platforms |

---

## 1. Goal

Make practice tests feel like the real thing. You sit at a desk in a real-looking classroom on a quiet
morning. The bell rings, the room fills with pencil scratching, the wall clock keeps moving, and you work
through a real past or sample test that you loaded from a PDF. When the end bell rings you get a short grace
period, walk up and hand it in, then get back a PDF of the test with your answers on it. You can keep it or
give it to an AI (or a person) to mark.

The point is **exam conditioning**. Timed practice at home on a laptop doesn't recreate the pressure, noise,
pacing and physical feel of an exam room. Pencils Down does, so that the real exam feels familiar.

### 1.1 Who it's for
Students preparing for multiple-choice exams (SAT/ACT/AP, state and provincial exams), math and science
tests (showing work, diagrams, graphs), and mixed class unit tests. Anyone can use it for free: download a
release from GitHub, load a PDF, and start.

### 1.2 Success criteria
- Loading a PDF to sitting at a desk with the test in front of you takes **under 30 seconds** and
  one screen of choices.
- Bubbling an answer, showing math work and writing a short answer each feel as fast as on paper. No
  answer type forces the player out of first-person view.
- On a 2020-era laptop with integrated graphics (Intel Iris Xe class) at 1080p, the **Medium** preset holds
  a steady **60 fps**, and **Low** holds 60 fps on a 2017-era integrated GPU (Intel UHD 620 class).
- The exported PDF keeps the original test as vector content and puts the player's marks exactly where
  they were made.
- A first-time player can find every control without leaving the classroom, through the desk sticky note
  (§7.3).
- Nothing on screen during the test looks like a "game HUD".

### 1.3 Non-goals (for the first build)
- No answer key, no auto-grading, no score. Marking happens outside the app (AI or human) using the export.
- No multiplayer, VR, mobile or web builds.
- No tests other than PDFs (no Word or image import in v0.1).

---

## 2. Reference & mood

Reference photos (Unsplash License; linked for inspiration only, not shipped):

| Reference | What we take from it |
|---|---|
| [Sunlight across an empty classroom — UThan Zaw](https://unsplash.com/photos/sunlight-streams-into-an-empty-classroom-with-desks-SBN9x6Tecxs) | **The key image for the v0.1 room.** Low morning sun from the side windows throws bright rectangles across beige painted walls while the rest of the room stays in soft shadow. 2×4 acoustic drop-ceiling tiles with fluorescent/LED panels, slightly warm. Posters and a laminated notice on the wall, a potted plant near the window, a pedestal fan. Laminate desks on steel legs with dark plastic chairs. Fine film grain and gently crushed blacks: *photographed*, not rendered. |
| [Classroom with roller shades — Allen Y (Waterloo, Canada)](https://unsplash.com/photos/an-empty-classroom-with-tables-and-chairs-0rPuGQ5Wu7A) | Big window bands with **roller shades pulled half down**, cream window frames, a brick building visible outside. **Polished vinyl tile floor** with long glossy reflections of the windows, which justifies screen-space reflections on High and reflection probes on Low. Sled-base chairs with mesh backs. |
| [Japanese classroom — "an empty classroom with desks and a chalkboard"](https://unsplash.com/photos/an-empty-classroom-with-desks-and-a-chalkboard-nkgAw4SFsWM) | **Future environment** (see §12): tall steel-framed windows over a dirt schoolyard, wooden flip-top desks, a green chalkboard with a ledge, a radiator under the sill, wood-strip floor. Kept here so the environment system is designed for it from day one. |

### 2.1 Visual pillars
1. **Light does the realism.** One low, warm sun (≈ 08:30, about 15° elevation) coming through the side
   windows, plus slightly cool fill from the ceiling panels. Contrast between sunlit patches and soft shade
   is the main feature of the look. Lighting is **baked** (LightmapGI), so even Low settings keep soft
   bounce light and contact shadows.
2. **Lived-in, not staged.** Backpacks leaning on chair legs, water bottles, a hoodie over a chair back, a
   slightly crooked poster, scuffs on the floor tiles, a coffee mug on the teacher's desk, a dusty fan.
3. **A photographic finish.** Filmic tonemapping (AgX), slight vignette, subtle grain, gentle bloom on the
   windows, and a shallow depth of field when looking down at the paper. Never stylized, oversaturated, or
   cel-shaded.
4. **The paper is the hero.** The test sheet gets the most texture resolution and the best shading: paper
   fiber, faint toner, graphite that sparkles a little at grazing angles, real smudges when you erase.

### 2.2 Palette (from the refs)
| Role | Hex | Use |
|---|---|---|
| Painted block wall | `#D8CDB8` | walls |
| Sun patch | `#F6DDB0` | warm light tint |
| Ceiling tile | `#E9E6DF` | ceiling |
| VCT floor | `#B9AE9C` speckled | floor |
| Desk laminate | `#C9A57A` | desk tops |
| Chair plastic | `#2F3236` | chairs |
| Whiteboard tray / trim | `#8E8F8C` | metal trim |
| Paper | `#F7F4EC` | test sheets |
| Graphite | `#3B3A3C` | pencil marks |
| Pencil yellow | `#E8B33A` | pencil, UI accent |

---

## 3. Technology

### 3.1 Engine: Godot 4.7 (GDScript)
- Free and open source (MIT) with no licensing strings, which suits a public GitHub project.
- Small builds (~100 MB) that run on modest hardware.
- **Forward+** renderer for Medium/High/Ultra; **Compatibility** renderer (OpenGL 3.3) offered as a
  "Low / older GPU" option that takes effect after a restart (Godot picks the renderer at launch;
  settings write `--rendering-method` into the launcher config).
- GDScript keeps the project easy for contributors. No C# or .NET dependency.

### 3.2 PDF pipeline: PDFium-GDE
[PDFium-GDE](https://store.godotengine.org/asset/aliarcanakgun/pdfium-gde/) (Zlib license; PDFium itself
is Apache-2.0) is a GDExtension wrapping Google's PDFium for Godot 4.5+. It provides:
- loading PDFs from absolute paths;
- rendering a page to a Godot `Image` at any DPI, which becomes the paper texture;
- extracting text with bounding boxes (used later for the AI teacher's context and for bubble snapping);
- inserting paths, images and text (with custom fonts) into pages and saving, which is how the export
  works.

**Risk:** the extension's v1.1 is marked unstable by its author. Mitigation:
1. All PDF access goes through one interface, `PdfService` (§5.2), so the backend can be swapped.
2. **The first implementation task is a spike** that checks load, render and export on Windows, macOS
   and Linux with Godot 4.7, using three real test PDFs (a scanned exam, a text-based exam, a big-image
   exam).
3. **Fallback exporter:** a small pure-GDScript PDF writer that saves each page as a flattened JPEG
   (rendered page with ink composited on top). It is less elegant (not vector) but only needs page
   rendering, so it works anywhere rendering works.
4. **We build the extension ourselves.** PDFium-GDE builds from source with SCons, so CI compiles it for
   all three platforms instead of relying on the author's prebuilt binaries. If rendering itself is broken
   on a platform, we fix it in a fork (Zlib allows this) before building anything else.

### 3.3 Other building blocks
| Need | Choice |
|---|---|
| Unit tests | [GUT](https://github.com/bitwes/Gut) (Godot Unit Test) |
| IK for hands and heads | Godot's `SkeletonModifier3D` IK nodes (two-bone IK, look-at) |
| Builds | GitHub Actions + Godot headless export, with artifacts attached to GitHub Releases |
| File dialogs | Godot `FileDialog` with `use_native_dialog = true` (OS-native picker) |
| AI teacher (v0.2) | `HTTPRequest` to the Gemini API (Google AI Studio key) behind a provider interface |

---

## 4. Experience walkthrough

### 4.1 Launch → pre-test (one screen)
The app opens on a **live, slowly drifting shot of the empty morning classroom**, softly blurred, with one
paper-card panel on top (see §7). The pre-test card has, top to bottom:

1. **Test PDF**: a drop zone ("Drop a PDF here or click to choose"). Once loaded it shows the file name,
   page count and a strip of page thumbnails. The last 5 tests used are one click away.
2. **Time**: chips for `30` `45` `60` `75` `90` `120` minutes plus "Custom". The default is the last
   value used.
3. **Start**: a big button, "Take your seat".
4. **More options** (collapsed by default):
   - Grace period after the bell: 0 / 1 / 1.5 / 2 min (default 1.5).
   - Scratch paper: off / 1 sheet / 2 sheets (default 1).
   - Time warnings from the teacher: none / 15 & 5 min / 30, 15 & 5 min (default 15 & 5).
   - Clock in the room: wall clock (default) / no clock (challenge).
   - Mode: **Practice** (Esc pauses the clock) or **Strict** (Esc opens settings, but time keeps running).
   - Class size: small (8) / normal (16) / full (24) students.
   - Start time shown on the clock: default 9:00 AM.

Everything is remembered, so a returning player only drops a PDF and presses Start.

### 4.2 Settling in (~20 s, skippable with Space)
Fade in, seated at the desk (middle row, slightly off-center, so most of the room and the clock are
visible when you look up). Other students settle, chairs scrape, someone unzips a bag. The teacher walks
the rows placing tests **face-down** on desks, ending at yours: the packet slides onto your desk. The teacher
writes on the whiteboard:

> **Start 9:00 · End 10:00**
> *No talking. Raise your hand if you have a question.*

### 4.3 The test
**Start bell.** The teacher says "You may begin" (speech bubble, §7.4). The packet flips face-up and the
room's pencil noise swells.

**Desk view** is the default. The camera looks down at the packet with a soft depth of field around the
paper edges. Your writing hand rests near the paper holding the pencil, and the cursor *is* the pencil tip
(no arrow cursor anywhere during the test).

**Looking up.** Hold **Space**, or rest the cursor against the top edge of the screen for 0.35 s, and the
camera eases up over 0.4 s to a natural seated view of the room: the clock above the whiteboard, students
working, the teacher at their desk. Release Space or move the cursor back down and the camera eases back
to the paper. While looking up, the mouse gives a little free-look (±25° yaw, ±10° pitch). Edge-look can be
turned off in settings for people who write near the top of the page a lot.

**Time warnings.** At the configured times the teacher says "Fifteen minutes left" (speech bubble, soft
murmur sound) and updates the board: *"15 min left"*.

**End bell → grace period.** The bell rings and the teacher says "Pencils down, please. Bring your tests up
when you're done." The grace countdown is never shown as a number. Instead the room acts it out: students
stand up row by row and walk to the front, and the teacher stacks papers. You can keep writing.

**Handing in.** Press **H** (or click the "Hand in" prompt that the sticky note shows during the grace
period). The camera stands up, walks a short scripted path to the teacher's desk (~5 s, head-bob off by
default), and your hand passes the packet over. If the grace time runs out first, the teacher walks over and
collects it from your desk ("Time's up, I'll take that.").

### 4.4 Review
A fade to a calm review screen (paper-card style, §7), showing:
- **Pages** at full resolution with your marks, a page strip and zoom.
- **Stats**: time used, time spent on each page (tracked by which page was on top), number of erasures,
  and (v0.2) questions asked of the teacher.
- **Actions:**
  - **Save PDF…** (native save dialog; default name `<test>-attempt-<date>.pdf`).
  - **Copy marking prompt**: puts a ready-made prompt on the clipboard for an AI (Gemini, Claude, ChatGPT)
    such as *"Here is my completed test and the answer key. Mark it question by question…"* so you only
    attach the exported PDF and your answer key.
  - **Retake** (same PDF, blank) and **Back to menu**.
- Every attempt is saved to `user://attempts/` (strokes, text, timeline, settings) so it can be reopened
  from **History** in the main menu.

---

## 5. The test-writing system (core)

This is the most important part of the product. It needs to be fast, precise and convincing.

### 5.1 The packet
- Each PDF page is rendered by `PdfService` to an `Image` at the quality-setting DPI (Low 110, Medium 150,
  High 200, Ultra 250), stored as a mipmapped texture on a thin paper mesh with a slight curl and corner lift.
- The packet is **stapled top-left**. **Turning a page:** press **D** / **A**, or click and drag the bottom
  right page corner. The page flips over the staple in a 0.45 s cloth-like bend (vertex-shader page curl),
  with a paper sound.
- **Scratch paper** sheets lie loose to the right of the packet. **Tab** slides the packet aside and pulls
  scratch paper in front; **Tab** again swaps back.
- **Mouse wheel** slides the paper up and down on the desk to reach the bottom of a page (the hand moves the
  paper, which feels physical). **Ctrl + wheel** leans in or out (camera dolly, 3 levels).
- **Page overview:** hold **Q** to fan the packet out and see all pages small; click one to jump to it.

### 5.2 Ink model
All marks are stored as **vector data in PDF page coordinates** (points, origin bottom-left), never as
pixels:

```
Stroke { id, page, tool: PENCIL|ERASER, points: PackedVector2Array, widths: PackedFloat32Array, t_start }
TextMark { id, page, origin: Vector2, font_size_pt, font_id, text: String, glyph_seeds: PackedInt32Array }
```

- **Rendering:** each page has an ink `SubViewport` that redraws only dirty regions. The paper shader
  combines `page_texture × paper_fiber`, then graphite ink (darkened, slightly specular, grain-modulated).
- **Undo / redo:** **Ctrl+Z** / **Ctrl+Y**, per page, unlimited during the session.
- **Autosave:** the whole attempt is serialized to `user://autosave.json` every 20 s and on each page turn.
  After a crash, the main menu offers "Resume test in progress" (the clock resumes from the saved
  remaining time).

### 5.3 Pencil
- **Left-drag** draws. Stroke width varies slightly with speed (faster is thinner). Pen tablets use real
  pressure (`InputEventMouseMotion.pressure`).
- Strokes are smoothed with a short Catmull-Rom spline, enough to look like graphite without lagging behind
  the cursor. Input is sampled every frame and at the OS event rate, so fast scribbles stay smooth.
- The **hand follows the tip** through IK. Wrist and forearm move naturally and the visible pencil tilts as
  real pencils do. Left-handed mode mirrors everything (Settings → Writing hand).
- **Pencil sound:** a granular graphite scratch whose loudness and pitch follow stroke speed.

### 5.4 Eraser
- **Right-drag** erases. The hand flips the pencil (0.2 s) to use the eraser end and flips back on release.
- Erasing removes stroke segments geometrically, and the paper shader leaves a faint ghost and smudge where
  graphite was erased. That is realistic, and it is cosmetic only: the export stays clean.
- **Ctrl+right-drag** erases typed text characters under the eraser.

### 5.5 Multiple choice: Quick Fill
Hand-shading forty bubbles is realistic but tedious, so:
- **Shift + click** a bubble and the hand scribbles it in (≈0.6 s animation, a real scribble stroke saved as
  ink). The bubble's size and center are snapped from the PDF's **text-extraction boxes** when the bubble is a
  letter in a circle, or found by a quick local circle detection on the rendered page image. If neither finds
  anything, a standard 9 mm filled ellipse is used centered on the cursor.
- **Shift + right-click** a filled bubble erases it cleanly.
- Ordinary pencil shading still works for people who prefer it.

### 5.6 Typed answers in handwriting
For short answers and labels:
1. Press **T** (or **double-click** on the paper) where the answer should go. A small graphite **caret dot**
   appears at that spot: no box, outline or panel.
2. Type. Letters appear in a **handwriting font** as the hand writes them: each glyph appears ~35 ms after
   the previous one while the hand moves along the line (the hand position is driven by the glyph's
   coordinates). Typing faster than the hand writes is fine; the text buffer runs ahead and the hand catches
   up, so typing never feels laggy.
3. **Realism:** each glyph gets a per-character seeded jitter (±0.6° rotation, ±4% scale, ±0.3 pt baseline
   drift) and a graphite texture, so the same letter never looks identical twice. The text **auto-sizes to
   the page's line spacing**: it detects the nearest ruled line or text-line height from the PDF text boxes,
   and **Ctrl+[ / ]** resizes manually.
4. **Enter** starts a new line (wrapping is automatic at the page margin), **Esc** or clicking elsewhere
   finishes. Clicking existing handwriting while pressing T puts the caret back into it for editing (a faint
   underline appears on hover in T mode only).
5. **Handwriting fonts** (all SIL OFL): *Caveat*, *Kalam*, *Patrick Hand*, *Shadows Into Light*, *Indie
   Flower*. Chosen in Settings → Writing, with a live preview line.

### 5.7 Fidget
**F** plays a pencil fidget with the writing hand. Each press picks one at random, without repeats:
- **Thumb-around spin** (the classic pen spin around the thumb, 0.9 s),
- **Finger twirl** (walks across index→middle→ring fingers and back),
- **Desk tap** (a quick rhythm of eraser taps, with sound),
- **Flip-catch** (a small toss and catch).

Holding **F** loops gentle fidgets until released. Clicking cancels any fidget instantly (blended out over
0.1 s) so it never gets in the way of writing. Animations are hand-keyframed on the player hand rig with
secondary motion on the pencil.

### 5.8 Controls summary
| Action | Default |
|---|---|
| Write / erase | Left-drag / Right-drag |
| Quick-fill bubble / clear | Shift + click / Shift + right-click |
| Type answer | T or double-click |
| Turn page | D / A, or drag page corner |
| Page overview | Hold Q |
| Scratch paper ↔ test | Tab |
| Slide paper / lean in | Wheel / Ctrl + wheel |
| Look up | Hold Space, or cursor to top edge |
| Undo / redo | Ctrl+Z / Ctrl+Y |
| Fidget | F |
| Raise hand (v0.2) | R |
| Hand in (grace period) | H |
| Sticky note (keys) closer | Hold F1 |
| Menu / pause | Esc |

All bindings can be changed in Settings → Controls.

---

## 6. The room

### 6.1 Environment: "Morning Classroom" (v0.1)
A typical North American secondary classroom, about 9 × 8 m, ceiling 2.9 m:
- **Front:** a whiteboard with an aluminum tray (markers, eraser), a projector screen rolled up above, an
  **analog wall clock** centered above the board, a PA speaker, a flag, and the bell (an off-screen hallway
  bell, heard through the door).
- **Teacher area:** a wooden teacher's desk with a monitor, a stack of papers, a coffee mug and a pen cup;
  a rolling chair.
- **Window wall (left):** 3 large window bays, roller shades at uneven heights, morning sun coming in at
  ~15°, an HVAC unit under the sills, plants on the sill. Outside: a parking lot, trees and a brick wing of
  the school, made as a high-resolution matte with parallax plus swaying tree cards.
- **Back and right walls:** a bulletin board, curriculum posters, a door with a narrow window to the hallway,
  coat hooks, a pencil sharpener, a recycling bin.
- **Students' area:** 5 columns × 5 rows of separate desks (laminate top, steel legs, book box) with
  sled-base chairs. Unused desks stay empty, which looks natural.

### 6.2 Models & where they come from

| Asset | Source / approach |
|---|---|
| Room shell, windows, ceiling, troffers | Modeled for this project in Blender (modular kit) |
| Materials (paint, VCT, laminate, metal, fabric, paper) | [ambientCG](https://ambientcg.com) and [Poly Haven](https://polyhaven.com) textures (CC0) |
| Desks, chairs, teacher desk, whiteboard, clock, props | Modeled for this project in Blender from the reference photos; small props from Poly Haven models (CC0) where suitable |
| Students and teacher | Generated with **MPFB 2** (MakeHuman for Blender). Its base mesh, targets and skins are CC0. 10 student variants + 1 teacher, with varied body shapes, skin tones, hair, glasses and clothing (hoodies, t-shirts, flannels, uniforms later) |
| Player arms and hand | MPFB 2 arms, higher-detail hand, cut at the shoulder |
| Pencil | Modeled for this project: hexagonal yellow #2 with a crimped ferrule, pink eraser, sharpened cedar tip, subtle paint wear |
| Sounds | [Freesound](https://freesound.org) recordings with the **CC0** license filter, plus our own recordings |
| Fonts | Google Fonts, SIL OFL |

Licensing rule: **only CC0, CC-BY, or OFL assets** go into the repo, each listed in `CREDITS.md` with its
source URL. No Mixamo, store-asset, or unclear-license content. Raw `.blend` sources live in `/art-src/`
so anyone can edit them.

**Pipeline.** Blender 4.x, with scripted export to `.glb` and LODs generated by Godot's importer. Characters
share one skeleton (MPFB's game-engine rig) so all animations work on all bodies.

### 6.3 Students (NPCs)
Students are what makes the room feel alive. Each one runs a small behavior loop:

| State | Animation | Share of time |
|---|---|---|
| Writing | procedural: hand IK traces scribble paths over their paper, head tracks the hand | 55% |
| Reading / thinking | chin on hand, pencil tap, staring at the page | 25% |
| Erasing | quick rub, brushing crumbs off | 6% |
| Page turn | flips their packet | 5% |
| Glance | looks at the clock, stretches, rolls neck, shifts in chair | 7% |
| Rare | sneeze or cough, drops the pencil and picks it up, sighs, sharpens a pencil (walks to the sharpener) | 2% |

- **Base poses** (sitting, sitting forward, leaning back) are keyframed. **Procedural IK layers** (writing
  hand, head look-at, breathing, weight shifts) sit on top, so no two students ever move in sync.
- **Sounds are driven by animation** (writing, erasing, page turns, chair creaks), using 3D-positioned audio
  on each student. The writing you hear is the writing you see.
- **Pacing:** students drift through the test at different speeds (their visible page count), and some stand
  up early in the grace period. With "Full" class size, a few finish early and sit with arms crossed.
- **Performance:** animation updates are throttled for students out of view or far away (30/15 Hz), there
  are mesh LODs, and only the sun casts real-time shadows on characters (on High and above).
- **Avoiding the uncanny valley:** the player sees most students from behind or the side at 2–6 m. Faces get
  care where they are visible (front-row students glancing back, the teacher). On High, skin uses
  subsurface scattering.

### 6.4 Teacher (v0.1: proctor without AI)
- Hands out tests, writes start and end times on the board, says the start, warning and end lines.
- **Proctoring behaviors:** sits at the desk marking papers and sipping coffee; every few minutes walks a slow
  loop up and down the aisles (footsteps get louder as they pass you); stands at the front scanning the room.
- Collects tests during the grace period and receives yours.

---

## 7. UI & presentation

### 7.1 Direction: "cozy stationery"
Menus look like **things on a teacher's desk**: cream index cards and manila folders with soft paper
texture and gentle shadows, over the blurred live classroom. Warm, quiet, readable. No neon, glow,
"game-y" bevels or loud animations. Transitions are slow fades and gentle slides (200–300 ms).

- **Fonts:** *Fraunces* (soft serif) for headings, *Atkinson Hyperlegible* for body and controls, both OFL.
- **Colors:** paper `#F7F4EC`, card edge `#E6DFD0`, ink `#2E2B28`, muted text `#6E675E`, accent pencil yellow
  `#E8B33A` (focus rings and the primary button), manila `#E3C98F` for folder tabs.
- **Controls:** pill chips for choices, soft checkboxes that look like pencil ticks, sliders whose handle is a
  small pencil-yellow eraser.

### 7.2 Screens
| Screen | Contents |
|---|---|
| **Main menu** | One card: *Pencils Down* title, "New test", "Resume" (only after a crash), "History", "Settings", "Quit". |
| **Pre-test** | §4.1, all on one card. |
| **Pause / Settings** | A manila folder with tabs: *General · Writing · Graphics · Audio · Controls · Accessibility · Teacher (v0.2)*. In Strict mode a small line reads "The clock is still running." |
| **History** | A list of attempts (test name, date, time used) to reopen in Review. |
| **Review** | §4.4. |

### 7.3 Keybind help: the desk sticky note
No overlay. A **yellow sticky note is stuck to the top-left corner of your desk**, handwritten in the
player's chosen handwriting font. It lists the six most-used controls and changes slightly with context (in
the grace period it adds "H — hand in"). It is readable when you glance left-down. **Hold F1** lifts it toward
the camera for a full, readable list. For the first 3 tests only, a tiny faded hint appears near the pencil
the first time each action is possible ("Shift-click to fill a bubble"). Both can be turned off.

### 7.4 Speech bubbles (teacher lines; reused by the v0.2 AI teacher)
A soft off-white rounded bubble anchored beside the speaker's head in world space, tail pointing to the
mouth, Atkinson Hyperlegible at 18 px. Text appears **word by word with a 60 ms fade-up of 4 px** (calm, no
bouncing), and a short murmur sound plays for each sentence. The bubble fades out 2.5 s after the last word,
plus 50 ms per word for reading time.

### 7.5 Diegetic first
Everything you need during the test is in the world: the clock, the board times, the sticky note, the
teacher's lines, the packet's pages. The only 2D element during a test is an optional small "subtitles" line
for audio cues (accessibility), off by default.

---

## 8. Audio

### 8.1 Layers (each with its own slider)
| Layer | Contents | Default |
|---|---|---|
| **Students writing** | 3D pencil scratching per student (driven by animation) | **90%** |
| Page turns and erasing | paper rustle, eraser rubs | 70% |
| Chairs and movement | creaks, scrapes, bag zips, shifting | 55% |
| People sounds | coughs, sniffles, sighs, yawns | 40% |
| Room tone | HVAC hum, faint fluorescent buzz | 50% |
| Outside | birds, distant traffic, a far-off PE class | 35% |
| Clock tick | second-hand tick from the wall clock | 25% |
| Teacher | footsteps, coffee sips, marking papers, speech murmur | 60% |
| Bells | start and end bells (hallway, slightly reverberant) | 80% |
| Your pencil | your own writing and erasing | 70% |

**Presets:** *Exam hall* (quiet, writing-forward), *Normal class* (default), *Busy* (more people sounds),
*Focus* (writing and room tone only), *Silent*. Changing any slider switches the label to *Custom*.

### 8.2 Mix and space
A Godot audio bus per layer goes into a room bus with Godot's Reverb effect tuned to a small classroom
(~0.6 s decay). There is a gentle low-pass when the camera is
looking down at the paper and you are writing, a small psychoacoustic "focus" effect that can be turned off.

---

## 9. Graphics settings

Every preset still looks realistic. Low drops cost, not the look, because the baked lighting is shared by
all tiers.

| Setting | Low (Compatibility) | Medium | High | Ultra |
|---|---|---|---|---|
| Renderer | Compatibility | Forward+ | Forward+ | Forward+ |
| Lighting | baked lightmaps (half res) | baked lightmaps | baked + SSIL | baked + SSIL (high) |
| Sun shadows (real-time, characters) | off (baked blob) | 1024, 1 cascade | 2048, 2 cascades | 4096, 3 cascades |
| SSAO | off | on (low) | on | on (high) |
| Reflections | reflection probes | probes | probes + SSR | SSR (high) |
| Volumetric light shafts and dust | off (fake cards) | off (fake cards) | volumetric fog | volumetric fog (high) |
| Paper DPI | 110 | 150 | 200 | 250 |
| Anti-aliasing | FXAA | TAA | TAA | TAA + 2× MSAA |
| Upscaling | FSR 1 at 75% | FSR 2 Quality | native | native |
| NPC animation rate (far) | 10 Hz | 15 Hz | 30 Hz | full |
| Skin SSS / DOF | off / cheap | off / on | on / on | on / on (bokeh) |

Individual overrides plus **FPS cap** (30/60/120/unlimited), **V-sync**, **resolution scale**, **field of view**
(60–90°, default 70°), **motion blur** (off by default) and **film grain**.
On first launch the game benchmarks for 3 seconds and picks a preset.

---

## 10. Architecture

### 10.1 Project layout
```
project.godot
addons/            pdfium-gde/, gut/
autoload/          settings.gd, session.gd, exam_clock.gd, audio_director.gd, pdf_service.gd
scenes/
  ui/              main_menu, pre_test, settings_folder, review, history, sticky_note, speech_bubble
  player/          player_rig (camera states, arms, pencil, fidgets), desk_view
  packet/          test_packet, paper_page, ink_canvas, handwriting_text, quick_fill
  npc/             student, student_brain, teacher, teacher_brain
  environments/    morning_classroom/ (scene, lightmaps, seats.tres, ambience_profile.tres)
systems/           pdf_export.gd, fallback_pdf_writer.gd, attempt_store.gd, bubble_detector.gd
ai/ (v0.2)         teacher_dialog.gd, providers/gemini.gd, guardrail.gd
tests/             GUT unit tests + fixtures/*.pdf
art-src/           .blend sources
```

### 10.2 Core units
| Unit | Responsibility | Depends on |
|---|---|---|
| `Settings` | load/save `user://settings.cfg`, apply graphics/audio, emit `changed` | — |
| `Session` | the test **state machine** (below); owns the current `Attempt` | ExamClock, PdfService |
| `ExamClock` | test time; `elapsed`, `remaining`, `start()`, `suspend(reason)`, `resume(reason)`; the wall clock, board and bells read from here | — |
| `PdfService` | `open(path) -> Doc`, `page_count`, `page_size_pt(i)`, `render_page(i, dpi) -> Image`, `text_boxes(i)`, `export(doc, attempt, out_path)` | PDFium-GDE / fallback |
| `TestPacket` | page meshes, flipping, overview, scratch sheets | PdfService, InkCanvas |
| `InkCanvas` | stroke and text data per page, rendering, undo, hit-testing for the eraser | — |
| `PlayerRig` | camera states (Desk, LookUp, Standing, Walking, FocusTeacher), hand IK, fidgets | Settings |
| `StudentBrain` / `TeacherBrain` | behavior selection and timing | Session (for phases) |
| `AudioDirector` | layers, presets, the focus low-pass, bell playback | Settings |
| `AttemptStore` | save/load attempts and autosave | — |

**Session states:** `MENU → PRETEST → SETTLING → TESTING → GRACE → HANDING_IN → REVIEW` (plus `PAUSED`, Practice
mode only). Each transition emits a signal; environment, NPCs and audio react to signals, never to polling.

**Environment contract** (makes future classrooms drop-in): every environment scene provides
`player_seat: Marker3D`, `student_seats: Array[Marker3D]`, `teacher_desk`, `teacher_patrol: Path3D`,
`handin_path: Path3D`, `wall_clock: WallClock`, `board: Whiteboard` (or `Chalkboard`), `ambience_profile`,
and a `lighting_preset` (lightmap bake + sky + sun). Swapping environments needs no code changes.

### 10.3 Export
For each page with marks:
1. Open the original PDF through PDFium-GDE.
2. Add pencil strokes as **vector path objects** (graphite color `#3B3A3C` at 92% opacity, rounded caps and
   joins, widths from the stroke data).
3. Add typed text as **text objects** with the chosen handwriting font embedded, positioned glyph by glyph
   so the jitter matches what was on screen.
4. Append scratch sheets as extra blank pages with their marks.
5. Save to the chosen path. Erase ghosts are not exported.

Coordinates are stored in PDF points from the start, so export maps 1:1 with no resampling. A golden test
(§11) protects this.

### 10.4 Error handling
| Case | Behavior |
|---|---|
| Encrypted or password-protected PDF | Message on the pre-test card: "This PDF is password-protected; remove the password and try again." |
| Corrupt or unreadable PDF | "Couldn't open this PDF." with the error detail in a collapsible line |
| Huge pages or 100+ pages | Render on demand (current page ±1 at full DPI, the rest as thumbnails), with a warning above 60 pages |
| Export fails (permissions, disk) | Keep the review open, show an error, offer a different location; the attempt is already in history |
| Vector export fails for a document | Use the fallback image exporter (§3.2) and note "Exported as images" in the review |
| Crash mid-test | Autosave plus "Resume test in progress" (§5.2) |

---

## 11. Testing
- **Unit (GUT):** ExamClock (suspend/resume, strict vs practice), Session transitions, stroke serialization
  round-trip, eraser geometry, glyph-jitter determinism, settings migration.
- **Golden export test:** export a fixture PDF with known strokes and text, re-render the result with
  PDFium, and compare pixels with a stored golden image within tolerance.
- **PDF corpus:** 10 fixture PDFs (scanned, vector, mixed sizes, landscape, A4 and Letter, 1 encrypted, 1
  corrupt) run through load, render and export in CI.
- **Performance:** a `perf_bench` scene that flies a fixed camera path and logs frame-time percentiles;
  checked by hand per preset on the target hardware tiers before each release.
- **Manual playtest checklist:** a full 10-minute test covering every control, the grace period, the
  forced pickup, crash recovery and export opened in a normal PDF reader.
- **CI:** GitHub Actions runs GUT headless on every push; tagged releases export Windows, macOS (universal,
  unsigned, with instructions) and Linux builds and attach them to the GitHub Release.

---

## 12. Roadmap (designed for now, built later)

### v0.2: AI teacher
- **Settings → Teacher:** provider (Google Gemini via an AI Studio key first; OpenAI-compatible and Anthropic
  later), model, API key (stored only on this machine in `user://`, obfuscated, with a clear note), "questions
  per test" (default 3), on/off.
- **Flow:**
  1. Press **R**: your hand goes up and a student near you glances over.
  2. The teacher notices (1–3 s) and walks over. **Test time keeps running.**
  3. The camera smoothly looks up at the teacher, FNAF-style. The packet drops out of view at the bottom of
     the screen. Move the cursor to the bottom edge (or hold **S**) to glance back down at your test, and
     move it up to look at the teacher again.
  4. Type your question. It appears as your own speech line under the teacher, in the same bubble style.
     Enter sends it.
  5. **Time hold:** from the moment you send until the teacher's bubble finishes plus reading time, the exam
     clock is suspended (`ExamClock.suspend("teacher")`). There is no "paused" indicator. The clock simply is
     not in view while you look at the teacher, and it carries on when you look back. Each hold is capped at
     60 s.
  6. The teacher answers in a speech bubble (word-by-word fade), with a small "thinking" gesture while the
     request is in flight. You can ask a follow-up (it counts toward the limit) or say "Thanks" (Esc). The
     teacher leaves and the camera returns to the desk.
- **No-answers guardrail:**
  1. The system prompt casts the model as a proctor who may clarify wording, define non-tested vocabulary,
     explain instructions, and give at most a gentle nudge on approach, and who must **never** give, confirm,
     eliminate, or narrow down answers.
  2. Context sent: the current page image and its extracted text, plus the question.
  3. A **second, cheap check call** classifies the draft reply ("does this reveal, confirm or narrow down an
     answer?"). If it does, a stock in-character deflection replaces it ("I can't help with that one, but
     read the question again carefully.").
  4. Replies are trimmed to 2–3 sentences.
- **Teacher look-up idle:** while you look at them, the teacher has small idle motions (glance at your
  paper, adjust glasses) so the moment feels alive.

### v0.3: Environments and time of day
- **American high school** (v0.1 room) at morning, midday and late afternoon.
- **Japanese classroom** at morning, sunset and overcast (chalkboard, wooden desks, uniforms, cicadas in
  summer).
- **University lecture hall** at morning and evening (tiered seating, 80+ students using instanced crowd
  LODs, a large analog clock or digital display).
- Each is one environment scene under the §10.2 contract, with a lighting preset per time of day (separate
  lightmap bakes) and its own ambience profile.

### Later
An on-desk calculator (basic/scientific), formula or reference sheets loaded as a second PDF, an answer-key
PDF for AI auto-marking inside the app, a ruler and protractor for diagrams, a highlighter, rain-day weather,
custom bell sounds, and Steam Deck controls.

---

## 13. Risks
| Risk | Impact | Mitigation |
|---|---|---|
| PDFium-GDE immaturity | Core feature | Day-one spike, the `PdfService` interface, a pure-GDScript fallback exporter |
| Realistic humans with free assets | Immersion | MPFB 2 + careful materials and lighting, seen mostly from behind or at a distance, procedural motion for variety |
| Asset workload (room, props, anims) | Schedule | Modular kit, reuse CC0 materials, procedural IK animation instead of many hand-keyed clips, ship v0.1 with 10 student variants |
| Handwriting looks fake | Immersion | Per-glyph jitter, graphite shader, line-spacing auto-size, several font choices |
| Low-end performance | Reach | Baked lighting, Compatibility renderer, throttled NPC updates, auto-benchmark |
| macOS Gatekeeper on unsigned builds | Install friction | Clear README steps; signing later if the project grows |
| Copyright of uploaded tests | Legal | Tests stay local, never uploaded (except the page image sent to the user's own AI key in v0.2); the README tells users to use tests they have the right to use |

---

## 14. v0.1 scope checklist
- [ ] PDFium-GDE spike (Windows/macOS/Linux) and fallback writer
- [ ] Morning Classroom environment (kit, props, baked lighting, window view)
- [ ] Player rig: desk view, look-up (Space and edge), lean, hand IK, left-handed mode
- [ ] Test packet: render, flip, overview, scratch paper, slide
- [ ] Ink: pencil, eraser, undo/redo, autosave
- [ ] Quick Fill bubbles (text-box snap, circle detection, fallback)
- [ ] Typed handwriting text (5 fonts, jitter, auto-size, edit)
- [ ] Fidgets (4)
- [ ] Students (10 variants, behavior loop, procedural writing, 3D audio)
- [ ] Teacher proctor (handout, board times, warnings, patrol, collection)
- [ ] Session flow: settling, start bell, warnings, end bell, grace, hand-in walk, forced pickup
- [ ] Review: pages, stats, Save PDF, copy marking prompt, retake; history
- [ ] UI: main menu, pre-test, settings folder, sticky note, speech bubbles
- [ ] Audio: 10 layers, presets, reverb, focus low-pass
- [ ] Graphics presets and auto-benchmark
- [ ] GUT tests, golden export test, CI build and release workflow
- [ ] README (how to play, add tests, build), CREDITS.md, LICENSE
