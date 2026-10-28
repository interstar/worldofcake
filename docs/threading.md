# WorldOfCake Threading Model — Discussion

Date: 2026-09-01

This document records an architectural discussion about **where simulation, UI, and audio run** in WorldOfCake (WoC), how that differs between OpenFL and native plugin hosts today, and what we should do when adding **web (WebAudio)** and **Android** targets.

It is a discussion piece, not an implementation plan. See `architecture.md` for the current framework layout and `redundancy.md` for Rack timing and runner consolidation status.

---

## 1. The question

WoC apps have three distinct kinds of work:

1. **Simulation** — advance the sequencer model (`advanceTime`), generate events, update ball/cursor positions.
2. **Presentation** — draw the play area and controls, handle mouse/keyboard.
3. **Audio output** — drive CV, gates, MIDI, or sample streams at real-time or near-real-time rates.

On **OpenFL desktop**, all three currently share one thread. On **VCV Rack**, they are split across three execution contexts. When we port to **VST/JUCE**, **browser + WebAudio**, or **Android**, we need to decide:

- Is the control/UI split a **fundamental WoC design** that should appear in Haxe, or a **Rack-only implementation detail**?
- Do web and Android recreate the same separation through new native bridges (like `bridge/native`), or can they keep the OpenFL “everything on main thread” model?
- What belongs in **portable Haxe** vs **per-host glue**?

The practical symptom that prompted this discussion: motion in Gbloink and TileLand feels **slower in OpenFL than in Rack**, partly because OpenFL runs simulation and redraw on the same main thread while Rack runs simulation on a dedicated control worker that is not blocked by NanoVG paint cost.

---

## 2. Current solution

### 2.1 Portable Haxe — logical separation only

The framework already separates **model** and **view** in Haxe:

| Piece | Location | Role |
|-------|----------|------|
| Sequencer / model | `Source/<app>/*Sequencer.hx`, `SequencerCore` | State, `advanceTime`, events, JSON persistence |
| View | `Source/<app>/*View.hx` | Pull-based redraw: `needsRedraw` / `redraw` |
| World (OpenFL) | `Source/<app>/*World.hx`, `ComponentWorldBase` | Input routing, component composition |
| Harness (native hosts) | `bridge/haxe/worldofcake/bridge/*Harness.hx` | Thin façade over the sequencer for C++ callers — no UI |

Haxe does **not** spawn threads. Threading is a host concern.

### 2.2 OpenFL — collapsed onto one thread

Each `*Main.hx` follows the same loop:

- **`Timer(1)`** → `sequencer.advanceTime(0.001)` (simulation; historically named “audio” timer).
- **`ENTER_FRAME`** → `view.redraw(...)` when the model is dirty.
- **Mouse/keyboard** → `World.handleMouse*` on the same main thread.
- **`MonitorInstrument`** → traces MIDI events; there is no separate audio device thread.

```
OpenFL (single main thread)
  Timer          → advanceTime (simulation)
  ENTER_FRAME    → redraw (presentation)
  stage events   → input
```

This is adequate for development and standalone preview. It is **not** a template for plugin-grade real-time hosts: the 1 ms timer is often not honoured by the OS, and heavy redraw can starve simulation.

### 2.3 Rack — three execution contexts

Rack modules use shared infrastructure under `bridge/native/`:

| Context | Where | Calls Haxe? | Typical work |
|---------|-------|-------------|--------------|
| **Audio** | VCV Rack engine → `Module::process()` | No | Pop prepared events / control snapshots; set output voltages; enqueue param changes |
| **Control** | `ControlThread` (`std::thread`) → `*ControlRunner::pump()` | Yes (via hxcpp harness) | `advanceTime`, command queues, snapshot publish |
| **UI** | Rack main/GPU thread → widget `draw()` | No | Read `latestVisualSnapshot()`; NanoVG paint; mouse → GUI command queue |

Shared native pieces:

- `ControlThread.cpp` — worker thread, hxcpp stack attachment, periodic `pump(delta)`.
- `ControlRunnerBase.h` — dual SPSC command queues (host + GUI), persistence handoff, start/stop lifecycle.
- `WorldOfCakeBridgeTypes.h` — `ControlCommand`, snapshot PODs, coordinate types.
- `*ControlRunner.cpp` — per-app pump, snapshot capture, harness wiring.

Rack-specific code in `derivatives/vcvrack/<app>/src/` maps VCV widgets, params, and `process()` to that bridge. It does **not** reimplement the threading model.

Timing policy (all Rack modules today):

- Control wake cadence: ~60 Hz (`kControlPeriodSeconds`).
- Step passed to the harness: the real time elapsed since the previous wake-up, measured by `ControlThread` (capped at 0.25 s). Models split it into their own physics steps (`maxStepSeconds`).

See `derivatives/vcvrack/common/WocRackTiming.hpp` and `redundancy.md` § “Timing Policy”.

### 2.4 What is already shared vs host-specific

```
                    ┌─────────────────────────────────────┐
                    │  Haxe (portable)                    │
                    │  Sequencer + Harness (+ View for   │
                    │  OpenFL reference UI)               │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  bridge/native (shared C++)         │
                    │  ControlRunner, ControlThread,      │
                    │  queues, snapshots, persistence     │
                    └──────────────┬──────────────────────┘
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
    OpenFL Main              VCV Rack shell           JUCE shell (planned)
    (no bridge today)        derivatives/vcvrack/     derivatives/juce/
```

OpenFL bypasses the native bridge entirely. Rack (and future VST) sit on top of it.

---

## 3. Is the split fundamental to WoC?

**Yes — as a host contract, not as “Haxe must own threads”.**

The invariant for real-time hosts is:

> **The audio callback never enters Haxe.** Simulation runs elsewhere; audio and UI consume plain snapshots or event queues.

That rule exists because of real-time safety and hxcpp lifecycle, not because Rack happened to need it. The same constraint applies to:

- VST/JUCE `processBlock`
- WebAudio **AudioWorklet**
- Android **AAudio / Oboe** callback

The **logical** model/view split in Haxe (`ISequencer` vs `IControlPanelView`) is the portable expression of “simulation state vs presentation”. The **physical** thread split is implemented per host.

OpenFL desktop is the **collapsed reference host**: one thread, direct calls, no snapshots. That is intentional for simplicity, not the canonical architecture for all targets.

---

## 4. Proposal for future platforms

### 4.1 Principle: one contract, many adapters

Do **not** port `ControlThread.cpp` to every platform. Do **reuse the same semantic boundary**:

- **Commands in** — play-area clicks, slider changes, transport, host params.
- **Control snapshots / events out** — what audio consumes (CV values, gates, MIDI).
- **Visual snapshots out** — what UI draws (ball positions, tile grid, cursor poses).
- **Pump** — `advanceTime(delta)` on a non-audio cadence, with a documented timing policy.

Each target gets a **thin host adapter** that implements queues and snapshot handoff in whatever threading model the platform provides.

### 4.2 VST / JUCE (near-term)

**Reuse `bridge/native/`** with a new shell under `derivatives/juce/` (mirroring `derivatives/vcvrack/`):

| JUCE context | WoC role |
|--------------|----------|
| `processBlock` (audio) | Read control snapshots / events; write parameters or CV buffers |
| Message thread (UI) | Paint from visual snapshot; mouse → GUI command queue |
| `ControlThread` (unchanged) | Harness pump, same as Rack |

No reinvention of queues, persistence, or hxcpp worker setup — only JUCE-specific wiring.

### 4.3 Web (OpenFL → HTML5 + WebAudio)

Browser constraints:

- **Main thread** — DOM, OpenFL stage, input, canvas/WebGL draw.
- **Web Worker** — background JS; no DOM; suitable for harness + `advanceTime`.
- **AudioWorklet** — real-time audio; tiny budget; must not run full simulation.

Proposed shape:

```
[Web Worker]       *Harness (Haxe→JS)  →  advanceTime(delta)
        ↕ postMessage or SharedArrayBuffer
[Main thread]      OpenFL World/View  →  draw from visual snapshot
[AudioWorklet]     read latest control snapshot → audio/MIDI/CV out
```

- **Preview-only web** (no worklet): collapsed main-thread model like OpenFL today is acceptable.
- **WebAudio production**: Worker + worklet separation is **required** for the same reasons as Rack.

Implementation: a **JavaScript host bridge** (`WoCWebHost` or similar), not a C++ port. Compile `bridge/haxe/*Harness` to JS and run it in the Worker.

### 4.4 Android (Haxe → Java)

Two paths:

**A. Java transpilation (stated priority in `Source/worldofcake/README.md`)**

- Harness + sequencer compile to Java.
- Simulation on a **`HandlerThread`** or executor (analogue of `ControlThread`).
- UI on Android main thread (OpenFL or native widgets).
- Audio callback reads snapshots only.

Advantage: no hxcpp on device; the “runner” can be pure Java implementing the same contract.

**B. OpenFL native / NDK (Haxe → C++)**

- Same as Rack/VST: reuse `bridge/native` with Android-specific glue.

For a Java-first app, a **Java host bridge** is likely cleaner than forcing the C++ runner.

### 4.5 OpenFL desktop evolution (optional)

OpenFL can remain collapsed for dev builds. For parity with plugin hosts or to fix timer starvation:

- Drive simulation from **`ENTER_FRAME` with measured wall-clock `delta`**, or
- Add an optional **background worker** (native extension or future Haxe threading where safe) that runs the harness and posts snapshots back to the main thread for `*View` redraw.

This is optional polish, not a blocker for other targets.

### 4.6 Summary table

| Target | Simulation thread | UI thread | Audio thread | Bridge technology |
|--------|-------------------|-----------|--------------|-------------------|
| OpenFL desktop (now) | Main | Main | None (`MonitorInstrument`) | None (direct calls) |
| VCV Rack | `ControlThread` | Rack UI | Rack engine | `bridge/native` C++ |
| VST/JUCE | `ControlThread` | JUCE message | `processBlock` | `bridge/native` C++ |
| Web preview | Main | Main | None | None |
| Web + WebAudio | Web Worker | Main | AudioWorklet | JS host bridge |
| Android (Java) | `HandlerThread` | Main | AAudio/Oboe | Java host bridge |
| Android (NDK) | `ControlThread` | Main | Audio callback | `bridge/native` C++ |

---

## 5. Haxe support we could add

Thread creation should stay in host adapters. Haxe should own **types, contracts, and snapshot construction** so C++, JS, and Java adapters do not duplicate field extraction logic.

### 5.1 Shared timing module

Add something like `worldofcake.WocTiming`:

- `LOGICAL_STEP_SECONDS` (e.g. `0.001`)
- Documented goal: **1 wall second ≈ 1 logical second** at default speeds unless the user changes speed params.
- Hosts pass **elapsed wall time** as `delta` where possible, rather than assuming 1000 callbacks per second.

Rack constants in `WocRackTiming.hpp` would align with this; OpenFL `AUDIO_INTERVAL` would reference the Haxe definition.

### 5.2 Command and snapshot types in Haxe

Today `ControlCommand` and snapshot layouts live mainly in `WorldOfCakeBridgeTypes.h`, with harness getters mirroring sequencer fields. Move the **contract** into Haxe:

- `worldofcake.host.ControlCommand` — kind, controlId, value, sequence, coordinates.
- `worldofcake.host.VisualSnapshot` — per-app typedefs or generated structs (or shared builders).
- `worldofcake.host.ControlSnapshot` — CV/event-facing state for audio consumers.

C++/JS/Java adapters serialize or memcpy these layouts at the boundary. Headless Haxe tests can assert snapshot contents without native code.

### 5.3 Snapshot builders on the harness

Extend `*Harness` (or a shared mixin) with explicit methods:

- `captureVisualSnapshot():VisualSnapshot`
- `captureControlSnapshot():ControlSnapshot`

Runners/workers call these instead of open-coded `harness->ballX(i)` loops in C++. The same methods serve JS Worker and Java `HandlerThread` when compiled from Haxe.

### 5.4 Host runtime interface (documentation + optional Haxe trait)

Define a small documented interface, e.g. `IHostRuntime`:

- `enqueueCommand(cmd:ControlCommand)`
- `pump(delta:Float)`
- `getVisualSnapshot():VisualSnapshot`
- `getControlSnapshot():ControlSnapshot` / drain events

OpenFL implements it inline on one thread (today’s `*Main`). Native hosts implement it across threads. No requirement that Haxe implements threading — only that **all hosts expose the same operations**.

### 5.5 Keep view and world host-agnostic

- `*View` continues to render from **either** live sequencer (OpenFL) **or** snapshot DTO (future: main thread reads last Worker snapshot).
- Avoid OpenFL types in harness and sequencer code (already mostly true).

### 5.6 What not to put in Haxe

- `std::thread`, pthread, or platform thread APIs wrapped in Haxe (fragile, non-portable).
- AudioWorklet or Oboe code (host-specific).
- hxcpp `SetTopOfStack` lifecycle (stays in `ControlThread.cpp`).

---

## 6. Open questions

1. **Logical time vs wall time on Rack** — *Decided (2026-10-25):* every host advances models in real time, and apps define speeds per real second (see `architecture.md`, *Time and speed*). Rack previously ran at about 1/17 of real time.

2. **OpenFL as web UI shell** — OpenFL html5 already builds. Is the long-term web plan OpenFL canvas on main + Worker harness, or a separate non-OpenFL renderer?

3. **Android UI** — OpenFL-on-Java vs native Material widgets for store-facing apps; harness/threading contract is the same either way.

4. **Snapshot versioning** — Visual/control snapshots may need generation counters and schema versions (like JSON `"v"` fields) for safe concurrent read on UI/audio threads.

5. **Single Haxe package for bridge types** — Should `bridge/haxe/worldofcake/host/` become a compile target shared by Rack hxml, html5, and Java builds?

---

## 7. Recommended next steps (when we choose to act)

These are suggestions for later work, not commitments:

1. Add `worldofcake.WocTiming` and align OpenFL + Rack constants.
2. Introduce Haxe `ControlCommand` and per-app snapshot types; generate or hand-maintain C struct parity in `WorldOfCakeBridgeTypes.h`.
3. Add `captureVisualSnapshot` / `captureControlSnapshot` to harnesses; refactor one runner (e.g. Gbloink) to use them.
4. Document the host contract in `architecture.md` with a link to this file.
5. When scoping web or Android, spike the **smallest** JS or Java adapter that pumps `TileLandHarness` in a background context and posts snapshots to a stub UI — before investing in WebAudio or Oboe.

---

## 8. Related documents

- `architecture.md` — framework interfaces, OpenFL shell pattern, native host boundary (§11).
- `redundancy.md` — Rack timing policy, `ControlRunnerBase`, harness migration status.
- `Source/worldofcake/README.md` — target platform priorities (VST, Android/Java, Web/JS).
- `consolidate_woc_and_audio.md` — broader multi-target and WebAudio scheduling notes.
- `derivatives/vcvrack/common/WocRackTiming.hpp` — current Rack timing constants.
