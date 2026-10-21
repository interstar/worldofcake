# WorldOfCake-Gbloink (VCV Rack 2, Linux)

Rack shell around the real **`gbloink.Gbloink`** sequencer from `Source/` (Haxe → hxcpp), with:

- **Play area** (click to add/remove blocks; balls bounce; NanoVG preview).
- **Three speed knobs** (same semantics as WoC uids 10–12).
- **Pitch** (1 V/oct, note 60 → 0 V) and **Gate** (~1 ms, 10 V) outputs from note events (`Event.type == 0`).

See **`OUTPUTS.md`** for the voltage contract.

## Requirements

- Rack **2.x** SDK at `../../Rack-SDK-2.6.6-lin-x64/Rack-SDK` (relative to this directory), or override `RACK_DIR` with another **space-free** path (GNU Make and the stock `plugin.mk` break on spaces in `RACK_DIR`).
- **Haxe** and **hxcpp** (`haxelib install hxcpp`).

## Simulation rate vs audio rate

OpenFL **`GbloinkMain`** advances the sequencer on a **1 ms timer** (`Timer(1)`), and **`moveBall` applies velocity once per `advanceTime` call** (not × `delta`). The Rack port accumulates `args.sampleTime` and calls **`advanceTime` when a host-defined period elapses** (see `controlPeriodS` in `src/Gbloink.cpp`—currently **5 ms** for calmer motion than OpenFL’s 1 ms). **`delta` passed into `advanceTime` equals that period**, so `currentTime` and MIDI-style event ordering stay consistent. Gate output still uses **per-sample** `args.sampleTime` for trigger length.

Rack-specific tuning is done in the **host** (cadence and, later, optional setup args on the Haxe API)—**not** with `#if cpp` in shared WoC sources.

### hxcpp and threads

VCV’s **audio thread** is not the same OS thread as the UI. **hxcpp’s GC** must know about every thread that enters Haxe (`SetTopOfStack` / thread-local anchor). `src/Gbloink.cpp` calls `attachThisThreadToHxcpp()` on each C++ entry point that touches the Haxe runtime (audio `process`, UI draw/click, `step`, ctor/dtor). Without that, collisions + `trace`/allocations can **segfault** intermittently.

## Build

From this directory:

```bash
make
```

This runs **codegen** (`haxe haxe/gbloink.hxml -cpp ../../../build/vcvrack/gbloink/linux/native`) then links `build/vcvrack/gbloink/linux/plugin.so`. Default goal is `build` (not stock `all`), so codegen always runs first. Windows uses the corresponding `windows/` artifact tree through `build-rack-windows.ps1`.

Install into your Rack user plugins folder:

```bash
make install
```

(On Linux this uses `~/.local/share/Rack2/plugins-*` per the SDK `plugin.mk`.)

## Layout

| Path | Role |
|------|------|
| `haxe/` | Haxe sources (`vcvrack.gbloink.*`); add WoC `-cp` here later. |
| `../../../build/vcvrack/gbloink/<platform>/native/` | Generated output from haxe/hxcpp (**gitignored**): headers, `src/*.cpp`, and runtime `.o` files under `obj/<platform>/`. Linux and Windows artifacts coexist in separate trees. |
| `src/` | Rack plugin C++ (`plugin.cpp`, `Gbloink.cpp`, …). |
| `res/` | Panel SVG and assets. |

## If the module does not appear in Rack

Rack 2 log file (Linux):

`~/.local/share/Rack2/log.txt`

After starting Rack, search that file for your plugin slug (`WorldOfCake-Gbloink`) or `Failed to load`. A successful load shows no error for that path.

Confirm the install layout (version numbers may differ):

`~/.local/share/Rack2/plugins-lin-x64/WorldOfCake-Gbloink/plugin.json`  
`~/.local/share/Rack2/plugins-lin-x64/WorldOfCake-Gbloink/plugin.so`  
`~/.local/share/Rack2/plugins-lin-x64/WorldOfCake-Gbloink/res/`

Optional: check the binary resolves hxcpp symbols (should print nothing if OK):

`nm -u ../../../build/vcvrack/gbloink/linux/plugin.so | grep ZTIN2hx6ObjectE`  (run on an **unstripped** local build, e.g. right after `make` before `make dist`).
