# World of Cake — current overview

Updated 26 August 2026. This is an orientation for work in this repository: what the project is, how it is shaped, and where development stands. It is not the legal source of truth for settled architecture; that remains `consolidate_woc_and_audio.md`. The ordered programme is `WOC_CONSOLIDATION_IMPLEMENTATION_PLAN.md`. Windows commands and toolchain are `WINDOWS_DEVELOPMENT.md`. In-tree Haxe/OpenFL shape is `architecture.md`.

The last section records tensions and gaps that the current direction has not fully closed. They are observations from reading the docs, the code, and the 26 August discussion — not a request to change course.

---

## What it is

World of Cake is a Haxe framework and a family of experimental music sequencers. Each sequencer is an interactive world that emits **notes** and/or **continuous control** (historically MIDI CC; in Rack, CV). The long-term products are **VST3** (prototypical: a MIDI-like model for notes and continuous control) and **VCV Rack**, plus **OpenFL** desktop and **browser** prototypes that should look like the same apps.

“One codebase” means **one authoritative implementation of each musical behaviour**, not one language or one UI toolkit everywhere.

- **Haxe** owns control-rate / domain logic: worlds, interaction, sequencing, persistence, visual-model facts.
- **Portable C++** owns the native control runner, bounded queues, prepared events/snapshots, and later real-time scheduling. Host audio callbacks must not enter Haxe.
- **Layla** owns spatial panel composition (nested regions, weights, semantic IDs/hints). Companion `.edn` owns UIDs, ranges, colours, widget kinds. Generators are project-owned under `laylagen/`. Canonical Layla is `G:\PRODUCTION\MAIN_PROJECTS\language_oriented\langdev\layla`.
- **Target shells** draw and host: OpenFL widgets for desktop/browser prototypes; native Rack widgets later; native JUCE controls for VST. Shared pixels are optional; shared semantics (IDs, values, gestures, layout intent) are not.

OpenFL still matters: it runs in the browser, gives basic drawing on several targets, and is the place to see a prototype and expect it to look like the VST. Layla is reducing Haxe’s role as a *UI composition* abstraction. Haxe remains the home of sequencer behaviour and of OpenFL widgets that actually draw.

---

## The five current sequencers

All five implement `ISequencerControl` (`ISequencer` + `IControlPanel`) in Haxe. All five have been through the shared native runner contract (Stage 2). All five are intended to ship as Rack and VST.

| App | World | Primary output |
|-----|--------|----------------|
| **Gbloink** | Three balls, user-placed blocks, collisions | Discrete notes |
| **TimeSlider** | Four parallel tracks; click sets level (Y) and travel time (X, log scale) | Continuous levels (MIDI-like CC / CV) |
| **TileLand** | 12×12 tile maze, three cursors, click flips tiles | Six continuous X/Y values |
| **K-Diagram** | Random graph, three cursors | Mixed: arrival notes + continuous position |
| **Zewp** | Moving line agents, draggable obstacles | Ten continuous Y positions |

**PlayArea** is World of Cake’s name for the **canvas where automated motion happens**, not a generic slider. Gbloink balls, TimeSlider tracks, TileLand tiles, K-Diagram graph, and Zewp agents are all play areas: custom drawing on a local coordinate space, with mouse forwarded into the sequencer. Ordinary `Slider` widgets sit *beside* that canvas when an app has them. TimeSlider’s tracks are a custom playfield, not `worldofcake.ui.Slider`.

A later sixth sequencer will wrap **Goldenpond**: a separate Haxe livecoding library that compiles compact chord/line text into a finite note score. World of Cake will own transport, looping, edit application, and host output. That work comes after the current Layla-panel phase. Goldenpond will need DAW transport sync; the current five probably will not, except maybe pausing when host transport is off.

---

## Architectural shape

### Haxe application contract

```text
platform input
    -> IControlPanel (uid + typed payload)
    -> ISequencer.advanceTime(delta)
    -> Event queue and/or control snapshots
    -> host output adapter
```

`ISequencer` also has pause/resume/reset and versioned JSON import/export. Each app owns its JSON schema.

Typical OpenFL shell: `OpenFLAppBase` (stage, 1 ms timer, `ENTER_FRAME`) -> `World` (`ISequencerWorld`, component routing) -> sequencer + view. All current apps now use the same `Main -> World -> Sequencer/View` boundary, including TimeSlider.

### Coordinate spaces

Three explicit point types exist to stop “everything is a float” bugs:

- **Window** — physical stage / window pixels
- **Panel** — logical control-panel layout space
- **Local** — the playfield or widget’s own space

Mappers convert between them; UI components go through `ComponentCommon` rather than ad-hoc math. Click-mapping bugs that motivated this typing are believed solved.

**Still slightly open:** how much of Window/Panel comes from Layla. Current leaning: Layla determines the **absolute design-time shape and size of Window and Panel**, and therefore the relationship between those two spaces. **Local** remains an app implementation concern (e.g. Gbloink’s 700×500 playfield). Runtime resize, if kept, would change Window only.

### Native host boundary (`bridge/`)

Every World of Cake sequencer is supposed to use **one lifecycle**, not a private threading design.

- A **control thread** (`ControlThread`) attaches to hxcpp, owns the Haxe sequencer, and advances it at a declared cadence. Tests can **pump** the same runner manually.
- **Two SPSC command queues**: GUI/message → control, and host/audio → control. Host is drained first. Each queue has one producer, its own drop counter, and high-water mark.
- The control thread publishes **prepared discrete events** and/or **immutable continuous snapshots** and **visual snapshots**.
- A simulated (and later real) **audio consumer** reads only that prepared native data. It must not call Haxe, lock the Haxe owner, allocate, or render.

The host queue exists so a DAW audio thread can send control (pause, automation, later Goldenpond clock) without sharing the GUI queue. Current apps do not yet *use* host-originated musical signals much; the capability is in the framework so it can be used when needed. Continuous host values should use latest-value mailboxes later, not flood the command queue.

There are currently **five parallel C++ runner classes** (one per app) sharing `ControlThread`, queue types, and the dual-input policy. That duplication is accepted until more hosts force a generic runner.

`PreparedEvent` is still MIDI-shaped. A richer semantic event ABI is deferred. The product intent for VSTs is a MIDI-like model for continuous control; Rack maps the same facts to CV/gates.

OpenFL desktop/browser still run the Haxe model on the OpenFL timer and `MonitorInstrument`. The native runner is the contract for Rack/VST (and tests), not yet how OpenFL executes.

### Layla

Layla describes hierarchy, orientation, named leaves, hints, and weights. It does not describe behaviour, DSP, styling systems, or widget class names.

World of Cake’s generator:

```text
layouts/openfl/<app>.layla  +  <app>.edn
    -> layla.core/parse-intent
    -> target validation + geometry
    -> Source/generated/<app>/  (Haxe composition, layout constants, geometry.edn)
```

Maintained code owns drawing, interaction, and sequencer logic. Generated files must not be hand-edited. `.\run-laylagen.ps1` tests, generates, and checks.

Rack originally went off on its own to get usable modules, including an older direct-Haxe audio-thread bridge. Current Rack shells have moved toward the shared runner boundary. Rack remains a near-term target and a useful Linux-testable native host, while OpenFL/browser remains the reference UI and VST/JUCE remains a near-term DAW target. Rack should use the same pipeline where practical, with **variant Layla files** where HP, jacks, and Rack control idioms require different composition. Definitive panel shapes for VST vs Rack are not frozen yet.

---

## Where development is

Programme stages:

1. **Done** — Gbloink Haxe model in a native C++ harness on Windows (seeded RNG, delta-based motion, queues, no Haxe in the simulated audio consumer).
2. **Done** — Same runner/lifecycle for TimeSlider, then TileLand, K-Diagram, and Zewp. Five-app compatibility audit complete.
3. **Active** — Replace hand-composed OpenFL panels with Layla generation.
4. **Active/near-term** — Rack: keep Linux and Windows builds working, keep `process()` off Haxe, clean up historical bridge residue, and move toward Layla → Rack widgets + SVG.
5. **Later** — JUCE VST3/standalone from the same runner and generated descriptions. Then Goldenpond as another World of Cake sequencer.

**Stage 3 now:** all five current OpenFL panels have been migrated through Layla/EDN generation and are in a cross-app sizing, coordinate, interaction, and semantic-widget refinement pass.

Windows toolchain (Haxe 4.3.6, hxcpp 4.3.2, Lime 8.1.3, OpenFL 9.3.4, VS 2022 x64) is recorded in `WINDOWS_DEVELOPMENT.md`. Headless tests: `.\build-headless.ps1`. OpenFL app selection is still one `project.xml` main at a time (`runapp` on Unix-like shells).

---

## What not to confuse this with

- **`ui.YAML` and `Source/worldofcake/README.md`** describe an older layout story (including `ui.YAML` as source of truth). Layla + companion config have taken that job for Gbloink; do not treat `ui.YAML` as current.
- **Older Rack documentation** still describes Rack derivatives that call Haxe from the audio thread. The current Rack shells have mostly moved to the shared runner boundary: `process()` consumes prepared native data and does not enter Haxe. Treat old direct-Haxe Rack notes as historical unless the code proves otherwise.
- **SandSonify** and a portable C++ audio-generator family appear in the consolidation guide. They are out of scope for current World of Cake sequencer work.
- Do not put OpenFL inside JUCE or Rack to reuse widgets. Do not call Haxe from a host audio callback.

---

## Working rules that matter

- Musical behaviour changes in one Haxe sequencer, not in a host-specific rewrite.
- Every app uses the same runner/queue/snapshot policy; apps do not invent private GUI/audio threading.
- Layla is spatial; `.edn` is component facts; generated Haxe is replaceable.
- Custom playfield rendering stays handwritten.
- Tests before moving authoritative logic: headless Haxe, hxcpp, native harness.
- Do not reorganize the repository until a working artifact needs a new directory.

---

## Issues and tensions the current direction has not fully closed

These are the places where the architecture is coherent on paper but the tree still has two stories, or where a later stage will hurt if nobody names the gap now. None of them say “stop Stage 3.”

### 1. OpenFL and the native runner are still two execution paths

The shared contract is proven in the C++ harness. OpenFL apps still step Haxe on a nominal 1 ms timer and drain `Event`s to `MonitorInstrument`. TimeSlider and Zewp still call `generateEvents()` from **view drawing**, not from `advanceTime`. Native facades already discard some of those legacy CC streams after each tick.

Until OpenFL either uses the runner or at least the same publication rules, “prototype in the browser and expect it to look elsewhere” is true for **layout**, and only loosely true for **timing and output**. Cadence, pause, and “when does a CC fire” can drift per target without a failing test.

Related: `GbloinkWorld.resize` replaces the window→panel mapper but does not obviously push that mapper into existing components. If Layla owns design-time Window/Panel and resize remains, this is a live seam, not a historical one.

### 2. Three output stories for the same musical facts

At once, the code has:

- Haxe `Event` (`type`, `data1`, `data2`, `data3`);
- native `PreparedEvent` (same MIDI-shaped fields);
- native continuous snapshots (the real TimeSlider/TileLand/Zewp native contract).

VST is supposed to be MIDI-like; Rack is CV/gates; OpenFL still emits CC events. That can work if **one** semantic fact (note arrival, slider level, cursor XY) is defined and hosts map it. It fails if Stage 3/4 generate contracts from whichever path is convenient. TimeSlider’s unused `BASE_CC` vs controllers 1–4, TileLand’s unused channel-slider layout, and K-Diagram’s old `-1..1 × 127` CC math (native runner already remaps; OpenFL may not) are small examples of the same hole.

The event ABI was deliberately deferred. Before the first real host maps outputs, it is worth listing per app: discrete events vs sampled controls vs visual-only, and treating snapshots as first-class rather than “whatever `generateEvents` used to do.”

### 3. Visual snapshots are not yet Rack-drawable

Stage 4 says Rack drawing must not call Haxe. Gbloink’s native snapshot is balls plus `blockCount` — not block geometry/colour, pause, scale, or edge-notes. TileLand/K-Diagram/Zewp snapshots are richer because the Stage 2 audit needed them.

If snapshot completeness waits until Windows Rack, the first “UI must not enter Haxe” week becomes a schema redesign. A cheap freeze (what each playfield must publish, bounded capacities, truncation policy) can happen without building Rack.

Fixed capacities (144 tiles, 64 arcs, 20 Zewp blocks) are the right idea; silent truncation should be explicit.

### 4. Stage 3 may overfit Gbloink, then throw layout away

The OpenFL generator’s composition renderer still names `Gbloink` / `GbloinkView`. TimeSlider is the right next consumer. The risk is extracting a “generic WorldOfCake generator” around Gbloink’s three sliders, then discovering TimeSlider is one custom canvas and K-Diagram needs keyboard + graph chrome.

A second risk: OpenFL panels generated now are **not** the definitive VST/Rack shapes. That is accepted — generation should make a later reshape cheap. It argues against investing in OpenFL-only composition cleverness, and for keeping `.layla` + `.edn` + geometry the portable artefact, not the Haxe `build()` spelling.

The Layla repo’s `examples/gbloink.layla` is a different layout (labels, nested stack) from `layouts/openfl/gbloink.layla`. Fine if everyone knows the World of Cake file is the product source.

### 5. “Look the same” vs Zewp (and Gbloink’s old Rack sim-rate)

Zewp motion is delta-based, but obstacle avoidance is a sampled nonlinear simulation. Trajectories **will** diverge at different control cadences; the docs already say hosts must keep a bounded cadence. Browser OpenFL at ~1 ms, a VST control thread at 5 ms, and Rack at audio-derived ticks will not be the same chaotic dance. That is a product fact, not just a test footnote.

Gbloink’s Rack modules previously used “how often we call `advanceTime`” as a feel control. Delta-based velocities invalidate that. When Rack is re-synced, `Sim rate` needs a deliberate redesign, not a wire-up.

### 6. The host queue is real; the first host signal is not

Two SPSC queues are the right shape. Nothing in the current five yet consumes DAW-originated signals in anger. The first real use is likely pause-with-transport or parameter automation, not Goldenpond’s clock.

Continuous automation **must not** be “enqueue every sample on the host SPSC.” Latest-value mailboxes are documented and not built. If the first JUCE/Rack adapter is written before mailboxes exist, someone will push automation through the command queue and recreate the audio-thread coupling the runner was meant to kill.

Also: each SPSC has exactly one producer. Plugin editor, processor, and a message thread are already three contexts. Marshalling rules need to be written down when the first host is attached, not after a second producer appears.

### 7. Five cloned runners, integer UIDs, no manifest yet

Lifecycle is shared in spirit; `GbloinkControlRunner`, `TimeSliderControlRunner`, … are copy-paste. That was correct for Stage 2. Stage 4–5 plus Goldenpond will make a sixth and seventh copy. Generalizing the runner is still premature **until** TimeSlider’s Layla reuse exists — after that, the duplication is harder to justify.

Control IDs are still scattered integers in Haxe constants and `.edn` files. Layla is generating *placement*, not a portfolio manifest (stable parameter/port IDs, MIDI CC numbers, Rack voltages). Without that, VST APVTS, Rack `configParam`, and docs will keep being handwritten from slightly different lists.

### 8. Tests do not see clicks, layout, or sound

Headless Haxe / hxcpp / harness tests are strong on seed, cadence, pause, and queue discipline. They do not see: PlayArea hit-testing after generated geometry, TimeSlider click-to-track mapping once it goes through Window→Panel→Local, OpenFL resize, or “does this MIDI/CV mapping match.” Stage 3 visual parity is manual. A single scripted OpenFL or geometry-fixture test per app would catch the class of bug this repo already paid for once.

Browser “works” today as OpenFL HTML5 + `MonitorInstrument` (logging, not a musical I/O story). Looking the same is not sounding in a browser; Web MIDI is a later product decision, not an assumption.

### 9. Documentation and leftover UI residue will mislead the next pass

`consolidate_woc_and_audio.md` is marked definitive, but early inventory still describes pre-delta Gbloink and “Zewp not ready.” `Source/worldofcake/README.md` and `ui.YAML` still describe the old layout source of truth. Agents and humans will mix eras.

Small contract residue still sitting in models/layouts: TileLand channel slider with no `newValue`; TimeSlider `BASE_CC`; K-Diagram OpenFL CC vs native normalized snapshots. Cheap to clean before schema extraction, expensive if generated as “truth.”

RNG is seedable for tests; persistence saves materialized worlds, not RNG continuation. Fine for the current five; Goldenpond random selectors will not be.

Goldenpond’s library license (AGPL in the sources that were inventoried) is a distribution constraint for a combined VST/Rack product. Out of scope for Stage 3, not out of scope for “we will wrap it next.”

### 10. Programme order vs the intended product

The staged order (harness → Layla OpenFL → Rack → VST) matches technical risk: Rack is the known dangerous threading case. The intended everyday product is VST. That is a valid choice; it means a long time before a DAW-hosted MIDI-effect exists, and MIDI-effect VST3 support is already listed as host-dependent. Keeping a thin “VST is the default output metaphor” in mind during Stage 3 (CC vs snapshot, panel as a plugin editor, pause-with-transport) will make Stage 5 less of a second architecture.
