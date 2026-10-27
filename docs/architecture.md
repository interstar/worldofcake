# WorldOfCake Architecture

Updated: 2026-10-24

## 1. Purpose and Design Direction

WorldOfCake is a Haxe framework for interactive, experimental music sequencers. The shared sequencer/control logic is written in Haxe so it can be reused across OpenFL/browser-style UIs, VCV Rack modules, and future plugin targets such as JUCE/VST.

Core goals:

- Keep musical state, sequencing, and control behavior in reusable Haxe classes.
- Route UI input through explicit control interfaces using component UIDs and typed payloads.
- Use explicit coordinate-space mapping to reduce input/render mismatch bugs.
- Share host/lifecycle scaffolding without erasing app-specific musical behavior.
- Keep layout moving toward single sources of truth: Layla for spatial layout and companion EDN for component details.

---

## 2. Top-Level Project Layout

Important source areas:

- `Source/worldofcake/`: core Haxe framework primitives and interfaces.
- `Source/worldofcake/ui/`: OpenFL-oriented UI components and shell bases (`ComponentWorldBase`, `OpenFLAppBase`, `PlayArea`, `Slider`, component plumbing).
- `Source/generated/<app>/`: generated Haxe layout, composition, and control-ID constants from Layla/EDN. These files should not be hand-edited.
- `Source/<app>/`: app-specific Haxe code for the six current sequencers (`gbloink`, `zewp`, `kdiagram`, `tileland`, `timeslider`, `goldenpond`).
- `Source/platform/`: simple instrumentation adapters such as `MonitorInstrument`.
- `bridge/haxe/`: Haxe harness classes used by native runners.
- `bridge/native/`: hand-written shared C++ native bridge code, including `ControlThread`, `ControlRunnerBase`, `SpscRingBuffer`, `StatePersistence`, bridge POD types (`WorldOfCakeBridgeTypes.h`), `HaxeRuntimeBoot`, `WorldOfCakeOutputMapping`, and the per-app `*ControlRunner` shells. The `worldofcake/generated/` subtree is generated output (§6), not hand-written bridge code.
- `layouts/openfl/`: canonical OpenFL Layla/EDN sources.
- `layouts/rack/`: authored Rack-specific Layla/EDN variants. These are source-of-truth inputs and must be versioned.
- `derivatives/vcvrack/`: VCV Rack module shells, Rack-specific panels/widgets, shared Rack build helpers, and install scripts.
- `derivatives/juce/`: JUCE/VST3 module shells, shared JUCE helpers (`common/`), and the Windows JUCE build script.
- `derivatives/openfl/`: OpenFL target shell — per-app `project-*.xml` Lime build descriptors and the OpenFL `Assets/` directory.
- `derivatives/Rack-SDK-*/`: vendored VCV Rack SDKs (Linux and Windows) used by the Rack builds; local caches, not source.
- `vendor/layla/`: prebuilt `worldofcake-laylagen.jar` and its SHA-256 — the self-contained Layla/EDN generator (Layla parser + WoC generator + Clojure + Instaparse), rebuilt by the project maintainer outside this repository.
- `test/native/`: native C++ harness and Rack stress tests (`GbloinkHarness.cpp`, `GoldenpondRackStress.cpp`, `run-goldenpond-rack-stress.sh`).
- `build/`: generated/intermediate build output. Rack artifacts are isolated under `build/vcvrack/<module>/<platform>/`, JUCE/VST under `build/juce/`, and headless Haxe test output under `build/headless-*/`.
- `hxml/tests/`: Haxe headless/native test descriptors (invoked with `haxe hxml/tests/...`). Distinct from the C++ unit tests under `bridge/native/tests/` and the native stress tests under `test/native/`.

OpenFL app builds usually use the per-app project files, for example:

- `lime build derivatives/openfl/project-gbloink.xml neko`
- `lime build derivatives/openfl/project-kdiagram.xml neko`
- `lime build derivatives/openfl/project-tileland.xml neko`
- `lime build derivatives/openfl/project-timeslider.xml neko`
- `lime build derivatives/openfl/project-zewp.xml neko`

Rack builds use the module Makefiles via the shared include in `derivatives/vcvrack/common/plugin.mk`; `derivatives/vcvrack/install_linux_local.sh` builds/packages/installs all Linux Rack modules on this machine.

---

## 3. Core Contracts

The main framework contracts are in `Source/worldofcake/` and `Source/worldofcake/ui/`.

### `ISequencer`

The host-facing sequencer contract:

- `advanceTime(delta)` advances logical time and app state by `delta` seconds of **real elapsed time**; `getLogicalTime()` reports it. See *Time and speed* below.
- `resyncTime(elapsedSeconds)` synchronizes forward to authoritative elapsed transport time; hosts with a monotonic clock call this instead of estimating elapsed time from callback cadence.
- `resetTransport()` starts a new host-transport epoch without resetting musical/editor state: pending events are discarded and logical time returns to zero (used for seeks, loop jumps, and transport restarts). It never changes the explicit pause or mute state.
- `hasEventBefore(timeLimit)` / `getNextEvent()` expose queued musical events.
- `correctInputNote(note, time, previousNote)` corrects an incoming MIDI note at logical sequencer time; sequencers without a harmonic model return the input unchanged.
- `reset()` returns to an app-defined baseline. It calls `resetTransport()`, so a paused sequencer stays paused after reset.
- `exportStateJson()` / `importStateJson(json)` persist recoverable runtime state.
- Three independent gates, each a command plus a query that every sequencer understands:
  - `setPaused(bool)` / `isPaused()`: explicit user pause; stops simulation and logical time.
  - `setMuted(bool)` / `isMuted()`: suppresses musical output while model time and visuals keep running. Adapters that publish outputs other than events (CV derived from snapshots, corrected input notes) must also honour the model's mute.
  - `setTransportRunning(bool)` / `isTransportRunning()`: the host transport gate, separate from the user's pause.

  Pause, mute, and transport stop are output boundaries: sounding notes are released and events prepared before the boundary are discarded.

Note lifetimes belong to the model. Every note-on a sequencer emits is followed by its note-off, either explicitly (Goldenpond's score) or through `SequencerCore.emitNote(time, channel, note, velocity, duration)`, which holds the note-off until model time reaches it and ends an earlier instance of a retriggered note. `CurrentlyPlaying` therefore knows exactly which notes are sounding, and output boundaries release them; `resetTransport()` stamps its releases at the new time origin so they are delivered immediately. Gbloink and K-Diagram expose the duration as a user **Note length** control (default 50 ms), persisted in their state JSON.

The sequencer owns these flags. Panels and host adapters send the commands and present the flags back from the model (§3 `IControlPanel`, §11); they never keep their own copy.
- `getModelStatus()` exposes the stable `{ ready, stateRevision }` lifecycle snapshot used by native adapters; `markStateReplaced()` advances the revision after model restoration.

### Time and speed

All apps define motion in real time, so the same knob position gives the same speed on every platform:

- Hosts pass the real time that elapsed since the previous call, never a nominal step: the native `ControlThread` measures it between wake-ups, OpenFL measures it with `haxe.Timer.stamp()`, and host-clocked runners (JUCE Gbloink, Goldenpond under a DAW) follow the host transport. A single step is capped at 0.25 s so a stall is not replayed at once.
- Each app states its speeds in real units, and its knobs carry those units in the EDN metadata (`:unit`), on logarithmic ranges: Gbloink ball speed in play-area units/s (10–1000, default 120); K-Diagram cursor speed in network units/s (0.05–8, default 0.5); TileLand cursor speed in tiles/s (0.25–40, default 2); Zewp a speed multiplier over 240–480 units/s base speeds (0.1–4, default 1); TimeSlider travel time in seconds (0.5–120, log by click position).
- Physics that needs fine steps declares `maxStepSeconds` (Gbloink and Zewp use `SequencerCore.PHYSICS_STEP_SECONDS`, 1 ms). `advanceTime` splits longer deltas into equal steps no larger than that, so collisions do not depend on the host's tick rate. Apps without collision physics advance analytically (K-Diagram) or split at their own event boundaries (TileLand tiles).
- `test/TestRealTime.hx` runs every app for one second at 1 ms, 1/60 s and 100 ms host steps and requires the same result, plus absolute checks (a default Gbloink ball travels 120 units in a second; the fastest TimeSlider glide takes 0.5 s).

Persistence JSON is deliberately app-owned. WoC standardizes the entry point and native/Rack transport, but each app writes its own serializer because generic Haxe JSON serialization of arbitrary structures caused Rack stability problems.

### `IControlPanel`

The control/input contract:

- mouse events use a component/control UID plus a `LocalPoint`.
- value changes use `newValue(uid, value)`.
- buttons and keyboard use explicit UID/key calls.
- `controlValue(uid)` returns the current model value presented by a control, or `null` when the model does not own one. Panels display this value instead of keeping their own state.

The sequencer is expected to know what a UID means inside that app. Panels are views in an MVC relationship with the sequencer: they can read it, it cannot see them.

Lifecycle controls are wired once per app: the constructor calls `bindLifecycleControls(pauseUid, muteUid)` (`SequencerCore`), and `newValue` starts with `if (applyLifecycleValue(uid, value)) return;`. `SequencerCore` then maps those controls to `setPaused` / `setMuted` and answers `controlValue` for them.

### `IControlPanelView`

The redraw contract:

- `redrawDirty()` is called once per OpenFL frame; the view owns its redraw UID policy and decides which components to repaint (typically via private `needsRedraw(uid)` / `redraw(uid)` helpers).

`OpenFLAppBase` no longer knows app-specific redraw UID lists.

### `ISequencerControl`

Combines `ISequencer` and `IControlPanel` for Haxe app models that are both time-advanced sequencers and UI-control targets.

### `ISequencerWorld`

The host-facing world contract used by OpenFL:

- `handleMouseDown/Drag/Up(WindowPoint)`
- `handleKeyPressed(key)`
- `getView()`
- `getSequencer()`
- `resize(width, height)`

The older `IFullApp` split has been removed. `ISequencerWorld` is now the single interface for a host-drivable sequencer world.

### `Event` and `IInstrument`

Musical output crosses the host boundary as `worldofcake.Event`, a plain data record of `timestamp`, `type`, and three data fields (`data1`/`data2`/`data3`). `type` is an `EventType`, an `enum abstract` over `Int`: typed in Haxe, a plain integer at the native bridge (`PreparedEvent::type`, mirrored as `NoteOutputScheduler::kNoteOn` etc.):

| `EventType` | Value | `data1` | `data2` | `data3` |
| --- | --- | --- | --- | --- |
| `NoteOn` | 0 | channel | note | velocity |
| `ControlChange` | 1 | channel | controller | 7-bit value |
| `NoteOff` | 2 | channel | note | — |

`IInstrument.send(e:Event)` is the output-adapter contract; `Source/platform/MonitorInstrument.hx` is the trace-based reference adapter.

### Control outputs

A continuous control a sequencer publishes (a TimeSlider lane, a K-Diagram cursor's X/Y) is **state, not events**: a `ControlOutput` holding a value from 0 to 1 plus its MIDI routing (channel, CC number). Everything about it is decided in Haxe, on the control thread; C++ only copies published values out for hosts that need them at audio or UI rate.

- **Declared once, in EDN** (`:outputs [{:id "cc1" :label "CC 1" :channel 1 :cc 1} ...]`). The generator emits `OUTPUT_<ID>` index constants and a `controlOutputs()` builder in the app's control-IDs class, and a `kControlOutputs` table in the C++ control metadata (VST hosts must declare parameters before the model runs).
- **Set by the app** with `SequencerCore.setControlOutput(index, value)` after `declareControlOutputs(...)`. Apps never build CC events themselves.
- **MIDI CC**: the core emits a `ControlChange` event on the output's channel whenever its 7-bit value changes, while output is open (not paused, muted or transport-stopped). After an output boundary the next value is resent. Changing an output's channel (`ControlOutput.setChannel`) also resends.
- **Published value**: `ControlOutput.published` follows the value while output is open and holds while muted or paused. `ISequencer.getControlOutputs()` exposes the outputs; `SequencerHarness.controlOutputValue(i)` returns the published value.
- **Native**: after every control tick `HarnessControlRunner` copies the published values into a lock-free table (`ControlRunnerBase::controlOutputValue(i)`, up to `kMaxControlOutputs`).
- **Hosts**: JUCE presents each output as an output-only host parameter (`jucehost::ControlOutputParameters`, pushed from a message-thread timer); Rack outputs `10 V × value`; MIDI CC is already in the event stream.

Control **inputs** (host parameters, CV or CC driving the model, e.g. K-Diagram rotation from an LFO) are planned as the mirror image: declared in EDN, 0..1, arriving through the command queue. Many will simply be existing knobs exposed as automatable.

### Other shared Haxe primitives

- `IRandomSource` with `SystemRandomSource` (non-deterministic) and `SeededRandomSource` (deterministic, used by bridges/tests) so a model can be driven reproducibly.
- `CurrentlyPlaying` tracks outstanding note-ons so pause/mute/transport-stop can flush matching note-offs.
- `NoteCalculator` + `Scale` map coordinates to notes within a selected scale.
- `SequenceNote`, `SequenceNoteEvent`, `SequenceSnapshot`, and `LoopingNotePlayer` form the shared, Goldenpond-independent multi-part looping playback model (see §10).
- `LocalRect`, `Utils`, and the point/mapper classes (§7) round out the common geometry utilities.

---

## 4. Shared Haxe Lifecycle

### `SequencerCore`

`Source/worldofcake/SequencerCore.hx` centralizes common sequencer lifecycle mechanics:

- `currentTime` and event queue storage
- `setPaused()` / `setMuted()` / `setTransportRunning()` and their queries, sharing one `flushOutput()` output-boundary helper
- `bindLifecycleControls()` / `applyLifecycleValue()` / `controlValue()` so panel pause/mute controls read and write the model flags
- finite-positive-delta guard in `advanceTime(delta)`, and splitting into steps no larger than `maxStepSeconds`
- `dirty` flag plus `consumeDirty()`
- `emitEvent()` gating: events are published only while unmuted, unpaused, and transport-running; pause/mute/transport-stop are output boundaries
- `CurrentlyPlaying` note-lifetime tracking so output boundaries flush outstanding note-offs
- event queue helpers (`hasEventBefore` / `getNextEvent` / `clearEvents`)
- `getLogicalTime()`
- `resyncTime()` / `resetTransport()` / `clearEvents()`; `resetTransport()` never changes the explicit pause/mute choices
- `getModelStatus()` / `markStateReplaced()` lifecycle revision tracking

Apps extend `SequencerCore` and implement their own model advancement, JSON schema, input behavior, and note/CC generation.

### `ComponentWorldBase`

`Source/worldofcake/ui/ComponentWorldBase.hx` centralizes OpenFL world mechanics:

- window-to-panel mapper creation
- component list storage
- active component tracking during drags
- mouse down/drag/up routing
- default no-op keyboard handling
- `getView()`
- resize mapper replacement

Concrete worlds still own app composition: creating the sequencer, creating the view, building generated/app-specific components, and returning the concrete sequencer.

### `OpenFLAppBase`

`Source/worldofcake/ui/OpenFLAppBase.hx` centralizes OpenFL `Main` boilerplate:

- extends `Sprite`
- waits for `ADDED_TO_STAGE`
- creates an `ISequencerWorld`
- adds the view sprite to the display list
- sets up `ResponsivePanelHost`
- starts the update timer, advancing by the real time measured between timer events
- advances the sequencer
- drains queued events to `MonitorInstrument`
- wires mouse down/move/up, optional keyboard input, resize, and enter-frame redraw

Per-app `*Main.hx` files are now small hook classes. They create the world, provide panel dimensions, and optionally customize keyboard translation.

---

## 5. OpenFL App Shell Pattern

Current OpenFL apps follow:

```text
*Main extends OpenFLAppBase
  -> creates *World
      -> extends ComponentWorldBase
      -> creates *Sequencer + *View + components
          -> *Sequencer extends SequencerCore
          -> *View implements IControlPanelView
```

Responsibilities:

- `Main`: OpenFL runtime shell only.
- `World`: app composition and component routing.
- `Sequencer`: musical state, timing, control semantics, event generation, state JSON.
- `View`: drawing and redraw UID policy.
- `Layout`: app-local layout facade over generated Layla output.

---

## 6. Layout Sources

Layout is moving toward one source of truth per target:

- Layla owns spatial panel composition.
- companion EDN owns component metadata such as ranges, labels, colors, widget hints, target bindings, and behavior-facing labels/defaults. The EDN map key is the semantic identity source; the generator assigns app-local numeric control UIDs in layout order. Essential app controls such as reset, pause, toggles, and rotate buttons are spatial Layla components in the canonical OpenFL layout.
- generated Haxe code lives under `Source/generated/<app>/` (composition, layout constants, and control IDs such as `<App>ControlIdsGenerated.hx`; each directory also carries a copy of its source EDN as `geometry.edn`).
- app-local `*Layout.hx` files wrap generated layout constants and provide a stable app-facing layout API.
- maintained app code should not import `*LayoutGenerated` directly. The intentional exception is the app-local `*Layout.hx` facade. Maintained behavior code may use generated control-ID classes directly or through temporary app-local aliases during migration.
- app `World` classes may import generated `*CompositionGenerated` builders, because worlds are the OpenFL composition boundary.

### Labelled containers and boxes

A Layla container can be named with a `%label` as its first element, e.g. `<%red redspeed/knob>`. Labels share one namespace with leaf IDs. Layla itself attaches no meaning to a label; it is just a name in the layout.

In the WoC generator a label behaves like a leaf ID in two ways:

- the generator emits its geometry (`<LABEL>_X/_Y/_WIDTH/_HEIGHT` in the Haxe layout class, `k<Label>` in the JUCE layout header), whether or not the EDN mentions it;
- the EDN may give it a component entry. The only component kind allowed on a container is `:box`, a filled, optionally bordered rectangle drawn behind the container's contents. A container entry may also carry `:padding`, which insets the container's children (the box keeps the full rectangle).

```clojure
"red" {:kind :box :fill "0xD4473D" :fill-alpha 0.16 :border "0xD4473D" :border-alpha 0.55 :padding 6.0}
```

Nothing is inherited from a container: every control states its own `:colour`. Grouping one ball's controls in a coloured box is a Gbloink convention written in Gbloink's EDN, not a framework concept.

Targets: OpenFL compositions add a `PanelBox` before any control (so it sits behind them); JUCE layout headers carry a `kBoxes` table that editors paint with `jucehost::paintBoxes`; Rack panel SVGs get one `<rect id="box-<label>">` per box (from `:rack-components`).

### Text, optional knob labels, and icons

- `:text` is a static piece of text in a cell, e.g. a column heading (`{:kind :text :text "Speed"}`).
- A `:semantic-select` may give `:choice-range {:from 0 :to 127 :format "CC %d"}` instead of listing `:choices`: one choice per integer, valued by that integer (so the select sends the number itself). The compact presentation steps on click and scrolls on vertical drag.
- A TimeSlider track names its per-lane controls with `:channel-control`, `:cc-control` and `:label-control`; the generator emits them as `CHANNEL_UIDS`, `CC_UIDS` and `LABEL_UIDS` in track order.
- A knob's `:label` is its name (host parameter name, tooltip). `:show-label false` stops the panel drawing it under the knob; the default is to draw it.
- Buttons and toggles may name an `:icon` (`:reset`, `:pause`, `:mute`, `:walls`). Icons are defined once, as a small op list, in `laylagen/src/worldofcake/laylagen/icons.clj`; the generator copies the op list into the Haxe composition and the C++ control metadata, and turns it into SVG paths for Rack panels. OpenFL draws it with `IconPainter`, JUCE with `jucehost::drawIcon`. A control with an icon shows the icon instead of its label.

Examples:

- `Source/zewp/ZewpLayout.hx` wraps `Source/generated/zewp/ZewpLayoutGenerated.hx`.
- `Source/timeslider/TimeSliderLayout.hx` wraps `Source/generated/timeslider/TimeSliderLayoutGenerated.hx` and generated TimeSlider track metadata. TimeSlider track objects store generated UIDs, while persisted state stores stable slot indexes.

Rack uses target-specific Layla/EDN layout variants because Rack panels need different proportions, output sockets, and control idioms. The Rack pair is a second layout source of truth for the Rack panel: the Rack generator emits the panel SVG and native `ModuleWidget` layout from the same geometry. Rack EDN may define output jacks and other Rack-only metadata that has no OpenFL counterpart.

All six current Rack modules now have Rack Layla/EDN pairs. `generate_rack_layout.sh` consumes each pair and writes the generated SVG under `derivatives/vcvrack/<app>/generated/` plus a native layout header under `bridge/native/worldofcake/generated/rack/`. The generated SVG includes Rack title/branding and panel-level visual regions; the native header supplies generated geometry consumed by Rack C++ where that module has completed the migration. Rack-only output sockets remain in Rack EDN. Native controls and custom playfield drawing are being migrated incrementally, so the Rack pair is the intended source of truth even where a C++ shell still has legacy handwritten placement.

All native control/layout C++ is generated from the Layla/EDN sources, never from the Haxe codebase. The generator emits, under `bridge/native/worldofcake/generated/`:

- `<app>/<App>ControlIdsGenerated.h`: numeric control UIDs from Layla (mirrors the Haxe `Source/generated/<app>/` IDs).
- `<app>/<App>ControlMetadataGenerated.h`: semantic ranges, choices, labels, defaults, units, and normalize/denormalize helpers from the EDN.
- `juce/<app>/LayoutGenerated.h`: JUCE panel widget geometry from the canonical OpenFL Layla/EDN layout.
- `rack/<app>/<App>RackLayoutGenerated.h` and `<App>RackOutputsGenerated.h`: Rack panel geometry and output socket labels from the Rack Layla/EDN variant.

The `bridge/native/worldofcake/generated/` tree is generated output (gitignored alongside `Source/generated/` and `derivatives/vcvrack/*/generated/`) and is not hand-edited or treated as source. Only the surrounding hand-written files directly under `bridge/native/` (runners, queues, thread, persistence, POD types, mapping helpers) are maintained C++.

---

## 7. Coordinate System and Mapping

The code uses three explicit point types:

- `WindowPoint`: host/window/design coordinates after OpenFL stage coordinates have been normalized by `ResponsivePanelHost`.
- `PanelPoint`: logical control-panel coordinates.
- `LocalPoint`: coordinates inside a specific component.

Mapping classes:

- `OneDMapper`: linear range map.
- `CoordinateMapper`: 2D map between rectangular spaces.
- `ComposedCoordinateMapper`: mapper composition.

Component input flow:

1. OpenFL `MouseEvent` provides `stageX/stageY`.
2. `ResponsivePanelHost.stageToDesign(...)` returns a `WindowPoint`.
3. `OpenFLAppBase` passes that to `world.handleMouseDown/Drag/Up(...)`.
4. `ComponentWorldBase` asks components to handle the `WindowPoint`.
5. `ComponentCommon` maps `WindowPoint -> PanelPoint -> LocalPoint`.
6. The sequencer receives `uid` plus component-local `LocalPoint`.

This is why component UIDs matter: the sequencer receives a local point whose meaning is scoped by the component that produced it.

---

## 8. Reusable UI Component Model

Defined in `Source/worldofcake/ui/`:

- `IComponent`: common API for coordinate conversion, hit-testing, and input handlers.
- `ComponentCommon`: shared mapping/hit-test implementation used by concrete components via composition.
- `PlayArea`: rectangular interaction region that forwards local mouse input.
- `Slider`: value control that maps local coordinates to numeric ranges and emits `newValue(uid, value)`.
- `Knob`: circular value control for music-software-style parameter editing; targets such as Rack/VST may render the same generated control with native knobs.
- `Button`: momentary command control that emits `buttonPressed(uid)`.
- `Toggle`: binary value control that emits `newValue(uid, 0/1)`. When the sequencer owns the value (`controlValue(uid)` is non-null, e.g. pause/mute) the toggle only displays it, refreshing each frame, and a click requests the opposite of the model's value. Otherwise it keeps a local value.
- `SemanticSelect`: selection control over named choices that emits `newValue(uid, index)`.
- `TextInput`: text entry control that emits `textSubmitted(uid, text)`.
- `PianoRoll`: score/note editing surface.
- `PanelTitle` / `PanelStatus`: static panel chrome.
- `ControlValueViewBase`: shared base for views that repaint value controls.
- `IValueControl`: common value-control contract implemented by value widgets.

TimeSlider uses app-local `TimeSliderTrackComponent` instances instead of the generic `Slider`, because its tracks have custom musical semantics: vertical position chooses target CC value and horizontal position chooses travel time.

---

## 9. Sequencer/Event/Redraw Flow

OpenFL runtime flow:

1. `OpenFLAppBase` timer tick calls `world.getSequencer().advanceTime(delta)` with the real elapsed time.
2. The sequencer mutates internal state and queues musical `Event`s.
3. `OpenFLAppBase` drains ready events via `hasEventBefore/getNextEvent`.
4. Events are sent to `MonitorInstrument` unless built in preview mode.
5. On `ENTER_FRAME`, `OpenFLAppBase` calls `world.getView().redrawDirty()`.
6. Each view decides which UIDs need redrawing and calls its own `redraw(uid)` as needed.

This keeps event generation, host event draining, and drawing policy separated.

Musical event generation belongs to the sequencer/control path; views publish redraw dirtiness but must not be required for audio/MIDI generation.

---

## 10. App Modules

Current app modules:

- `gbloink`: bouncing balls plus block interactions; emits note events.
- `zewp`: moving line agents with obstacle interactions; emits CC events based on positions.
- `kdiagram`: graph-based cursor walkers; emits position CC and note events on node arrivals.
- `tileland`: Truchet-tile maze cursors; emits CC/control-style streams.
- `timeslider`: four parallel time-to-target tracks; emits CC events while sliders move.
- `goldenpond`: text-driven multi-part looping note sequencer with score compilation and harmonic input-note correction.

Goldenpond is a full peer app, but its sequencer is derived from the external Goldenpond library, which is developed in its own project. When that upstream library changes, it is re-imported into this repository; developing the upstream library is out of scope for WorldOfCake. The reusable playback core has already been extracted into `Source/worldofcake/LoopingNotePlayer.hx` (with `SequenceNote`/`SequenceNoteEvent`/`SequenceSnapshot`), so only the app-specific part remains in `Source/goldenpond/`.

Each app owns:

- domain state and update rules in its sequencer
- app-specific rendering in its view
- component composition and input routing in its world
- app-facing layout constants in its `*Layout.hx` wrapper
- manual state JSON schema and serializer
- host-specific output interpretation where needed

---

## 11. Native Host Boundary

Native host integration lives under `bridge/`.

Key pieces:

- `bridge/haxe/worldofcake/bridge/SequencerHarness.hx`: shared harness base owning one `ISequencer` and exposing its lifecycle (time, transport, reset, pause, mute, persistence, model status) to C++.
- `bridge/haxe/worldofcake/bridge/*Harness.hx`: per-app harnesses extending `SequencerHarness`; they construct the app model and add only app-specific calls.
- `bridge/native/ControlThread`: background control cadence and hxcpp thread attachment.
- `bridge/native/ControlRunnerBase.h`: shared C++ runner shell for command queues, thread lifecycle, persistence requests, command drop counters, logical-time storage, and real-time-safe copies of the model's pause/mute flags (`isModelPaused()` / `isModelMuted()`).
- `bridge/native/NoteOutputScheduler.h`: the one audio-thread note output object every host adapter uses (Rack and JUCE). It delivers model events on the host clock in timestamp order, emits late events immediately, never drops a note-off, tracks sounding notes (Rack gates are derived from it), and offers `releaseAll()` for host discontinuities the model cannot see (play/stop, seeks, `prepareToPlay`). Adapters do not flush notes on pause/mute/reset; the model does.
- `bridge/native/HarnessControlRunner.h`: template layer owning the harness pointer; it applies lifecycle commands for every app and refreshes the pause/mute flags after each command drain. Concrete runners implement only `applyAppCommand`.
- `bridge/native/SpscRingBuffer.h`: bounded single-producer/single-consumer queues.
- `bridge/native/StatePersistence.h`: native persistence request/response transport (header-only).
- `bridge/native/WorldOfCakeBridgeTypes.h`: POD command/snapshot/event types shared across runners and hosts.
- `bridge/native/HaxeRuntimeBoot.h`: boots the hxcpp library exactly once and releases the loader thread's top-of-stack registration (required for Rack's plugin-loading thread).
- `bridge/native/WorldOfCakeOutputMapping.h`: shared normalized↔MIDI↔CV conversion helpers used by native hosts.

The generated C++ under `bridge/native/worldofcake/generated/` (control IDs, control metadata, Rack layout/outputs, and JUCE layout) is produced from the Layla/EDN sources, not from the Haxe codebase; see §6. The maintained C++ lives directly under `bridge/native/` plus the C++ unit tests in `bridge/native/tests/`.

The real-time host/audio side must not call into Haxe, allocate through Haxe, render, or take a Haxe/UI mutex. Native runners advance Haxe on the control side and publish prepared native events/snapshots for host consumption.

### Thread and queue contract

Each [`ControlRunnerBase`](bridge/native/ControlRunnerBase.h) owns one [`ControlThread`](bridge/native/ControlThread.h) and two bounded [`SpscRingBuffer<ControlCommand, 64>`](bridge/native/SpscRingBuffer.h) queues:

```text
JUCE editor / Rack UI  ──GUI queue──┐
Rack audio/host thread ──host queue─┼─> control thread -> Haxe harness/model
                                    │
control thread -> prepared-event queue / native visual snapshot
                                    └─> host audio/UI consumers
```

- The GUI/editor and host/audio sides are the producers for their respective command queues; the control thread is the sole consumer. The shared command/event structures are defined in [`WorldOfCakeBridgeTypes.h`](bridge/native/WorldOfCakeBridgeTypes.h).
- Host commands are drained before GUI commands on each control tick, so transport, MIDI, CV, and reset commands get priority over UI gestures.
- Commands are fixed-size POD values. Text submission uses the fixed 256-byte buffer in `ControlCommand`; pointers, Haxe objects, STL containers, and UI objects must never cross an SPSC queue.
- Lifecycle commands (`CommandKind::setPaused`, `setMuted`, `reset`, built with `pauseCommand()` / `muteCommand()` / `resetCommand()`) need no app control ID; hosts use them for every app. Other commands carry app-local control UIDs.
- Adapters never keep their own pause/mute state. Editors display the snapshot's `paused` / `muted` and request the opposite; audio threads read `isModelPaused()` / `isModelMuted()`. A host widget whose value the host itself persists (a Rack latch param) only forwards user changes and is restored from the model on patch load.
- A full queue drops the command and increments its separate drop counter. High-water marks are recorded for diagnostics; queues are not resized or dynamically allocated from the real-time path.
- Musical events are drained from Haxe by the control thread into prepared native event queues. The audio thread only pops POD `PreparedEvent` values and schedules/outputs them; see the per-app runners such as [`GbloinkControlRunner.cpp`](bridge/native/GbloinkControlRunner.cpp) and [`GoldenpondControlRunner.cpp`](bridge/native/GoldenpondControlRunner.cpp).
- Visual snapshots are published as native immutable-by-convention snapshots. UI code copies/reads the latest snapshot and never enters Haxe.
- Host transport time, epoch, running state, and BPM are latest-value atomics/mailboxes, not command queues. Publishing a host time enables the runner’s authoritative-clock mode; omitting it leaves the runner in its adapter default (Rack Goldenpond currently free-runs).
- Persistence export/import is request/response transport through [`StatePersistence`](bridge/native/StatePersistence.h); serialization and Haxe model replacement occur on the control thread, never in the audio callback.
- [`ControlThread.cpp`](bridge/native/ControlThread.cpp) attaches the worker to hxcpp, runs setup/model creation, ticks at the configured cadence, performs teardown, and joins before runner destruction. Native module destructors must stop the runner before releasing their harness or queues.

Representative host consumers are [`Gbloink.cpp`](derivatives/vcvrack/gbloink/src/Gbloink.cpp) for Rack and [`PluginProcessor.cpp`](derivatives/juce/gbloink/PluginProcessor.cpp) for JUCE/VST. Their audio/process callbacks consume native events and publish latest-value transport state; they do not call Haxe directly.

All six current apps have Rack-facing native runners using the shared runner pattern. App-specific code remains responsible for harness creation, app command dispatch, snapshot capture/publication, event draining, and any app-specific diagnostics.

---

## 12. Rack Target

The Rack target lives in `derivatives/vcvrack/`.

Current shape:

- each module has a small Rack C++ shell under `derivatives/vcvrack/<module>/src/` (some add an app-specific `*Persistence.cpp` such as `KDiagramPersistence.cpp`).
- shared Rack helpers live under `derivatives/vcvrack/common/`.
- `derivatives/vcvrack/common/plugin.mk` owns shared build rules.
- `derivatives/vcvrack/common/WocRackTiming.hpp` owns the current Rack control/logical timing policy.
- `derivatives/vcvrack/common/WocRackTransport.hpp` owns button edge helpers and turns pause/mute latches and the reset button into lifecycle commands.
- `derivatives/vcvrack/common/WocRackParamSync.hpp` owns repeated Rack-param-to-WoC-control mirroring helpers.
- `derivatives/vcvrack/common/WocRackStateJson.hpp` owns Rack↔JSON persistence wrapping for the app-owned state JSON.
- `derivatives/vcvrack/common/WocRackVoltage.hpp` owns MIDI↔CV/gate conversion on top of `WorldOfCakeOutputMapping.h`.
- `Source/generated/<app>/<App>ControlIdsGenerated.hx` contains generated Haxe control IDs and generated OpenFL redraw-control UID lists for redrawable controls such as sliders, semantic selects, and knobs. Views use those lists, while app-specific draw dispatch remains handwritten.
- `bridge/native/worldofcake/generated/<app>/<App>ControlIdsGenerated.h` contains generated C++ control IDs for Layla/EDN components, including buttons, toggles, knobs, sliders, selectors, play areas, and TimeSlider tracks. `bridge/native/WorldOfCakeControlIds.h` is now a compatibility/helper header that aliases generated names and provides grouping helpers such as `speedUid()` / `trackUid()`.
- generated hxcpp output, Rack object files, module binaries, and package output are written under `build/vcvrack/<module>/<platform>/`.
- `derivatives/vcvrack/install_linux_local.sh` builds and installs Linux modules into the local Rack plugin folder.

Rack uses the native runner boundary, not the obsolete direct-Haxe `*RackApi` approach. Audio processing consumes native snapshots/events produced by the control runner.

Rack `ParamId`, `InputId`, `OutputId`, and `LightId` values remain Rack-local host identifiers. Where a Rack parameter controls WoC behavior, the Rack shell maps from the Rack-local ID to the app-local WoC control UID through named constants and common sync helpers. Rack output sockets remain target-specific host metadata rather than OpenFL components.

Windows and Linux builds use the same module Makefiles with platform-specific Rack SDK defaults and artifact platform markers. Linux has been verified in this workspace; Windows/MSYS2 remains a separate verification step when working on Windows.

## 12a. JUCE/VST3 Target

The JUCE target lives in `derivatives/juce/` and currently produces Gbloink, TimeSliders, and Goldenpond VST3/standalone targets. Its architecture mirrors Rack at the native boundary:

- the Haxe app model remains authoritative for sequencing, controls, state, and event semantics;
- `bridge/haxe/*Harness.hx` owns the model instance on the control thread;
- `bridge/native/*ControlRunner` advances Haxe away from the audio thread and publishes prepared MIDI/events plus immutable visual snapshots;
- JUCE processors consume native events in `processBlock`, while JUCE editors render generated layout metadata and use host-native widgets only as the platform presentation layer;
- generated control metadata supplies semantic ranges, choices, labels, units, and defaults; JUCE must not maintain a second hand-written semantic table;
- coordinate conversion uses the shared WorldOfCake/native coordinate mapper, with only JUCE component/window conversion at the edge;
- generated JUCE panel geometry lives in `bridge/native/worldofcake/generated/juce/<app>/LayoutGenerated.h` (Layla/EDN-derived, not Haxe-derived); shared JUCE helpers (`WocJuceCoordinateMapper.h`, `WocJuceEditorSupport.h`) live in `derivatives/juce/common/`; note output uses the host-neutral `NoteOutputScheduler` (§11).

VST transport policy is adapter-owned. Gbloink and K-Diagram are free-running models gated by DAW play/stop; Goldenpond follows DAW transport position/BPM; TimeSliders remain gesture-driven unless a future policy explicitly opts them into transport. Mute suppresses emitted musical events; pause stops model advancement; transport stop is a separate host gate.

---

## 13. Build and Verification

Common checks:

- OpenFL app build: `lime build derivatives/openfl/project-<app>.xml neko`.
- Headless Haxe tests: `haxe hxml/tests/test-<app>-headless.hxml`.
- Native Haxe tests: `haxe hxml/tests/test-<app>-native.hxml` where present.
- Native C++ unit tests: `bridge/native/tests/WorldOfCakeCoordinates_test.cpp` and `WorldOfCakeControlMetadata_test.cpp`.
- Native harness/stress tests: `test/native/GbloinkHarness.cpp` and `test/native/GoldenpondRackStress.cpp` (see `test/native/GOLDENPOND_RACK_STRESS.md`).
- Rack all-modules build: `./derivatives/vcvrack/build_all.sh`.
- Linux local Rack install: `./derivatives/vcvrack/install_linux_local.sh`.
- Windows Rack all-modules clean build/install: `powershell -NoProfile -ExecutionPolicy Bypass -File .\derivatives\vcvrack\build-all-rack-windows.ps1 -Clean -Install`.
- Windows per-module Rack build/install: `powershell -NoProfile -ExecutionPolicy Bypass -File .\derivatives\vcvrack\build-rack-windows.ps1 -Module <gbloink|goldenpond|kdiagram|tileland|timeslider|zewp> -Clean -Install`.
- Windows JUCE/VST build: `powershell -NoProfile -ExecutionPolicy Bypass -File .\derivatives\juce\build-windows.ps1 -Plugin <Gbloink|Goldenpond|TimeSliders> -Target <target>`; VST3 artifacts are under `build/juce/cmake-vs2022/<target>_artefacts/Release/VST3/`.
- VST3 installation is host-independent: copy the resulting `.vst3` bundle to `C:\Program Files\Common Files\VST3` (or another scanned VST3 directory), then rescan the host. Preserve older bundles under distinct names only when historical comparison is intentional.

Avoid running multiple `lime build ... neko` commands in parallel. Lime can collide on shared generated output such as `ApplicationMain.n`; rerun the failed app alone if that happens.

---

## 14. Constraints and Open Questions

Current constraints:

- OpenFL is the reference UI implementation, but Rack needs target-specific panel variants.
- JUCE/VST3 integration is implemented under `derivatives/juce` for Gbloink, TimeSliders, and Goldenpond. VST editors must consume generated canonical OpenFL layout metadata and reuse the shared native bridge and coordinate mapper; JUCE-specific code is limited to host widgets, drawing, and MIDI/audio integration.
- Windows Rack builds need verification on Windows/MSYS2 after Linux-side changes.
- Resize currently replaces world mappers, but existing component instances may retain the mapper they were constructed with. This deserves a focused pass before relying heavily on dynamic resize behavior.
- Output semantics differ by host: MIDI/MIDI-CC are the base assumption, while Rack exposes gates/CV whose musical meaning is user-patched.
- OpenFL component UIDs are generated from Layla/EDN for the full canonical app UI. Rack control IDs for Rack-visible components are generated from the Rack Layla/EDN variant; Rack output/socket IDs remain Rack-local because sockets are physical host connection points.
- The Layla/EDN generator (the `laylagen` tool, distributed as `vendor/layla/worldofcake-laylagen.jar`) is an offline build-time generator maintained outside this repository. A complete rebuild regenerates OpenFL Haxe composition/ID files, native C++ control-ID and metadata headers (from Layla/EDN, not from Haxe), JUCE layout headers, Rack metadata/layout headers, and Rack SVGs before compiling targets. Generated files are not hand-edited or treated as source; the generated native C++ under `bridge/native/worldofcake/generated/` is gitignored.
- The generation pass also emits target-neutral native control metadata (`*ControlMetadataGenerated.h`) from the EDN component semantics. This is the common contract consumed by Rack and JUCE/VST adapters for ranges, choices, labels, defaults, and text values. Host adapters may translate that contract into Rack parameters or JUCE widgets, but must not duplicate the semantic tables. Host-only concerns (Rack sockets/panel geometry, JUCE widget classes and host I/O) remain outside this common metadata layer.
- Generated knob metadata also provides shared `normalize` and `denormalize` helpers. These define the adapter boundary explicitly: the WorldOfCake value remains in its semantic range, while a host such as Rack may expose a normalized `0..1` parameter and convert at the edge. Persistence, parameter synchronization, and host automation should use these helpers rather than repeating range arithmetic.
- Control metadata also carries semantic `unit` and `output` tags (for example `speed`/`midi-note`, `midi-velocity`/`midi-note`, or `bpm`/`transport`). These tags describe the WorldOfCake meaning and intended musical destination; they are not Rack or JUCE parameter IDs and do not replace host-specific output wiring.
- JUCE transport policy is adapter-owned: free-running generators such as Gbloink and K-Diagram should pause/resume with DAW play/stop without seeking to host position; clocked sequencers such as Goldenpond should follow host play/stop and transport position; gesture-driven sequencers such as TimeSliders may remain independent of transport. Shared host transport plumbing must expose these as explicit policies rather than adding host conditionals to Haxe sequencers.
- VST persistence is host-state persistence: JUCE saves the app-owned state JSON plus adapter state and restores it before the editor is expected to render. The editor must redraw from the restored visual snapshot; it must not infer readiness from empty patterns, notes, or text fields.
- Rack persistence uses Rack's `dataToJson`/`dataFromJson` boundary and transports the app-owned state JSON through the native runner. It must not use Haxe reflection-based generic serialization for app state.
- Rack clock policy: Rack has no universal musical transport clock. Goldenpond currently runs free-running from the Rack audio callback by default, using its own BPM/model timing. The Rack adapter must not publish a synthetic host transport clock unless an actual clock/transport input is implemented. External clock input (pulse counting, reset/start, and optional BPM estimation) is planned as a future adapter feature.

Open design questions:

- how much app definition can become host-neutral before OpenFL/Rack/VST differences make that abstraction counterproductive;
- how to formalize output semantics across MIDI, CV/gate, and future hosts;
- how to treat Goldenpond as a derivative of an external, separately-developed library while keeping its shared playback core (`LoopingNotePlayer` and friends) reusable here.

---

## 15. Recommended Mental Model

Treat WorldOfCake as:

- a Haxe sequencer/control framework (`Source/worldofcake`),
- an OpenFL reference UI layer (`Source/worldofcake/ui` plus app views/worlds),
- a native bridge layer for real-time hosts (`bridge/`),
- target-specific derivative shells (`derivatives/vcvrack`, `derivatives/juce`),
- and a set of independent musical experiments sharing the same lifecycle contracts.

The framework should remove host, timing, persistence, coordinate, and lifecycle boilerplate. It should not merge away the distinct musical identities of Gbloink, Zewp, KDiagram, TileLand, TimeSlider, or Goldenpond (whose sequencer is derived from the external Goldenpond library and re-imported when that library changes).
