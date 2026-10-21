# WorldOfCake Consolidation Implementation Plan

Status: active implementation roadmap. Stages 1, 2, and 3 are complete. The shared Rack runner boundary is in use, Linux and Windows Rack build paths exist, and the Layla/EDN UI pipeline is operational for OpenFL plus all five Rack variants. Rack control/widget migration and VST/JUCE remain active work. Updated 15 September 2026.

This plan turns the architectural decisions in `consolidate_woc_and_audio.md` into an ordered programme of work. It covers WorldOfCake sequencers, Layla-generated user interfaces, VCV Rack on Windows, and later VST3 builds. SandSonify is deliberately deferred and is not part of the active sequence below.

## Current implementation status

Completed on Windows:

- Haxe 4.3.6, hxcpp 4.3.2, Lime 8.1.3, OpenFL 9.3.4, and Visual Studio 2022 x64 are documented and working.
- Gbloink has injectable deterministic randomness for tests and delta-based movement calibrated to its former 1 ms behaviour.
- Gbloink, TimeSlider, TileLand, K-Diag, and Zewp compile through hxcpp-native paths and pass the shared runner contract; current Rack shells for Gbloink, TimeSlider, TileLand, and K-Diag use the runner boundary.
- The runners support deterministic manual pumping and background control-thread operation.
- Two bounded native SPSC command queues per runner separate GUI/message input and host/audio input from the Haxe owner. The control thread drains host commands first, then GUI commands; each channel reports drops and peak depth independently. Gbloink publishes discrete events; TimeSlider, TileLand, K-Diag, and Zewp publish continuous control snapshots where appropriate.
- The simulated native audio consumers call no Haxe API, take no Haxe/GUI mutex, allocate nothing, and perform no UI work.
- Haxe interpreter tests, hxcpp-native model tests, the combined native C++ harness, and the Gbloink OpenFL HTML5 smoke build pass.

Current boundary and deliberately open work:

- The input policy is settled as two explicit SPSC queues rather than one MPSC dependency. Each queue must retain exactly one producer; continuous host values will use latest-value mailboxes rather than command flooding.
- The shared lifecycle is proven across the five current apps and is now used by the current Rack shells. JUCE/VST integration has not started.
- TimeSlider's current native contract is a continuous sampled-control snapshot; whether a host also needs discrete CC events remains a target-level decision.
- Gbloink, TimeSlider, TileLand, K-Diag, and Zewp pass the shared runner contract. The five-app Stage 2 compatibility audit is complete.

## 1. Goals and constraints

The programme has five large stages, in this order:

1. Run the authoritative Haxe/WorldOfCake Gbloink model from a native C++ test harness on Windows, while refining the shared WorldOfCake contracts.
2. Prove that the same WorldOfCake runner and native harness work for another app, beginning with TimeSlider.
3. Replace hand-composed WorldOfCake control panels with project-owned Layla generation, beginning with Gbloink.
4. Continue Rack modernization: keep Rack audio callbacks off Haxe, verify Linux and Windows builds, remove leftover historical bridge code/docs, and generate composition and SVG panels from Rack-specific Layla/EDN variants.
5. Build VST3 versions of WorldOfCake applications using the same shared runner, scheduler, and generated UI descriptions.

The governing constraints are:

- Each application's musical behaviour has one authoritative Haxe implementation.
- Every WorldOfCake app uses one shared lifecycle and one shared GUI/control-to-real-time communication model.
- The Rack and VST audio callbacks do not call Haxe, allocate Haxe objects, acquire a GUI/Haxe mutex, or invoke hxcpp garbage collection.
- Target shells remain target-specific. Rack uses Rack widgets, JUCE uses JUCE components, and OpenFL uses WorldOfCake/OpenFL components.
- Layla describes layout composition. Companion configuration describes widget classes, parameters, ports, labels, styling, and target bindings.
- Layla generators belong in the WorldOfCake project, under `laylagen/`; generic Layla remains target-neutral.
- Generated files are deterministic, visibly generated, and never hand-edited.
- Existing OpenFL implementations remain the UI/behaviour reference. Current Rack implementations are native-host targets, with older direct-Haxe Rack notes retained only as historical reference.

## 2. Current Windows baseline

The initial audit found the following. The missing Windows libraries described here have now been installed and verified; see `WINDOWS_DEVELOPMENT.md` for the current baseline:

- Haxe 4.3.6 is installed at `C:\HaxeToolkit\haxe\haxe.exe`.
- `haxelib` was initially missing the required native/UI libraries. hxcpp 4.3.2, Lime 8.1.3, and OpenFL 9.3.4 are now installed and verified.
- Rack Free 2.6.4 is installed. The matching official Windows x64 SDK is now stored under `derivatives/Rack-SDK-2.6.4-win-x64`; its downloaded archive SHA-256 is `AA57B3D225C11B213FAA2F0CE405971876473588CA4EB7DE65E41E996E715AAD`.
- MSYS2 MinGW64 and the official Rack build dependencies are installed. GCC 16.2 requires the documented local compatibility adjustment to hxcpp 4.3.2's MinGW toolchain.
- `derivatives/vcvrack/build-rack-windows.ps1` builds, packages, or installs the Windows Rack modules. Linux remains important for local Rack testing through `build_module.sh` and `build_all.sh`.
- The existing WorldOfCake test program is small and focuses on coordinate mapping. It is not yet an application-level deterministic test suite.
- Older Rack modules transpiled app-specific Haxe facades and called them directly from `Module::process()` under a mutex. That is historical; current Rack work should use the shared runner boundary.

Toolchain installation and discovery must be reproducible rather than dependent on undocumented machine state. Record exact versions and paths in a Windows development document or checked-in bootstrap script. Do not vendor user-specific absolute paths into generated files.

## 3. Target repository shape

The exact names may be adjusted while implementing, but the intended ownership is:

```text
worldofcake/
  Source/
    worldofcake/             shared Haxe contracts and models
    gbloink/                 authoritative Gbloink behaviour
    timeslider/              authoritative TimeSlider behaviour
    ...
  test/
    fixtures/                deterministic commands and expected results
    haxe/                    headless Haxe tests
    native/                  C++ harness tests
  bridge/
    haxe/                    one shared cpp-safe WorldOfCake bridge surface
    native/                  queues, POD snapshots, scheduler, harness
  layouts/
    openfl/                  Layla sources where shared layouts fit
    rack/                    Rack-specific Layla sources where appropriate
    juce/                    JUCE-specific sources only where composition differs
    config/                  non-spatial component and binding data
  laylagen/
    src/                     WorldOfCake-owned generators
    test/                    IR/geometry/golden-file tests
  generated/
    openfl/
    rack/
    juce/
  derivatives/
    vcvrack/
    vst3/
```

Do not reorganize the repository at the beginning. Introduce directories only when the corresponding working artifact exists, and migrate existing files incrementally.

## 4. Stage 0 — preserve and measure the baseline

### Tasks

1. Build or run the current Gbloink OpenFL target and record the commands, tool versions, visible behaviour, nominal update cadence, and default speed feel.
2. Run the existing WorldOfCake tests and turn their result into a reliable process exit code.
3. Capture small behavioural fixtures from current Gbloink:
   - initial ball positions and velocities;
   - speed-control mapping;
   - block creation/removal semantics;
   - collision-to-note mapping;
   - pause, resume, reset, and persistence;
   - edge-note behaviour.
4. Preserve one reference Linux Rack build/result if the Linux installation remains accessible. It is a compatibility reference, not a prerequisite for starting Windows work.
5. Record current Gbloink apparent speed at the nominal OpenFL cadence so conversion to per-second velocities preserves its character.

### Exit gate

- A documented command runs the existing tests.
- Gbloink's current behaviour and event meanings are captured well enough to distinguish intentional refinements from regressions.
- No production behaviour has been moved yet.

## 5. Stage 1 — Gbloink Haxe model in a C++ harness

### 5.1 Establish the Windows Haxe/hxcpp toolchain

1. Install or register a compatible hxcpp for Haxe 4.3.6.
2. Compile the smallest Haxe class to C++ on Windows.
3. Build and run a tiny native executable that initializes hxcpp and calls a Haxe method.
4. Choose and document the initial Windows C++ toolchain. Prefer the same compiler family required by the Windows Rack SDK when practical, so the proof is relevant to Stage 4.
5. Add a PowerShell build/test entry point with paths discovered from tools or configuration, not embedded personal paths.

### 5.2 Make Gbloink testable and cadence-independent

1. Introduce an injectable random source or seedable project RNG.
2. Use a fresh seed in normal interactive runs and a fixed seed in tests.
3. Decide whether presets save only materialized world state or also RNG continuation state. Exact RNG continuation is not required for the first harness.
4. Convert movement from distance-per-`advanceTime` call to distance-per-second using `delta`.
5. Calibrate new velocity units against the original nominal cadence so the default app feels substantially unchanged.
6. Add validation for invalid/negative/very large deltas and bounded catch-up policy at the runner level.
7. Preserve stable logical coordinates and current note mapping.

### 5.3 Define the first shared bridge data

Begin with the minimum required by Gbloink, not a speculative universal ABI:

- `ControlCommand`: command kind, stable control ID, local coordinates/value, and sequence number.
- `MusicalEvent`: logical timestamp, semantic kind, channel/voice, note/value, and velocity where relevant.
- `GbloinkVisualSnapshot`: version, logical time, balls, blocks, pause state, scale, and edge-note state.
- Runner status: queue pressure, dropped-command/event counters, snapshot generation, and last error.

Use fixed-width scalar fields and fixed-capacity or preallocated storage across the real-time boundary. Haxe-specific strings and objects must not be read by the simulated audio consumer.

### 5.4 Build the common WorldOfCake control runner

The runner owns one Haxe `ISequencerControl` instance. It:

1. Accepts commands from a bounded queue.
2. Advances logical time at a declared control cadence.
3. Drains Haxe events into a bounded native-readable event queue.
4. Publishes immutable/double-buffered visual and continuous-control snapshots.
5. Exposes reset, shutdown, state import/export, and instrumentation outside the real-time consumer.
6. Has a deterministic manual-pump mode for tests before a background-thread mode is introduced.

The first harness should use manual pumping. This makes timing reproducible and lets tests separate runner correctness from operating-system scheduling. Add the background control thread only after the manual contract passes.

### 5.5 Build the C++ harness

The harness must simulate the roles later held by Rack/JUCE without depending on either framework:

- initialize the shared Haxe bridge;
- submit scripted UI commands;
- advance control time in fixed steps;
- consume events without calling Haxe during the simulated audio block;
- read visual snapshots;
- export/import state;
- report queue overflow and timing failures;
- compare results with checked-in deterministic fixtures.

Test at least:

- equal results for equivalent elapsed time under different control step subdivisions;
- fixed-seed repeatability;
- click-created block identity and removal;
- collision event ordering and pitch mapping;
- pause/resume/reset;
- state round trip;
- slow consumer and bounded queue behaviour;
- shutdown while queues contain data;
- no Haxe calls inside the harness's explicitly marked simulated audio-consumer function.

### Stage 1 exit gate

**Status: complete.**

- One Windows command builds and runs the Haxe-generated C++ plus native harness.
- Gbloink passes deterministic headless tests.
- Equivalent elapsed time is cadence-independent within declared tolerances.
- The simulated audio consumer receives prepared events/snapshots without entering Haxe or locking the Haxe owner.
- OpenFL Gbloink remains functional with calibrated behaviour.

## 6. Stage 2 — prove reuse with TimeSlider, then audit the remaining apps

### 6.1 Generalize only what Gbloink and TimeSlider both require

1. Add TimeSlider to the same shared runner and bridge build.
2. Do not copy the runner, command queue, lifecycle, or state machinery.
3. Add a continuous-control snapshot for its four slider values.
4. Decide whether TimeSlider needs discrete CC events in addition to sampled control values; make the semantic contract explicit.
5. Test interpolation/sampling behaviour at simulated Rack audio rates.
6. Verify pause, reset, state round-trip, and different control cadences.

Refactor shared bridge code only after both apps run. Keep visual snapshot payloads app-specific behind a common publication envelope if their structures differ substantially.

### 6.2 Compatibility audit

Apply the resulting contract, initially as paper/design tests and then headless smoke tests, to:

- TileLand: three cursor positions and six continuous outputs.
- K-Diagram: graph visual snapshot, cursor positions, and arrival events.
- Zewp: discrete events and interaction, including the absence of an existing Rack derivative.

Record any capability genuinely missing from the common contract before adding it. Candidate capabilities include clock/reset input, sample-and-hold output, target-specific channel selection, and larger variable-length visual snapshots.

### Stage 2 exit gate

**Status: complete.** All five apps use the shared lifecycle and dual-input model in the native proof. Tests cover discrete, continuous, mixed, fixed-grid, graph, and draggable-world publication.

- Gbloink and TimeSlider use the same runner, queues, lifecycle, and harness executable/library.
- Tests demonstrate both discrete event and continuous control publication.
- Remaining apps have a documented fit/gap assessment.
- No app-specific thread architecture has appeared.

## 7. Stage 3 — Layla-generated WorldOfCake panels

**Current status:** the Gbloink pilot is complete for its existing OpenFL panel. `layouts/openfl/gbloink.layla` is now the spatial source of truth for the play area and three speed sliders; `gbloink.edn` owns component UIDs, ranges, defaults, orientation, colours, and local playfield size. The project-owned Clojure generator under `laylagen/` consumes `layla.core/parse-intent`, calculates deterministic geometry, and emits both Haxe component construction and layout constants under `Source/generated/gbloink/`. Maintained `GbloinkWorld` calls the generated composition, while maintained `GbloinkView`, widgets, sequencer behaviour, and drawing remain outside generation.

The original coordinates revealed that the declared 800-unit panel did not contain sliders extending to x=880. The generated layout preserves the intended 700x500 play area and slider positions x=770/810/850, and corrects the logical/window width to 930 so the right margin is real. Generator unit tests, generate/check reproducibility, and a complete Windows OpenFL/hxcpp debug build pass.

**TimeSlider reuse is complete.** Its Layla file describes four columns, each containing a label and a custom simulation track. Generated geometry exactly preserves the existing 800x600 panel, x positions 24/215/406/597, 179x504 tracks, label band, and gaps. The generated TimeSlider composition creates the four `TimeSlider` simulation objects and supplies panel dimensions, track count, CC bindings, and travel-time defaults. This demonstrated a real common generator core without pretending that TimeSlider tracks are WorldOfCake `Slider` widgets.

**K-Diag and TileLand reuse is complete.** Both use the generator's standard WorldOfCake component composition: a custom maintained play area plus three shared speed sliders and a channel slider. Their Layla geometry preserves the 600x600 playfield and existing control positions, while correcting the logical/window height from 600 to 640 so the playfield and 20-unit bottom margin are contained. K-Diag's renderer now draws in play-area-local coordinates, so visible nodes correspond to mouse hit testing. Clicking a node relocates the selected cursor and starts it along an outgoing arc; a sink leaves it stopped.

**Zewp reuse is complete and undergoing behavioural refinement.** Its 600x560 play area, population slider, and global speed slider are generated from Layla plus EDN. The complete agent glyph and draggable blocks are constrained in model space, shared `PlayArea` clipping guards the renderer, and look-ahead was shortened so agents turn later. OpenFL can vary population from 0–40 and speed from one-third to 1.5 times default. The native bridge deliberately remains a fixed ten-agent output/snapshot contract pending a separate control-identity decision.

Standalone no-MIDI OpenFL previews are now a standard migration output. All five applications have a stable project file and can be built or launched through `run-openfl-preview.ps1`.

`ResponsivePanelHost` treats each generated panel size as a design resolution. Preview project files declare that initial client size; resizing scales the whole panel uniformly, letterboxes when aspect ratios differ, and inverse-transforms pointer input back to design coordinates. Components do not independently reinterpret window size.

`SemanticSelect` is now part of the WorldOfCake semantic widget vocabulary. Layla locates a `.../semanticselect` region; EDN supplies stable values, labels, optional colours, default choice, and an OpenFL presentation hint. The generator emits the target widget. K-Diag tests a three-choice coloured segmented selector; Gbloink tests a compact current-label selector for six scales. These are functional first drafts whose visual polish may change without changing the semantic contract. Rack should map the same K-Diag control to a multipolar switch; JUCE/web may choose radio, segmented, combo, stepped-rotary, or other native resources.

The OpenFL playfield is a behavioural and visual reference view of the same shared model used by Rack. Shared state, colours, alpha, coordinate orientation, and interaction semantics should match Rack; host chrome and physical Rack controls need not. This policy caught and fixed Gbloink's obsolete grey rendering, K-Diag's vertical mirroring and node palette, and TileLand's older grid/background styling.

This stage starts only after control IDs, component semantics, and snapshot bindings are stable enough to generate against.

### 7.1 Define Gbloink layout sources

1. Write a Gbloink Layla layout using semantic IDs and hints for play area, three speed controls, scale, simulation rate, wall notes, reset, pause, and outputs/status where relevant.
2. Use a shared layout where targets genuinely share composition.
3. Permit a separate Rack Layla file where physical jack rows, HP constraints, or compact controls make composition materially different.
4. Keep behaviour, parameter ranges, Rack widget types, artwork styling, and enum bindings out of Layla text.

### 7.2 Define companion component configuration

The WorldOfCake-owned configuration maps semantic components to:

- control/parameter/port IDs;
- OpenFL component class or composition hook;
- Rack widget class and enum binding;
- JUCE component/binding for the later VST stage;
- label and formatting;
- sizing constraints and alignment;
- custom component class, such as `GbloinkPlayWidget`;
- optional SVG styling tokens.

It also owns target geometry policy that Layla intentionally does not express: canvas size, edge padding, inter-region gaps, minimum sizes, and presentation selection. WorldOfCake uses EDN for this companion data. These facts must not duplicate Layla's hierarchy or weights.

It must not restate Layla's hierarchy or weights.

### 7.3 Implement the project-owned generator

Create `worldofcake/laylagen/`. Consume `layla.core/parse-intent` and implement an observable pipeline:

```text
Layla -> normalized IR -> target validation -> geometry
      -> generated composition/bindings/artwork in memory
      -> controlled write under generated/
```

Initial outputs:

- generated Haxe/OpenFL World composition or layout constants;
- generated semantic control IDs/bindings where this removes duplication;
- an inspectable geometry file used by tests and later native targets.

Keep Gbloink rendering, collision behaviour, and custom playfield drawing handwritten.

### 7.4 Verify generation

- golden-file tests for deterministic output;
- deep nesting, quoted IDs, hints, symbol collisions, and unknown-component errors;
- geometry invariants and minimum sizes;
- generated Haxe compilation smoke test;
- visual comparison with the current Gbloink panel;
- regenerate-from-clean-tree test proving no hand edits are required.

After Gbloink works, apply the generator to TimeSlider, K-Diag, and TileLand. Extract generator helpers only where real applications demonstrate stable commonality.

### Stage 3 exit gate

**Status: complete, 26 August 2026.**

- Gbloink's ordinary OpenFL/WorldOfCake composition is generated from Layla plus companion configuration.
- Custom rendering and behaviour remain maintained code.
- TimeSlider proves support for a different custom simulation composition.
- K-Diag and TileLand prove reuse of standard WorldOfCake component construction around custom play areas.
- All five applications have standalone OpenFL previews; the latest `SemanticSelect` changes pass OpenFL HTML5 compilation and await a Windows native rebuild after running preview processes release the shared output DLL.
- `SemanticSelect` proves one semantic control can generate substantially different native presentations without leaking target widget types into the sequencer.
- Generated output is deterministic and replaceable.

## 8. Stage 4 — modernize and build VCV Rack modules on Windows

### 8.1 Establish the Windows Rack toolchain

**Status: substantially complete.** The matching SDK, compiler environment, smoke build, real Gbloink DLL/package build, and user-directory installation have been verified. Loading and interactive testing in Rack remains to be confirmed.

1. Select the Windows Rack version to support first, preferably matching the user's installed Rack major/minor and a compatible SDK.
2. Obtain the official Windows Rack SDK and record its checksum/version.
3. Build the SDK's minimal plugin example on this laptop.
4. Convert or supplement Linux Make/bash orchestration with Windows-compatible PowerShell/CMake/Make commands as required by the SDK; retain Linux scripts until cross-platform replacements are proven.
5. Verify plugin packaging and loading in the installed Windows Rack application.

### 8.2 Replace audio-thread Haxe entry

For Gbloink:

1. Link the shared WorldOfCake control runner and native adapter.
2. Start/stop the Haxe control owner outside `Module::process()`.
3. Convert Rack UI actions and parameter changes into commands.
4. Make `process()` consume only prepared events/control snapshots.
5. Keep gate pulse shaping, voltage scaling, and per-sample output updates in native C++.
6. Publish visual snapshots for the Rack UI thread; drawing must not call Haxe.
7. Move persistence through a safe request/response or suspension point outside the real-time callback.
8. Add telemetry for queue overflow, stale snapshots, and control-runner failure.

Test rapid UI interaction, editor/widget creation and destruction, patch save/load, module duplication, sample-rate changes, engine stop/start, and removal while the control runner is active.

### 8.3 Generate Rack composition and SVG from Layla

The Rack generator consumes Layla IR plus Rack companion configuration and emits from one calculated geometry model:

- panel SVG at exactly 128.5 mm height and an HP-derived width;
- static background areas, labels, frames, and branding hooks;
- optional hidden Inkscape `components` circles;
- C++ `ModuleWidget` composition for params, inputs, outputs, lights, screws, and custom widgets;
- generated bounds/constants for custom playfield widgets;
- validation that components are inside the panel and do not overlap forbidden/clearance regions.

The SVG is the Rack panel artwork loaded by `createPanel`; physical Rack widgets remain C++ widget objects placed over it. Both must derive coordinates from the same geometry pass so the current duplicated SVG/C++ positions disappear.

Handwritten files retain:

- custom NanoVG playfield drawing;
- mouse/keyboard interaction logic;
- module DSP/CV/gate behaviour;
- unusual Rack widgets not expressible as ordinary component factories.

### 8.4 Repeat with TimeSlider and remaining apps

1. Port TimeSlider using the unchanged runner and Rack generator.
2. Confirm continuous outputs remain smooth under control-snapshot publication.
3. Port TileLand and K-Diagram, extending visual snapshot support only where demonstrated.
4. Add Zewp as the strongest proof that a Rack target can be produced without beginning from an old handwritten Rack implementation.

### Stage 4 exit gate

- Gbloink and TimeSlider build, package, load, save, and restore in Windows Rack.
- Rack audio callbacks never enter Haxe or lock the Haxe/UI owner.
- Rack UI drawing never enters Haxe.
- Panel SVG and C++ widget composition are generated from the same Layla-derived geometry.
- The Linux target either still builds or has a documented, bounded compatibility task; Windows success must not silently destroy it.

## 9. Stage 5 — WorldOfCake VST3 products

Begin only after the common runner has been proven by the Windows Rack modules.

### 9.1 Define the JUCE WorldOfCake shell

Create one reusable JUCE framework layer providing:

- plugin lifecycle and state chunks;
- host tempo, play state, sample/PPQ position, loops, seeks, and discontinuity snapshots;
- APVTS parameters mapped to WorldOfCake commands;
- WorldOfCake runner ownership;
- event-to-block/sample-offset MIDI scheduling;
- editor snapshot consumption;
- panic/all-notes-off on reset, seek, stop, destruction, or queue failure.

Gbloink should initially be a MIDI-effect/sequencer plugin unless product testing identifies a better host form. Host support for MIDI-effect VST3 varies, so verify in the user's actual DAWs early and retain standalone/test-host options.

### 9.2 Generate JUCE UI composition

Extend the WorldOfCake Layla generator with a JUCE target:

- native JUCE sliders, buttons, labels, and custom playfield placement;
- APVTS attachment/binding declarations;
- generated layout/resized code or geometry constants;
- maintained custom drawing and interaction for play areas.

Do not embed OpenFL or a web view merely to reuse controls.

### 9.3 App sequence

1. Gbloink VST3/standalone test shell.
2. TimeSlider, validating continuous automation/control output policy.
3. Goldenpond WorldOfCake sequencer after its separate library/score adapter and headless scheduler are ready.
4. TileLand, K-Diagram, and Zewp according to musical priority and host-output fit.

### Stage 5 exit gate

- At least Gbloink and TimeSlider build as Windows VST3 products from the shared runner.
- DAW transport, state, editor reopen, automation, and MIDI scheduling are tested in representative hosts.
- Their JUCE composition is generated from WorldOfCake-owned Layla sources/configuration.
- No app has duplicated the threading, queue, transport, or parameter-binding architecture.

## 10. Cross-cutting verification

Every stage should add tests rather than rely only on visual/manual success:

- Haxe unit tests for model behaviour.
- Cross-target deterministic fixtures for commands, time, events, and snapshots.
- C++ unit tests for queues, scheduling, interpolation, overflow, and shutdown.
- Thread assertions/instrumentation proving forbidden callbacks do not enter Haxe.
- State-schema version and migration tests.
- Layla IR and generator golden tests.
- SVG parse/render smoke tests and geometry validation.
- Windows clean-build scripts tested from paths containing spaces.
- Rack plugin load/save/reload tests.
- JUCE plugin validation and DAW smoke tests.

Performance measurements should include control-runner cadence/jitter, command-to-result latency, queue high-water marks, native callback cost, snapshot publication cost, and UI redraw performance.

## 11. Decision points that remain open

Resolve these using experiments at the named stage rather than deciding them speculatively:

- exact bounded queue implementation and capacities;
- background control-thread cadence and event lookahead horizon;
- behaviour following late commands or a stalled control runner;
- whether visual snapshots use fixed arrays, bounded variable payloads, or app-specific buffers;
- RNG state persistence beyond deterministic testing;
- one shared Layla composition versus target-specific Layla files per app;
- Clojure invocation/packaging of `laylagen` inside the Windows build pipeline;
- future Rack SDK upgrade policy beyond the currently matched Rack/SDK 2.6.4 pair;
- VST3 MIDI-effect compatibility in the user's DAWs;
- when Goldenpond enters Stage 5 relative to the remaining graphical apps.

Record each resolved decision in `consolidate_woc_and_audio.md` and update this plan if it changes task order.

## 12. Immediate next task sequence

### Per-module Haxe ownership migration

Historical note: the old Rack bridge had a structural defect where static
`*HarnessApi` wrappers stored models in process-wide fields, so multiple Rack
modules could overwrite and share one Haxe model. Those static wrappers and
their standalone bridge build have been removed. Haxe-generated C++ classes
were not the problem; singleton bridge ownership was.

The target architecture is one ordinary bridge object and one ordinary model
per native runner. WorldOfCake code must describe one app instance only. It
must not contain a singleton, a process-wide model registry, an instance map, or
logic for managing Rack multiplicity. Rack owns multiplicity by constructing
multiple independent `Module`/runner pairs.

Migration order:

1. Change Gbloink's Haxe harness from static model state and static operations
   to an instance class whose constructor creates one `Gbloink` model and whose
   methods operate on that model.
2. Make the native `GbloinkControlRunner` own one hxcpp object reference to its
   harness. Construct it on the runner's control thread, service all commands,
   snapshots, events, and persistence through that object, and destroy it after
   the worker has joined.
3. Regenerate the hxcpp bridge and add a two-instance regression harness: create
   two runners with different seeds, mutate only runner A, and assert that
   runner B's snapshots, events, and exported state are unchanged.
4. Verify Rack with two Gbloink modules, including independent reset, pause,
   block creation, scale, autosave, save/load, duplication, and removal.
5. Apply the same object-owned bridge shape to KDiagram, TileLand, and
   TimeSlider. Do not introduce a shared generic registry while doing so; only
   factor genuinely target-neutral call plumbing.
6. Update the Haxe/C++ bridge documentation and skills after the Gbloink pilot
   passes, then make per-module ownership part of the Rack completion gate.

**Gbloink pilot result (2026-08-28):** the object-owned bridge is implemented,
the Windows Rack module builds and installs, and two simultaneous Gbloink
modules have been tested successfully as independent worlds. The obsolete
static bridge is no longer in the Gbloink build target. The next migration
target is KDiagram, followed by TileLand and TimeSlider.

Rejected alternatives: thread-local statics (ownership would depend on call
thread and construction order), a global handle registry (still singleton-style
WorldOfCake architecture), and direct Rack-thread calls into Haxe (violates the
control-thread boundary).

### Persistence hardening decision

Gbloink's full reflective Haxe JSON export was implicated in earlier Rack autosave hangs. Rack-facing state must therefore be serialized by explicit, deterministic application code (`StringBuf`/field writers and corresponding parsers), never by generic reflective `Json.stringify` over the live model. The native adapter continues to marshal persistence to the control thread with a bounded wait and an abandoned-request path. A quit investigation also found a separate ASIO/other-module shutdown stall; blank Rack and Gbloink-only sessions exit cleanly, so that incident is not currently attributed to Gbloink.

KDiagram, TileLand, TimeSlider, Zewp, and Gbloink now use native `dataToJson`/`dataFromJson` adapters with the same manual-serializer and bounded-request contract. Rack-facing state remains an opaque app JSON string, and each Rack module mirrors restored host params after load so stale panel values do not overwrite imported Haxe state on the next `process()` tick.

Stage 2 is complete. The next working session should begin Stage 3:

1. **Completed:** audit and implement TileLand with seeded grids, cadence-safe cursor travel, dual inputs, six continuous outputs, and a fixed visual snapshot.
2. **Completed:** audit and implement K-Diag with deterministic graph generation, cadence-safe multi-arrival stepping, continuous cursor outputs, discrete arrivals, and a bounded graph snapshot.
3. **Completed:** audit and implement Zewp with seeded world generation, elapsed-time motion, v2 persistence, queued obstacle dragging, ten continuous outputs, and a fixed visual snapshot.
4. Treat the five implemented runners and tests as the completed fit/gap matrix and resist speculative runner generalization.
5. **Completed:** inventory and stabilize Gbloink's semantic component/control IDs for generated composition.
6. **Completed:** write the first Gbloink Layla source and WorldOfCake-owned companion configuration.
7. **Completed for the Gbloink pilot:** implement the smallest OpenFL/WorldOfCake generator slice, deterministic geometry/tests, checked output, and Windows OpenFL compilation.
8. **Completed:** TimeSlider validates reuse with a different custom-drawn simulation architecture; shared parsing, validation, geometry, deterministic output, and invocation remain common while composition rendering stays explicit per application shape.
9. **Completed for the Windows environment proof:** install MSYS2/MinGW64, add the matching Rack 2.6.4 Windows SDK, compile/package/install the historical Gbloink module, and provide a PowerShell build entry point.
10. **Completed:** the Rack modules now use the shared runner boundary rather than old direct-Haxe/static bridge calls.

The completed milestone is a repeatable Windows command proving that authoritative Haxe Gbloink and TimeSlider behaviour can drive C++ consumers without entering Haxe from simulated audio callbacks. The next milestone is demonstrating that this is a WorldOfCake-wide contract, not merely a two-app special case.

## UI Pipeline Checkpoint (15 September 2026)

The Layla work has moved beyond the original Gbloink pilot. The current
pipeline is:

```text
layouts/openfl/<app>.layla + layouts/openfl/<app>.edn
    -> laylagen
    -> Source/generated/<app>/ and bridge/native/worldofcake/generated/

layouts/rack/<app>.layla + layouts/rack/<app>.edn
    -> rack_layout_generate
    -> derivatives/vcvrack/<app>/generated/<panel>.svg
       bridge/native/worldofcake/generated/rack/<app>/...RackLayoutGenerated.h
```

`laylagen/` is maintained generator source, including tests and the Java
launcher/package entry point. `layouts/openfl/` and `layouts/rack/` are
maintained authored inputs. Generated Haxe, C++, SVG, native build output,
packages, and local Rack installations are derived artifacts.

All five current Rack modules now have Rack Layla/EDN variants. These variants
may differ from OpenFL for physical panel geometry, Rack-only output sockets,
and native widget idioms. They should not duplicate semantic facts that belong
in the canonical app definition. The Rack generator currently owns generated
panel branding, panel regions, output metadata, and migrated geometry;
remaining handwritten native control placement is a tracked migration boundary,
not a second intended source of truth.

Next UI work:

1. Migrate remaining Rack native control/widget positions and labels into Rack
   Layla/EDN, preserving custom playfield drawing where appropriate.
2. Make generation/checking fail fast when required Rack controls or geometry
   are absent from metadata.
3. Complete generated passive titles and shared control presentation across any
   remaining OpenFL apps.
4. Keep Linux and Windows generation/build paths aligned; neither platform's
   generated files are authoritative.
5. Begin VST/JUCE only after host-neutral control and timing contracts are
   documented against this pipeline.
