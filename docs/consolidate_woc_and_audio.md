# Consolidating WorldOfCake and Audio Applications

Status: **definitive architectural guide and source inventory**, updated 26 August 2026. The shared native-runner audit and five-app Layla/OpenFL migration are complete. The previews are in a cross-app sizing, coordinate, interaction, and semantic-widget refinement pass before Windows Rack modernization.

This report considers how WorldOfCake, SandSonify, and future experimental musical applications can share implementations across web, VST3/standalone, VCV Rack, and later targets. It is based on the current Haxe/OpenFL WorldOfCake sources, the existing hxcpp-based Rack derivatives, and the C++/JUCE SandSonify implementation.

### Authority and use of this guide

This file is the project-level source of truth for consolidation work. An AI or human working on WorldOfCake/SandSonify/Goldenpond consolidation should read it before proposing or implementing architecture. Current source code remains authoritative for what an application does today; this guide is authoritative for the intended cross-target direction and for decisions explicitly marked as settled.

Do not silently reverse a settled decision because another technology is theoretically attractive. If implementation evidence requires a change, document the evidence, update this guide deliberately, and identify the superseded decision. Exploratory ideas in this file are not permission for a portfolio-wide rewrite.

Settled decisions as of this revision:

- “One codebase” means one authoritative implementation of each musical behaviour, not one language or one UI toolkit everywhere.
- Haxe remains first-class for control-rate/domain logic; portable C++ is the preferred hard real-time layer.
- Managed/Haxe work should not be required inside host audio callbacks; use prepared events/snapshots and bounded communication.
- JUCE, Rack, OpenFL, and the browser are target shells with genuinely target-specific lifecycle and presentation code.
- VST3/standalone products use JUCE as their application/plugin framework. OpenFL is not embedded in JUCE plugins.
- A JUCE plugin may use native JUCE controls or, for a separately justified UI, a JUCE WebView. WebView is not the default merely to share pixels.
- The Goldenpond WorldOfCake app uses a compact form of separate progression/line inputs, not a general code document.
- Goldenpond VST3/standalone v1 uses native JUCE controls, especially `juce::TextEditor`; it does not require CodeMirror, a WebView, React, or OpenFL.
- Goldenpond Rack v1 supports live text entry inside Rack. It is not designed around preparing source externally and loading it for performance.
- Goldenpond Rack v1 uses native Rack text fields with four line inputs. Soft wrapping is not a prerequisite for short per-line patterns; the progression field may use sufficient width/horizontal navigation, with a focused wrap enhancement only if testing proves necessary.
- Goldenpond remains a separately developed note-generation library. WorldOfCake owns the live sequencer, transport, scheduling, edit application, and host output.
- All WorldOfCake sequencers, including the planned Goldenpond sequencer, use one shared WorldOfCake lifecycle and one shared policy for GUI/control work versus real-time host work. Target adapters may differ; individual apps do not invent their own threading architecture.
- Goldenpond parsing and note-data regeneration occur outside the audio callback, normally after text edits on the GUI/control side. Playback consumes the last valid immutable score until a replacement is safely published.
- WorldOfCake remains the home of common sequencer widgets, logical coordinate handling, and application composition. Layla may generate WorldOfCake compositions and bindings; it does not replace WorldOfCake with unrelated per-app UI architectures.
- SandSonify and future audio generators form a second application family: a portable native simulation/audio core plus host UI shells. SandSonify does not embed OpenFL or run its pixel simulation in Haxe merely to reuse WorldOfCake controls.
- SandSonify may share Layla layout descriptions and generated semantic control metadata with WorldOfCake applications, but its initial JUCE and Rack controls are native controls generated or composed directly for those hosts.

### Implementation status at this revision

The recommended first vertical experiment has now succeeded on Windows:

- The Windows toolchain is established with Haxe 4.3.6, hxcpp 4.3.2, Lime 8.1.3, OpenFL 9.3.4, and Visual Studio 2022 x64.
- Gbloink is deterministic under an injected test seed and its movement is delta-based while preserving the former nominal feel.
- Gbloink and TimeSlider share one native background `ControlThread`, bridge build, bounded command model, shutdown lifecycle, and combined C++ harness.
- Gbloink proves discrete-event publication; TimeSlider proves continuous-control snapshot publication.
- The simulated audio consumers operate only on prepared native data and do not enter Haxe, lock the Haxe/UI owner, allocate, or render.
- Interpreter tests, hxcpp-native tests, native manual/background harness tests, and the OpenFL HTML5 regression build pass.

This is an architectural proof, not yet a Rack or VST integration. The input routing decision is now two explicit bounded SPSC queues per runner: GUI/message-thread commands and host/audio-thread commands, both consumed by the Haxe control thread with host-first priority. This avoids a new MPSC dependency and reserves capacity independently for each source. Continuous automation, CV, and transport state should use replaceable latest-value mailboxes rather than enqueueing every sample. TileLand confirms the contract for a randomized grid, GUI tile edits, semantic speed changes, six continuous outputs, and a substantially larger fixed visual snapshot. K-Diagram and Zewp have since completed the same audit and implementation, so all five current applications now share the runner/thread contract and the work has advanced to Layla-generated composition.

## 1. Executive conclusion

The useful goal is not literally one language or zero target-specific files. The useful goal is that each musical behaviour has one authoritative implementation, while host integration is either shared or generated.

The proposed direction has three deliberately constrained layers:

1. **Haxe for control-rate musical behaviour**: generative sequencing, interactive simulations, state machines, event generation, and other work that does not have to execute in a hard real-time callback.
2. **Portable C++ for hard real-time work**: audio DSP, sample clocks, event scheduling, trigger/gate shaping, CV interpolation, lock-free communication, and engines such as SandSonify's sonifiers. This C++ should be independent of JUCE and Rack so it can also compile to WebAssembly.
3. **Declarative schemas and generators for repeated facts**: application identity, parameters, controls, ports, persistence versions, host mappings, UI geometry, and documentation.

JUCE, VCV Rack, OpenFL, and the browser then become target shells. They should adapt the shared engines to their different lifecycle, drawing, automation, transport, and I/O models without reimplementing the musical idea.

This is a portfolio architecture rather than a special solution for SandSonify. An individual application may use only the layers it needs:

- A WorldOfCake sequencer: Haxe control engine plus a native scheduling/output adapter.
- SandSonify: portable C++ simulation/audio engine plus target UI shells.
- A future hybrid: Haxe generative control engine driving a portable C++ synthesizer.

## 2. Why the portfolio context matters

WorldOfCake already demonstrates that Haxe is valuable for a family of experimental sequencers. Its shared interfaces, coordinate mapping, event queue, OpenFL shells, hxcpp bridges, Rack modules, persistence hooks, and build scripts are the beginning of a multi-target toolkit.

SandSonify introduces a different workload. Its falling-sand simulation and frame analysis operate at visual/control rates, but its RGB waveform readers and 72 oscillators produce continuous audio at sample rate. That makes it unsafe to assume that the execution strategy appropriate for a graphical sequencer is also appropriate for every audio engine.

The important boundary is therefore not Haxe versus C++. It is control-rate work versus hard real-time work.

## 3. Current common model

The existing WorldOfCake applications broadly follow this flow:

```text
UI input
    -> IControlPanel calls identified by uid
    -> ISequencerControl state transition
    -> advanceTime(delta)
    -> queued worldofcake.Event values
    -> host instrument/output adapter
```

Their OpenFL shells generally run a nominal 1 ms timer, advance the sequencer, drain due events, and render separately on `ENTER_FRAME`. `World`, `View`, `Layout`, and the coordinate-mapping components connect platform UI to the control interface.

The Rack derivatives preserve the Haxe musical models but replace OpenFL rendering and output with Rack widgets, NanoVG drawing, CV jacks, and gates. Native control runners call Haxe harnesses on a non-audio control thread and publish POD snapshots to Rack C++.

SandSonify follows a compatible but audio-heavier flow:

```text
UI input
    -> simulation update and RGBA render
    -> shared frame analysis
    -> prepared waveform/band snapshots
    -> audio callback consumes snapshots
    -> continuous stereo output
```

Both families therefore need control commands, logical time, state persistence, visual snapshots, parameter snapshots, and safe publication to a real-time consumer. They differ mainly in the content produced by the control engine and in whether a substantial audio engine follows it.

## 4. Proposed execution boundary

### 4.1 Haxe control engine

Haxe should remain a supported first-class implementation language for:

- application/world state;
- GUI-rate and control-rate simulation;
- generative sequencing;
- interaction rules;
- timestamped musical event generation;
- visual-model snapshots;
- platform-neutral persistence;
- rapid experimentation.

The architectural rule should be:

> Haxe may generate future events and immutable control/visual snapshots, but no host is required to call Haxe from its hard real-time audio callback.

### 4.2 Portable real-time C++ kernel

A host-neutral C++ library should provide:

- a non-owning audio-block representation;
- sample and transport clocks;
- fixed-capacity command and event queues;
- parameter snapshots;
- snapshot exchange between control and audio domains;
- event-to-sample-offset scheduling;
- CV interpolation and smoothing;
- trigger and gate generation;
- reusable oscillators and DSP utilities;
- optional audio engines, including SandSonify;
- deterministic test hooks.

It should not depend on JUCE, Rack, OpenFL, or browser APIs. Adapters translate JUCE buffers, Rack per-sample calls, and Web Audio worklet buffers into this common model.

### 4.3 Directional asynchronous bridge

The desired boundary is:

```text
Host/UI -> command queue -> control engine
Control engine -> timestamped event/snapshot queue -> real-time adapter
```

The real-time thread consumes already prepared data. It does not acquire a UI/Haxe mutex, allocate Haxe objects, invoke the hxcpp garbage collector, or run an unbounded simulation step.

This is a change from the current Rack pattern, where `Module::process()` can attach to hxcpp and call Haxe while sharing a mutex with UI entry points. That has enabled working prototypes, but it can block the audio thread and makes callback timing depend on the Haxe runtime. It should be treated as transitional architecture rather than the common long-term contract.

## 5. Common application contract

The shared platform should define optional capabilities rather than forcing every application into one large interface.

### Lifecycle and persistence

- create/configure;
- reset;
- pause/resume where meaningful;
- export/import versioned state;
- destroy.

### Control domain

- advance logical/control time;
- accept typed commands;
- publish timestamped musical events;
- publish immutable visual/control snapshots;
- expose logical time and dirty/version counters.

### Real-time domain

- prepare sample rate and maximum block size;
- receive immutable parameter and event data;
- process audio or CV without allocation, blocking, or UI access;
- reset real-time state.

### Description

- stable application and control IDs;
- parameters, ranges, defaults, units, scales, and automation properties;
- inputs and outputs with signal semantics;
- state schema version;
- logical layout and asset references;
- supported targets.

Applications implement only relevant capabilities. A MIDI sequencer need not expose audio processing; a synthesizer need not expose a graphical world; a Rack utility may expose only CV.

## 6. Stable bridge data

Hosts should not depend directly on arbitrary Haxe object layouts. A narrow, versioned C-compatible bridge should carry plain data. Likely values include:

- `MusicalEvent`: timestamp, type, target/channel, and typed numeric payload;
- `ControlCommand`: control ID, gesture/type, local coordinates, and value;
- `TransportSnapshot`: tempo, beat/sample position, playing state, and discontinuity generation;
- `ParameterSnapshot`: immutable numeric values indexed by stable IDs;
- `VisualSnapshot`: app-defined immutable arrays plus a version counter.

The current five-field `worldofcake.Event` is a useful prototype but its MIDI-shaped `data1`/`data2`/`data3` fields are already interpreted differently by Rack modules. A new event schema should preserve simple MIDI mapping while making semantic intent explicit enough for CV, gates, notes, and modulation.

A stable ABI would also permit headless tests, Python/Java bindings, dynamic engines, and replacement of an implementation language without rewriting every host.

## 7. Declarative application manifest

At portfolio scale the same facts are currently repeated in Haxe constants, Rack enums and `configParam` calls, JUCE APVTS declarations, HTML controls, `plugin.json`, SVG panels, persistence code, and Markdown output documentation.

A small manifest should become the source of truth for stable facts such as:

- app ID, display name, vendor, version, and engine kind;
- parameter IDs, types, ranges, defaults, units, scales, and groups;
- control IDs and logical coordinate spaces;
- input/output IDs and note/CV/gate/audio semantics;
- MIDI and voltage mappings;
- state schema version;
- target inclusion and target-specific presentation hints;
- UI geometry, labels, colours, and assets where these are genuinely shared.

Generators can then produce Haxe identifiers/types, a C ABI header, JUCE parameter boilerplate, Rack enums/configuration, TypeScript models, metadata, documentation, and conformance fixtures.

The manifest should describe facts and contracts, not become a general-purpose programming language. Simulation algorithms, explosion behaviour, arbitrary drawing, and DSP loops should remain normal code. Likewise, UI generation should initially cover IDs, binding, logical geometry, and ordinary controls while allowing custom renderers.

## 8. UI strategy

UI reuse has two levels.

**Shared semantics should be mandatory:** control identity, value range, gesture, label, grouping, coordinate space, and formatting.

**Shared pixels should be optional:** the browser may use HTML/canvas, a JUCE plugin may use native components or a WebView, and Rack may use its native widget/panel conventions. Custom playfields can consume the same visual snapshot without sharing the renderer.

JUCE 8's WebView support makes a shared HTML/CSS/TypeScript frontend possible for a browser and a VST/standalone target, but it does not compile JUCE itself for the browser. It is an optional target-shell technique, not the default architecture. For modest forms and controls, prefer the host's native widgets. VCV Rack should normally retain native Rack presentation. Existing `ui.YAML` is relevant prior art; the near-term opportunity is to turn a narrower subset into generated contracts rather than immediately inventing a complete universal UI DSL.

## 9. Target model

### Web

- Haxe may compile control engines to JavaScript or C++ engines may compile to WebAssembly.
- Continuous DSP should run in an AudioWorklet, preferably as portable C++/Wasm.
- HTML/canvas handles UI and exchanges commands/snapshots with the engine.

### JUCE VST3 and standalone

- JUCE owns plugin lifecycle, host parameters, state chunks, transport, device/plugin audio callbacks, and possibly UI.
- The processor delegates real-time work to the portable kernel.
- A sequencer adapter converts queued musical events into sample-offset MIDI.

### VCV Rack

- Rack owns module lifecycle, parameters, ports, panel widgets, and per-sample calls.
- A shared native adapter schedules Haxe-produced events and produces CV/gates without calling Haxe under an audio-thread mutex.
- Rack-specific voltage semantics remain explicit target mappings.

### Later targets

- CLAP, AU, LV2, desktop, embedded, Python, and Java should consume the same descriptions and ABI where appropriate.
- Support for a target should not require every engine to compile through the same language toolchain.

## 10. Migration plan outline

### Phase 0: preserve working systems

- Keep current OpenFL applications, Rack modules, and SandSonify VST working.
- Add deterministic/headless tests before moving authoritative logic.
- Record toolchain versions and generated-source policy.

### Phase 1: inventory and normalize contracts

- Complete the application inventory below.
- Define event, command, parameter, time, visual-snapshot, and state concepts.
- Identify accidental differences in units and cadence.
- Choose stable IDs independently of current UI constants.

### Phase 2: manifest pilot

- Create one minimal manifest for a well-understood app, probably TimeSlider or Gbloink.
- Generate identifiers, host parameter/port declarations, bridge types, and documentation.
- Keep custom behavior and drawing handwritten.

### Phase 3: real-time adapter pilot

- Introduce fixed-capacity command/event queues and a native scheduler.
- Move one Rack module from audio-thread Haxe calls to asynchronous prepared events/snapshots.
- Measure latency, jitter, queue pressure, and UI responsiveness.

### Phase 4: portable C++ audio kernel

- Extract JUCE-independent audio buffers, parameter snapshots, and DSP utilities from SandSonify.
- Build the same kernel in JUCE and a headless test executable.
- Add VCV and Emscripten adapters only after the host-neutral tests pass.

### Phase 5: browser/Wasm pilot

- Compile the portable SandSonify core with Emscripten.
- Start with simulation/render equivalence, then add AudioWorklet processing.
- Compare native and Wasm grids, pixels, analysis, and audio within defined tolerances.

### Phase 6: targeted UI reuse

- Reuse UI semantics and generated bindings first; do not require identical rendering toolkits.
- Test an HTML/canvas JUCE WebView only for an application whose interaction genuinely benefits from it and after measuring deployment/bridge cost.
- Preserve native Rack rendering.
- Expand schema-driven UI only where repeated implementation demonstrably hurts.

### Phase 7: portfolio automation

- One command per app/target and one matrix command for all supported builds.
- Generated manifests, metadata, bindings, docs, and tests.
- CI or local verification matrices for native, Rack, and Wasm targets.
- Packaging and install steps remain target adapters, not app-specific scripts.

## 11. Architectural inventory: shared WorldOfCake framework

The current framework under `Source/worldofcake` provides:

- `ISequencer`: time advancement, ordered event consumption, pause/resume/reset, and JSON persistence;
- `IControlPanel`: mouse, keyboard, button, text, and numeric-value entry points addressed by integer UIDs;
- `ISequencerControl`: the combined musical/control contract;
- `IControlPanelView`: pull-style dirty/redraw calls;
- `IInstrument`: an event sink;
- `Event`: timestamp plus integer type and three integer data fields;
- explicit `WindowPoint`, `PanelPoint`, and `LocalPoint` coordinate types;
- `CoordinateMapper`, `ComposedCoordinateMapper`, and UI components such as `PlayArea` and `Slider`;
- OpenFL `Main -> World -> Sequencer/View` application shells;
- `MonitorInstrument` as the current desktop event destination.

Common strengths are explicit separation of control IDs, domain logic, coordinate conversion, rendering, and event output. Common gaps are the MIDI-shaped but weakly typed event format, per-app bridge boilerplate, nominal 1 ms timers whose actual host cadence can differ, and no formal boundary between control-safe and real-time-safe operations.

Four current apps have Rack derivatives: Gbloink, K-Diagram, TileLand, and TimeSlider. Zewp has no corresponding Rack directory.

## 12. Gbloink inventory

### Musical model

Gbloink contains three coloured balls moving in a 700 x 500 local play area. The user adds or removes rectangular blocks. Ball/block collisions emit note-style events; optional edge-note mode also emits on play-area boundary collisions. Ball/ball collision changes motion but does not directly emit an event.

Pitch is derived from vertical position through `NoteCalculator`. Events use type `0`, `data1` as MIDI channel, `data2` as note, and `data3` as velocity 100.

### Controls and visual state

- Play-area click: add a randomly sized/coloured block, or remove the clicked block.
- Three ball-speed controls use UIDs 10-12.
- Clear blocks uses UID 20.
- Pause toggle uses UID 21.
- Edge-note enable uses UID 22.
- Scale is set through a direct helper rather than the generic control interface.
- Visual snapshot needs ball position/radius/colour and block bounds/colour.

### Timing and persistence

The model's `moveBall` applies velocity once per `advanceTime` call rather than multiplying movement by `delta`; cadence therefore changes physical speed. Logical time does use `delta`. State version 1 stores logical time, pause, scale, balls, blocks, and edge-note mode. Random block creation and initial state use the ambient Haxe RNG, so deterministic replay is not yet defined.

### Current targets

- OpenFL desktop shell exists.
- Rack derivative exists and is documented as a Linux-first working module.
- Rack outputs are held 1 V/oct pitch and a roughly 1 ms 10 V gate pulse.
- Rack exposes playfield, three speeds, persistence, and additional transport/edge-note controls.
- Rack currently advances Haxe on a configurable control cadence (documented as 5 ms in its README), attaches Rack threads to hxcpp, and protects Haxe entry with a mutex.

### Consolidation implications

Gbloink is a strong manifest and asynchronous-bridge pilot because its state and outputs are understandable and it already spans OpenFL and Rack. Before using it for deterministic cross-target tests, movement should become time-based or its tick-rate dependency should be made an explicit app contract, and randomness should be injectable/seedable.

## 13. Zewp inventory

### Musical model

Zewp creates ten coloured moving line agents and twenty draggable rectangular obstacles. Each agent looks ahead for world edges, other agents, and blocks. On detecting an obstruction it rotates by a fixed signed angular increment; otherwise it advances by a velocity vector.

`generateEvents()` emits CC-style events for every agent: type `1`, common MIDI channel 1, CC numbers 10-19, and vertical position mapped to 0-127.

### Controls and visual state

- Play-area mouse down selects a block.
- Drag moves the selected block using a stored pointer offset.
- Mouse up releases it.
- There are currently no functional generic sliders, buttons, or keyboard controls.
- Visual snapshot needs agent position, angle, length, colour, look-ahead marker/front state, and obstacle geometry.

### Timing and persistence

Agent movement and turning now scale with elapsed seconds, calibrated so a 1 ms step preserves the original feel. Obstacle avoidance remains a nonlinear sampled simulation, so chaotic trajectories can diverge at substantially different control cadences; hosts should use the declared bounded cadence. The old `generateEvents()` call remains tied to OpenFL view drawing and is not the native output contract. Persistence v2 now stores agents, turn direction, blocks, time, and pause. Initial agents, turn direction, and blocks use the injectable random source; tests are seeded and interactive runs remain random.

### Current targets

- OpenFL desktop shell exists.
- No VCV Rack derivative is present.
- A portable native runner/harness adapter is now present; no VST product exists yet.

### Consolidation implications

**Compatibility result:** implemented and passing. Zewp's OpenFL model now supports 0–40 agents and a global one-third-to-1.5-times speed multiplier; persistence v3 records the multiplier. Look-ahead was shortened from fifteen to eight probe steps. The complete rotated glyph and dragged blocks are constrained to the 600x560 model-space play area, while shared renderer clipping provides a separate safety boundary. The native runner still publishes ten continuous Y-position slots and at most ten visual agents; dynamic control identity/output policy is explicitly deferred rather than silently changing that real-time contract.

## 14. TimeSlider inventory

### Musical model

TimeSlider contains four parallel vertical tracks. Clicking within a track selects a target level from vertical position and a travel time from horizontal position. Travel time follows a logarithmic scale from a slow left edge to a fast right edge. The current defaults used by the Rack documentation are 120 seconds and 0.5 seconds.

Each moving slider can emit a CC-style event: type `1`, channel 1, controller 1-4, value 0-127 derived from inverted vertical position. The `BASE_CC` constant is currently 20 but the constructed sliders use controller numbers 1-4, so the unused/inconsistent constant should not become a generated contract without a decision.

### Controls and visual state

- Play-area click is the primary and only implemented app-specific control.
- Drag, generic value, button, and keyboard handlers are currently empty.
- Visual snapshot needs each track's bounds, current position, destination, movement state, and perhaps chosen duration/speed.

### Timing and persistence

Movement explicitly scales by `delta`, making TimeSlider more portable across control cadences than Gbloink or Zewp. State version 3 stores time, pause, duration bounds, dimensions, and complete slider state. Import includes migration/rebuild behavior for older three/narrow-track layouts.

`generateEvents()` is separate from `advanceTime` and emits only while sliders move. The current Rack module instead documents continuous CV reflecting current position, demonstrating that semantic outputs may be richer than the original event stream.

### Current targets

- OpenFL desktop shell exists but does not use the same `World` composition pattern as all other apps; its main owns the sequencer/view more directly.
- Rack derivative exists as a 26 HP module.
- Rack exposes four continuous 0-10 V outputs plus simulation-rate, reset, and pause controls.
- The Haxe Rack API exposes state, control, visual geometry, and current MIDI-style values.

### Consolidation implications

TimeSlider is probably the cleanest first schema pilot: it is small, delta-correct, well persisted, and its four repeated controls/outputs make generation valuable. It is also a good example of why the shared app description must distinguish events from observable control signals.

## 15. TileLand inventory

### Musical model

TileLand is a 12 x 12 grid of two tile types. Three coloured cursors traverse the tile maze, with tile shape determining how direction changes. Clicking flips a tile. Each cursor continuously generates X and Y CC-style events: type `1`, channel 1-3, controller 1 for X or 2 for Y, value 0-127.

### Controls and visual state

- Play-area click flips the selected grid tile.
- Three speed sliders use UIDs 10-12.
- Other generic handlers are empty.
- The layout declares a channel-slider region, but the sequencer exposes no corresponding `newValue` behavior and `getBaseChannel()` simply returns 1. This is currently presentation residue, not a reliable control contract.
- Visual snapshot needs tile types, cursor positions/directions/colours, grid dimensions, and possibly per-cursor movement progress.

### Timing and persistence

Cursor update receives `delta`. The original implementation discarded travel beyond the first tile boundary in a control call, so equivalent elapsed time could follow different paths at different cadences. The sequencer now subdivides only at tile boundaries and preserves the remaining travel, with coarse/fine cadence tests. State version 2 stores tile types, cursor tile/direction/channel/speed/progress, logical time, and pause. Grid generation now accepts the common injectable random source: interactive construction remains random, while tests use a fixed seed. Serialized tiles still provide exact session restoration after creation; RNG continuation is not persisted.

### Current targets

- OpenFL desktop shell exists.
- Rack derivative exists.
- Rack publishes six continuous 0-10 V outputs: X and Y for each of three cursors; it has no gates.
- A Haxe Rack API exposes tile and cursor snapshots, control, state, and timing.

### Consolidation implications

TileLand is a good visual-snapshot and repeated-port-generation test. The unused channel layout/control should be removed or implemented before schema extraction. Continuous coordinate signals should be first-class outputs rather than inferred only from dense CC events.

**Compatibility result:** implemented and passing. Tile flips use the GUI command queue; cursor-speed changes use semantic `setValue` commands and can arrive through the appropriate GUI or host queue. A native snapshot publishes six normalized cursor values to the simulated audio consumer without Haxe access. A separate fixed visual snapshot publishes the 12 x 12 tile grid and three cursors. The legacy six-CC-events-per-tick stream is discarded by the native facade after each tick because it duplicates the continuous snapshot; existing OpenFL and old Rack paths are unchanged.

## 16. K-Diagram inventory

### Musical model

K-Diagram builds a random directed graph of twelve nodes inside a radius of approximately 0.9. Three coloured cursors travel between connected nodes. Arrival emits a note-style event, and movement emits X/Y CC-style events.

Arrival events use type `0`, cursor MIDI channel, note `60 + node index`, and velocity 100. Position events use type `1`, CC 1/2. The graph's local coordinate system is -1 to 1, but the Haxe CC calculation multiplies raw coordinates by 127 without translating/clamping them into 0-127. The Rack derivative avoids relying solely on this by reading cursor positions directly and mapping them to voltage.

### Controls and visual state

- Play-area click selects a node for the currently selected cursor and resumes traversal.
- Speed controls use UIDs 10-12.
- Base MIDI channel uses UID 20 and assigns consecutive channels.
- Keys 1/2/3 select the cursor.
- Space rebuilds the random graph.
- `[` and `]` rotate graph and cursors.
- Direct helper methods expose these operations for Rack.
- Visual snapshot includes nodes, directed arcs, radius, cursor position/target/colour/motion, and selected cursor.

### Timing and persistence

Cursor movement scales by `delta`. The original code stopped at the first arrival within a call, losing leftover travel and timestamping the arrival at the end of the tick. It now consumes multiple arrivals when necessary and assigns their actual logical times. State version 2 stores the complete graph, arc data, cursor state, time, pause, selection, and radius. Graph construction, cursor starts, and weighted arc choices now use the common injectable random source. Interactive resets remain random; tests are seeded. RNG continuation is not persisted.

### Current targets

- OpenFL desktop shell exists.
- Rack derivative exists as a 44 HP module.
- Rack provides four outputs per cursor: arrival gate, continuous Y, continuous X, and sample-and-held Y.
- Rack controls include three speeds, channel, selected cursor, simulation cadence, reset, pause, and rotation.
- The Haxe Rack API exposes a particularly broad visual/state bridge for graph rendering.

### Consolidation implications

K-Diagram is the richest test of custom rendering, structured visual snapshots, keyboard/command normalization, and mixed event/continuous outputs. It should not be the first migration pilot. Its coordinate-to-CC mapping needs clarification, and graph randomness should become seedable for deterministic equivalence testing.

**Compatibility result:** implemented and passing. The native runner publishes six correctly normalized continuous coordinates and retains note-style arrival events while discarding redundant movement CC events. Its bounded visual snapshot holds twelve nodes, up to 64 directed arcs, and three complete cursor records. Seeded graph/topology tests, cadence tests, state restoration, semantic controls, mixed output consumption, and native audio-boundary tests pass. This demonstrates that mixed discrete/continuous output does not require another lifecycle or queue architecture.

## 17. Cross-app findings

### Reusable now

- `ISequencer` lifecycle and versioned JSON idea;
- local control IDs and typed coordinate spaces;
- separation of sequencer, view, world, and output sink;
- event queues;
- dirty/redraw signaling;
- logical play-area coordinates;
- hxcpp compilation of OpenFL-free Haxe models;
- native host replacement of rendering and output.

### Needs normalization

- time units and whether motion multiplies by `delta`;
- whether event generation occurs inside `advanceTime` or in a separate call;
- MIDI-shaped event field semantics;
- continuous outputs versus discrete queued events;
- RNG injection and reproducible seeds;
- control IDs currently encoded as scattered integers;
- state validation, versions, and migrations;
- visual snapshot APIs, currently handwritten per Rack bridge;
- pause/reset/channel controls that vary between the OpenFL and Rack presentations;
- target-safe threading and ownership.

### Current maturity grouping

- **Best schema/runtime pilot:** TimeSlider.
- **Best simple cross-host interaction/event pilot:** Gbloink.
- **Best continuous CV and grid snapshot pilot:** TileLand.
- **Mixed event/control and graph snapshot proof:** K-Diag.
- **Best complex snapshot/command/output stress test:** K-Diagram.
- **Requires core completion before porting:** Zewp.

## 18. Recommended immediate design exercise

Before migrating code, write a small proposed manifest and ABI for TimeSlider and Gbloink only. Use them to answer concrete questions:

- Can one event representation describe notes, CC-like values, gates, and continuous controls without host-specific ambiguity?
- Which values are parameters, commands, state, outputs, or merely visual data?
- How are control time and host/sample time related after pause, load, tempo change, and transport discontinuity?
- What is the minimum immutable visual snapshot each target needs?
- Which generated artifacts remove real duplication without constraining custom UI?
- Can the Rack audio thread consume prepared data without entering Haxe?

Only after this pilot should the common framework receive a permanent name or directory layout. The design should be extracted from two real apps and validated against SandSonify, rather than invented as a large framework in advance.

## 19. Provisional success criteria

The consolidation succeeds when:

- a musical rule is changed in one authoritative place;
- native and browser targets can be compared with deterministic fixtures;
- no hard real-time callback calls managed/control code or waits on a UI mutex;
- parameters, ports, IDs, defaults, and documentation are generated from one schema;
- custom UI and target conventions remain possible;
- adding a target mostly means implementing a host adapter, not porting every app;
- adding an app mostly means implementing its engine and manifest, not copying target boilerplate;
- existing working applications can migrate incrementally rather than through a portfolio-wide rewrite.

## 20. Goldenpond library inventory

Goldenpond is not currently a sequencer or live event source. It is a separate Haxe library and pair of textual DSLs that turn harmonic and rhythmic descriptions into a finite score: note-like values with MIDI channel, pitch, velocity, start time, and duration. Goldenpond applications may schedule, render, export, or otherwise consume that score, but those application responsibilities are not part of the core library.

This distinction should remain firm. The WorldOfCake integration should depend on Goldenpond as a library; Goldenpond should not acquire WorldOfCake interfaces, host transport, VST, Rack, or UI dependencies.

### 20.1 Repository and authority

The authoritative implementation is the Haxe library under Goldenpond's `current/haxe/src/goldenpond`. Older Haskell, Python, Sonic Pi, and other attic implementations are historical. Python, JavaScript, C++, and Java products are transpiled or packaged from the Haxe source.

The repository reports that its tests pass in Haxe/interpreter, Python, JavaScript, C++, and Java. It already has target build descriptions, Java packaging, a Python/PyPI distribution path, browser integrations, FL Studio Piano Roll scripts, example MIDI-file generation, and Sonic Pi export. This makes Goldenpond the strongest existing demonstration in this group that a Haxe-authored pure musical library can serve many ordinary, non-real-time environments.

Goldenpond is licensed under the GNU Affero General Public License in the inspected sources/repository. Any combined distribution plan needs to preserve compatible licensing and notices, particularly when generated C++ is linked into plugins.

### 20.2 Chord language and harmonic model

`ChordParser` parses a compact chord-progression string in the context of a root and mode. `ChordProgression` exposes parsed `ChordThing` objects, generated chord-note arrays, and chord names. The language supports diatonic degrees, extensions, inversions, alterations, secondary relationships, mode changes, stuttering, and other harmonic operations described in the Goldenpond tutorial.

`ChordThing` owns the theory representation needed to calculate concrete chord notes and names: key, mode, degree, extension length, modifiers, inversion, and optional secondary degree. `Mode` supplies major, natural/harmonic/melodic minor and additional modal interval sets used by the current `GoldenData` mode index.

### 20.3 Rhythm/line language

`RhythmLanguage` parses line patterns into an `IRhythmGenerator`. It supports explicit patterns and simple/Bjorklund-distributed Euclidean patterns. Selectors include specific chord notes, ascending/descending traversal, repeat, full chord, wrapped chord, chord-with-bass, drop-2, random chord/scale/pentatonic choices, top note, scale degree, and rest.

`LineGenerator` combines a chord progression, `TimeManipulator`, rhythm generator, and instrument context. Its `generateNotes(startTime)` method creates a finite array of `INote` values. Some selector modes use `Math.random`, so reproducible regeneration will require a seed/RNG policy if deterministic cross-host playback and state restoration are required.

### 20.4 Score and project model

`INote` exposes channel, MIDI note, velocity, start time, and length through the concrete `Note` representation. Times are normally expressed in ticks. `TimeManipulator` supplies PPQ, chord duration, BPM, chord ticks, and conversions. `MidiInstrumentContext` determines channel, velocity, gate-length scaling, and transposition when constructing notes.

`GoldenData` is the project-level description:

- root MIDI pitch;
- mode index;
- chord-sequence DSL text;
- stutter count;
- BPM;
- chord duration;
- PPQ;
- a list of lines, each containing rhythm-pattern text and an instrument context.

It can build the progression, time manipulator, and per-line generators, serialize itself to JSON, reconstruct itself with a deserialization helper, correct incoming notes to the active scale, and report changes. `ScoreUtilities` can transpose notes and generate piano-roll SVG. `Exports` currently includes Sonic Pi generation.

### 20.5 What Goldenpond deliberately does not provide

Goldenpond does not currently provide:

- a running playhead;
- start/stop/pause/seek transport;
- DAW beat/sample-position synchronization;
- looping during real-time playback;
- lookahead scheduling;
- incremental note-on/note-off event emission;
- active-note tracking or panic/all-notes-off;
- thread communication;
- VST/Rack/browser audio callbacks;
- a live text editor or WorldOfCake view;
- policies for applying edits while notes are sounding.

Those belong to a Goldenpond application or host adapter, not to the Goldenpond theory/note-generation library.

### 20.6 Integration assets and gaps

Assets that can be reused directly include `GoldenData`, the chord and rhythm parsers, line generation, `INote`, instrument contexts, JSON project data, piano-roll SVG generation, and the existing multi-target test corpus.

Important gaps for a live sequencer wrapper are structured parser diagnostics, deterministic random generation, an explicit score/cycle-length result, stable library versioning/package consumption, and an efficient plain-data export surface for generated note arrays. A failed rhythm parse can currently produce a rest-only `ParseFailedRhythmGenerator`; the live UI will need more informative error position/message data. Chord parse behavior should receive the same audit before it is exposed in an interactive editor.

## 21. Planned Goldenpond WorldOfCake sequencer

### 21.1 Product concept

The proposed application is a WorldOfCake-style sequencer whose main creative interface is Goldenpond text. A user enters a chord progression and one or more line definitions; the app compiles them through the separately maintained Goldenpond library, previews the result, loops or follows host transport, and emits MIDI events.

The first version should be a MIDI generator, not a synthesizer. Its responsibility is:

```text
Goldenpond project text/settings
        -> Goldenpond finite note score
        -> WorldOfCake transport/scheduler
        -> timestamped note-on/note-off events
        -> host MIDI, Rack gate/CV, or browser destination
```

### 21.2 Dependency boundary

Goldenpond remains in its own repository and release cycle. WorldOfCake should consume a pinned Goldenpond library version through a reproducible mechanism such as a Haxelib package, Git dependency/submodule, or an explicitly versioned local package. It should not copy current Goldenpond classes into `Source/worldofcake` or edit generated Python/JavaScript/C++ distributions.

A thin `GoldenpondScoreCompiler` adapter in the WorldOfCake application should be the only layer that understands Goldenpond's object graph. It accepts a serializable project specification and returns a plain score snapshot plus diagnostics. This protects the scheduler and hosts from changes in parser/internal class layout.

### 21.3 Proposed app-specific model

The app can implement `ISequencerControl`, but it needs a stronger transport-aware model than the current GUI-timer sequencers. Suggested state includes:

- editable progression text;
- zero or more editable line-pattern strings;
- root, mode, stutter, chord duration, PPQ, and optional internal BPM;
- per-line channel, velocity, gate length, transpose, mute, and possibly output assignment;
- compiled immutable notes grouped by line;
- cycle length in ticks/beats;
- current playhead/loop iteration;
- compile generation and diagnostics;
- active-note identities;
- pending note-on and note-off events;
- transport mode: host sync or internal clock;
- edit-application policy.

The Goldenpond `GoldenData` JSON can be embedded as the musical-project portion of WorldOfCake state. Sequencer runtime fields and host presentation should be stored in a versioned wrapper rather than added to Goldenpond's JSON contract.

### 21.4 Compile versus play

Parsing and note generation may allocate substantially, traverse strings, construct many objects, and use randomness. Compilation must therefore occur outside the hard real-time callback.

The output should be an immutable `ScoreSnapshot` containing sorted plain notes and cycle metadata. The scheduler consumes the current snapshot while the control/UI side builds a replacement. A successful replacement is published atomically or through a queue.

The first edit policy should be musically predictable:

- keep playing the current compiled score while text is invalid;
- show diagnostics without replacing the valid score;
- when a new score compiles, apply it at the next loop boundary or an explicit user action;
- send required note-offs before swapping if active notes cannot continue safely;
- retain a clear “last valid compilation” indication.

Hot replacement at arbitrary sub-beat positions can be added later. Boundary replacement avoids many stuck-note and phase-alignment problems.

### 21.5 Scheduler requirements

Unlike Goldenpond itself, the wrapper must turn finite notes into a stream. It needs:

- conversion from Goldenpond ticks to host beat/sample time;
- stable sorting of simultaneous events;
- separate note-on and note-off events derived from start and length;
- lookahead sufficient for each host;
- looping without drift;
- active-note tracking;
- panic/all-notes-off on stop, seek, load, recompile, and transport discontinuity;
- correct behavior for overlapping notes of the same pitch/channel;
- sample offsets within a VST process block;
- bounded queues and a defined overflow policy;
- deterministic treatment of tempo and PPQ.

The portable native scheduler proposed earlier is a good fit. Haxe/Goldenpond can compile the score at control rate; native C++ can schedule it in JUCE and Rack without calling hxcpp from the real-time callback. In a browser-only Haxe/JavaScript build, an equivalent scheduler may run in an appropriate worker/worklet boundary while retaining the same fixtures and semantics.

### 21.6 Clock and transport policy

The app must explicitly distinguish musical position from elapsed wall-clock time.

For VST, the preferred default is host transport and tempo. Goldenpond note ticks should be normalized to musical beats, then mapped to sample offsets using the host's current tempo and position. Tempo changes should alter playback time without requiring the theory score to be regenerated unless tempo is itself used compositionally.

For standalone/web, internal BPM supplies the clock. For Rack, an initial internal BPM mode is possible, but a useful module will likely need clock and reset inputs; the scheduler must define how external pulses map to beats and how loss/jitter of clock is handled.

Goldenpond's current `GoldenData.bpm` is valuable for offline rendering/export. The live app should decide whether it is authoritative only in internal-clock mode or is overridden by host sync. That decision should be visible in state and UI.

### 21.7 WorldOfCake control and UI surface

A first useful interface is a compact form modeled on the existing FL Studio Piano Roll script generated as `goldenpond/current/haxe/for-distribution/fl/post-live.py`. That script is useful prior art because it already presents Goldenpond as a progression plus independent line strings and line-specific settings. It also processes lines independently so one failing line does not prevent other valid lines from generating notes.

Goldenpond is intended for live coding, but its normal source strings are compact: typically a few hundred characters, not large source files. The app therefore does not need a general-purpose document editor or IDE. The v1 form should contain:

- one chord-progression text input;
- exactly four line-pattern text inputs for the first implementation;
- per-line channel/output assignment, velocity, gate length, octave/semitone transpose, and mute;
- root and mode controls;
- stutter and chord-duration controls;
- host/internal sync and BPM controls;
- Apply/Compile and compact per-field status/errors;
- play/pause/reset/panic controls where the host permits them;
- playhead and current-chord indication;
- piano-roll or per-line score preview using Goldenpond's existing SVG capability or a host-native rendering of the same score snapshot.

Each field needs ordinary editing, selection, cut, copy, paste, and useful horizontal navigation. Syntax colouring is optional and is explicitly not a v1 requirement. Fonts, IDE completion, folding, multiple cursors, and similar CodeMirror features are not important enough to justify extra UI infrastructure.

The browser can use ordinary HTML inputs or text areas. CodeMirror may be added later if its live-coding ergonomics provide clear value, but it is not required by the architecture.

OpenFL uses its native `TextField` controls. OpenFL remains a desktop/browser prototyping shell and is not incorporated into VST plugins.

VST3/standalone uses a plain JUCE plugin/application shell with native JUCE controls. `juce::TextEditor` is the preferred component for the progression and four line fields. `ComboBox`, sliders/numeric editors, labels, and toggle buttons cover the remaining form. `CodeEditorComponent` is unnecessary for this separated-field design, and CodeMirror/WebView/React should not be introduced in v1. This keeps the stack to JUCE plus the shared Haxe/native engine layers.

Rack v1 must support authoring and live editing inside the module. It uses native `rack::ui::TextField`-derived controls for the progression and four lines, plus native Rack knobs/switches and a compact status display. The external-file/editor workflow may exist as an optional convenience later, but it is not the primary interaction design.

Rack's stock field supports selection, cursor movement, cut/copy/paste/select-all, context-menu actions, and explicit multiline input. Inspection of Rack's current implementation does not establish true visual soft wrapping: `multiline` mainly enables inserted newlines and newline-based up/down movement, while drawing still uses the normal Blendish text-field function. Separating the four short patterns removes most need for wrapping. The progression field should first be made wide enough and tested with realistic few-hundred-character strings. If that is uncomfortable, add a narrowly scoped visual-wrap/scroll enhancement for the progression field without inserting source newlines or building a general code editor.

The common UI schema should describe field identity, parameters, bindings, defaults, and line repetition, but host-native widgets implement the presentation. Diagnostics and piano-roll previews remain custom components consuming shared compiler/score data.

### 21.8 Live compilation behavior

The Goldenpond form must be forgiving while the user types. Each source field has at least:

- current edited text;
- last successfully compiled text/revision;
- last valid generated score fragment;
- dirty/valid status;
- diagnostic text and, when available, source position.

Compilation rules for v1:

- compile the progression before compiling dependent lines;
- process each non-empty line independently, following the existing FL script's resilience;
- an invalid line does not silence or block other valid lines;
- incomplete/invalid edits do not replace the last valid running score;
- Apply or Ctrl+Enter requests compilation; optional debounced validation may report errors without immediately changing playback;
- publish successful replacements at a musically defined boundary, initially the next loop boundary;
- issue required note-offs/panic operations when replacing or muting material so no note is left hanging;
- clearly indicate whether the audible score matches the currently edited text or the last valid revision.

### 21.9 Target outputs

**Web:** compact browser form and score preview, Web MIDI where available, and optional internal Web Audio instruments later. CodeMirror is optional rather than assumed.

**VST3/standalone:** plain JUCE MIDI-effect or instrument-style plugin with native JUCE form controls, emitting sample-offset MIDI. Host compatibility must be checked because DAWs differ in how they route MIDI-generating plugins. An optional simple internal sound source can aid standalone testing without becoming the main product.

**VCV Rack:** four editable line fields in the module plus per-line or configurable pitch/gate/velocity outputs. Pitch can use 1 V/oct, gate 10 V, and velocity 0-10 V. Four lines provide a natural bounded v1 port layout; polyphonic/banked expansion can be considered later. Clock/reset inputs remain important.

**Offline/other:** preserve direct MIDI-file, Piano Roll, Python, JavaScript, Java, and Sonic Pi workflows in Goldenpond itself rather than routing them through WorldOfCake.

### 21.10 Persistence and reproducibility

The WorldOfCake wrapper state should include:

- Goldenpond project JSON or equivalent source fields;
- last valid compiled-source hash;
- app state version;
- host/internal clock choice;
- loop and edit-application settings;
- UI state that matters to recovery;
- random seed/generation policy when random selectors are used.

Compiled notes need not normally be persisted if they can be deterministically regenerated. Until Goldenpond randomness is injectable, either persist the resulting score snapshot or persist sufficient RNG state/seed through a Goldenpond extension. The preferred long-term solution is a seedable RNG supplied to generation without changing the textual language unnecessarily.

### 21.11 Testing strategy

Goldenpond's existing cross-language golden tests should remain owned by the Goldenpond repository. WorldOfCake adds integration fixtures that:

- compile known progression/line text to a normalized score snapshot;
- verify cycle length and note ordering;
- convert notes to exact on/off events;
- test loop boundaries and overlapping notes;
- simulate pause, seek, tempo change, recompile, and invalid text;
- ensure all-notes-off behavior prevents stuck notes;
- compare Haxe/JavaScript and hxcpp/native compilation results;
- verify VST block scheduling and Rack gate/CV mapping from the same fixture.
- verify native editing operations and keyboard focus in representative DAWs and Rack;
- test realistic long progression strings in Rack and decide from evidence whether the progression field needs visual wrapping;
- verify that invalid edits retain the last valid audible revision and that independent valid lines continue.

### 21.12 Phased implementation plan

1. **Library consumption proof:** build a tiny WorldOfCake Haxe program against the authoritative Goldenpond source/package without copying it; compile one progression and line and print normalized notes.
2. **Score adapter:** define `GoldenpondProjectSpec`, diagnostics, plain `ScoreNote`, and `ScoreSnapshot`; isolate all Goldenpond-specific construction in the adapter.
3. **Headless sequencer:** implement tick/beat playhead, loop, note-on/off derivation, active-note tracking, panic, and versioned state with deterministic tests.
4. **OpenFL/web prototype:** add the progression plus four-line form, compile status, preview, internal clock, and `MonitorInstrument` or browser MIDI output.
5. **Asynchronous publication:** compile outside real-time execution and publish immutable score snapshots; establish next-loop-boundary replacement.
6. **JUCE MIDI plugin:** connect the portable scheduler to host transport and sample-offset MIDI, then implement the native JUCE `TextEditor`-based form.
7. **Rack adaptation:** implement four native Rack line fields plus progression field, clock/reset, pitch/gate/velocity outputs, and last-valid compilation behavior. Add progression wrapping only if realistic UI testing demonstrates the need.
8. **Schema/generation:** once the real controls and ports are known, move stable metadata into the common manifest and generate host boilerplate/docs.

### 21.13 Architectural value

This app is an especially useful consolidation test because it connects the two sides of the proposed platform without forcing either to absorb the other:

- Goldenpond remains a pure, multi-target Haxe note-generation library.
- WorldOfCake supplies interactive application state and control conventions.
- The common real-time kernel supplies transport-aware event scheduling.
- JUCE, Rack, and the browser supply host-specific presentation and output.

If this integration works cleanly, it validates the central portfolio idea: Haxe is excellent for expressive musical-domain computation, while real-time scheduling and host behavior can be supplied by a shared native layer instead of being duplicated inside every musical library.

## 22. Second-round inventory audit and clarified family boundaries

This section records the audit made after adopting three stronger constraints: WorldOfCake owns one execution model for all of its sequencers; Goldenpond is an ordinary WorldOfCake sequencer application around the separate Goldenpond library; and SandSonify is the first member of a reusable audio-generator family.

### 22.1 The WorldOfCake execution model is the canonical sequencer model

The current source already contains the right conceptual seam:

```text
platform input -> IControlPanel/ISequencerControl
                         |
                  Haxe app model
                         |
              Event/control snapshots
                         |
              platform output adapter
```

`ISequencer.advanceTime`, `hasEventBefore`, and `getNextEvent` separate logical musical evolution from output. `IControlPanel` separates semantic interactions from platform events. Shared coordinate types, components, `World` composition, dirty/redraw handling, and state import/export make WorldOfCake a real common application framework.

Every WorldOfCake application should therefore use the same lifecycle, command, event, snapshot, persistence, and target-adapter contracts. Apps may have unusual controls and output semantics, but must not invent private GUI/audio communication architectures.

The audit does reveal a gap between the intended separation and today's host implementations:

- OpenFL's `audioTimer` is a logical high-rate timer in the OpenFL event environment, not an operating-system hard-real-time audio thread.
- Rack `Module::process()` currently enters hxcpp/Haxe periodically and shares a mutex with UI and persistence calls. This works, but allows the audio thread to block and enter the garbage-collected runtime.
- Cadence is not completely normalized. Some movement is delta-based, while Gbloink movement currently advances per call, so nominal OpenFL and Rack tick rates are not always interchangeable.

The response is to strengthen WorldOfCake's answer:

1. A common control runner owns and advances the Haxe sequencer at a declared cadence.
2. GUI commands reach it through a bounded command path where threads differ.
3. It publishes timestamped events and immutable visual/control snapshots.
4. A common native real-time adapter consumes prepared data and performs sample-offset MIDI, CV, trigger, and gate work without entering Haxe or taking a GUI mutex.
5. OpenFL may use a simpler single-event-loop implementation, but follows the same logical contract and headless behavioural tests.

This native adapter is WorldOfCake target infrastructure, not an alternative framework. Gbloink, Zewp, TimeSlider, TileLand, K-Diagram, Goldenpond, and later sequencers reuse it.

### 22.2 Cross-app output and state findings

The five current apps all fit the same family, but require two output forms:

- Gbloink and K-Diagram prominently produce discrete future events such as notes, arrivals, and gates.
- TimeSlider and TileLand prominently expose continuously changing controller/cursor values.
- Zewp supplies another interactive note-generating world and, because it lacks a Rack derivative, is an important later check that the adapter was not overfitted to existing Rack modules.

The common contract therefore needs both a compact timestamped-event channel and an immutable control-snapshot channel. Encoding everything solely as the current MIDI-shaped `Event(type, data1, data2, data3)` would hide useful semantics.

App-specific responsibilities remain where they are: ball/block collision rules in Gbloink; Zewp's world rules; four trajectories in TimeSlider; tiles and cursors in TileLand; and graph topology/cursors in K-Diagram. Shared responsibilities include timing, command delivery, publication, persistence conventions, target scheduling, and standard widgets.

Before cross-target conformance testing, cadence-dependent movement must either become delta-based or be declared explicitly, randomness must be seedable, control IDs must stabilize, and handwritten Rack visual getters should become explicit snapshot schemas.

### 22.3 Goldenpond is a normal WorldOfCake application

Goldenpond remains responsible for parsing progression/line text and producing note data. The WorldOfCake application is responsible for everything temporal:

```text
text edit
   -> GUI/control-side Goldenpond compile
   -> immutable score snapshot
   -> WorldOfCake Goldenpond sequencer
   -> timestamped note events
   -> ordinary WorldOfCake target adapter
```

The intended edit path is:

1. After Apply or a short debounce, the GUI/control side calls Goldenpond.
2. Successful output is normalized into plain score-note data with cycle length and diagnostics.
3. A replacement is published safely at a declared musical boundary, initially the next loop boundary.
4. Failed compilation updates diagnostics but leaves the last valid score playing.

Compilation must never happen in a VST or Rack audio callback. Synchronous GUI-thread compilation is acceptable initially because sources are short. If measurement shows a visible pause, it can move to the common control worker without changing the contract.

The Goldenpond sequencer itself remains Haxe and implements the same WorldOfCake interface as the others. It owns playhead, looping, note-on/off derivation, active-note tracking, panic, and score replacement. JUCE supplies DAW tempo, play state, sample/PPQ position, loop/discontinuity information, and MIDI output. Rack supplies external clock/reset and pitch/gate/velocity output. Both use the shared WorldOfCake real-time adapter.

DAW synchronization is thus a target input to the common WorldOfCake timing contract, not Goldenpond-specific threading. Other WorldOfCake apps may later opt into the same host-synchronized clock.

### 22.4 SandSonify implementation inventory

The two SandSonify versions currently duplicate the authoritative behaviour:

- The browser has a JavaScript typed-array simulation, canvas renderer, browser controls, and Web Audio sonifiers.
- The VST has a separate C++ simulation, JUCE renderer and controls, and C++ sonifiers.

The VST code is divided sensibly by responsibility but is not host-neutral yet:

- `Simulation` owns grid/state, material rules, reactions, randomness, painting, RGBA pixels, and grid persistence.
- `FrameAnalyzer`, `RGBTextureSonifier`, `RowSpectrumSonifier`, and `AudioGraph` own analysis and audio generation.
- `PluginProcessor` owns JUCE parameters, plugin state, and the audio callback.
- `PluginEditor` owns the 60 Hz simulation tick, emitters, frame ingestion, and controls.
- `SandCanvas` copies the 160 x 120 RGBA frame into a JUCE image and maps pointer coordinates.

Two immediate risks follow:

- Simulation advances in `PluginEditor::timerCallback`, so closing the editor stops world evolution while audio continues from the last ingested frame. Simulation lifetime must belong to a processor-owned engine/control runner, not the editor.
- Editor, state callbacks, and audio callback share processor-owned objects without a fully explicit publication protocol. `ingestFrame` prepares audio data outside the callback, which is the right direction, but should become documented immutable/double-buffered publication.

The C++ core currently uses JUCE strings, random numbers, colours, clamping, memory blocks, audio buffers, and utilities. These are removable conveniences, not reasons for JUCE to remain in the portable engine.

### 22.5 Decision on Haxe and WorldOfCake controls for SandSonify

The sand simulation should remain C++ for consolidation. It scans and mutates a large typed grid each visual tick and produces the pixel data consumed by sonification. Keeping simulation, analysis, and sonification in one native address space avoids copying the bitmap across a Haxe/native boundary and gives the same core a direct route to JUCE, Rack, and WebAssembly.

OpenFL should not be embedded in JUCE to obtain WorldOfCake controls. Current WorldOfCake `Slider` and `PlayArea` classes extend OpenFL `Sprite`; OpenFL brings its own rendering and event lifecycle while JUCE still must own automation and plugin lifecycle. That would add a runtime and bridge without sharing the important simulation or DSP work.

Haxe could technically mediate ordinary SandSonify controls, but sliders, buttons, toggles, palettes, and parameter attachments are straightforward native host controls. Initially this extra boundary has little payoff.

The settled initial design is therefore:

- SandSonify is not internally a WorldOfCake app.
- Its canonical simulation, analysis, snapshot publication, and sonifiers become portable C++.
- JUCE, Rack, and browser/Wasm code are thin host and UI shells.
- Ordinary controls use target-native components.
- WorldOfCake and SandSonify may share stable IDs, manifests, Layla layouts, generated bindings, style tokens, tests, and build conventions, but not an embedded OpenFL widget runtime.

If several native audio apps later reveal a useful target-neutral subset of WorldOfCake's semantic component/coordinate model, extract it from those working cases rather than forcing it through SandSonify now.

### 22.6 Layla's role

Layla describes composition; it does not decide threading or engine ownership. A layout may name a sand play area, palette, button, or audio parameter.

For WorldOfCake, a project-owned generator can produce WorldOfCake composition and binding code plus native shell composition where required. For SandSonify, a project-owned generator can read the same generic Layla IR and directly produce JUCE, Rack, or web composition bound to SandSonify commands and parameters, bypassing WorldOfCake.

#### Implemented Gbloink OpenFL pilot (25 August 2026)

The first concrete WorldOfCake-owned generator now exists. Its boundaries are:

- `layouts/openfl/gbloink.layla` owns only hierarchy, semantic IDs, hints, and ratios;
- `layouts/openfl/gbloink.edn` owns non-spatial component facts such as UIDs, slider ranges/defaults/orientation/colours, generated class names, and playfield-local dimensions;
- `laylagen/` calls the canonical `layla.core/parse-intent`, validates the target configuration, derives deterministic geometry, and renders ordinary Haxe source in memory;
- `Source/generated/gbloink/` contains replaceable generated layout constants, component construction, and an inspectable geometry EDN file;
- maintained Gbloink code owns drawing, interaction, sequencer behaviour, and the established WorldOfCake widgets.

Stable semantic IDs for the pilot are `playarea`, `redspeed`, `greenspeed`, and `bluespeed`, with hints `gbloinkplayarea` and `speedslider`. The generator fails on missing/unused component configuration and target-symbol collisions rather than silently guessing.

The old constants described a panel width of 800 while the sliders reached x=880. The Layla-derived geometry retains the intended play area and slider positions and defines a 930x600 logical panel, providing the intended 50-unit outer margins. Tests prove deterministic output and exact geometry; a full Windows OpenFL/hxcpp debug build compiles the generated classes.

#### TimeSlider second-consumer result (26 August 2026)

TimeSlider confirms that the useful shared layer is the generator pipeline rather than a forced universal widget model. Its four tracks are parts of one custom-drawn simulation, not instances of the WorldOfCake `Slider` widget. Layla describes four label/track columns; companion configuration supplies CC numbers, channel, and travel-time defaults. Generated geometry reproduces the existing 800x600 composition exactly, while generated Haxe constructs the four simulation tracks and supplies panel size and track count to maintained TimeSlider code.

The refactoring justified by two consumers remains small:

- shared canonical Layla parsing and target validation;
- shared deterministic weighted geometry, now supporting per-edge padding;
- shared Haxe constants and inspectable geometry output;
- explicit composition rendering for the Gbloink widget graph and TimeSlider simulation graph.

No universal runtime component registry or generic `Slider` fiction was introduced. The complete generator suite, all five headless/native app tests, and standalone Windows OpenFL builds pass.

#### K-Diag and TileLand result (26 August 2026)

K-Diag and TileLand reuse the standard WorldOfCake component renderer established around Gbloink: generated code constructs each maintained custom play area, three common speed sliders, and the channel slider, then attaches them through small maintained view hooks. Their Layla sources preserve the existing 600x600 playfield and control positions. The generated panel height is corrected from 600 to 640 because the old playfield began at y=20 and extended to y=620; the new height makes the intended bottom margin explicit rather than relying on clipping.

The OpenFL and Rack modules call the same authoritative Haxe simulation code but have separate renderers. Therefore OpenFL preview parity is an explicit migration requirement: shared simulation state, colour meaning, alpha, coordinate orientation, and interaction should agree with Rack, while host-specific panel chrome may differ. The first parity pass restored Gbloink block colours from `Block.colour`, matched its dark Rack background, corrected K-Diag's Y orientation and node/background colours, and matched TileLand's Rack background, grid, and trefoil styling. Zewp has no Rack derivative, so its maintained OpenFL renderer remains the visual reference until another host implementation exists.

The coordinate audit also introduced `ResponsivePanelHost`: generated panel dimensions are the design resolution, the initial OpenFL client matches them, resizing uniformly fits the entire panel with letterboxing, and pointer coordinates are inverse-transformed before reaching WorldOfCake. K-Diag's custom renderer was corrected to draw nodes/cursors in play-area-local rather than doubly offset window coordinates, restoring visible-node click correspondence.

#### SemanticSelect first draft

`SemanticSelect` is a WorldOfCake semantic widget, not a Layla or OpenFL widget type. Layla places a `.../semanticselect` region; companion EDN defines choices, numeric bridge values, human labels, optional colours, default selection, and target presentation. The OpenFL generator currently supports a coloured segmented presentation (K-Diag cursor selection) and a compact current-label previous/next presentation (Gbloink scales). All renderers must both change and visibly communicate selection. Rack can use a multipolar switch for K-Diag and a stepped control plus current-name display for longer lists; JUCE and web choose their own native resources.

This is deliberately a first draft. Appearance and presentation heuristics may evolve, while the semantic choice contract and application bindings remain stable. EDN remains the chosen companion format. Canvas dimensions, edge padding, gaps, minimum sizes, and presentation policy belong there unless repeated cross-target experience justifies extending Layla itself.

#### Standalone OpenFL preview policy

Every application completed through Layla migration should acquire a stable `project-<app>.xml` and an entry in `run-openfl-preview.ps1`. Preview builds define `woc_preview`: engine events are drained so queues remain bounded, but no monitor/MIDI sink is created or called. The purpose is immediate visual and interactive evaluation of the simulation, generated layout, and visual parity with native hosts. All five current applications now have previews.

```text
Layla source
   +-> WorldOfCake generator -> WoC OpenFL/JUCE/Rack composition
   +-> SandSonify generator  -> direct JUCE/Rack/web composition
```

Both generators remain project-owned. Shared generator helpers are extracted only after real implementations expose worthwhile duplication. Custom playfield rendering should remain handwritten initially.

### 22.7 Revised portfolio boundary

```text
WORLD-OF-CAKE SEQUENCERS
Haxe app model + common WoC lifecycle
   -> events/control snapshots
   -> common native real-time adapter
   -> JUCE MIDI | Rack CV/gates | browser/OpenFL output

AUDIO GENERATORS
portable C++ simulation/control + DSP
   -> immutable frame/parameter snapshots
   -> native audio processing
   -> JUCE audio | Rack audio/CV | WebAssembly/AudioWorklet

SHARED PORTFOLIO INFRASTRUCTURE
stable IDs + manifests + Layla layouts + generated bindings
tests + build conventions + target metadata
```

A future hybrid may combine the families: a WorldOfCake Haxe sequencer can publish events to a portable C++ synthesizer. Neither family must absorb the other.

### 22.8 Inventory-derived work order

1. **Completed:** add headless Gbloink and TimeSlider contract tests for timing, deterministic state, pause, persistence, and publication behaviour.
2. **Completed:** build the common runner/adapter pilot using Gbloink for discrete scheduling and TimeSlider for continuous-control snapshots.
3. **Completed:** TileLand, K-Diag, and Zewp pass the shared contract; the five-app fit/gap audit required no alternative thread architecture.
4. **Completed:** stabilize the required semantic component IDs, pilot project-owned Layla generation for Gbloink, and validate reuse across TimeSlider, K-Diag, TileLand, and Zewp.
5. Modernize and build Windows Rack ports using the shared runner, with no audio-callback entry into Haxe, then adopt Layla-generated composition/SVG where appropriate.
6. Build JUCE VST3/standalone WorldOfCake shells using the same runner and generated semantic descriptions.
7. Prove direct consumption of the authoritative Goldenpond library and build its headless WorldOfCake sequencer with immutable score publication, looping, active-note safety, and host transport.
8. Resume the deferred audio-generator track: extract SandSonify's portable simulation/audio boundary, add native/Wasm fixtures, and later pilot its direct Layla target generation.

### 22.9 Recommended first vertical experiment

Start inside WorldOfCake. Make Gbloink deterministic with seeded randomness and delta-based movement. Run it headlessly through the common runner, publish note events and a visual snapshot, and let a minimal C++ harness consume them without calling Haxe from its simulated audio callback. Then reuse the runner for TimeSlider to prove it is framework-level rather than Gbloink-specific.

Success means the authoritative musical behaviour stays in Haxe, OpenFL still runs it, native consumers receive bounded prepared data without an audio-thread mutex/hxcpp call, and both discrete and continuous apps share the bridge. SandSonify extraction then becomes the first separate audio-family experiment.

**Result:** achieved for the standalone Windows harness. The next proof is breadth across the remaining WorldOfCake apps, followed by real Rack host integration. SandSonify remains deliberately on the back burner under the current project order.
## Persistence and Rack shutdown findings (2026-08-27)

The Gbloink Rack investigation established two separate facts. The earlier long-run instability was associated with the full Haxe state-export path, not with Rack's ordinary module rendering. Gbloink is therefore required to use an explicit, hand-written serializer for its small, known state schema (currently `StringBuf` plus per-model `writeJson` methods), with Haxe `Json.stringify`/reflection excluded from Rack autosave. Native Rack code still marshals the request to the control owner and uses a bounded wait; a missed autosave is preferable to blocking the host.

An explicit quit test then left a Rack process after the window closed, but shutdown markers showed that Rack stopped at its ASIO audio-device teardown before reaching `Gbloink::~Gbloink()`. A blank Rack session reproduced clean shutdown correctly, while the surviving case involved another loaded module. This is recorded as an external Rack/module shutdown issue, not evidence that Gbloink's runner leaks. The runner nevertheless retains the invariant that it signals and joins its control thread before Haxe model destruction; it must never detach a worker.

All future Rack adapters must follow the same persistence rule: each app defines a small, explicit state schema and manual serializer/deserializer, and its native adapter owns the bounded request protocol. KDiagram, TileLand, and TimeSlider currently expose Haxe state methods but do not yet have the complete native Rack `dataToJson`/`dataFromJson` path; adding that path is a required follow-up before calling their persistence production-ready.
