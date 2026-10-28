# Guide: Adapting a World of Cake app to VCV Rack

> **Start with [`WRITING_WOC_APPS.md`](WRITING_WOC_APPS.md)**, which defines how Rack panels are described (`apps/<app>/rack.edn` + `rack.layla`), generated (SVG, layout and output headers), and how panel text is made (§9.3). This guide covers Rack C++ and build pitfalls only; where its panel advice differs, `WRITING_WOC_APPS.md` wins.

This is a **practical companion** to the Rack plan and the consolidation documents. It captures the current runner-based Rack architecture. Older Rack ports called Haxe directly from `Module::process()` under a mutex; that approach is now historical and should not be copied.

**Reference implementations:** all six modules under `derivatives/vcvrack/` — `gbloink`, `zewp`, `kdiagram`, `tileland`, `timeslider`, `goldenpond` (each: Makefile, `src/`, `haxe/`, `res/`, `plugin.json`).

---

## 1. What stays in Haxe vs what you rewrite

| Keep in `Source/` (platform-independent) | Implement in Rack (C++ / widgets) |
|----------------------------------------|-------------------------------------|
| Sequencer state, `advanceTime`, event queue | Shared native control runner, Rack output adapter, jack voltages |
| `IControlPanel` / `ISequencerControl` entry points (`mouseDown`, `newValue`, …) | Rack UI maps mouse/params to bounded runner commands with **local coordinates** matching the OpenFL “world” space |
| `worldofcake.Event` and note/CC semantics | Drain events in `process()` → gates, 1 V/oct CV, etc. |
| Domain types (`LocalPoint`, `LocalRect`, scales, …) | Panel SVG, NanoVG playfield, screws, params |

**Rule:** no `#if cpp` hacks in shared WoC code to “fix physics for Rack”. Behaviour belongs in the Haxe model and shared runner; host-specific code adapts controls, output voltages, scheduling, and panel presentation.

---

## 2. Repo layout for a new module

Create a sibling of Gbloink, e.g. `derivatives/vcvrack/zewp/`:

- `Makefile` — Rack build + hxcpp link (see §4).
- `plugin.json` — unique plugin **slug** and module entry.
- `src/` — only Rack glue (`plugin.cpp`, `YourModule.cpp`, …).
- `haxe/` — small hxml that compiles the shared `worldofcake.bridge.*Harness` for the app.
- `generated/<Slug>.svg` — the panel, **generated** from `apps/<app>/rack.edn` + `rack.layla`; `res/` only for extra assets.
- hxcpp output is written under `build/vcvrack/<module>/<platform>/`; **do not hand-edit** generated C++; `clean` must delete the object directory when the Haxe graph changes.

Hxml should include **`-cp`** to the shared tree, e.g. `-cp ../../../Source`, and to `bridge/haxe`. It should compile the app's harness class. Legacy direct-Haxe facades have been removed; new work should extend the harness path instead.

---

## 3. Haxe bridge and native runner

Each Rack module should use the shared runner boundary:

- Haxe harness class under `bridge/haxe/worldofcake/bridge/`.
- Native app runner under `bridge/native/*ControlRunner.*`.
- Shared `ControlThread`, bounded queues, prepared events, control snapshots, visual snapshots, and persistence mailboxes.
- Rack `process()` enqueues host commands and consumes prepared native data. It does not enter Haxe.
- Rack playfield widgets enqueue GUI commands and draw from copied visual snapshots. They do not inspect live Haxe objects.

When you add new core features, extend the Haxe model and harness first, then wire Rack params or widgets to runner commands.

**`ISequencer` transport:** Prefer exposing `pause()`, `resume()`, and `reset()` through the harness/runner contract rather than ad-hoc target-only state. That matches the shared WoC contract and keeps OpenFL, Rack, and VST on the same semantics.

**`ISequencer` persistence:** Implement `exportStateJson()` / `importStateJson()` on the sequencer; the Rack module saves one string (e.g. under a `stateJson` key in `dataToJson`) and restores it in `dataFromJson`. The JSON shape is **app-defined** (include `"v"` when you evolve it). After `importStateJson`, align any **host-side** state with the model: e.g. reset your event-scheduler clock to `getLogicalTime()` (or equivalent from your API), zero physics catch-up accumulators if needed, and **push loaded flags into Rack `Param` widgets** (pause latch, scale selector) so the next `syncPanelToHaxeLocked()` does not clobber Haxe. **Gbloink** also keeps legacy load of `blocksJson` for older patches; new saves use `stateJson` (balls, pause, scale, logical time, blocks).

---

## 4. Makefile essentials (Linux and Windows)

On Windows, use `derivatives/vcvrack/build-rack-windows.ps1`. It invokes Haxe from PowerShell, where the installed haxelib configuration is available, and invokes Rack's Makefile through the MSYS2 MinGW64 shell. Do not try to compile Rack plugins directly from ordinary PowerShell with Microsoft C++: the official Rack Windows SDK build uses MSYS2/MinGW.

The installed Rack host is currently 2.6.4, so Windows builds use the matching `Rack-SDK-2.6.4-win-x64`. Linux remains on the historical 2.6.6 SDK. Makefiles select the SDK, platform defines, and hxcpp object directory (`mingw64` or `linux64`) by host OS.

GCC 16 requires the local hxcpp 4.3.2 compatibility adjustment documented in `docs/WINDOWS_DEVELOPMENT.md`.

**`RACK_DIR`** must be a path **without spaces** (GNU Make `include` and linker `-L` break otherwise). From `derivatives/vcvrack/<app>/`, use a **relative** path like `../../Rack-SDK-2.6.6-lin-x64/Rack-SDK`.

**`HXCPP`:** `haxelib path hxcpp` prints multiple lines—use **line 1 only** as the include root (e.g. `sed -n '1p'`).

**Codegen before compile:** the default target should run `haxe …hxml` (or a `codegen` phony) **before** the nested `make` that links `plugin.so`, so `native/include` exists.

**Link every hxcpp object:** after `plugin.mk`, the real link rule must depend on **all** `native/obj/linux64/*.o`, including **`___main__.o`** (defines `__hxcpp_lib_main`). Plain `OBJECTS +=` after `compile.mk` often **does not** update link prerequisites—use a pattern like `$(TARGET): $(HXCPP_LINK_OBJS)` with a shell `find native/obj/linux64 -name '*.o'` (use **relative** paths from the plugin dir if the checkout path contains spaces).

**`clean`:** remove `native/obj` as well as Rack’s `build/` and `dist/`, or stale `.o` will cause missing symbols or duplicate `__main__` confusion.

**Wrapper:** `derivatives/vcvrack/build_module.sh <dir>` and `build_all.sh` exist to run `make` from the right place.

---

## 5. C++: threads, hxcpp, and the audio callback

hxcpp’s GC expects each OS thread that enters Haxe to be set up correctly. In the current architecture, that should be the control thread, not Rack audio or drawing code.

- The control thread owns the Haxe object and attaches to hxcpp once.
- Rack audio and UI code communicate with the runner through native queues, snapshots, and persistence mailboxes.
- `process()` must not call Haxe, allocate Haxe objects, invoke hxcpp GC, take a Haxe-owner mutex, or render.

The older mutex/direct-Haxe pattern commonly produced crashes or stalls under interaction. Treat it as historical reference only.

---

## 6. `process()` vs `step()` — push params on the audio path

Rack 2 runs **`Module::process(const ProcessArgs&)`** on the **audio thread**. If you override `process()` **without** calling `Module::process()` / `step()`, then any logic you put only in **`step()`** may **never run**.

**Lesson:** sync knobs/switches from `process()` by enqueueing runner commands or updating a host-side mailbox. Do not move that work to `step()` only, and do not call Haxe directly from `process()`.

---

## 7. Time stepping and “how fast” the sim feels

WoC’s `moveBall`-style logic usually runs **once per `advanceTime(delta)`** call; `delta` often only advances **event timestamps**, not “how far” things move per call.

- **OpenFL** may call `advanceTime` on a ~1 ms timer.
- **Rack:** the shared `ControlThread` advances the model at its declared control cadence. `process()` consumes prepared events/snapshots at audio rate.

Current delta-based models should not rely on changing call frequency as a musical speed control. If a Rack panel has an overall-speed control, wire it deliberately to model parameters or a documented host-side scale. Remove or relabel old dead "sim rate" controls.

---

## 8. Events → jacks (CV / gate)

WoC does **not** define Eurorack jacks; it defines **`Event`** (`timestamp`, `type`, `data1`…`data3`). De facto conventions used in the repo:

- **`type == 1`** — CC-style: `data1` channel, `data2` controller, `data3` value (see Zewp).
- **Other `type` (e.g. 0)** — note-style: `data1` channel, `data2` MIDI note, `data3` velocity (see `MonitorInstrument` and Gbloink).

Rack should **peek / pop** the queue in `process()` and set outputs:

- **Pitch:** \((\mathrm{note} - 60) / 12\) V for 1 V/oct (middle C = 0 V).
- **Gate/trigger:** Gbloink uses a **short pulse** (`dsp::PulseGenerator`, ~1 ms)—not a sustained gate—unless you change the design.

Use **`data1`** as a **voice index** if you need poly outputs (one gate + pitch per ball/channel).

Document the mapping in a small `OUTPUTS.md` next to the module.

---

## 9. Panel and interaction

- **SVG:** generated, never hand-drawn: Rack height **128.5 mm**, width in HP, sockets at generated positions (the hidden `components` layer is generated too). Static text is flattened to paths by the generator; never draw static text in C++ (`WRITING_WOC_APPS.md` §9.3).
- **Playfield:** often an `OpaqueWidget` child with **NanoVG** drawing; map mouse to the **same local width/height** the Haxe world uses (Gbloink: 700×500).
- **Clip drawing** with `nvgScissor` so balls/blocks don’t paint outside the widget; optionally clamp block bounds in Haxe to the play rectangle.
- **Screws:** `ScrewSilver` at standard positions from the SDK helper pattern.
- **Controls:** `componentlibrary.hpp` gives knobs and switches; there is **no HTML dropdown**—use snap knobs, `CKSSThree`, or **context menus** (`helpers.hpp` / `createIndexSubmenuItem`) for long option lists.

---

## 10. Pitfalls checklist

- [ ] **`RACK_DIR`** path has **no spaces** (or use relative SDK path).
- [ ] **Full hxcpp `.o` set** linked, including **`___main__.o`**.
- [ ] **`plugin.cpp`** calls `__hxcpp_lib_main()` once before any Haxe use.
- [ ] **No direct Haxe calls** from `process()` or Rack drawing code.
- [ ] **Param sync** runs on **`process()`** by queue/mailbox, not only `step()`.
- [ ] **No OpenFL** imports in the transpiled Haxe surface.
- [ ] **`clean`** clears **`native/obj`** when Haxe exports change.
- [ ] **Event routing** uses the right `data1` / `data2` fields for your app.
- [ ] **Snapshot-only apps:** if Rack publishes state snapshots instead of consuming Haxe `Event` objects, add an explicit `discardPendingEvents()` call after each model step; never allow an unconsumed event array to grow indefinitely.
- [ ] **Event/queue lifecycle:** every generated-event stream and every bounded SPSC queue has a defined consumer, bounded drain/coalescing policy, observable depth/drop counters, and an explicit safe behavior under pressure; no producer may leave a queue permanently clogged.
- [ ] **Patch load:** after `importStateJson`, sync host logical time and any mirrored params (pause, scale, …) with Haxe.
- [ ] **Manifest ABI:** `plugin.json` uses a `2.x.y` version for Rack 2; do not use `1.x.y`.
- [ ] **Manifest identity:** package directory/slug, manifest slug, module slug, and C++ `createModel` slug agree exactly.
- [ ] **Install verification:** inspect the installed package and fresh Rack log for `Loaded plugin`; a copied package or stale extracted directory is not proof of loading.

---

## 11. Build noise

A full build may emit **many GCC warnings** from **hxcpp headers** (`-Wreorder`, `-Wsuggest-override`, etc.). That is **normal** and does not indicate bugs in `Source/` WoC logic. Warnings in **your** `src/*.cpp` glue are worth fixing.

---

## 12. Next app: minimal task order

1. Start from the current runner-based module shape, not the old direct-Haxe facade shape.
2. Add or extend the app harness under `bridge/haxe/worldofcake/bridge/`.
3. Add the app runner under `bridge/native/`, sharing `ControlThread` and queue types.
4. Hxml `-cp` to `Source/` and `bridge/haxe`; `haxe` → verify `native/` generated.
5. Minimal `Module` that starts the runner and consumes snapshots/events; then add outputs, then full UI.
6. Document jack semantics (`OUTPUTS.md`) and install path for the `.vcvplugin`.

When two modules share the same C++ helpers (event→voltage, thread helpers), extract **`derivatives/vcvrack/common/`** and link both plugins against it—[`PLAN.md`](../derivatives/vcvrack/PLAN.md) §3.2.
