# WorldOfCake Architecture

Updated: 2026-09-03

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
- `Source/<app>/`: app-specific Haxe code (`gbloink`, `zewp`, `kdiagram`, `tileland`, `timeslider`).
- `Source/platform/`: simple instrumentation adapters such as `MonitorInstrument`.
- `bridge/haxe/`: Haxe harness classes used by native runners.
- `bridge/native/`: shared C++ native bridge code, including `ControlThread`, `ControlRunnerBase`, queue types, bridge POD types, and persistence transport.
- `derivatives/vcvrack/`: VCV Rack module shells, Rack-specific panels/widgets, shared Rack build helpers, and install scripts.
- `build/`: generated/intermediate build output. Rack artifacts are under `build/vcvrack/<module>/`.
- `hxml/tests/`: Haxe test build files.
- `project-*.xml`: per-app OpenFL project files kept at the repo root for direct `lime build` use.

OpenFL app builds usually use the per-app project files, for example:

- `lime build project-gbloink.xml neko`
- `lime build project-kdiagram.xml neko`
- `lime build project-tileland.xml neko`
- `lime build project-timeslider.xml neko`
- `lime build project-zewp.xml neko`

Rack builds use the module Makefiles via the shared include in `derivatives/vcvrack/common/plugin.mk`; `derivatives/vcvrack/install_linux_local.sh` builds/packages/installs all Linux Rack modules on this machine.

---

## 3. Core Contracts

The main framework contracts are in `Source/worldofcake/` and `Source/worldofcake/ui/`.

### `ISequencer`

The host-facing sequencer contract:

- `advanceTime(delta)` advances logical time and app state.
- `hasEventBefore(timeLimit)` / `getNextEvent()` expose queued musical events.
- `pause()` / `resume()` freeze or resume simulation and logical time.
- `reset()` returns to an app-defined baseline.
- `exportStateJson()` / `importStateJson(json)` persist recoverable runtime state.

Persistence JSON is deliberately app-owned. WoC standardizes the entry point and native/Rack transport, but each app writes its own serializer because generic Haxe JSON serialization of arbitrary structures caused Rack stability problems.

### `IControlPanel`

The control/input contract:

- mouse events use a component/control UID plus a `LocalPoint`.
- value changes use `newValue(uid, value)`.
- buttons and keyboard use explicit UID/key calls.

The sequencer is expected to know what a UID means inside that app.

### `IControlPanelView`

The redraw contract:

- `needsRedraw(uid)` answers whether one visual component needs updating.
- `redraw(uid)` redraws that component.
- `redrawDirty()` is called once per OpenFL frame and lets the view own its own redraw UID policy.

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

---

## 4. Shared Haxe Lifecycle

### `SequencerCore`

`Source/worldofcake/SequencerCore.hx` centralizes common sequencer lifecycle mechanics:

- `currentTime`
- event queue storage
- `pause()` / `resume()`
- finite-positive-delta guard in `advanceTime(delta)`
- dirty flag handling
- event queue helpers
- `getLogicalTime()` / `isPaused()`
- `resetTransport()` / `clearEvents()`

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
- starts the 1 ms update timer
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
- companion EDN owns component metadata such as ranges, labels, colors, widget hints, target bindings, and behavior-facing labels/defaults. The EDN map key is the semantic identity source; laylagen assigns app-local numeric control UIDs in layout order. Essential app controls such as reset, pause, toggles, and rotate buttons are spatial Layla components in the canonical OpenFL layout.
- generated Haxe code lives under `Source/generated/<app>/`, including `<App>ControlIdsGenerated.hx`.
- app-local `*Layout.hx` files wrap generated layout constants and provide a stable app-facing layout API.
- maintained app code should not import `*LayoutGenerated` directly. The intentional exception is the app-local `*Layout.hx` facade. Maintained behavior code may use generated control-ID classes directly or through temporary app-local aliases during migration.
- app `World` classes may import generated `*CompositionGenerated` builders, because worlds are the OpenFL composition boundary.

Examples:

- `Source/zewp/ZewpLayout.hx` wraps `Source/generated/zewp/ZewpLayoutGenerated.hx`.
- `Source/timeslider/TimeSliderLayout.hx` wraps `Source/generated/timeslider/TimeSliderLayoutGenerated.hx` and generated TimeSlider track metadata. TimeSlider track objects store generated UIDs, while persisted state stores stable slot indexes.

Rack uses target-specific Layla/EDN layout variants because Rack panels need different proportions, output sockets, and control idioms. The Rack pair is a second layout source of truth for the Rack panel: the Rack generator will emit the panel SVG and native `ModuleWidget` layout from the same geometry. Rack EDN may define output jacks and other Rack-only metadata that has no OpenFL counterpart.

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
- `Toggle`: binary value control that emits `newValue(uid, 0/1)`.

TimeSlider uses app-local `TimeSliderTrackComponent` instances instead of the generic `Slider`, because its tracks have custom musical semantics: vertical position chooses target CC value and horizontal position chooses travel time.

---

## 9. Sequencer/Event/Redraw Flow

OpenFL runtime flow:

1. `OpenFLAppBase` timer tick calls `world.getSequencer().advanceTime(delta)`.
2. The sequencer mutates internal state and queues musical `Event`s.
3. `OpenFLAppBase` drains ready events via `hasEventBefore/getNextEvent`.
4. Events are sent to `MonitorInstrument` unless built in preview mode.
5. On `ENTER_FRAME`, `OpenFLAppBase` calls `world.getView().redrawDirty()`.
6. Each view decides which UIDs need redrawing and calls its own `redraw(uid)` as needed.

This keeps event generation, host event draining, and drawing policy separated.

Caveat: some current apps still generate continuous events from view redraw paths. That is historical behavior and should be kept in mind when moving toward stricter host timing, Rack, or VST behavior.

---

## 10. App Modules

Current app modules:

- `gbloink`: bouncing balls plus block interactions; emits note events.
- `zewp`: moving line agents with obstacle interactions; emits CC events based on positions.
- `kdiagram`: graph-based cursor walkers; emits position CC and note events on node arrivals.
- `tileland`: Truchet-tile maze cursors; emits CC/control-style streams.
- `timeslider`: four parallel time-to-target tracks; emits CC events while sliders move.

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

- `bridge/haxe/worldofcake/bridge/*Harness.hx`: small Haxe wrappers around one app model instance.
- `bridge/native/ControlThread`: background control cadence and hxcpp thread attachment.
- `bridge/native/ControlRunnerBase.h`: shared C++ runner shell for command queues, thread lifecycle, persistence requests, command drop counters, and logical-time storage.
- `bridge/native/SpscRingBuffer.h`: bounded single-producer/single-consumer queues.
- `bridge/native/StatePersistence.*`: native persistence request/response transport.
- `bridge/native/WorldOfCakeBridgeTypes.h`: POD command/snapshot/event types shared across runners and hosts.

The real-time host/audio side must not call into Haxe, allocate through Haxe, render, or take a Haxe/UI mutex. Native runners advance Haxe on the control side and publish prepared native events/snapshots for host consumption.

All five current apps have Rack-facing native runners using the shared runner pattern. App-specific code remains responsible for harness creation, command dispatch, snapshot capture/publication, event draining, and any app-specific diagnostics.

---

## 12. Rack Target

The Rack target lives in `derivatives/vcvrack/`.

Current shape:

- each module has a small Rack C++ shell under `derivatives/vcvrack/<module>/src/`.
- shared Rack helpers live under `derivatives/vcvrack/common/`.
- `derivatives/vcvrack/common/plugin.mk` owns shared build rules.
- `derivatives/vcvrack/common/WocRackTiming.hpp` owns the current Rack control/logical timing policy.
- `derivatives/vcvrack/common/WocRackTransport.hpp` owns reset/pause/button edge helpers.
- `derivatives/vcvrack/common/WocRackParamSync.hpp` owns repeated Rack-param-to-WoC-control mirroring helpers.
- `Source/generated/<app>/<App>ControlIdsGenerated.hx` contains generated Haxe control IDs and generated OpenFL redraw-control UID lists for redrawable controls such as sliders, semantic selects, and knobs. Views use those lists, while app-specific draw dispatch remains handwritten.
- `bridge/native/worldofcake/generated/<app>/<App>ControlIdsGenerated.h` contains generated C++ control IDs for Layla/EDN components, including buttons, toggles, knobs, sliders, selectors, play areas, and TimeSlider tracks. `bridge/native/WorldOfCakeControlIds.h` is now a compatibility/helper header that aliases generated names and provides grouping helpers such as `speedUid()` / `trackUid()`.
- generated hxcpp output, Rack object files, module binaries, and package output are written under `build/vcvrack/<module>/`.
- `derivatives/vcvrack/install_linux_local.sh` builds and installs Linux modules into the local Rack plugin folder.

Rack uses the native runner boundary, not the obsolete direct-Haxe `*RackApi` approach. Audio processing consumes native snapshots/events produced by the control runner.

Rack `ParamId`, `InputId`, `OutputId`, and `LightId` values remain Rack-local host identifiers. Where a Rack parameter controls WoC behavior, the Rack shell maps from the Rack-local ID to the app-local WoC control UID through named constants and common sync helpers. Rack output sockets remain target-specific host metadata rather than OpenFL components.

Windows and Linux builds use the same module Makefiles with platform-specific Rack SDK defaults and artifact platform markers. Linux has been verified in this workspace; Windows/MSYS2 remains a separate verification step when working on Windows.

---

## 13. Build and Verification

Common checks:

- OpenFL app build: `lime build project-<app>.xml neko`.
- Headless Haxe tests: `haxe hxml/tests/test-<app>-headless.hxml`.
- Native Haxe tests: `haxe hxml/tests/test-<app>-native.hxml` where present.
- Rack all-modules build: `./derivatives/vcvrack/build_all.sh`.
- Linux local Rack install: `./derivatives/vcvrack/install_linux_local.sh`.

Avoid running multiple `lime build ... neko` commands in parallel. Lime can collide on shared generated output such as `ApplicationMain.n`; rerun the failed app alone if that happens.

---

## 14. Constraints and Open Questions

Current constraints:

- OpenFL is the reference UI implementation, but Rack needs target-specific panel variants.
- VST/JUCE integration has not been implemented yet.
- Windows Rack builds need verification on Windows/MSYS2 after Linux-side changes.
- Resize currently replaces world mappers, but existing component instances may retain the mapper they were constructed with. This deserves a focused pass before relying heavily on dynamic resize behavior.
- Output semantics differ by host: MIDI/MIDI-CC are the base assumption, while Rack exposes gates/CV whose musical meaning is user-patched.
- OpenFL component UIDs are generated from Layla/EDN for the full canonical app UI. Rack output/socket metadata still needs a later metadata decision because sockets are Rack-specific physical connection points.

Open design questions:

- how much app definition can become host-neutral before OpenFL/Rack/VST differences make that abstraction counterproductive;
- how to formalize output semantics across MIDI, CV/gate, and future hosts;
- how Goldenpond's reusable multi-part sequence player should fit into WoC once that app begins.

---

## 15. Recommended Mental Model

Treat WorldOfCake as:

- a Haxe sequencer/control framework (`Source/worldofcake`),
- an OpenFL reference UI layer (`Source/worldofcake/ui` plus app views/worlds),
- a native bridge layer for real-time hosts (`bridge/`),
- target-specific derivative shells (`derivatives/vcvrack`, future `derivatives/juce`),
- and a set of independent musical experiments sharing the same lifecycle contracts.

The framework should remove host, timing, persistence, coordinate, and lifecycle boilerplate. It should not merge away the distinct musical identities of Gbloink, Zewp, KDiagram, TileLand, TimeSlider, or future Goldenpond-based apps.
