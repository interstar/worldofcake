# World of Cake → VCV Rack: port plan

This document is the historical and current plan for porting World of Cake (WoC) sequencers to **VCV Rack 2.x** as **independent native modules**, reusing Haxe algorithmic code via **`haxe` → C++** transpilation. Linux remains important because Rack can be tested here, but Windows Rack builds also exist and recently drove much of the runner cleanup.

The old direct-Haxe Rack bridge is superseded. Current modules should use the shared native runner: a control thread owns the Haxe model, Rack audio/UI code communicates through bounded queues and snapshots, and `Module::process()` consumes prepared native data without entering Haxe.

---

## 1. Goals and non-goals

### Goals

- One **Rack plugin project per sequencer app** (e.g. Gbloink, Zewp, …), each exposing **one or more module models** if needed later—not a single “mega” module bundling every app.
- **Reuse WoC core logic** (sequencer state, time stepping, event generation) from the existing `Source/` tree where it is **pure Haxe** and free of OpenFL/Lime APIs.
- **Full interactive surfaces**: mouse-driven interaction is essential; Rack UI must support the same class of gestures as the OpenFL apps (hit tests, drags, etc.), mapped into the same conceptual control paths as `IControlPanel` (uids + typed payloads).
- **Electrical outputs** in Rack terms: **gates/triggers** and **control voltages** (not MIDI inside Rack). Per-module documentation defines how WoC `Event` streams (or equivalent) map to each output jack.
- **Panels** built with Rack’s normal workflow: **SVG** (Inkscape, `components` layer) for layout and branding; **variable width (HP)** so modules with more CV/gate outputs can be wider.
- **End state**: a **single shell script** (or small script suite) that, from a clean dev tree, **transpiles Haxe → C++**, builds the shared runner-backed Rack module against **Rack SDK 2.x**, and produces installable **`.vcvplugin`** / build artifacts. This now exists for the current Linux module set through `build_module.sh` and `build_all.sh`, with Windows support in `build-rack-windows.ps1`.

### Non-goals (initially)

- macOS builds and CI. Windows builds exist and should be kept working, but they are not the only source of truth.
- Polyphonic Rack outputs (unless an app clearly needs it later); default is **mono CV/gate per jack**, documented per module.
- Shipping OpenFL/Lime inside Rack.

---

## 2. VCV Rack context (reference)

- **Rack 2.x** plugin API: `Module::process(const ProcessArgs& args)` on the **audio thread**; `params` / `inputs` / `outputs` / `lights`; widget tree for UI on the **UI thread**.
- **Panels**: SVG per module, **height 128.5 mm**, width **multiple of 5.08 mm (1 HP)**; `components` layer with labeled circles (param/input/output/light colors per SDK conventions).
- **Voltage norms** (from project notes): audio often **±5 V**, CV **0–10 V** or **±5 V**, triggers **10 V** for **~1 ms** (exact gate/trigger shaping to be chosen per module and documented).

Local SDK path in this repo (Linux x64): `derivatives/Rack-SDK-2.6.6-lin-x64/Rack-SDK/`. The Gbloink plugin Makefile defaults to a **relative** `RACK_DIR` with no spaces (`../../Rack-SDK-…` from `derivatives/vcvrack/gbloink/`) so GNU Make `include` and the linker `-L` line work even when the checkout path contains spaces.

---

## 3. Architecture: WoC concepts mapped to Rack

### 3.1 Separation of concerns (unchanged from WoC)

| WoC concept | Rack responsibility |
|-------------|---------------------|
| `ISequencer` — time advance, event queue, transport (`pause`/`resume`/`reset`), `exportStateJson`/`importStateJson` | Shared native runner drives stepping on a control thread; **`dataToJson`/`dataFromJson`** persist `stateJson` through a mailbox and then mirror host params from snapshots where needed. |
| `IControlPanel` — user commands, uids | **ModuleWidget** + custom widgets: map mouse/params to runner commands (e.g. `newValue(uid, value)`, local clicks with **panel-local or widget-local** coordinates). |
| `IControlPanelView` — redraw hints | Rack: invalidate regions or set dirty flags; custom widget `draw()` / layer updates. |
| OpenFL `*View` / `worldofcake/ui/*` | **Not transpiled**; reimplemented with **Rack widgets** + optional **NanoVG**-style drawing for playfields. |

Dependency direction stays **one-way**: core does not depend on Rack; a thin **adapter** (C++ and/or small Haxe extern layer) connects Rack to the core.

### 3.2 Many independent modules

- Each app gets its **own** plugin directory under `derivatives/vcvrack/` (exact naming TBD, e.g. `derivatives/vcvrack/gbloink/`, `derivatives/vcvrack/zewp/`).
- **`plugin.json`**: unique **slug** per plugin; **version** `2.x.y` matching Rack major **2**.
- **Shared code**: if multiple modules need the same helper (e.g. event→voltage mapping, Schmitt trigger, time accumulation), introduce a **small static library or shared `src/common/`** in a **separate directory** (e.g. `derivatives/vcvrack/common/` or `derivatives/vcvrack/libworldofcake-bridge/`) and link from each plugin—**no forced monolith**.

### 3.3 Outputs and panel size

- Each module declares **`NUM_OUTPUTS`** (and inputs for future: clock, reset, etc.) to match **physical jacks** drawn on its SVG.
- **Wider HP** when more outputs or more controls are required; **per-module** `res/<slug>.svg` reflects that width.
- Maintain a **per-module mapping table** (see §8) listing each jack, label, voltage range, and semantic (gate vs CV).

---

## 4. Haxe: what is transpiled and how

### 4.1 In scope for `target cpp`

- **Sequencer logic**: classes that implement or support `ISequencer`, domain models, math/utils **without** OpenFL/Lime imports.
- **Shared types**: e.g. `worldofcake.Event`, enums/constants for event kinds, as long as the cpp target and used APIs are supported.
- **Entry surface**: a **minimal, cpp-safe harness** per app under `bridge/haxe/worldofcake/bridge/`. Native C++ runners own threading, queues, snapshots, and Rack-facing state.

### 4.2 Out of scope (stay in C++ or reference-only)

- OpenFL `Main`, `World`, display list rendering, `worldofcake/ui/*` OpenFL components.
- Lime application loop.

### 4.3 Greenfield constraints

- No existing `cpp` hxml in WoC is assumed. The first milestones are: **smallest possible Haxe class** compiling to cpp, linked into a **minimal Rack module**, then grow to **real sequencer** types and **strip/replace** any disallowed dependencies.

### 4.4 Generated code layout (convention)

- Transpiler output goes under each plugin or shared lib, e.g. `src/gen/haxe/` or `src/gen/cpp/` (exact choice fixed in implementation), **gitignored** or committed per project policy—default **gitignore** with reproducible regeneration via script.

---

## 5. Time stepping: control runner

- The shared `ControlThread` advances sequencer time at a declared control cadence.
- `Module::process()` runs at audio rate, enqueues host commands if needed, and consumes prepared events or control snapshots.
- Document chosen cadence per module; ensure **deterministic** behaviour and **no drift** beyond acceptable error for musical use.
- **Future**: optional sample-accurate scheduling for note/gate edges if an app needs it.

---

## 6. Interaction: full mouse-driven surface

- **ModuleWidget** hosts:
  - **Rack param widgets** for knobs/switches aligned to SVG `components`.
  - A **custom widget** (or hierarchy) for the **play area**: implements `onButton`, `onDragMove`, `onHoverKey` (as appropriate), converts to **local coordinates** consistent with WoC’s expectations, and calls into the **same control surface** the Haxe `IControlPanel` would have used.
- Reuse **WoC’s mental model** (uids, local points); **reimplement** coordinate pipelines in C++ where the OpenFL `CoordinateMapper` stack is not available, **mirroring** behavior from `worldofcake/ui` and app `Layout` constants.
- **Threading**: Rack separates audio and UI threads. Sequencer mutation from UI must be queued to the runner; audio thread reads prepared native data. Do not call Haxe from audio or drawing code.

---

## 7. Build and automation pipeline (target end state)

1. **Haxe**: `haxe` (version-pinned) builds **cpp** from an app-specific `.hxml` (and shared `-cp` to `Source/`).
2. **Install generated sources** into the plugin’s `src/gen/` (copy or `haxe` `-cpp` out dir).
3. **Rack plugin**: `export RACK_DIR=...` → `make clean` (optional) → `make` / `make install` / `make dist` as needed.
4. **One top-level script** under `derivatives/vcvrack/` (e.g. `build_all.sh` or `build_module.sh <name>`) orchestrates the above for **Linux**.

CI and packaging can be added later.

---

## 8. Per-module output documentation (required artifact)

For **each** sequencer module, maintain a small file (e.g. `OUTPUTS.md` or a machine-readable `outputs.json`) in that plugin directory:

- Module slug and human name.
- List of **outputs** in **jack order** (left-to-right or as drawn): name, **gate vs CV**, voltage range, scaling law (e.g. MIDI note → 1 V/oct from a reference, or CC 0–127 → 0–10 V).
- Mapping from **WoC event fields** (`Event.type`, `data1`–`data3`) to outputs.
- Any **trigger width** / **gate high** voltage assumptions.

This file is the contract for panel design (number of blue circles) and for QA in Rack.

---

## 9. Phased implementation checklist

1. ~~**Toolchain proof**: Haxe → cpp linked into a Rack module; `make` on Linux (`derivatives/vcvrack/gbloink/`).~~
2. ~~**Bridge**: old direct-Haxe facade + real `gbloink.Gbloink` from `Source/`; `advanceTime`, event peek/pop, play-area + slider hooks.~~
3. ~~**Threading**: historical mutex/direct-Haxe prototype. Superseded by the shared control runner.~~
4. **Pilot — Gbloink**: runner-backed interactive playfield + pitch/gate outputs + `OUTPUTS.md`; panel SVG widened (48 HP). Remaining work is polish, optional inputs, and tighter generated layout parity.
5. ~~**Script**: `derivatives/vcvrack/build_module.sh <dir>` (passes through to `make`).~~
6. **Repeat** for other apps; factor shared C++/Haxe into **`derivatives/vcvrack/<shared>/`** only when duplication hurts.

---

## 10. Open questions (to resolve during implementation)

- **Exact Haxe version and std** quirks for cpp on Linux (pin in `.hxml` or `flake`/`nix`/docs).
- **Host calibration**: e.g. Rack control period vs OpenFL’s 1 ms timer, or optional setup arguments on the Haxe bridge—**not** `#if cpp` forks in shared `Source/` sequencers.
- **Rack layout generation** from Layla plus EDN variant files, including sockets and Rack-specific control idioms.
- **Gate semantics** per app: trigger pulse vs held gate, retrigger rules.

---

## 11. Related documents

- `derivatives/vcvrack/vcvrack.md` — Rack plugin authoring notes (SVG, `process`, voltages).
- `Source/worldofcake/README.md`, `architecture.md` — WoC core/view/control split.
