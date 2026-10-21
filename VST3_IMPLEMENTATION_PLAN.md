# WorldOfCake VST3 Implementation Plan

Status: Gbloink, TimeSliders, and Goldenpond Windows VST3 implementations build successfully. FL Studio validation remains host-side and Goldenpond widget/control binding is still being completed.

## 1. Goal

Build the WorldOfCake sequencers as separate VST3 MIDI-effect plug-ins, initially for Windows and FL Studio, while preserving one authoritative Haxe implementation of each sequencer.

The VST products will reuse the existing native runner, command queues, prepared-event queues, visual snapshots, persistence boundary, and hxcpp lifecycle. JUCE will own the plug-in lifecycle, host communication, MIDI buffers, parameters, state chunks, and native editor.

The first delivery target was Gbloink as both a VST3 and a standalone application. TimeSliders is the continuous-control proof, and Goldenpond is the multi-part sequencer target. All targets share the native runner, coordinate mapper, generated control IDs, and generated canonical layout metadata.

## 2. Real-time boundary

The DAW audio thread must never enter Haxe or hxcpp. In particular, `processBlock()` must not:

- call a Haxe method;
- allocate a Haxe object or trigger Haxe garbage collection;
- lock a mutex shared with the Haxe/control or message thread;
- wait for persistence or UI work;
- perform unbounded allocation.

The existing WorldOfCake control thread owns the Haxe model. It advances the model, drains Haxe events into a bounded native SPSC queue, and publishes native visual snapshots. The JUCE audio processor consumes only native prepared events and immutable/latest-value native state.

The corrected hxcpp lifecycle is mandatory in every VST target: initialize the runtime once from the plug-in binary, detach the initializing thread, and attach the control worker for the whole period in which it owns Haxe objects. Plug-in construction, destruction, rescanning, and multiple simultaneous instances must be stress-tested.

## 3. Timing and sample-accurate scheduling

Gbloink publishes prepared events with absolute timestamps in logical seconds. The VST runner now simulates a bounded 20 ms ahead of the host playhead and advances physics in 1 ms substeps. This preserves the established collision cadence while allowing the native scheduler to place events at offsets within an audio block. Sample-offset scheduling does not require the Haxe sequencer to understand audio blocks, sample rates, or JUCE.

The native VST layer will:

1. Read the host play state, tempo, time signature, sample position, PPQ position, loop state, and discontinuity information at the start of each block.
2. Maintain a native mapping between WorldOfCake logical seconds and the current host transport epoch.

### Transport policy

Transport behavior is selected per sequencer at the host adapter boundary:

- Gbloink and K-Diagram are free-running generators. They pause/resume with DAW play/stop but do not seek their internal model to the host position.
- Goldenpond and future sequencers built on the clocked looping-score core follow DAW play/stop and host transport position, including seek/restart discontinuities.
- TimeSliders is gesture-driven and may remain independent of DAW transport.

These policies must not be implemented as host checks in shared Haxe sequencer code.
3. Keep future prepared events in a fixed-capacity native scheduler.
4. Convert each event time inside the current block to an integer sample offset.
5. Add the corresponding MIDI message to JUCE's `MidiBuffer` at that offset.
6. Retain later events for subsequent blocks and discard or recover safely from stale events.
7. Send note-offs/all-notes-off on stop, seek, loop discontinuity, reset, queue overflow, or destruction.

Haxe changes should remain host-neutral. The likely shared addition is an explicit transport reset/seek contract that clears pending events and establishes a new logical epoch. It must not mention samples, blocks, PPQ, VST, or JUCE. Forward monotonic synchronisation can continue using `resyncTime()`.

The current Rack runner advances by fixed control-thread deltas. The VST runner must gain a host-clock mode: the audio side publishes an authoritative target time through a latest-value native mailbox, and the Haxe-owning control thread advances towards `host time + look-ahead`. This is a shared runner-clock facility, not VST logic in Haxe. Gbloink currently detects collisions at control-tick resolution, so its event timestamps initially have that resolution even when C++ converts them to exact sample offsets. If finer collision timing proves musically necessary, interpolation belongs in the host-neutral Gbloink simulation.

The initial look-ahead horizon is 20 ms. Both the prepared-event bridge and native pending scheduler are fixed-capacity. These values remain subject to measurement in FL Studio stress tests.

Implemented transport behavior uses an explicit host-neutral `resetTransport()` contract in Haxe. Native epoch changes reset the logical clock while preserving the editor's musical layout. Events are tagged with their epoch so a seek or restart cannot leak old triggers into the new transport timeline.

## 4. JUCE product architecture

Add the VST implementation incrementally under:

```text
derivatives/juce/
  CMakeLists.txt
  cmake/
  common/
    WocAudioProcessorBase.*
    WocControlBridge.*
    WocMidiScheduler.*
    WocTransportTracker.*
    WocStateCodec.*
    WocEditorBase.*
  gbloink/
  timeslider/
  kdiagram/
  tileland/
  zewp/
  goldenpond/
```

Each application is a separate plug-in binary with a stable plug-in identifier and its own generated hxcpp application code. The binaries share source-level JUCE infrastructure but do not share a mutable global application instance.

Use JUCE's CMake API (`juce_add_plugin`) and generate Visual Studio builds with CMake. Projucer-era Gbloink projects elsewhere on this machine are historical references only.

The initial formats are:

- VST3 MIDI effect for DAW use;
- Standalone for debugger access and development without host routing;
- no VST2 build;
- no audio synthesis in the shipping Gbloink plug-in.

## 5. Parameters, commands, and state

Before release, define stable identifiers for every plug-in, parameter, command, and persisted field. Host-visible parameters use JUCE `AudioProcessorValueTreeState` and stable textual IDs. WorldOfCake controls that are not useful automation targets remain commands rather than artificial parameters.

Parameter changes from the host audio thread must use a bounded real-time-safe channel. Slowly changing commands can use the existing host SPSC queue. Continuously automated values require latest-value atomic mailboxes so dense automation cannot flood a command queue.

Plug-in state contains:

- a versioned JUCE parameter tree;
- the versioned WorldOfCake Haxe state JSON;
- any native scheduler or routing configuration that must survive reload.

State requests cross the existing bounded persistence boundary. Host state callbacks must have a bounded wait and a safe fallback; they must never wait indefinitely for the Haxe thread.

## 6. User interface

Use native JUCE controls and custom JUCE drawing. Do not embed OpenFL in the plug-in.

The editor consumes native visual snapshots and sends bounded commands. It never directly accesses Haxe objects. Gbloink's play area will be a custom component, while knobs, sliders, buttons, labels, and selectors use native JUCE components.

The first Gbloink editor may establish the component vocabulary by hand. Once proven, extend the WorldOfCake-owned Layla generator with a JUCE target that emits deterministic component composition, geometry, parameter attachments, and bindings from the existing Layla/EDN semantics.

## 7. Implementation stages

### Stage A — Windows toolchain proof

- Locate and record the installed JUCE, Visual Studio, CMake, VST3 validator, and plug-in validation tools.
- Pin the JUCE version or checkout used by the project.
- Build an empty VST3 plus standalone target.
- Install/scan it in FL Studio.

Build and standalone/VST3 product generation are complete. FL Studio scanning remains a manual host validation step.

### Stage B — Shared shell

- Implement the common processor and editor foundations.
- Integrate `HaxeRuntimeBoot` and `ControlThread` without duplicating their lifecycle code.
- Add transport capture, a fixed-capacity MIDI scheduler, panic handling, state chunks, and diagnostics.
- Add native tests for event-to-sample-offset conversion and transport discontinuities.

The runner clock, bounded MIDI scheduler, epoch handling, panic behavior, and scheduler regression test are implemented. Common-class extraction can wait until the second sequencer demonstrates the stable boundary.

### Stage C — Gbloink product

- Compile the current Gbloink Haxe bridge to C++ as part of the VST build.
- Start one Gbloink runner per plug-in instance.
- Emit channel-correct note-on and note-off MIDI at block-relative sample offsets.
- Implement the native Gbloink editor from visual snapshots and commands.
- Restore WorldOfCake and parameter state after project reload.

The Gbloink bridge, MIDI output, native snapshot-driven editor, and Haxe JSON state chunk are implemented. Host-visible automatable parameters and the combined JUCE/Haxe versioned state envelope remain before release.

### Stage D — Validation

- Run the Steinberg VST3 validator and `pluginval` when available.
- Scan and use the VST3 in FL Studio.
- Verify MIDI routing into an FL Studio instrument.
- Test play, stop, seek, loop, tempo change, project save/reload, editor reopen, offline render, and automation.
- Test multiple instances, repeated create/destroy, forced hxcpp garbage collection, queue overflow recovery, common sample rates, and variable block sizes.
- Inspect the audio callback for Haxe calls, locks, and avoidable allocation.

### Stage E — Portfolio rollout

1. TimeSlider: establish continuous MIDI CC and automation mailbox policy.
2. K-Diagram: mixed event behaviour and hxcpp/GC lifecycle stress.
3. TileLand: multiple continuous controller streams.
4. Zewp: dynamic agents with a bounded host-visible output contract.
5. Goldenpond: host-synchronised score playback and input correction, after resolving its distribution/licensing requirements.

## 8. Gbloink acceptance gate

Gbloink is complete for the first milestone when:

- a repeatable Windows command builds VST3 and standalone Release products;
- FL Studio scans and instantiates the VST3;
- MIDI notes are scheduled at correct sample offsets and route to another instrument;
- stop, seek, loop, reset, overflow, and destruction cannot leave hanging notes;
- editor interactions and visuals use only commands and snapshots;
- state survives saving and reopening an FL Studio project;
- multiple instances and repeated load/unload survive forced-GC stress;
- `processBlock()` contains no Haxe calls, blocking locks, or unbounded work;
- the Windows procedure and dependency locations are documented in `BUILD_INSTRUCTIONS.md`.

## 9. Decisions to preserve

- Haxe remains the authoritative musical model.
- Host-specific scheduling stays in native C++.
- JUCE is the VST3 shell; raw Steinberg SDK integration is unnecessary unless validation exposes a JUCE limitation.
- CMake is the reproducible build authority; old `.jucer` projects are reference material.
- FL Studio is the first real host, but host-specific MIDI-effect behaviour is tested rather than assumed.
- Target-specific UI rendering is acceptable; semantic controls and bindings remain shared through Layla/EDN.
