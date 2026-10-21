# VCV Rack modules — comparison to Gbloink

Reviewed 28 August 2026. No code was changed. Gbloink (`derivatives/vcvrack/gbloink/`) is treated as the working reference. The other current Rack plugins are TimeSlider, TileLand, and K-Diagram. There is **no Zewp Rack module**.

This is a snapshot of the **current** Rack shells, not the older mutex-in-`process()` design described in `GUIDE_ADAPTING_WOC_TO_VCV_RACK.md` and the Gbloink README. Those docs are behind the code.

---

## What all four already share (the good news)

The modules have largely converged on the intended native boundary:

- Each plugin compiles a `worldofcake.bridge.*Harness` from `bridge/haxe/` (instance-owned Haxe model).
- Each links `bridge/native/*ControlRunner.cpp` plus shared `ControlThread.cpp`.
- `process()` does **not** enter Haxe. It enqueues host commands and consumes prepared events and/or control snapshots.
- Playfield `draw()` reads `latestVisualSnapshot()` (mutex copy), not live Haxe fields.
- Persistence goes through a control-thread mailbox (`exportStateJson` / `importStateJson`), not a UI/audio-thread hxcpp call.
- Makefiles, `plugin.cpp` hxcpp boot, Windows vs Linux SDK selection, and `panel_title` injection are the same shape.

So the old “audio thread + mutex + `SetTopOfStack`” pattern is **not** what Gbloink currently does, and the others already followed that migration. Remaining differences are polish, completeness, and copy-paste.

---

## A. Gbloink does this; the others often do not

### 1. After patch load, push Haxe state back into Rack params

Gbloink `dataFromJson` imports JSON, then sets pause / scale / edge-notes knobs from the visual snapshot and updates `lastPause` / `lastScaleIdx` / `lastEdgeNotes`. That stops the next `process()` from seeing `lastX == -1` and **overwriting** the loaded model with stale or default knob values.

TimeSlider, TileLand, and K-Diagram only call `runner->importStateJson(...)`. They never restore pause (or speeds, channel, selected cursor) onto widgets. Combined with `lastPause = -1` (and similar sentinels), the first audio block after load sends the Rack-saved params into Haxe and can clobber JSON.

Gbloink also still loads legacy `blocksJson`. The others have no equivalent fallback (probably fine if they never shipped that format).

**Also missing on import in the shared runners:** Gbloink’s control-thread import updates `logicalTime`, drains events, and republishes the visual snapshot. TimeSlider / TileLand / K-Diagram `StatePersistence` import only calls `harness->importStateJson` and does not refresh logical time or snapshots. UI and CV can sit on a pre-load frame until the next tick.

### 2. Visual snapshots are complete enough to draw without Haxe

Gbloink’s snapshot includes balls (position, radius, colour), **all blocks**, pause, edge-notes, and scale index. Drawing never calls Haxe.

The others already publish playfield geometry (tracks, tiles, graph). They do **not** publish pause (or other mirrored params) on the visual snapshot, which is why (1) is harder for them. TimeSlider’s “visual” snapshot is the same struct as the CV snapshot — no pause flag.

### 3. The “sim rate / overall speed” knob actually does something

Gbloink’s `SIM_RATE_PARAM` is labelled **Overall speed**. It does not change the control-thread period (that is a fixed 1 ms). It **multiplies** the three ball-speed values before they are sent as uids 10–12. That is a real, documented host-side feel control now that motion is delta-based.

TimeSlider, TileLand, and K-Diagram all still have a **Display rate** / **Sim rate** knob on the panel. **`process()` never reads it.** The runner is always `start(0.001)`. The TimeSlider README still claims it is a physics tick period like old Gbloink. Dead control, leftover from the pre-runner era.

### 4. Playfield mouse handling

Gbloink: `Widget::onButton` first, then left-press only if `!e.isConsumed()`, then consume.

TimeSlider and K-Diagram: same idea (K-Diagram maps to **−1…1** local graph space, which is correct for that app).

TileLand: does **not** call `Widget::onButton` first, does **not** check `isConsumed()`, and consumes every left-press. Easier to steal clicks from other widgets.

### 5. Panel chrome

Gbloink places **four** `ScrewSilver` (corners). The others place **two** (top only).

Gbloink has a context-menu duplicate of wall-notes. Optional; the others have no extra menu.

Gbloink’s `configOutput` names include colour and 1 V/oct. K-Diagram configures every jack as generic `"Cursor N output"`.

### 6. Event drain safety and voice mapping

Gbloink pops prepared note events with a **256-event cap**, maps `event.channel - 1` to ball 0..2, writes 1 V/oct, and runs `PulseGenerator` with `args.sampleTime` (~1 ms, 10 V).

K-Diagram also caps pops and uses pulses, but:

- `drainEvents` **forces `e.type = 0`**, ignoring `eventType()`.
- Voice index is `e.channel - (lastChannel + 1)`. Until the first `process()` syncs `lastChannel` from the knob (`lastChannel` starts at −1), the first arrivals can hit the wrong row.

TimeSlider and TileLand have no discrete events in Rack (continuous snapshots only). That matches the native contract. TileLand’s `OUTPUTS.md` still describes draining CC **events**; the C++ path does not.

### 7. Host command enqueue is slightly more careful

Gbloink uses `guiSequence.fetch_add` and records command-queue high-water marks in the runner.

K-Diagram’s runner increments drop counters on failed push but **does not** track high-water. Same enqueue pattern otherwise.

### 8. Readable module C++ vs compressed one-liners

Gbloink `Gbloink.cpp` / `Gbloink.hpp` are formatted and commented. TimeSlider, TileLand, and K-Diagram pack constructors, `process()`, and widgets onto very long lines. Same ideas, much harder to diff against Gbloink. Persistence is split into tiny `*Persistence.cpp` files that Gbloink inlines.

### 9. Docs vs code (Gbloink is not innocent)

Gbloink is the best **implementation** reference and a weak **document** reference:

| File | What it still says | What the code does |
|------|--------------------|--------------------|
| `gbloink/README.md` | 5 ms `controlPeriodS`, `attachThisThreadToHxcpp()`, mutex, `vcvrack.gbloink` | 1 ms `ControlThread`, no Haxe in `process()`, `GbloinkHarness` |
| `gbloink/OUTPUTS.md` | One pitch + one gate; `data1` unused | Six jacks (gate+pitch × 3); channel selects ball |
| `GUIDE_ADAPTING_WOC_TO_VCV_RACK.md` | Mutex + `SetTopOfStack` on every Haxe call from `process()` | Obsolete for all four modules |
| `timeslider/README.md` | Described the old direct-Haxe facade; sim rate = tick period | Compiles `TimeSliderHarness`; sim-rate knob unused |
| `timeslider/plugin.json` | “three lagging sliders” | Four tracks / four CV jacks |
| `tileland/OUTPUTS.md` | Drain CC events from the queue | `popControlSnapshot` only |

### 10. Duplicate / leftover files

- `derivatives/vcvrack/tileland/src/TileLandControlRunner.h` is a **copy** of `bridge/native/TileLandControlRunner.h`. Gbloink includes the bridge header only. The copy will drift.
- Legacy direct-Haxe facade files have been removed: hxml now compiles `worldofcake.bridge.*Harness`.
- Static `bridge/haxe/.../*HarnessApi.hx` bridge files and `WorldOfCakeHarnessExports` have been removed. New native work should use instance `*Harness.hx` classes owned by native runners.

### 11. No Zewp plugin

`build_all.sh` is `gbloink timeslider kdiagram tileland`. Zewp has a native runner and snapshots but no `derivatives/vcvrack/zewp/`. That is a product gap, not a Gbloink-vs-sibling inconsistency.

---

## B. Redundancy — what could be shared

### Already shared (do not re-copy)

| Piece | Where |
|--------|--------|
| Control thread, SPSC queues, command/event/snapshot POD types | `bridge/native/` |
| Persistence mailbox | `bridge/native/StatePersistence.h` (TimeSlider, TileLand, K-Diagram) |
| Per-app runners and Haxe harnesses | `bridge/native/*ControlRunner.*`, `bridge/haxe/worldofcake/bridge/*Harness.hx` |
| Sequencer behaviour | `Source/<app>/` |

Gbloink’s runner **does not use** `StatePersistence.h`. It inlines the same mailbox with extra stage/timeout telemetry. The others already refactored the generic part. The next cleanup is: **Gbloink should call `StatePersistence`**, and **import should keep Gbloink’s post-load refresh** (logical time, drain, republish). Do not fork a third mailbox.

### Shared C++ for all Rack modules (`derivatives/vcvrack/common/` or `bridge/native/rack/`)

These recur almost verbatim. They are Rack-shaped, not Haxe-shaped.

1. **Plugin boot** — `ensureHaxeBoot()` + `__hxcpp_lib_main()` + `init()`. Four near-identical `plugin.cpp` files.
2. **Host command helpers** — `playAreaClick` → GUI SPSC; `setValue(uid, v)` → host SPSC; pause/reset edge detection (`lastPause`, rising-edge reset button). Gbloink’s `syncPanelToRunner` / `enqueueHostValue` vs TimeSlider’s same functions vs TileLand/K-Diagram `send()`.
3. **Voltage mapping** — MIDI 0..127 → 0..10 V; MIDI note → 1 V/oct `(note - 60) / 12`; ~1 ms 10 V `PulseGenerator`. TimeSlider and TileLand duplicate `cv()`; Gbloink and K-Diagram duplicate pulse logic.
4. **Playfield widget skeleton** — dark fill, `nvgScissor`, mouse → local coordinates (`x/w * localW`). App drawing (balls, tiles, graph, tracks) stays per module. K-Diagram’s −1…1 mapping is a second helper, not a reason to skip the skeleton.
5. **Panel furniture** — four screws, LED reset + VCVLatch pause, optional unused-sim-rate removal.
6. **Makefile fragment** — four Makefiles differ only in app name, hxml, SVG, and which `*ControlRunner.cpp` to compile. A shared `rack-plugin.mk` would remove a real maintenance hazard (Windows pthread flags, hxcpp obj dir, codegen-before-link).
7. **`dataToJson` / `dataFromJson`** — three identical Persistence.cpp files plus Gbloink’s slightly richer version. One helper: save `stateJson`; load it; then a **module callback** to mirror params from snapshot.

These should **not** go into OpenFL/`Source/worldofcake/ui`. They depend on Rack’s `Module`, NanoVG, jansson, and `dsp::PulseGenerator`.

### Shared C++ already in `bridge/native` that the runners still duplicate

The five `*ControlRunner.cpp` files repeat:

- enqueue GUI/host + drop counters (+ high-water, except K-Diagram);
- `pump`: create model, service persistence, apply commands, `advanceTime`, publish;
- `start`/`stop` wiring to `ControlThread` setup/teardown;
- `createModel` / `destroyModel` on the control thread (this part is **correct** and should stay the shared lifecycle).

A small `ControlRunnerBase` (or a template over harness type) is justified **now that four Rack modules plus the headless harness use it**. App-specific pieces: `applyCommand`, snapshot capture, event drain. Resist putting TileLand’s `discardPendingEvents` into the base.

Transport uid convention: Gbloink / TimeSlider / TileLand use **20 = reset, 21 = pause**. K-Diagram uses **40 / 41** because 20 is base channel. A shared Rack helper can still use “reset/pause param widgets”; mapping to uids stays per app. Optionally reserve a small uid band on `IControlPanel` for transport so hosts do not invent 40/41.

### Shared Haxe (generic codebase)

Most Rack C++ should **not** move into Haxe. What *is* generic:

1. **Harness façade pattern** — `advanceTime`, `click` → `mouseDown(PLAY_AREA_UID, LocalPoint)`, `reset`, `setPaused`, JSON, `logicalTime`, event peek/pop. Four classes copy this. A thin `SequencerHarness<T>` or a small `IHarness` in `bridge/haxe` would shrink glue. Visual getters stay per app (or become snapshot builders in Haxe, still app-specific).
2. **Transport on `ISequencer`** — already there. Rack should keep calling `pause`/`resume`/`reset` rather than magic uids only some apps know. GbloinkHarness already has `setPaused`/`reset`; TimeSlider/TileLand/K-Diagram do too; C++ still funnels them through `setValue(20/21)`. Either is fine if **all** apps agree.
3. **Do not** put 1 V/oct, 0–10 V, or PulseGenerator into Haxe. Those are Rack (and later JUCE) output adapters. The Haxe contract is notes, 0..127-style controls, or normalized snapshots.
4. **Do not** share NanoVG drawing through Haxe. Playfields stay handwritten per target, as in the consolidation plan.

The old per-plugin direct-Haxe facades are gone. New work should extend `*Harness.hx` only.

---

## Suggested priority (when Rack is in scope again)

Not Stage 3 work. When bringing Rack back in line with Gbloink:

1. **Behavioural parity (cheap, user-visible)**  
   Wire or remove the dead sim-rate knobs. Make TileLand clicks respect `isConsumed`. Cap or document snapshot drain.

2. **One persistence path**  
   Complete: all current Rack modules use `StatePersistence`, shared `stateJson` wrapping, runner-side post-import snapshot refresh, and Rack-side param mirroring after `dataFromJson`.

3. **Delete duplicates**  
   Static `HarnessApi` bridge files and the obsolete standalone bridge build are removed. Remaining cleanup is stale historical prose in older notes and any target-specific duplicate UI drawing.

4. **Extract `derivatives/vcvrack/common/`**  
   Boot, screws, voltage helpers, playfield base, Makefile include. Keep per-app `process()` output wiring and NanoVG drawing.

5. **Consider a runner base class** after TimeSlider Layla, not before — four Rack copies plus the headless harness are enough evidence.

6. **Zewp** as the first module generated from the common Rack shell rather than cloned from a minified sibling.

---

## Per-module scorecard

| Topic | Gbloink | TimeSlider | TileLand | K-Diagram |
|--------|---------|------------|----------|-----------|
| Haxe in `process()` | No (runner) | No | No | No |
| Draw from snapshot | Yes, full blocks | Yes, tracks | Yes, grid | Yes, graph |
| Persistence mailbox | Yes (custom) | Yes (`StatePersistence`) | Yes | Yes |
| Params restored from JSON | Yes | No | No | No |
| Sim-rate knob live | Yes (speed ×) | Dead | Dead | Dead |
| Reset / pause | uids 20/21 | 20/21 | 20/21 | 40/41 |
| Discrete events → jacks | Notes → gate+1V/oct ×3 | — | — | Arrivals → gate; S&H in C++ |
| Continuous CV from snapshot | — | 4 × 0–10 V | 6 × 0–10 V | 6 × 0–10 V + S&H |
| Mouse consume protocol | Reference | OK | Weaker | OK (−1…1) |
| Screws | 4 | 2 | 2 | 2 |
| Docs match code | Partial | No | Partial | Closer |
| Zewp | — | — | — | — |

The architectural win (no Haxe on the audio thread) is already in all four. Gbloink is ahead on **load/save mirroring**, **snapshot completeness for UI state**, **a live overall-speed control**, and **maintainable C++**. The others are a compressed port of the same runner with leftover knobs and docs from the mutex era.
